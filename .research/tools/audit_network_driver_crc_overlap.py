#!/usr/bin/env python3
"""Read-only CRC/size crosswalk for POPStarter's hosted 7z and 2020 SMB ZIP.

Uses the already checked directory-only 7z parser; ZIP entries are read from
its central directory. Neither archive's driver payload is decompressed,
executed, or rewritten. Matching stored CRC metadata strongly suggests
identical driver bytes but does not prove collision-free SHA-256 equivalence.

python3 .research/tools/audit_network_driver_crc_overlap.py \
  .research/downloads/network_modules.7z \
  .research/downloads/POPStarter_SMB_Quickstarter_Pack_20200209.zip
"""
import argparse
from pathlib import Path
from zipfile import ZipFile

from inspect_network_modules_header import manifest

SIX = {
    "poweroff.irx",
    "ps2dev9.irx",
    "ps2ip.irx",
    "ps2smap.irx",
    "smbman.irx",
    "smsutils.irx",
}


def compare(seven_zip, quickstarter):
    entries, _ = manifest(Path(seven_zip).read_bytes())
    seven = {}
    for name, size, crc in entries:
        key = name.rsplit("/", 1)[-1].casefold()
        if key in SIX:
            if key in seven:
                raise ValueError("Duplicate 7z driver: " + key)
            seven[key] = (size, crc)
    with ZipFile(quickstarter) as z:
        records = z.infolist()
    zipped = {}
    for e in records:
        path = e.filename.replace("\\", "/").casefold()
        if "/network_modules/mc0/popstarter/" not in path:
            continue
        key = path.rsplit("/", 1)[-1]
        if key in SIX:
            if key in zipped:
                raise ValueError("Duplicate ZIP driver: " + key)
            zipped[key] = (e.file_size, e.CRC)
    if set(zipped) != SIX or set(seven) != SIX:
        print("Expected drivers:", sorted(SIX))
        print("7z driver names:", sorted(seven))
        print("ZIP driver names:", sorted(zipped))
        return 1
    failures = []
    for key in sorted(SIX):
        a, b = seven[key], zipped[key]
        good = a == b
        print(f"{key:16} 7z={a[0]:>6} bytes / {a[1]:08X}  "
              f"2020-ZIP={b[0]:>6} bytes / {b[1]:08X} "
              f"{'MATCH' if good else 'DIFF'}")
        if not good:
            failures.append(key)
    print(f"Result: {len(SIX)-len(failures)}/{len(SIX)} "
          "size/stored-CRC32 matches")
    print("Caution: these are directory CRC values, not recomputed member hashes.")
    return 1 if failures else 0


def main():
    a = argparse.ArgumentParser(description=__doc__)
    a.add_argument("hosted_network_7z", type=Path)
    a.add_argument("hosted_2020_smb_zip", type=Path)
    o = a.parse_args()
    return compare(o.hosted_network_7z, o.hosted_2020_smb_zip)


if __name__ == "__main__":
    raise SystemExit(main())
