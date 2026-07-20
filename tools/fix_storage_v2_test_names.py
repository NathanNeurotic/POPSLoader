#!/usr/bin/env python3
from pathlib import Path

path = Path("tools/host_harness.py")
text = path.read_text(encoding="utf-8")

replacements = {
    '(ROOT / "src" / "main.cpp")': '(REPO / "src" / "main.cpp")',
    '(ROOT / "src" / "luasystem.cpp")': '(REPO / "src" / "luasystem.cpp")',
    'SYSTEM_SRC': 'SYS_SRC',
}

for old, new in replacements.items():
    count = text.count(old)
    if count == 0:
        raise SystemExit(f"missing harness token: {old}")
    text = text.replace(old, new)

path.write_text(text, encoding="utf-8")
print("Corrected hardware follow-up harness identifiers")
