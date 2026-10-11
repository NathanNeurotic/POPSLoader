#!/usr/bin/env python3
"""Read-only exact game-entry parity for the original POPStarter automated wiki.

Use the UNMODIFIED AstroSnail original Bitbucket Git wiki checkout and a
POPSLoader checkout. This checks names, disc IDs, versions, annotations and
automatic-mode/fix text as entire rows, including duplicate-row multiplicity.

Usage:
  python3 .research/tools/audit_original_automated_parity.py \
    /path/to/original/wiki/automated.textile .research/wiki/automated.md

No network access, output files, repository mutation, or game compatibility
claims. The four explicitly labelled 2017-only recovered rows are reported
separately, and no other unmatched rows are silently allowed.
"""
import argparse
from collections import Counter
from hashlib import sha256
from pathlib import Path

ORIGINAL = (
    ("compatibility modes", "h3. _Compatibility modes :_",
     "h3. _LibCrypt fixes :_"),
    ("LibCrypt fixes", "h3. _LibCrypt fixes :_",
     "h3. _Miscellaneous fixes :_"),
    ("miscellaneous fixes", "h3. _Miscellaneous fixes :_",
     'h3. "*Index*"'),
)
RECOVERED = (
    ("compatibility modes", "### *Compatibility modes :*",
     "### *LibCrypt fixes :*"),
    ("LibCrypt fixes", "### *LibCrypt fixes :*",
     "### *Miscellaneous fixes :*"),
    ("miscellaneous fixes", "### *Miscellaneous fixes :*",
     "## Changelog / version history (from the 2017-06-29 snapshot)"),
)
EXPECTED_2017_ONLY = {
    "Dance Dance Revolution: Disney's Rave (SLPM-86667) : $COMPATIBILITY_0x06",
    "Dance Dance Revolution: Disney's Rave (SLPM-86667, R18) : $COMPATIBILITY_0x06",
    "DonPachi (SLPS-00548) : $COMPATIBILITY_0x06",
    "Tobal 2 v1.1 (SLPM-86033) : $COMPATIBILITY_0x06",
}
EXTRA_SUFFIX = " *(from 2017 snapshot)*"

def between(content, first, last):
    if content.count(first) != 1 or content.count(last) != 1:
        raise ValueError(f"Expected exactly one section delimiter: {first!r} / {last!r}")
    return content.split(first, 1)[1].split(last, 1)[0]

def source_rows(content, group):
    _, first, last = ORIGINAL[group]
    return [line[2:].strip() for line in between(content, first, last).splitlines()
            if line.startswith("* ")]

def recovered_rows(content, group):
    _, first, last = RECOVERED[group]
    rows = [line[2:].strip().replace("×", "x")
            for line in between(content, first, last).splitlines()
            if line.startswith("- ")]
    regular, historical = [], []
    for line in rows:
        if line.endswith(EXTRA_SUFFIX):
            historical.append(line.removesuffix(EXTRA_SUFFIX))
        else:
            regular.append(line)
    return regular, historical

def digest(rows):
    return sha256("\n".join(sorted(rows)).encode("utf-8")).hexdigest()

def differences(expected, observed):
    return list((Counter(expected) - Counter(observed)).elements())

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original_textile", type=Path)
    parser.add_argument("recovered_markdown", type=Path)
    args = parser.parse_args()
    src = args.original_textile.read_text(encoding="utf-8")
    dst = args.recovered_markdown.read_text(encoding="utf-8")
    okay = True
    totals = [0, 0]
    for i, (name, _, _) in enumerate(ORIGINAL):
        old = source_rows(src, i)
        new, extra = recovered_rows(dst, i)
        missing = differences(old, new)
        added = differences(new, old)
        invalid_extras = sorted(set(extra) - EXPECTED_2017_ONLY)
        missing_extras = sorted(EXPECTED_2017_ONLY - set(extra)) if i == 0 else []
        if i != 0 and extra:
            invalid_extras += extra
        passed = not (missing or added or invalid_extras or missing_extras)
        okay &= passed
        totals[0] += len(old)
        totals[1] += len(new)
        print(f"{name}: {len(old)} original; {len(new)} recovered; "
              f"{len(extra)} attributed historical additions; "
              f"{'PASS' if passed else 'DIFF'}")
        print(f"  original SHA-256:  {digest(old)}")
        print(f"  recovered SHA-256: {digest(new)}")
        for label, values in (("missing rows", missing), ("unattributed rows", added),
                              ("invalid historical extras", invalid_extras),
                              ("missing labelled extras", missing_extras)):
            for value in values:
                print(f"  {label}: {value}")
    print(f"TOTAL {totals[0]} original, {totals[1]} matched recovered: "
          f"{'PASS' if okay else 'DIFF'}")
    return 0 if okay else 1

if __name__ == "__main__":
    raise SystemExit(main())
