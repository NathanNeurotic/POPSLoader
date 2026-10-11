#!/usr/bin/env python3
"""Read-only original POPStarter wiki Git-history inventory.

Usage:
  python .research/tools/audit_original_git_history.py --git-dir /path/to/extracted/wiki \
    --wiki .research/wiki --assets .research/assets --out /tmp/wiki-history-audit.json

Supply AstroSnail's original Git working tree, unmodified. Does not run builds,
fetch network resources, alter Git, or overwrite an existing report.
"""
import argparse
import collections
import hashlib
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import unquote

DISC_ID = re.compile(r'\b[A-Z]{4}-\d{5}\b')
CODE = re.compile(r'^\s*([0-9A-F]{8})\s+([0-9A-F]{8})\s*$', re.M)
URL = re.compile(r'https?://[^\s\]"<>\)]+')
IMAGE = re.compile(r'/(?:images|uploads)/([^/\s?#]+)', re.I)
DOWNLOAD = re.compile(r'/downloads/([^\s?#]+)', re.I)
EXPECTED_SHA256 = 'd0c243d91e417988825ed92b440224ed46cbbf448d0b67528e0957c15c0d029a'

def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], stderr=subprocess.DEVNULL)

def text_lines(repo, *args):
    return git(repo, *args).decode('utf-8', 'replace').splitlines()

def last_surviving_blob(repo, path):
    for revision in text_lines(repo, 'rev-list', '--all', '--', path):
        try:
            data = git(repo, 'show', f'{revision}:{path}')
        except subprocess.CalledProcessError:
            continue
        return revision, data.decode('utf-8', 'replace')
    return None, ''

def prefix(name):
    m = re.match(r'^(\d+)-', name)
    return m.group(1) if m else None

def ordered_code_digest(text):
    codes = [f'{address} {value}' for address, value in CODE.findall(text)]
    return {'rows': len(codes), 'distinct_pairs': len(set(codes)),
            'sha256_ordered_pairs': hashlib.sha256('\n'.join(codes).encode('ascii')).hexdigest()}

def historical_urls(repo):
    command = ['git', '-C', str(repo), 'log', '--all', '-p', '--unified=0', '--format=%H']
    proc = subprocess.Popen(command, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True, errors='replace')
    images = collections.defaultdict(set)
    downloads = collections.defaultdict(set)
    path = ''
    added_lines = 0
    assert proc.stdout is not None
    for line in proc.stdout:
        if line.startswith('diff --git a/'):
            path = line[13:].split(' b/', 1)[0]
        if not line.startswith('+') or line.startswith('+++'):
            continue
        added_lines += 1
        for url in URL.findall(line):
            image = IMAGE.search(url)
            download = DOWNLOAD.search(url)
            if image:
                name = unquote(image.group(1)).rstrip('!.,;:*')
                images[name].add(path)
            if download and 'popstarter-documentation-stuff' in url.lower():
                name = unquote(download.group(1)).rstrip('!.,;:*')
                downloads[name].add(path)
    if proc.wait() != 0:
        raise RuntimeError('git log --all -p failed')
    return images, downloads, added_lines

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--git-dir', type=Path, required=True)
    p.add_argument('--wiki', type=Path, required=True)
    p.add_argument('--assets', type=Path, required=True)
    p.add_argument('--downloads', type=Path)
    p.add_argument('--asset-state', type=Path)
    p.add_argument('--source-zip', type=Path)
    p.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    if not (args.git_dir / '.git').is_dir():
        p.error('--git-dir must point at an extracted Git working tree')
    if not args.wiki.is_dir() or not args.assets.is_dir():
        p.error('--wiki and --assets must point at existing recovered directories')
    if args.out.exists():
        p.error('refusing to overwrite a previous audit report')
    head = git(args.git_dir, 'rev-parse', 'HEAD').decode().strip()
    commits = text_lines(args.git_dir, 'log', '--all', '--format=%aI')
    years = dict(sorted(collections.Counter(date[:4] for date in commits).items()))
    head_pages = text_lines(args.git_dir, 'ls-tree', '-r', '--name-only', 'HEAD')
    recovered_names = {file.stem for file in args.wiki.glob('*.md')}
    missing_current = sorted(file for file in head_pages if Path(file).stem not in recovered_names)
    touched, deleted = set(), set()
    events = collections.Counter()
    for line in text_lines(args.git_dir, 'log', '--all', '--name-status',
                           '--find-renames', '--format='):
        columns = line.split('\t')
        if len(columns) not in (2, 3):
            continue
        status = columns[0][0]
        events[status] += 1
        touched.update(columns[1:])
        if status == 'D':
            deleted.add(columns[1])
    images, downloads, added = historical_urls(args.git_dir)
    recovered_ids = {prefix(file.name) for file in args.assets.iterdir() if file.is_file()}
    unmatched = {name: sorted(paths) for name, paths in sorted(images.items())
                 if prefix(name) and prefix(name) not in recovered_ids}
    recovered_log = {}
    if args.asset_state and args.asset_state.is_file():
        targets = {prefix(name) for name in unmatched}
        for line in args.asset_state.read_text(errors='replace').splitlines():
            m = re.search(r'/images/(\d+)-', line)
            if m and m.group(1) in targets:
                recovered_log.setdefault(m.group(1), []).append(line)
    deletion_ledger = {}
    for path in sorted(deleted):
        revision, content = last_surviving_blob(args.git_dir, path)
        if revision:
            deletion_ledger[path] = {'last_existing_revision': revision,
                                     'bytes_utf8': len(content.encode('utf-8')),
                                     'disc_ids': len(set(DISC_ID.findall(content)))}
    historical_games_revision, old_games = last_surviving_blob(args.git_dir, 'poop.textile')
    recovered_games = args.wiki / 'automated.md'
    old_ids = set(DISC_ID.findall(old_games))
    game_comparison = {'source_revision': historical_games_revision,
                       'historical_disc_ids': len(old_ids),
                       'warning': 'disc ID coverage only; not title/fix-version equivalence'}
    if recovered_games.is_file():
        new_ids = set(DISC_ID.findall(recovered_games.read_text(errors='replace')))
        game_comparison.update({'recovered_disc_ids': len(new_ids),
                                'missing_historical_ids': sorted(old_ids - new_ids)})
    _, old_codes = last_surviving_blob(args.git_dir, 'PS1 codes .textile')
    current_codes = args.wiki / 'ps1-codes-in-ps2-raw-format.md'
    code_comparison = {'deleted_source': ordered_code_digest(old_codes)}
    if current_codes.is_file():
        code_comparison['recovered'] = ordered_code_digest(current_codes.read_text(errors='replace'))
        code_comparison['ordered_pairs_match'] = code_comparison['deleted_source'] == code_comparison['recovered']
    report = {
        'method': 'original Git history and reconstructed wiki; read-only; no downloads',
        'limitations': 'source-page name equivalence and disc IDs do not establish semantic parity',
        'source': {'head': head, 'commit_count': len(commits), 'years': years,
                   'head_pages': len(head_pages), 'historical_path_count': len(touched),
                   'events': dict(sorted(events.items())), 'distinct_deleted_paths': len(deleted),
                   'unmatched_current_page_names': missing_current},
        'last_surviving_deleted_pages': deletion_ledger,
        'compatibility_disc_ids': game_comparison,
        'ps2_raw_codes': code_comparison,
        'image_references': {
            'filename_forms': len(images),
            'numeric_ids': len({prefix(name) for name in images if prefix(name)}),
            'unmatched_ids': sorted({prefix(name) for name in unmatched}),
            'unmatched_filename_sources': unmatched,
            'recovery_log_matches': recovered_log},
        'download_references': {'raw_normalized_filename_forms': len(downloads),
                                'filename_sources': {name: sorted(paths) for name, paths in sorted(downloads.items())},
                                'hosted_file_names': sorted(file.name for file in args.downloads.iterdir() if file.is_file())
                                if args.downloads and args.downloads.is_dir() else []},
        'git_patch_added_lines_scanned': added
    }
    if args.source_zip:
        sha = hashlib.sha256()
        with args.source_zip.open('rb') as source:
            for chunk in iter(lambda: source.read(1 << 20), b''):
                sha.update(chunk)
        report['source']['supplied_zip_sha256'] = sha.hexdigest()
        report['source']['matches_original_zip_sha256'] = sha.hexdigest() == EXPECTED_SHA256
        if not report['source']['matches_original_zip_sha256']:
            raise ValueError('source ZIP SHA-256 does not match the original archive')
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
    print(f"Commits: {len(commits)}, historical paths: {len(touched)}, deleted: {len(deleted)}")
    print(f"Unmatched historical image IDs: {len(report['image_references']['unmatched_ids'])}")
    print(f"Audit report: {args.out}")

if __name__ == '__main__':
    main()
