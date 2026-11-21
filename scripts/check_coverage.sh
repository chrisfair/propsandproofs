#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CACHE_DIR="${NIMCACHE_TEST_DIR:-${ROOT_DIR}/build/nimcache_cov}"
COV_DIR="${COVERAGE_DIR:-${ROOT_DIR}/build/coverage}"
MIN_PCT="${COVERAGE_MIN_PCT:-85.0}"

rm -rf "${CACHE_DIR}" "${COV_DIR}"
mkdir -p "${CACHE_DIR}" "${COV_DIR}"

echo "==> [1/3] Compiling & running Nim unit test suite with gcov instrumentation..."
nim c -r \
  --path:nim/src \
  --debugger:native \
  --lineDir:on \
  --opt:none \
  --passC:--coverage \
  --passL:--coverage \
  --nimCache:"${CACHE_DIR}" \
  -o:"${COV_DIR}/test_runner_cov" \
  tests/test_all.nim

echo ""
echo "==> [2/3] Generating .nim.gcov line reports from GCC profile counters..."
(
  cd "${COV_DIR}"
  for gcno in "${CACHE_DIR}"/@m*sim*.nim.c.gcno; do
    gcov -l -o "${CACHE_DIR}" "${gcno}" >/dev/null
  done
)

echo "==> [3/3] Aggregating Nim source coverage across nim/src/sim/*.nim..."
python3 - "${ROOT_DIR}" "${COV_DIR}" "${MIN_PCT}" <<'PY'
import glob
import json
import os
import sys

root_dir, cov_dir, min_pct_str = sys.argv[1], sys.argv[2], sys.argv[3]
min_pct = float(min_pct_str)
sim_dir = os.path.realpath(os.path.join(root_dir, "nim", "src", "sim"))

file_lines: dict[str, dict[int, int]] = {}

for gcov_path in sorted(glob.glob(os.path.join(cov_dir, "*.nim.gcov"))):
    source_path = None
    with open(gcov_path, "r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            if ":Source:" in raw:
                src = raw.split(":Source:", 1)[1].strip()
                real_src = os.path.realpath(src)
                if real_src.startswith(sim_dir + os.sep) and real_src.endswith(".nim"):
                    source_path = real_src
                    file_lines.setdefault(source_path, {})
                break
        if not source_path:
            continue

        fh.seek(0)
        lines_map = file_lines[source_path]
        for raw in fh:
            parts = raw.split(":", 2)
            if len(parts) < 3:
                continue
            cnt_s = parts[0].strip()
            lno_s = parts[1].strip()
            code_s = parts[2].strip()
            if not lno_s.isdigit():
                continue
            lno = int(lno_s)
            if lno <= 0 or cnt_s == "-":
                continue
            if not code_s or code_s.startswith("#"):
                continue
            if cnt_s.startswith("#") or cnt_s.startswith("="):
                lines_map.setdefault(lno, 0)
            else:
                digits = "".join(ch for ch in cnt_s if ch.isdigit())
                hits = int(digits) if digits else 0
                lines_map[lno] = max(lines_map.get(lno, 0), hits)

if not file_lines:
    print("ERROR: No .nim.gcov coverage files found for nim/src/sim!", file=sys.stderr)
    sys.exit(1)

rows = []
total_exec = 0
total_hit = 0
for path in sorted(file_lines.keys()):
    rel = os.path.relpath(path, root_dir)
    lmap = file_lines[path]
    executable = len(lmap)
    covered = sum(1 for v in lmap.values() if v > 0)
    pct = (100.0 * covered / executable) if executable > 0 else 100.0
    total_exec += executable
    total_hit += covered
    missed = sorted(k for k, v in lmap.items() if v == 0)
    rows.append({
        "file": rel,
        "coveredLines": covered,
        "executableLines": executable,
        "coveragePct": round(pct, 2),
        "missedSample": missed[:12],
    })

overall_pct = (100.0 * total_hit / total_exec) if total_exec > 0 else 0.0

print("------------------------------------------------------------------")
print(f"{'Module':<34} {'Covered':>11} {'Coverage':>10}")
print("------------------------------------------------------------------")
for r in rows:
    ratio = f"{r['coveredLines']}/{r['executableLines']}"
    print(f"{r['file']:<34} {ratio:>11} {r['coveragePct']:>9.2f}%")
print("------------------------------------------------------------------")
tot_ratio = f"{total_hit}/{total_exec}"
print(f"{'TOTAL (Nim Backend)':<34} {tot_ratio:>11} {overall_pct:>9.2f}%  (min {min_pct:.1f}%)")
print("------------------------------------------------------------------")

summary = {
    "overallCoveragePct": round(overall_pct, 2),
    "thresholdPct": min_pct,
    "coveredLines": total_hit,
    "executableLines": total_exec,
    "modules": rows,
}
with open(os.path.join(cov_dir, "summary.json"), "w", encoding="utf-8") as fh:
    json.dump(summary, fh, indent=2)

md = [
    "# Props & Proofs — Nim Coverage Report",
    "",
    "| Module | Covered / Executable | Line Coverage |",
    "| :--- | ---: | ---: |",
]
for r in rows:
    md.append(f"| `{r['file']}` | {r['coveredLines']} / {r['executableLines']} | **{r['coveragePct']:.2f}%** |")
md.append(f"| **Total** | **{total_hit} / {total_exec}** | **{overall_pct:.2f}%** (gate >= {min_pct:.1f}%) |")
with open(os.path.join(cov_dir, "summary.md"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(md) + "\n")

if overall_pct < min_pct:
    print(f"\nFAIL: Coverage {overall_pct:.2f}% is below required {min_pct:.1f}%", file=sys.stderr)
    for r in rows:
        if r["missedSample"]:
            print(f"  Missed lines in {r['file']}: {r['missedSample']}", file=sys.stderr)
    sys.exit(1)

print(f"\nPASS: Nim backend line coverage is {overall_pct:.2f}% (>= {min_pct:.1f}%).")
PY
