#!/usr/bin/env python3
"""Check translator handoffs and convert returned TSV/XLSX rows to a Lua table.

Only English keys from the current Slovak template are accepted. Blank target
cells are omitted, preserving PLDR.L's English fallback. No workbook code runs.
"""
import argparse
import json
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
TOKEN = re.compile(
    r'--\[(=*)\[.*?\]\1\]|--[^\n]*|"(?:[^"\\]|\\.)*"|'
    r"'(?:[^'\\]|\\.)*'|\[(=*)\[.*?\]\2\]", re.S)
FORMAT = re.compile(r'%(?:[-+ #0]*\d*(?:\.\d+)?[cdiouxXaAeEfgGqs]|%)')
NS = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def escape_handoff(text):
    return text.replace('\\', '\\\\').replace('\n', '\\n').replace('\t', '\\t')


def unescape_handoff(text):
    return re.sub(r'\\([\\nt])', lambda m: {'\\': '\\', 'n': '\n', 't': '\t'}[m[1]], text)


def decode_literal(token):
    if token.startswith('['):
        m = re.fullmatch(r'\[(=*)\[(.*?)\]\1\]', token, re.S)
        return re.sub(r'^\n', '', m[2])
    escapes = {'a': '\a', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r',
               't': '\t', 'v': '\v', '\\': '\\', '"': '"', "'": "'", '\n': '\n'}
    def decode(m):
        s = m[0][1:]
        if s in escapes:
            return escapes[s]
        if s.startswith('z'):
            return ''
        if s.startswith('x'):
            return chr(int(s[1:], 16))
        if s.startswith('u{'):
            return chr(int(s[2:-1], 16))
        if s.isdigit():
            return chr(int(s))
        raise ValueError('unsupported Lua escape: ' + m[0])
    return re.sub(r'\\(?:z\s*|x[0-9A-Fa-f]{2}|u\{[0-9A-Fa-f]+\}|\d{1,3}|.)',
                  decode, token[1:-1], flags=re.S)


def source_data(repo=REPO):
    live, required, dictionaries = {}, set(), {}
    for name in ('bin/POPSLDR/system.lua', 'bin/POPSLDR/ui.lua', 'etc/boot.lua'):
        src = (repo / name).read_text(encoding='utf-8')
        if name.endswith('system.lua'):
            start, end = src.index('PLDR.I18N = {'), src.index('function PLDR.L(s)')
            block = src[start:end]
            for match in re.finditer(r'^  (\w+) = \{(.*?)^  \},', block, re.M | re.S):
                rows = []
                pair = r'\[("(?:[^"\\]|\\.)*")\]\s*=\s*("(?:[^"\\]|\\.)*")'
                for p in re.finditer(pair, match[2]):
                    rows.append((decode_literal(p[1]), decode_literal(p[2])))
                dictionaries[match[1]] = rows
            # Preserve offsets for useful source references, excluding translations.
            src = src[:start] + re.sub(r'[^\n]', ' ', src[start:end]) + src[end:]
        for m in TOKEN.finditer(src):
            if m[0].startswith('--'):
                continue
            value = decode_literal(m[0])
            # Credits remove their trailing newline before the PLDR.L lookup.
            if m[0].startswith('[') and src[m.end():m.end()+22].startswith('):gsub("\\n$", "")'):
                value = value.removesuffix('\n')
            if not value:
                continue
            live.setdefault(value, []).append(f'{name}:{src.count(chr(10), 0, m.start())+1}')
            if re.search(r'PLDR\.L(?:Fmt)?\(\s*$', src[max(0,m.start()-40):m.start()]):
                required.add(value)
    for rows in dictionaries.values():
        required.update(k for k, _ in rows if k in live)
    return live, required, dictionaries


def read_tsv(path):
    rows = []
    for i, line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
        if not line:
            continue
        cells = line.split('\t')
        if len(cells) != 2:
            raise ValueError(f'{path.name}:{i}: expected exactly two tab-separated cells')
        rows.append(cells)
    if not rows or not rows[0][0].startswith('English'):
        raise ValueError('missing English header')
    return rows[1:]


def read_xlsx(path):
    with zipfile.ZipFile(path) as z:
        strings = []
        if 'xl/sharedStrings.xml' in z.namelist():
            root = ET.fromstring(z.read('xl/sharedStrings.xml'))
            strings = [''.join(t.text or '' for t in si.iter('{'+NS['s']+'}t'))
                       for si in root.findall('s:si', NS)]
        # Resolve the named sheet, rather than assuming workbook tab order.
        book = ET.fromstring(z.read('xl/workbook.xml'))
        sheet = next((s for s in book.findall('s:sheets/s:sheet', NS)
                      if s.get('name') == 'Slovak'), None)
        if sheet is None:
            raise ValueError('workbook has no Slovak sheet')
        rel_id = sheet.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
        rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
        target = next(r.get('Target') for r in rels if r.get('Id') == rel_id)
        target = target.lstrip('/') if target.startswith('/') else 'xl/' + target
        root = ET.fromstring(z.read(target))
        rows, started = [], False
        for row in root.findall('s:sheetData/s:row', NS):
            cells = {}
            for c in row.findall('s:c', NS):
                col = re.sub(r'\d', '', c.get('r', ''))
                if col not in ('A', 'B'):
                    continue
                if c.find('s:f', NS) is not None:
                    raise ValueError(f'formula in translation cell {c.get("r")}')
                kind = c.get('t')
                v = c.findtext('s:v', '', NS)
                if kind == 's':
                    v = strings[int(v)]
                elif kind == 'inlineStr':
                    v = ''.join(t.text or '' for t in c.find('s:is', NS).iter('{'+NS['s']+'}t'))
                elif v and kind != 'str':
                    raise ValueError(f'non-text translation cell {c.get("r")}')
                cells[col] = v
            en, value = cells.get('A', ''), cells.get('B', '')
            if en.startswith('English (do not edit)'):
                started = True
            elif started and (en or value):
                rows.append((en, value))
        if not started:
            raise ValueError('missing English header on Slovak sheet')
        return rows


def validate_rows(rows, allowed):
    seen, translated = set(), {}
    for en, value in rows:
        if en not in allowed:
            raise ValueError(f'unknown or edited English key: {en!r}')
        if en in seen:
            raise ValueError(f'duplicate English key: {en!r}')
        seen.add(en)
        if not value or not value.strip():
            continue
        if any(ord(c) < 32 for c in en + value):
            raise ValueError(f'use literal \\n / \\t escapes, not cell line breaks: {en!r}')
        if FORMAT.findall(en) != FORMAT.findall(value):
            raise ValueError(f'changed or reordered format placeholders: {en!r}')
        if en.count('\\n') != value.count('\\n'):
            raise ValueError(f'changed line breaks: {en!r}')
        if en.startswith(' ') and not value.startswith(' '):
            raise ValueError(f'dropped leading space: {en!r}')
        translated[en] = value
    return translated


def check_catalogs(repo=REPO):
    live, required, dictionaries = source_data(repo)
    template = read_tsv(repo / 'docs/translations/slovak.tsv')
    allowed = {en for en, _ in template}
    errors = []
    for key in sorted(required):
        escaped = escape_handoff(key)
        if escaped not in allowed:
            errors.append(f'Slovak template missing active key: {escaped!r}')
    live_escaped = {escape_handoff(k) for k in live}
    for key in allowed - live_escaped:
        errors.append(f'Slovak template contains inactive key: {key!r}')
    for path in sorted((repo / 'docs/translations').glob('*.tsv')):
        try:
            rows = read_tsv(path)
            validate_rows(rows, allowed)
            if {k for k, _ in rows} != allowed:
                raise ValueError('English key set differs from Slovak template')
        except ValueError as exc:
            errors.append(f'{path.name}: {exc}')
    for lang, rows in dictionaries.items():
        seen = set()
        for en, value in rows:
            if en in seen:
                errors.append(f'{lang}: duplicate runtime key {en!r}')
            seen.add(en)
            if FORMAT.findall(en) != FORMAT.findall(value):
                errors.append(f'{lang}: changed format placeholders {en!r}')
    workbook = repo / 'docs/translations/slovak.xlsx'
    if not workbook.exists():
        errors.append('missing Slovak Excel workbook')
    else:
        try:
            rows = read_xlsx(workbook)
            validate_rows(rows, allowed)
            if {k for k, _ in rows} != allowed:
                raise ValueError('workbook English keys differ from TSV template')
        except ValueError as exc:
            errors.append(f'slovak.xlsx: {exc}')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--import-file', type=Path, help='returned .xlsx or two-column .tsv')
    parser.add_argument('--language', default='SK', help='Lua language code for the generated table')
    parser.add_argument('--output', type=Path, help='write a reviewable Lua table (does not edit the app)')
    args = parser.parse_args()
    errors = check_catalogs()
    if errors:
        raise ValueError('\n'.join(errors))
    if args.import_file:
        allowed = {en for en, _ in read_tsv(REPO / 'docs/translations/slovak.tsv')}
        rows = read_xlsx(args.import_file) if args.import_file.suffix.lower() == '.xlsx' else read_tsv(args.import_file)
        translated = validate_rows(rows, allowed)
        if not re.fullmatch('[A-Z]{2,8}', args.language):
            raise ValueError('language must be an uppercase language code')
        if args.output is None:
            raise ValueError('--output is required for import')
        # Decode only handoff escapes. json.dumps gives Lua-compatible quoted
        # UTF-8 strings for these keys, without interpreting translator code.
        def quote(s):
            return json.dumps(unescape_handoff(s), ensure_ascii=False)
        text = args.language + ' = {\n' + ''.join(
            f'  [{quote(en)}] = {quote(value)},\n' for en, value in sorted(translated.items())) + '}\n'
        args.output.write_text(text, encoding='utf-8')
        print(f'{len(translated)} translations written to {args.output}; omitted blanks fall back to English')
    else:
        print('Translation catalogs, runtime duplicates and format placeholders: OK')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, zipfile.BadZipFile, ET.ParseError) as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)
