#!/usr/bin/env python3
from pathlib import Path

path = Path("tools/host_harness.py")
text = path.read_text(encoding="utf-8")

old = '''# T24 A stale marker must not force byte-identical BDMA driver rewrites.
t24 = "local function FileBytesMatch" in SYS_SRC
bdma_pos = SYS_SRC.find("function PLDR.ApplyBdmaMode(mode_key)")
if bdma_pos < 0 or "FileBytesMatch(dest, bytes)" not in SYS_SRC[bdma_pos:bdma_pos + 7000]:
    t24 = False
check("T24 adaptive BDMA can skip byte-identical driver rewrites", t24)
'''
new = '''# T24 A stale marker must not force byte-identical BDMA driver rewrites.
t24 = "local function FileBytesMatch" in SYS_SRC
bdma_pos = SYS_SRC.find("function PLDR.ApplyBdmaMode(mode_key)")
if bdma_pos < 0:
    t24 = False
else:
    next_function = SYS_SRC.find("\\nfunction ", bdma_pos + 1)
    bdma_scope = SYS_SRC[bdma_pos:next_function if next_function != -1 else None]
    if "FileBytesMatch(dest, bytes)" not in bdma_scope:
        t24 = False
check("T24 adaptive BDMA can skip byte-identical driver rewrites", t24)
'''

count = text.count(old)
if count != 1:
    raise SystemExit(f"expected one T24 block, found {count}")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
print("Applied dynamic ApplyBdmaMode scoping to T24")
