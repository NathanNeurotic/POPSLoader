#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

ALLOWED_CTRL = {0x09, 0x0A, 0x0D}
SMART_PUNCT = {
    0x2018: "'",  # left single quote
    0x2019: "'",  # right single quote
    0x201C: '"',   # left double quote
    0x201D: '"',   # right double quote
    0x2013: '-',   # en dash
    0x2014: '-',   # em dash
    0x2026: '...', # ellipsis
    0x2022: '-',   # bullet
    0x2011: '-',   # non-breaking hyphen
}


def iter_lua_files(root: Path) -> list[Path]:
    return sorted([p for p in root.rglob("*.lua") if p.is_file()])


def check_file(path: Path, check_punct: bool) -> list[str]:
    issues: list[str] = []
    raw = path.read_bytes()

    if raw.startswith(b"\xef\xbb\xbf"):
        issues.append("BOM present (UTF-8 BOM not allowed)")

    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        issues.append(f"invalid UTF-8 at byte {e.start}")
        return issues

    for idx, b in enumerate(raw):
        if b < 0x20 and b not in ALLOWED_CTRL:
            issues.append(f"disallowed control char 0x{b:02X} at byte {idx}")
            break

    if check_punct:
        for i, ch in enumerate(text):
            cp = ord(ch)
            if cp in SMART_PUNCT:
                issues.append(f"smart/high punctuation U+{cp:04X} at char {i}")
                break

    return issues


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate Lua file encoding/integrity.")
    ap.add_argument("--root", default=".", help="repository root")
    ap.add_argument("--check-punctuation", action="store_true", help="also fail on smart/high punctuation")
    args = ap.parse_args()

    root = Path(args.root)
    files = iter_lua_files(root)
    bad = 0
    for f in files:
        issues = check_file(f, args.check_punctuation)
        if issues:
            bad += 1
            print(f"[FAIL] {f}")
            for issue in issues:
                print(f"  - {issue}")

    if bad:
        print(f"\nLua integrity check failed: {bad} file(s) with issues.")
        return 1

    print(f"Lua integrity check passed: {len(files)} file(s) scanned.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
