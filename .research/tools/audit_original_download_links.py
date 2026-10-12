#!/usr/bin/env python3
"""Read-only source-history Bitbucket download-link coverage audit.

Usage:
    python3 .research/tools/audit_original_download_links.py \
      /path/to/extracted/original/wiki \
      .research/research/original-download-catalog.tsv

Reads every reachable Git blob, not only latest .textile pages. Compares URL
filename forms against wiki_git rows in the canonical catalog. It does not
download or authenticate any executable/archive payload.
"""
import argparse
import csv
from collections import Counter
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote

URL = re.compile(rb'popstarter-documentation-stuff/downloads/([^\s<>\]\)\}\|"\']+)', re.I)


def reachable_blobs(repo):
    refs = subprocess.check_output(['git', '-C', str(repo), 'rev-list',
                                    '--objects', '--all'])
    shas = [line.split(maxsplit=1)[0] for line in refs.splitlines() if line]
    proc = subprocess.run(['git', '-C', str(repo), 'cat-file', '--batch'],
                          input=b'\n'.join(shas) + b'\n',
                          capture_output=True, check=True)
    data, pos = proc.stdout, 0
    for sha in shas:
        e = data.index(b'\n', pos)
        header = data[pos:e].split()
        if len(header) != 3 or header[0] != sha:
            raise ValueError('Invalid Git batch header or SHA')
        _, kind, size = header
        n = int(size)
        body = data[e+1:e+1+n]
        if len(body) != n or data[e+1+n:e+2+n] != b'\n':
            raise ValueError('Invalid Git object batch delimiter')
        pos = e+n+2
        if kind == b'blob':
            yield body
    if pos != len(data):
        raise ValueError('Unexpected trailing Git batch data')


def source_filenames(repo):
    links, blobs = Counter(), 0
    for body in reachable_blobs(repo):
        blobs += 1
        for match in URL.finditer(body):
            value = match.group(1).decode('utf-8', 'replace')
            value = unquote(value.split('?', 1)[0].split('#', 1)[0]
                            .strip('.,;!')).rstrip('*')
            if value:
                links[value] += 1
    return links, blobs


def catalog_filenames(tsv):
    with tsv.open(encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader((line for line in f if not line.startswith('#')),
                                   delimiter='\t'))
    if not rows or not {'filename', 'evidence'} <= set(rows[0]):
        raise ValueError('Catalog must have filename and evidence columns')
    duplicates = [name for name, n in Counter(r['filename'] for r in rows).items()
                  if n > 1]
    if duplicates:
        raise ValueError('Duplicate catalog filename(s): ' + ', '.join(duplicates))
    by_wiki = {r['filename'] for r in rows if 'wiki_git' in r['evidence'].split('+')}
    separate = [(r['filename'], r['evidence']) for r in rows
                if r['filename'] not in by_wiki]
    return by_wiki, separate


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('original_wiki_git', type=Path)
    ap.add_argument('catalog_tsv', type=Path)
    a = ap.parse_args()
    source, blobs = source_filenames(a.original_wiki_git)
    catalog, other = catalog_filenames(a.catalog_tsv)
    missing = sorted(source.keys() - catalog)
    stale = sorted(catalog - source.keys())
    print(f'Original reachable Git blobs: {blobs}')
    print(f'Historical link occurrences: {sum(source.values())}')
    print(f'Distinct original filename forms: {len(source)}')
    print(f'Catalog wiki_git rows: {len(catalog)}')
    print(f'Catalog non-wiki_git rows: {len(other)}')
    for name, evidence in other:
        print(f'  separate provenance: {name} [{evidence}]')
    for name in missing:
        print('MISSING FROM CATALOG:', repr(name))
    for name in stale:
        print('CATALOG WIKI_GIT ROW NOT FOUND IN SOURCE:', repr(name))
    ok = not missing and not stale
    print('Result:', 'PASS' if ok else 'DIFF')
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
