#!/usr/bin/env python3
"""Read-only candidate archive fingerprinting and member comparison for preservation.

Accept a candidate ZIP/7z and optionally a separately sourced reference ZIP/7z.
Prints full-archive SHA-256 and per-member SHA-256/CRC32; never writes extracted
contents, executes members, changes repository data, or claims historical identity.

Rejects archive member names matching known excluded proprietary Sony POPS/BIOS
patterns, ambiguous basenames, unsupported containers, archive paths that
could escape their directory, and unexpectedly large members. Review each
candidate's provenance and legal status before supplying it.
"""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import zlib
from zipfile import ZipFile

EXCLUDED_BASENAMES = {
    "pops.elf", "pops.pak", "pops_iox.pak", "ioprp252.img",
    "scph1000.bin", "scph5500.bin", "scph5501.bin", "scph5502.bin",
    "scph7000.bin", "scph7001.bin", "scph7002.bin",
}
MAX_ARCHIVE_BYTES = 32_000_000
MAX_MEMBER_BYTES = 16_000_000
MAX_FILES = 500


def normalized(name):
    s = name.replace('\\', '/')
    parts = PurePosixPath(s).parts
    if not s or s.startswith('/') or '\x00' in s or any(p in ('..', '.') for p in parts):
        raise ValueError(f"Unsafe archive path {name!r}")
    return s


def select_exe():
    result = next((shutil.which(n) for n in ('7zz', '7z', '7za') if shutil.which(n)), None)
    if not result:
        raise RuntimeError("7zz/7z/7za required for 7z archives")
    return result


def seven_entries(exe, path):
    p = subprocess.run([exe, 'l', '-slt', str(path)],
                       text=True, capture_output=True, check=False, timeout=60)
    if p.returncode or '----------' not in p.stdout:
        raise RuntimeError(f"Unable to list 7z directory: {path.name}")
    records = []
    for block in p.stdout.split('----------', 1)[1].split('\n\n'):
        fields = dict(line.split(' = ', 1) for line in block.splitlines() if ' = ' in line)
        name = fields.get('Path')
        if not name:
            continue
        if fields.get('Folder') == '+':
            continue
        size = int(fields.get('Size', '-1'))
        crc = fields.get('CRC')
        records.append((name, size, crc))
    names = [normalized(name) for name, _, _ in records]
    return [(name, size, crc) for (name, size, crc), n in zip(records, names)
            if not (size == 0 and not crc and
                    any(x.startswith(n + '/') for x in names))]


def fingerprint(path, exe=None):
    path = Path(path).resolve()
    if not path.is_file() or path.stat().st_size > MAX_ARCHIVE_BYTES:
        raise ValueError(f"Missing/oversized archive: {path}")
    ext = path.suffix.casefold()
    if ext not in ('.zip', '.7z'):
        raise ValueError(f"Only ZIP/7z supported: {path}")
    archive_sha = hashlib.sha256(path.read_bytes()).hexdigest()

    if ext == '.zip':
        with ZipFile(path) as z:
            records = [(i.filename, i.file_size, f'{i.CRC:08X}')
                       for i in z.infolist() if not i.is_dir()]
    else:
        exe = exe or select_exe()
        records = seven_entries(exe, path)

    if not records or len(records) > MAX_FILES:
        raise ValueError("Unexpected file count")
    keys = set()
    for name, size, crc in records:
        safe = normalized(name)
        basename = PurePosixPath(safe).name.casefold()
        if basename in EXCLUDED_BASENAMES or (
            basename.startswith('scph') and basename.endswith(('.bin', '.rom'))
        ):
            raise ValueError(f"Excluded Sony binary filename in {path.name}: {safe}")
        if basename in keys:
            raise ValueError(f"Ambiguous duplicate basename in {path.name}: {basename}")
        keys.add(basename)
        if size < 0 or size > MAX_MEMBER_BYTES:
            raise ValueError(f"Unexpected member length in {path.name}: {safe}")

    if ext == '.7z':
        t = subprocess.run([exe, 't', '-bd', '-y', str(path)],
                           capture_output=True, check=False, timeout=120)
        if t.returncode:
            raise ValueError(f"Archive failed full 7z test: {path.name}")

    members = {}
    if ext == '.zip':
        with ZipFile(path) as z:
            for name, size, crc in records:
                with z.open(name) as f:
                    body = f.read(MAX_MEMBER_BYTES + 1)
                if len(body) != size or len(body) > MAX_MEMBER_BYTES:
                    raise ValueError(f"ZIP size mismatch: {name}")
                actual_crc = zlib.crc32(body)
                if actual_crc != int(crc, 16):
                    raise ValueError(f"ZIP CRC mismatch: {name}")
                members[PurePosixPath(normalized(name)).name.casefold()] = (
                    name, size, f'{actual_crc:08X}', hashlib.sha256(body).hexdigest())
    else:
        for name, size, crc in records:
            p = subprocess.run([exe, 'x', '-so', '-bd', str(path), name],
                               capture_output=True, check=False, timeout=120)
            if p.returncode or len(p.stdout) != size:
                raise ValueError(f"7z extraction/length failure: {name}")
            actual_crc = f'{zlib.crc32(p.stdout):08X}'
            if crc and actual_crc != crc.upper():
                raise ValueError(f"7z CRC mismatch: {name}")
            members[PurePosixPath(normalized(name)).name.casefold()] = (
                name, size, actual_crc, hashlib.sha256(p.stdout).hexdigest())
    return path.name, path.stat().st_size, archive_sha, members


def show(data):
    name, length, sha, members = data
    print(f"ARCHIVE {name}: {length} bytes, SHA256={sha}, {len(members)} files")
    for basename, (path, size, crc, digest) in sorted(members.items()):
        print(f"  {basename:24} size={size:>8} crc={crc} sha256={digest} path={path}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('candidate', type=Path)
    p.add_argument('reference', type=Path, nargs='?')
    p.add_argument('--expect-identified-matches', type=int, default=None,
                   help='Fail if fewer than N common-basename member SHA256 matches')
    args = p.parse_args()
    try:
        a = fingerprint(args.candidate)
        show(a)
        if args.reference:
            b = fingerprint(args.reference)
            show(b)
            common = sorted(set(a[3]) & set(b[3]))
            identical = [x for x in common if a[3][x][3] == b[3][x][3]]
            different = [x for x in common if x not in identical]
            print(f"COMMON member basenames: {len(common)}; "
                  f"SHA256-identical: {len(identical)}; SHA256-different: {len(different)}")
            print("IDENTICAL:", ', '.join(identical) or '(none)')
            print("DIFFERENT:", ', '.join(different) or '(none)')
            print("Candidate-only:", ', '.join(sorted(set(a[3]) - set(b[3]))) or '(none)')
            print("Reference-only:", ', '.join(sorted(set(b[3]) - set(a[3]))) or '(none)')
            if (args.expect_identified_matches is not None and
                    len(identical) < args.expect_identified_matches):
                raise ValueError("Not enough identical per-member SHA256 comparisons")
        elif args.expect_identified_matches is not None:
            raise ValueError("--expect-identified-matches requires reference")
    except (ValueError, OSError, RuntimeError, TimeoutError, EOFError) as e:
        print(f"REJECT: {e}", file=sys.stderr)
        return 1
    print("PROVENANCE UNVERIFIED: hash equality alone is not an original-date certificate.")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
