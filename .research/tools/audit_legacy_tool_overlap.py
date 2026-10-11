#!/usr/bin/env python3
"""Read-only source-to-source payload matching for three unresolved old .7z tools.

Compare decompressed member SHA-256 from 3 already-published, Git-pinned
Pages-only archive files against members of already-tracked ZIP/7z packages.
Does not execute binaries, extract members to disk, authenticate old Bitbucket
uploads, claim safety, or promote files for download.
"""
from pathlib import Path, PurePosixPath
from io import BytesIO
import argparse
import hashlib
import shutil
import subprocess
import sys
from zipfile import ZipFile

TARGETS = (
    "BATCHER_0.3.1.EXE.7z",
    "DEBUG_AND_HALT.7z",
    "uLE_kHn_20191110_2.7z",
)
EXTERNAL_MAX_BYTES = 16_000_000
MAX_MEMBER_NAMES = 1000


def sha(body):
    return hashlib.sha256(body).hexdigest()


def normal(path):
    s = path.replace("\\", "/")
    parts = PurePosixPath(s).parts
    if not s or s.startswith("/") or any(part in ("..", ".") for part in parts):
        raise ValueError("Unsafe path: " + path)
    return PurePosixPath(s).name.casefold()


def seven_list(path, exe):
    proc = subprocess.run([exe, "l", "-slt", str(path)],
                          capture_output=True, text=True, timeout=60)
    if proc.returncode or "----------" not in proc.stdout:
        raise ValueError("Failed to inspect " + str(path))
    items = []
    for block in proc.stdout.split("----------", 1)[1].split("\n\n"):
        fields = {}
        for row in block.splitlines():
            if " = " in row:
                k, v = row.split(" = ", 1)
                fields[k] = v
        name = fields.get("Path")
        if not name or fields.get("Folder") == "+":
            continue
        if len(items) >= MAX_MEMBER_NAMES:
            raise ValueError("Too many members")
        length = int(fields.get("Size", "-1"))
        if length < 0 or length > EXTERNAL_MAX_BYTES:
            raise ValueError("Member too large or unknown: " + name)
        items.append((name, length, fields.get("CRC")))
    names = [n.replace("\\", "/").rstrip("/") for n, _, _ in items]
    return [(name, length) for (name, length, crc), q in zip(items, names)
            if not (length == 0 and not crc and
                    any(other.startswith(q + "/") for other in names))]


def seven_bytes(exe, archive, member, expected):
    p = subprocess.run([exe, "x", "-so", "-bd", str(archive), member],
                       capture_output=True, timeout=90)
    if p.returncode or len(p.stdout) != expected:
        raise ValueError("Member 7z decode error: " + str(archive) + "::" + member)
    return p.stdout


def zip_list(path):
    with ZipFile(path) as z:
        return [(i.filename, i.file_size) for i in z.infolist()
                if not i.is_dir() and i.file_size <= EXTERNAL_MAX_BYTES]


def zip_bytes(path, member, expected):
    with ZipFile(path) as z:
        with z.open(member) as f:
            body = f.read(EXTERNAL_MAX_BYTES + 1)
    if len(body) != expected:
        raise ValueError("ZIP decompressed member size changed")
    return body


def members(path, exe):
    if path.suffix.lower() == ".7z":
        return seven_list(path, exe)
    if path.suffix.lower() == ".zip":
        return zip_list(path)
    return []


def member_bytes(path, member, length, exe):
    return seven_bytes(exe, path, member, length) if path.suffix.lower() == ".7z" \
           else zip_bytes(path, member, length)


def audit(site, research):
    exe = next((shutil.which(n) for n in ("7zz", "7z", "7za") if shutil.which(n)), None)
    if not exe:
        raise ValueError("7-Zip required")
    originals = {}
    for f in TARGETS:
        archive = site / "downloads" / f
        if not archive.is_file():
            raise ValueError("Missing pinned legacy file: " + str(archive))
        paths = members(archive, exe)
        if len(paths) != 1:
            raise ValueError("Expected one payload member in " + f)
        name, size = paths[0]
        payload = member_bytes(archive, name, size, exe)
        key = normal(name)
        originals[f] = (key, sha(payload), size)
        print(f"LEGACY {f} member={name} size={size} sha256={sha(payload)}")
    # The legacy uLE 7z contains a *ZIP*, not the loose BOOT.ELF some
    # documentation assumes. CRC-test its actual inner members in memory.
    ule_7z = site / "downloads" / "uLE_kHn_20191110_2.7z"
    ule_name, ule_length = members(ule_7z, exe)[0]
    ule_zip = member_bytes(ule_7z, ule_name, ule_length, exe)
    if not ule_name.casefold().endswith(".zip") or not ule_zip.startswith(b"PK"):
        raise ValueError("2019 uLE inner member is not the expected ZIP")
    with ZipFile(BytesIO(ule_zip)) as nested:
        infos = [item for item in nested.infolist() if not item.is_dir()]
        if not infos or len(infos) > 64:
            raise ValueError("Unexpected nested uLE ZIP file count")
        total = sum(item.file_size for item in infos)
        if total > 64_000_000 or any(item.file_size > EXTERNAL_MAX_BYTES for item in infos):
            raise ValueError("uLE inner ZIP decompression limit exceeded")
        for info in infos:
            normal(info.filename)
        bad_member = nested.testzip()  # checks member stream CRCs, no disk writes
        if bad_member:
            raise ValueError("Nested uLE ZIP member CRC failure: " + bad_member)
        print(f"NESTED_ZIP {ule_name} bytes={len(ule_zip)} sha256={sha(ule_zip)} "
              f"members={len(infos)} total_unpacked={total} crc=PASS")
        for item in infos:
            print(f"NESTED_MEMBER name={item.filename} size={item.file_size} "
                  f"crc32={item.CRC:08X}")
    candidates = sorted([x for x in research.iterdir()
                         if x.is_file() and x.suffix.lower() in (".zip", ".7z")])
    print(f"Scanning {len(candidates)} tracked packages for exact decompressed payloads.")
    match_count = {f: 0 for f in TARGETS}
    matches = []
    matches_by_hash = {d: f for f, (_, d, _) in originals.items()}
    for archive in candidates:
        listed = members(archive, exe)
        for name, length in listed:
            key = normal(name)
            plausible = [
                f for f, (n, _, l) in originals.items()
                if n == key and l == length
            ]
            # For BOOT.ELF or renamed executables, require matching length before
            # decoding; different basename hash equality can be investigated later.
            if not plausible:
                continue
            digest = sha(member_bytes(archive, name, length, exe))
            for f in plausible:
                identical = digest == originals[f][1]
                status = "MATCH" if identical else "DIFFERENT"
                print(f"{status}: {f} vs {archive.name}::{name} "
                      f"member_sha256={digest}")
                if identical:
                    match_count[f] += 1
                    matches.append((f, archive.name, name))
    if not any(f == "DEBUG_AND_HALT.7z" and archive == "POPStarter_r13_WIP_06_OBT_20170128.zip"
               for f, archive, name in matches):
        raise ValueError("Expected historical DEBUG_AND_HALT.PPF payload cross-package match missing")
    for f in TARGETS:
        print(f"SUMMARY {f}: {match_count[f]} exact-name+byte matches "
              f"among {len(candidates)} tracked archives")
    print(f"SUMMARY total_matches={len(matches)}; this does NOT establish original "
          "date/authenticity/author, rights or runtime safety.")
    return matches


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("published", type=Path)
    p.add_argument("tracked_downloads", type=Path)
    args = p.parse_args()
    try:
        audit(args.published, args.tracked_downloads)
    except (OSError, ValueError, subprocess.TimeoutExpired) as e:
        print("FAIL " + str(e), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
