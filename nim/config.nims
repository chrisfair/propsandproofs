--nimblePath: "../.nimble/pkgs2"
--path: "src"

import gdext/buildconf

let setting = BuildSettings(
  name: "PropsAndProofs"
)

configure(setting)
