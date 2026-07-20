#!/usr/bin/env python3
from pathlib import Path

path = Path("tools/apply_storage_fix_v4.py")
text = path.read_text(encoding="utf-8")

changes = [
    (
        '  local raw_confirm = UI.Pad.Events.CONFIRM\n  local captured = nil',
        '  local raw_confirm = UI.Pad.Events.CONFIRM\n  local raw_input = Input_GetEvent\n  local captured = nil',
    ),
    (
        '  UI.Pad.Events.CONFIRM = true\n  System.loadELF = function(path, reboot_iop, selector)',
        '  UI.Pad.Events.CONFIRM = true\n  Input_GetEvent = function() return 0 end\n  System.loadELF = function(path, reboot_iop, selector)',
    ),
    (
        '  UI.Pad.Events.CONFIRM = raw_confirm\n\n  return type(captured)',
        '  UI.Pad.Events.CONFIRM = raw_confirm\n  Input_GetEvent = raw_input\n\n  print("T25_CAPTURE path="..tostring(captured and captured.path)\n    .." reboot="..tostring(captured and captured.reboot)\n    .." selector="..tostring(captured and captured.selector))\n  return type(captured)',
    ),
    (
        '''ata_lua_start = SYS_SRC.index('if mode == "ata" then')
ata_lua_end = SYS_SRC.index('return\\n  end', ata_lua_start)
''',
        '''ata_fn_start = SYS_SRC.index("local function EnsureMassBackendsReady(mode)")
ata_lua_start = SYS_SRC.index('if mode == "ata" then', ata_fn_start)
ata_lua_end = SYS_SRC.index('return\\n  end', ata_lua_start)
''',
    ),
]

for old, new in changes:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one T25/T27 token, found {count}: {old[:70]}")
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
print("Isolated T25 callback, enabled capture output, and corrected T27 anchor")
