#!/usr/bin/env python3
from pathlib import Path

path = Path("tools/apply_storage_fix_v4.py")
text = path.read_text(encoding="utf-8")

changes = [
    (
        '  local raw_confirm = UI.Pad.Events.CONFIRM\n  local captured = nil',
        '  local raw_confirm = UI.Pad.Events.CONFIRM\n  local raw_input = Input_GetEvent\n  local raw_resolve = PLDR.ResolveLaunchPopstarterPath\n  local raw_probe = PLDR.PopstarterProbeWithEnsure\n  local raw_stage = PLDR.MaybeApplyAdaptiveBdma\n  local captured = nil',
    ),
    (
        '  UI.Pad.Events.CONFIRM = true\n  System.loadELF = function(path, reboot_iop, selector)',
        '  UI.Pad.Events.CONFIRM = true\n  Input_GetEvent = function() return 0 end\n  PLDR.ResolveLaunchPopstarterPath = function() return "mc0:/POPSTARTER/POPSTARTER.ELF" end\n  PLDR.PopstarterProbeWithEnsure = function() return true end\n  PLDR.MaybeApplyAdaptiveBdma = function() return true end\n  System.loadELF = function(path, reboot_iop, selector)',
    ),
    (
        '  UI.Pad.Events.CONFIRM = raw_confirm\n\n  return type(captured)',
        '  UI.Pad.Events.CONFIRM = raw_confirm\n  Input_GetEvent = raw_input\n  PLDR.ResolveLaunchPopstarterPath = raw_resolve\n  PLDR.PopstarterProbeWithEnsure = raw_probe\n  PLDR.MaybeApplyAdaptiveBdma = raw_stage\n\n  print("T25_CAPTURE path="..tostring(captured and captured.path)\n    .." reboot="..tostring(captured and captured.reboot)\n    .." selector="..tostring(captured and captured.selector))\n  return type(captured)',
    ),
    (
        '''ata_lua_start = SYS_SRC.index('if mode == "ata" then')
ata_lua_end = SYS_SRC.index('return\\n  end', ata_lua_start)
ata_lua = SYS_SRC[ata_lua_start:ata_lua_end]
if not (ata_lua.index("System.ensureBDMFatFs") < ata_lua.index("System.ensureDev9") < ata_lua.index("System.initATA")):
    t27 = False
    print("    T27 FAIL: Lua ATA staging order differs from native lazy order")
''',
        '''ata_fn_start = SYS_SRC.index("local function EnsureMassBackendsReady(mode)")
ata_fn_end = SYS_SRC.index("local function WaitMassProbeRetry", ata_fn_start)
ata_lua = SYS_SRC[ata_fn_start:ata_fn_end]
pos_bdm = ata_lua.find("System.ensureBDMFatFs")
pos_dev9 = ata_lua.find("System.ensureDev9")
pos_ata = ata_lua.find("System.initATA")
if not (pos_bdm >= 0 and pos_bdm < pos_dev9 < pos_ata):
    t27 = False
    print(f"    T27 FAIL: positions bdm={pos_bdm} dev9={pos_dev9} ata={pos_ata}")
''',
    ),
]

for old, new in changes:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one T25/T27 token, found {count}: {old[:90]}")
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
print("Isolated T25 handoff contract and corrected T27 function-scope check")
