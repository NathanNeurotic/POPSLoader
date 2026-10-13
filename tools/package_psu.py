#!/usr/bin/env python3
"""Build and verify a flat PS2 PSU from the POPSLoader app payload.

Ported from NathanNeurotic/Open-PS2-Loader/.github/scripts/package_release_app.py.
PSU includes a save-directory HEADER named PS1_POPSLOADER, not a nested folder.
All file records are direct children of that save directory.
"""
import argparse
import datetime as dt
import struct
from pathlib import Path

ENTRY = struct.Struct("<HHI8sII8sI28s448s")
DIR_MODE, FILE_MODE, CLUSTER = 0x8027, 0x8017, 1024
APP = "PS1_POPSLOADER"
FILES = {"POPSLOADER.ELF", "POPSTARTER.ELF", "icon.sys", "list.icn",
         "copy.icn", "del.icn", "title.cfg", "APPINFO.PBT"}
# Matches RiptOPL's SAS PS1_ category and timestamp ordering.
BASE = dt.datetime(2099, 1, 1, 7, 59, 59, tzinfo=dt.timezone.utc)
CATS = ("APP_", "APPS", "PS1_", "EMU_", "GME_", "DST_", "DBG_", "RAA_",
        "RTE_", "DEFAULT", "SYS_", "ZZY_", "ZZZ_")
CHARS = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-."
def timestamp():
    payload = APP[len("PS1_"):].replace("-", "")[:48]
    base = len(CHARS)
    rank = 0
    for c in payload:
        rank = rank * base + CHARS.index(c) + 1
    rank *= base ** (48 - len(payload))
    slot = min(rank * 86400 // base ** 48, 86399)
    when = BASE - dt.timedelta(seconds=CATS.index("PS1_") * 86400 + slot)
    return struct.pack("<BBBBBBH", 0, when.second, when.minute,
                       when.hour, when.day, when.month, when.year)

def entry(mode, length, date, name):
    if name not in (".", "..") and (not name.isascii() or len(name) > 31):
        raise ValueError("Invalid PS2 memory card filename: " + name)
    return ENTRY.pack(mode, 0, length, date, 0, 0, date, 0,
                      bytes(28), name.encode("ascii").ljust(448, b"\0"))

def read_app(folder):
    if not folder.is_dir():
        raise ValueError(f"Missing app directory: {folder}")
    names = {p.name for p in folder.iterdir()}
    if names != FILES or any(not p.is_file() or not p.stat().st_size for p in folder.iterdir()):
        raise ValueError(f"App files must be exactly {sorted(FILES)}; found {sorted(names)}")
    return {name: (folder / name).read_bytes() for name in sorted(FILES)}

def build(folder, destination):
    app = read_app(folder)
    date = timestamp()
    with destination.open("wb") as f:
        f.write(entry(DIR_MODE, len(app) + 2, date, APP))
        f.write(entry(DIR_MODE, 0, date, "."))
        f.write(entry(DIR_MODE, 0, date, ".."))
        for name, data in app.items():
            f.write(entry(FILE_MODE, len(data), date, name))
            f.write(data)
            f.write(bytes((-len(data)) % CLUSTER))
    if destination.stat().st_size >= 8 * 1024 * 1024:
        raise ValueError("PSU does not fit an 8 MiB PS2 memory card")
    verify(folder, destination)

def verify(folder, destination):
    source = read_app(folder)
    blob = destination.read_bytes()
    if len(blob) < 1536:
        raise ValueError("PSU is truncated")
    records = [ENTRY.unpack_from(blob, i * 512) for i in range(3)]
    name = lambda r: r[-1].split(b"\0", 1)[0].decode("ascii")
    if ([name(r) for r in records] != [APP, ".", ".."]
            or records[0][0] != DIR_MODE or records[0][2] != len(source) + 2
            or any(r[3] != timestamp() or r[6] != timestamp() for r in records)):
        raise ValueError("PSU header, save directory or timestamps mismatch")
    pos, found = 1536, {}
    for _ in source:
        if pos + 512 > len(blob):
            raise ValueError("Truncated PSU record")
        r = ENTRY.unpack_from(blob, pos)
        n, size = name(r), r[2]
        start = pos + 512
        end = start + size
        if r[0] != FILE_MODE or n in found or n not in FILES or end > len(blob):
            raise ValueError("Unexpected PSU file record")
        if r[3] != timestamp() or r[6] != timestamp():
            raise ValueError("Invalid PSU file timestamp")
        found[n] = blob[start:end]
        pos = start + ((size + 1023) // 1024) * 1024
    if pos != len(blob) or found != source:
        raise ValueError("PSU file payload differs from APPS directory")
    print(f"Verified {destination}: {APP} header, {len(found)} direct files, exact bytes")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=("build", "verify"))
    p.add_argument("folder", type=Path)
    p.add_argument("output", type=Path)
    a = p.parse_args()
    if a.action == "build":
        build(a.folder, a.output)
    else:
        verify(a.folder, a.output)
