#!/usr/bin/env python3
"""Verify hosted POPStarter network 7z/2020 SMB ZIP, without writing extracted payloads.

Requires Python 3 and an installed 7z/7zz/7za command. Decompresses archived
members into memory only. Verifies every declared 7z member's actual CRC/size;
compares full SHA-256 of the six network IRXs to the separately decoded ZIP.
It does not authenticate an unavailable 2017 Bitbucket upload or run any IRX.
"""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import zlib
from zipfile import ZipFile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_network_modules_header import manifest

SIX = {"poweroff.irx", "ps2dev9.irx", "ps2ip.irx", "ps2smap.irx", "smbman.irx", "smsutils.irx"}
KNOWN_7Z_SHA256 = "ee3aeec5a9259665c6d505b81ee1bbdd3025a6925185e7cc4d3657100f37fad2"
EXPECTED_MEMBERS = 12
MAX_MEMBER = 250_000


def digest(data):
    return hashlib.sha256(data).hexdigest()


def extract_stream(executable, archive, member):
    proc = subprocess.run(
        [executable, "x", "-so", "-bd", str(archive), member],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if proc.returncode:
        raise ValueError(f"7z extraction failed for {member}: {proc.stderr.decode(errors='replace')}")
    if len(proc.stdout) > MAX_MEMBER:
        raise ValueError(f"7z extracted member unexpectedly large: {member}")
    return proc.stdout


def verify(seven_path, zip_path, executable):
    seven_path, zip_path = Path(seven_path).resolve(), Path(zip_path).resolve()
    raw = seven_path.read_bytes()
    if len(raw) != 93_934 or digest(raw) != KNOWN_7Z_SHA256:
        raise ValueError("Current hosted network archive differs from documented SHA-256/length")
    if not zip_path.is_file():
        raise ValueError(f"Missing ZIP: {zip_path}")
    print(f"7z archive SHA-256: {digest(raw)} ({len(raw)} bytes)")
    print(f"ZIP archive SHA-256: {digest(zip_path.read_bytes())} ({zip_path.stat().st_size} bytes)")
    members, _ = manifest(raw)
    if len(members) != EXPECTED_MEMBERS:
        raise ValueError(f"Unexpected 7z member count: {len(members)}")
    listing = {}
    for name, size, stored_crc in members:
        canonical = name.replace('\\', '/')
        if not canonical.startswith('POPSTARTER/') or '..' in canonical.split('/'):
            raise ValueError(f"Unexpected archive member path: {name!r}")
        if canonical.casefold() in listing or size > MAX_MEMBER:
            raise ValueError(f"Duplicate or oversized archive member: {name!r}")
        listing[canonical.casefold()] = (name, size, stored_crc)
    actual = {}
    for key, (name, size, stored_crc) in listing.items():
        data = extract_stream(executable, seven_path, name)
        observed_crc = zlib.crc32(data)
        if len(data) != size or observed_crc != stored_crc:
            raise ValueError(f"7z member corrupted: {name}; size {len(data)}/{size}, "
                             f"CRC32 {observed_crc:08X}/{stored_crc:08X}")
        actual[key] = digest(data)
    check = subprocess.run([executable, "t", "-bd", str(seven_path)],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if check.returncode:
        raise ValueError("Full 7z archive integrity test failed: " +
                         (check.stderr or check.stdout).decode(errors='replace')[-1000:])
    print(f"7z: {len(actual)}/{len(members)} member size/CRC verified; full 7z test passed")
    seven = {}
    for key, (name, size, crc) in listing.items():
        base = name.rsplit('/', 1)[-1].casefold()
        if base in SIX:
            if base in seven:
                raise ValueError(f"Duplicate 7z driver: {base}")
            seven[base] = (size, crc, actual[key])
    with ZipFile(zip_path) as zipf:
        zipped = {}
        for item in zipf.infolist():
            path = item.filename.replace('\\', '/').casefold()
            if '/network_modules/mc0/popstarter/' not in path:
                continue
            base = path.rsplit('/', 1)[-1]
            if base not in SIX:
                continue
            if base in zipped or item.file_size > MAX_MEMBER:
                raise ValueError(f"Duplicate or oversized ZIP driver: {base}")
            data = zipf.read(item)
            if len(data) != item.file_size or zlib.crc32(data) != item.CRC:
                raise ValueError(f"ZIP driver corrupted: {base}")
            zipped[base] = (len(data), zlib.crc32(data), digest(data))
    if set(seven) != SIX or set(zipped) != SIX:
        raise ValueError(f"Missing drivers: 7z={sorted(set(SIX)-set(seven))}, "
                         f"ZIP={sorted(set(SIX)-set(zipped))}")
    for name in sorted(SIX):
        size7, crc7, sha7 = seven[name]
        sizez, crcz, shaz = zipped[name]
        print(f"{name:16} {size7:>6} bytes  CRC32={crc7:08X}  SHA256={sha7}  "
              f"{'PASS' if (size7, crc7, sha7) == (sizez, crcz, shaz) else 'MISMATCH'}")
        if (size7, crc7, sha7) != (sizez, crcz, shaz):
            raise ValueError(f"Driver data mismatch: {name} (ZIP SHA256={shaz})")
    print("PASS: six independently decompressed IRX SHA-256 pairs identical (6/6).")
    print("Historical 2017 Bitbucket archive identity remains UNVERIFIED.")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('hosted_network_7z', type=Path)
    p.add_argument('hosted_2020_smb_zip', type=Path)
    p.add_argument('--sevenzip', help='Optional path to 7-Zip command')
    args = p.parse_args()
    tool = args.sevenzip or next((shutil.which(x) for x in ('7zz', '7z', '7za') if shutil.which(x)), None)
    if not tool:
        p.error('7z/7zz/7za not installed; install the 7zip or p7zip-full package')
    try:
        verify(args.hosted_network_7z, args.hosted_2020_smb_zip, tool)
    except (ValueError, OSError, EOFError) as exc:
        print(f'FAIL: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
