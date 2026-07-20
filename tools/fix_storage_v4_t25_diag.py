#!/usr/bin/env python3
from pathlib import Path

path = Path("tools/apply_storage_fix_v4.py")
text = path.read_text(encoding="utf-8")

old = '''  return type(captured) == "table"
     and captured.path == "mc0:/POPSTARTER/POPSTARTER.ELF"
     and captured.reboot == 1
     and captured.selector == "mass:/POPS/XX.Test Game.ELF"
'''
new = '''  print("T25_CAPTURE path="..tostring(captured and captured.path)
    .." reboot="..tostring(captured and captured.reboot)
    .." selector="..tostring(captured and captured.selector))
  return type(captured) == "table"
     and captured.path == "mc0:/POPSTARTER/POPSTARTER.ELF"
     and captured.reboot == 1
     and captured.selector == "mass:/POPS/XX.Test Game.ELF"
'''
if text.count(old) != 1:
    raise SystemExit(f"expected one T25 return block, found {text.count(old)}")
text = text.replace(old, new, 1)

old_t27 = '''ata_lua_start = SYS_SRC.index('if mode == "ata" then')
ata_lua_end = SYS_SRC.index('return\\n  end', ata_lua_start)
'''
new_t27 = '''ata_fn_start = SYS_SRC.index("local function EnsureMassBackendsReady(mode)")
ata_lua_start = SYS_SRC.index('if mode == "ata" then', ata_fn_start)
ata_lua_end = SYS_SRC.index('return\\n  end', ata_lua_start)
'''
if text.count(old_t27) != 1:
    raise SystemExit(f"expected one T27 anchor block, found {text.count(old_t27)}")
text = text.replace(old_t27, new_t27, 1)

path.write_text(text, encoding="utf-8")
print("Added T25 capture diagnostics and corrected T27 anchor")
