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
        '  UI.Pad.Events.CONFIRM = raw_confirm\n  Input_GetEvent = raw_input\n\n  return type(captured)',
    ),
]

for old, new in changes:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one T25 input token, found {count}: {old[:50]}")
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
print("Isolated T25 launch-return input callback")
