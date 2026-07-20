#!/usr/bin/env python3
from pathlib import Path

path = Path("tools/apply_storage_readiness_followup.py")
text = path.read_text(encoding="utf-8")

old_open = "addition = r'''"
new_open = 'addition = r"""'
if text.count(old_open) != 1:
    raise SystemExit(f"expected one addition opener, found {text.count(old_open)}")
text = text.replace(old_open, new_open, 1)

old_close = "\nprint()\n'''\nharness = replace_once(harness, anchor, addition, \"host harness storage follow-up tests\")"
new_close = "\nprint()\n\"\"\"\nharness = replace_once(harness, anchor, addition, \"host harness storage follow-up tests\")"
if text.count(old_close) != 1:
    raise SystemExit(f"expected one addition closer, found {text.count(old_close)}")
text = text.replace(old_close, new_close, 1)

path.write_text(text, encoding="utf-8")
print("Repaired readiness applicator test-block quoting")
