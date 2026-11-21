#!/usr/bin/env python3
"""Patch gdext-nim v0.17.1 for Nim 2.4+ compatibility (macros, distinct ClassInstancePtr, and early NimMain init)."""
import os
import sys

root = sys.argv[1]

ib_path = os.path.join(root, "src", "gdext", "private", "internalbridge.nim")
with open(ib_path, "r", encoding="utf-8") as fh:
    ib = fh.read()

ib = ib.replace(
    'editorhint = field.getPragmaVal("gdexport") or (quote do: Appearance())',
    'editorhint = block:\n          let pv = field.getPragmaVal("gdexport")\n          if pv.isNil: newCall(bindSym"Appearance") else: pv',
)
ib = ib.replace(
    "proc free_instance_func[T: SomeUserClass](p_userdata: pointer; p_instance: pointer)",
    "proc free_instance_func[T: SomeUserClass](p_userdata: pointer; p_instance: ClassInstancePtr)",
)
ib = ib.replace(
    "result = cast[pointer](class)",
    "result = cast[ClassInstancePtr](class)",
)
ib = ib.replace(
    "proc reference_func(p_instance: pointer)",
    "proc reference_func(p_instance: ClassInstancePtr)",
)
ib = ib.replace(
    "proc unreference_func(p_instance: pointer)",
    "proc unreference_func(p_instance: ClassInstancePtr)",
)
with open(ib_path, "w", encoding="utf-8") as fh:
    fh.write(ib)

gd_path = os.path.join(root, "src", "gdext.nim")
with open(gd_path, "r", encoding="utf-8") as fh:
    gd = fh.read()

gd = gd.replace('      {.emit: "NimMain();".}\n', "")
target_ep = (
    "  proc entryPoint(p_get_proc_address: InterfaceGetProcAddress; p_library: ClassLibraryPtr; "
    "r_initialization: ptr Initialization): Bool {.gdcall, exportc: Extension.entrySymbol, dynlib.} = once:\n"
    "    try:\n"
)
replacement_ep = (
    "  proc entryPoint(p_get_proc_address: InterfaceGetProcAddress; p_library: ClassLibraryPtr; "
    "r_initialization: ptr Initialization): Bool {.gdcall, exportc: Extension.entrySymbol, dynlib.} = once:\n"
    '    {.emit: "NimMain();".}\n'
    "    try:\n"
)
if '{.emit: "NimMain();".}' not in gd:
    assert target_ep in gd, "Failed to locate entryPoint in gdext.nim"
    gd = gd.replace(target_ep, replacement_ep, 1)

with open(gd_path, "w", encoding="utf-8") as fh:
    fh.write(gd)
