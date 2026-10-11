#!/usr/bin/env python3
"""Read-only parity test for historic WIP06 OBT17 compatibility/fix records.

Usage:
 git -C /path/to/original/wiki show a005d6274eb845b6307fcdb1bad4a20b2a5f9d57:automated.textile > /tmp/automated-2017.textile
 python3 audit_original_wip06_2017.py /tmp/automated-2017.textile .research/wiki/automated.md

The input is a 2017 original *source revision*, not the later original HEAD.
Compares entire normalized game-entry text, preserving duplicates and game revisions.
"""
import argparse
from collections import Counter
from hashlib import sha256
from pathlib import Path
import re
import unicodedata

START = "## Changelog / version history (from the 2017-06-29 snapshot)"
DISC = re.compile(r"\b(?:SCES|SCPS|SCUS|SIPS|SLES|SLPM|SLPS|SLUS|SLED|PAPX)-\d{5}\b")


def canon(s):
    s = unicodedata.normalize("NFKC", s)
    s = s.replace("×", "x").replace("–", "-").replace("—", "-").replace("’", "'")
    return " ".join(s.split())


def source_rows(s):
    return [canon(line[2:]) for line in s.splitlines() if line.startswith("* ")]


def recovered_rows(s):
    if s.count(START) != 1:
        raise ValueError("Missing or ambiguous recovered 2017 history section")
    section = s.split(START, 1)[1]
    return [canon(line[2:]) for line in section.splitlines() if line.startswith("- ")]


def digest(rows):
    return sha256("\n".join(sorted(rows)).encode("utf-8")).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("original_2017_textile", type=Path)
    ap.add_argument("recovered_markdown", type=Path)
    args = ap.parse_args()
    original = source_rows(args.original_2017_textile.read_text(encoding="utf-8"))
    recovered = recovered_rows(args.recovered_markdown.read_text(encoding="utf-8"))
    missing = list((Counter(original) - Counter(recovered)).elements())
    unexpected = list((Counter(recovered) - Counter(original)).elements())
    src_ids = set(DISC.findall("\n".join(original)))
    rec_ids = set(DISC.findall("\n".join(recovered)))
    good = (len(original) == 497 and len(recovered) == 497
            and not missing and not unexpected and len(src_ids) == 460 and src_ids == rec_ids)
    print("2017 OBT17 original:", len(original), "rows,", len(src_ids), "distinct disc IDs")
    print("Recovered historical:", len(recovered), "rows,", len(rec_ids), "distinct disc IDs")
    print("Original SHA-256: ", digest(original))
    print("Recovered SHA-256:", digest(recovered))
    print("Result:", "PASS" if good else "DIFF")
    for label, items in (("missing", missing), ("unexpected", unexpected)):
        for item in items:
            print(label, item)
    return 0 if good else 1


if __name__ == "__main__":
    raise SystemExit(main())
