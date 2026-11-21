#!/usr/bin/env bash
set -euo pipefail

PKGNAME="propsandproofs"
AUR_REPO="ssh://aur@aur.archlinux.org/${PKGNAME}.git"
CLONE_DIR="/tmp/aur-${PKGNAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

VERSION=$(grep -E '^pkgver=' PKGBUILD | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
GDEXT_SUM="e446f3d682e49c609552bee599d21de01ebc86b47889559ab267655b3e887f2d"

echo "==> Publishing ${PKGNAME} v${VERSION} to AUR (${AUR_REPO})..."

if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: Git working directory is not clean. Commit all changes before running push-aur.sh." >&2
    exit 1
fi

if ! git rev-parse "v${VERSION}" >/dev/null 2>&1; then
    echo "ERROR: Local git tag v${VERSION} does not exist. Create and push the tag first." >&2
    exit 1
fi

if ! git ls-remote --tags origin "refs/tags/v${VERSION}" | grep -q "v${VERSION}"; then
    echo "ERROR: Remote tag v${VERSION} has not been pushed to origin yet." >&2
    exit 1
fi

TAG_URL="https://github.com/chrisfair/${PKGNAME}/archive/refs/tags/v${VERSION}.tar.gz"
echo "==> Fetching live tarball SHA256 from ${TAG_URL}..."
SUM=$(curl -fsSL --retry 5 --retry-delay 2 "${TAG_URL}" | sha256sum | awk '{print $1}')

if [ -z "${SUM}" ] || [ "${#SUM}" -ne 64 ]; then
    echo "ERROR: Failed to calculate live SHA256 from ${TAG_URL}" >&2
    exit 1
fi

echo "==> Live GitHub tarball SHA256: ${SUM}"
python3 - "${SUM}" "${GDEXT_SUM}" <<'PY'
import re, sys
pkg_sum, gdext_sum = sys.argv[1], sys.argv[2]
with open("PKGBUILD", "r", encoding="utf-8") as fh:
    txt = fh.read()
replacement = f"sha256sums=(\n  '{pkg_sum}'\n  '{gdext_sum}'\n)"
txt = re.sub(r"sha256sums=\([^)]*\)", replacement, txt, count=1)
with open("PKGBUILD", "w", encoding="utf-8") as fh:
    fh.write(txt)
PY

echo "==> Regenerating .SRCINFO..."
makepkg --printsrcinfo > .SRCINFO

if [ -n "$(git status --porcelain PKGBUILD .SRCINFO)" ]; then
    git add PKGBUILD .SRCINFO
    git commit -m "Update PKGBUILD and .SRCINFO checksums for v${VERSION}"
    git push origin main
fi

rm -rf "${CLONE_DIR}"
git clone "${AUR_REPO}" "${CLONE_DIR}"
git -C "${CLONE_DIR}" checkout -B master

cp PKGBUILD "${CLONE_DIR}/PKGBUILD"
cp .SRCINFO "${CLONE_DIR}/.SRCINFO"

echo "==> Verifying archive checksum, prepare(), build(), check(), and package() in ${CLONE_DIR}..."
MAKEPKG_EXTRA=()
if ! pacman -Q nim >/dev/null 2>&1 && command -v nim >/dev/null 2>&1; then
    MAKEPKG_EXTRA+=("-d")
fi
(cd "${CLONE_DIR}" && makepkg -f -C --noconfirm "${MAKEPKG_EXTRA[@]}")

rm -rf "${CLONE_DIR}/src" "${CLONE_DIR}/pkg" "${CLONE_DIR}"/*.tar.* "${CLONE_DIR}"/*.pkg.*

git -C "${CLONE_DIR}" add PKGBUILD .SRCINFO
if [ -n "$(git -C "${CLONE_DIR}" status --porcelain)" ]; then
    git -C "${CLONE_DIR}" -c user.name="Christopher Patrick Fair" -c user.email="christopherpatrickfair@gmail.com" commit -m "Release v${VERSION}"
    git -C "${CLONE_DIR}" push -u origin master
    echo "==> Published ${PKGNAME} v${VERSION} to AUR."
else
    echo "==> AUR repository is already at v${VERSION}."
fi
