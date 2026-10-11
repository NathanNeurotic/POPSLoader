#!/usr/bin/env python3
"""Read-only direct archive-member census for POPStarter hosted downloads.

ZIP and 7z metadata only; detects potential patch members without extracting
or executing payloads. Nested archives are reported but not recursively parsed.
Does NOT authenticate historic Bitbucket packages.
"""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import shutil
import subprocess
from zipfile import ZipFile

TARGETS = {'nopal_patch.7z', 'forcepal_patch.7z', 'patch_9.7z',
           'patch_9.bin', 'patch_8.bin'}
ARCHIVE_EXTS = {'.zip', '.7z', '.rar'}


def list_7z_members(exe, archive):
    result = subprocess.run([exe, 'l', '-slt', str(archive)],
                            capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(f"7z listing error for {archive}: {result.stderr[-400:]}")
    if '----------' not in result.stdout:
        raise RuntimeError(f"No 7z file-list separator for {archive}")
    records = result.stdout.split('----------', 1)[1].split('\n\n')
    members = []
    for record in records:
        fields = dict(line.split(' = ', 1) for line in record.splitlines()
                      if ' = ' in line)
        name = fields.get('Path')
        if name and fields.get('Folder') != '+':
            members.append((name, int(fields.get('Size', -1)), fields.get('CRC', '')))
    return members


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('directory', type=Path)
    args = p.parse_args()
    root = args.directory.resolve()
    sevenzip = next((shutil.which(n) for n in ('7zz', '7z', '7za') if shutil.which(n)), None)
    if not sevenzip:
        p.error('Requires 7z/7zz/7za command')
    if not root.is_dir():
        p.error(f'Not a directory: {root}')
    files = sorted(x for x in root.iterdir() if x.is_file())
    archives, hits, nested = [], [], []
    for archive in files:
        if archive.suffix.casefold() not in ('.zip', '.7z'):
            continue
        if archive.suffix.casefold() == '.zip':
            with ZipFile(archive) as z:
                members = [(i.filename, i.file_size, f'{i.CRC:08X}')
                           for i in z.infolist() if not i.is_dir()]
        else:
            members = list_7z_members(sevenzip, archive)
        if not members:
            raise ValueError(f'No files in archive: {archive.name}')
        archives.append((archive.name, len(members),
                         hashlib.sha256(archive.read_bytes()).hexdigest()))
        for name, size, crc in members:
            normalized = name.replace('\\', '/')
            base = PurePosixPath(normalized).name.casefold()
            if base in TARGETS or 'nopal' in base or 'forcepal' in base:
                hits.append((archive.name, normalized, size, crc))
            elif PurePosixPath(normalized).suffix.casefold() in ARCHIVE_EXTS:
                nested.append((archive.name, normalized, size))
    print(f'Host archives checked: {len(archives)} (other tracked files not archives)')
    for name, count, sha in archives:
        print(f'ARCHIVE {name}: {count} direct file members; SHA256={sha}')
    print(f'Direct candidate patch members: {len(hits)}')
    for archive, member, size, crc in hits:
        print(f'CANDIDATE {archive} :: {member} :: size={size} :: stored_crc={crc or "n/a"}')
    print(f'Nested archive candidates (NOT recursively inspected): {len(nested)}')
    for archive, member, size in nested:
        print(f'NESTED {archive} :: {member} :: size={size}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
