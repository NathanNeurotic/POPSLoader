#!/usr/bin/env python3
# Deterministic audit of the built site: link integrity, policy compliance, render artifacts, completeness.
import os, re, sys, json, html
ROOT = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(ROOT, 'site')
# docs.google.com removed 2026-06-22 (maintainer call) — community compat lists/forms are allowed live links.
BANNED = re.compile(r'(elotrolado|el[_-]?patas|elpatas|byethost|epizy|000webhost)', re.I)
issues = {'links': [], 'policy': [], 'render': [], 'complete': []}

htmls = []
for base, _, files in os.walk(SITE):
    for f in files:
        if f.endswith('.html'):
            htmls.append(os.path.join(base, f))

def rel_exists(page, href):
    href = href.split('#')[0].split('?')[0]
    if not href or href.startswith(('http://', 'https://', 'mailto:', '#', 'data:')):
        return True
    target = os.path.normpath(os.path.join(os.path.dirname(page), href))
    return os.path.exists(target)

# Anchor targets per page. rel_exists() throws the #fragment away before it checks anything, so a
# link to a real page with a nonexistent heading always passed. That hid 5 dead anchors in the
# mirrored README/STATE pages, where GitHub's "a--b" slugs do not match ours.
ANCHORS = {}
for _p in htmls:
    _t = open(_p, encoding='utf-8', errors='replace').read()
    ANCHORS[os.path.normpath(_p)] = (set(re.findall(r'\sid="([^"]+)"', _t))
                                     | set(re.findall(r'\sname="([^"]+)"', _t)))

def anchor_exists(page, href):
    if '#' not in href or href.startswith(('http://', 'https://', 'mailto:', 'data:')):
        return True
    path, frag = href.split('#', 1)
    if not frag:
        return True
    target = os.path.normpath(page if not path
                              else os.path.join(os.path.dirname(page), path))
    if target not in ANCHORS:
        return True   # missing file is rel_exists()'s job; don't double-report
    return frag in ANCHORS[target]

for page in htmls:
    txt = open(page, encoding='utf-8', errors='replace').read()
    rp = os.path.relpath(page, SITE)
    # content region only (after <main)
    body = txt.split('<main', 1)[-1].split('</main>', 1)[0]
    # links
    for href in re.findall(r'href="([^"]+)"', txt):
        if not rel_exists(page, href):
            issues['links'].append(f'{rp}: dead local link -> {href}')
        elif not anchor_exists(page, href):
            issues['links'].append(f'{rp}: dead anchor -> {href}')
    for src in re.findall(r'src="([^"]+)"', txt):
        if not rel_exists(page, src):
            issues['links'].append(f'{rp}: dead local src -> {src}')
    # policy (banned-host hyperlinks; DISCS_POOPER; POPS download links)
    for href in re.findall(r'href="([^"]+)"', body):
        if BANNED.search(href):
            issues['policy'].append(f'{rp}: BANNED-host link -> {href}')
        if re.search(r'disc[s]?_?pooper', href, re.I):
            issues['policy'].append(f'{rp}: DISCS_POOPER link -> {href}')
        if re.search(r'downloads/(POPS\.ELF|POPS\.PAK|POPS_IOX\.PAK|IOPRP252\.IMG)', href, re.I):
            issues['policy'].append(f'{rp}: POPS-binary download link -> {href}')
    # render artifacts in content
    if '<!--' in body:
        issues['render'].append(f'{rp}: raw HTML comment leaked into content')
    if re.search(r'\]\(https?://', body):
        issues['render'].append(f'{rp}: unrendered markdown link syntax "](http"')
    if re.search(r'&lt;!--|\x1f\x8b', body):
        issues['render'].append(f'{rp}: gzip/escaped-comment junk')
    if re.search(r'>\s*(None|nil|nan)\s*<', body) and not rp.startswith('popsloader'):
        issues['render'].append(f'{rp}: literal None/nil leaked')   # popsloader docs have real Lua nil/None
    if '<div class="cards"></div>' in body:
        issues['render'].append(f'{rp}: empty cards container')

# completeness: search index URLs resolve
si = json.load(open(os.path.join(SITE, 'data', 'search-index.json'), encoding='utf-8'))
for e in si:
    u = e['url'].split('#')[0]
    if not os.path.exists(os.path.join(SITE, u)):
        issues['complete'].append(f'search url missing file -> {e["url"]} ({e["title"]})')
# every download present & linked
dlpage = open(os.path.join(SITE, 'downloads.html'), encoding='utf-8').read()
for f in os.listdir(os.path.join(SITE, 'downloads')):
    if f'downloads/{f}' not in dlpage and html.escape(f) not in dlpage:
        issues['complete'].append(f'download not linked on downloads.html -> {f}')
# Historical inventory completeness: unavailable/withheld means labelled, not omitted.
# The recovery manifest is not a verified binary list, so never infer a download.
import csv
catalog_path = os.path.join(ROOT, 'research', 'original-download-catalog.tsv')
if not os.path.exists(catalog_path):
    issues['complete'].append('tracked historical download catalogue missing')
else:
    with open(catalog_path, encoding='utf-8', newline='') as _f:
        history_rows = list(csv.DictReader((line for line in _f if not line.startswith('#')),
                                           delimiter='\t'))
    if len(history_rows) < 80:
        issues['complete'].append(f'historical catalogue unexpectedly short: {len(history_rows)}')
    seen_names = set()
    for item in history_rows:
        name = item.get('filename', '')
        if not name:
            issues['complete'].append('historical catalogue contains blank name')
            continue
        if name.casefold() in seen_names:
            issues['complete'].append(f'duplicate historical catalogue entry: {name}')
        seen_names.add(name.casefold())
        if '<code>' + html.escape(name) + '</code>' not in dlpage:
            issues['complete'].append(f'historical download reference omitted from site: {name}')
        if item.get('status') in ('withheld', 'invalid_reference'):
            if 'href="downloads/' + html.escape(name) + '"' in dlpage:
                issues['policy'].append(f'withheld/invalid download received a link: {name}')
    if 'verification status' not in dlpage.lower():
        issues['complete'].append('historical inventory missing explicit status column')
    for sample in ('NOPAL_PATCH.7z', 'network_modules.7z'):
        if sample not in dlpage or 'Historical size discrepancy:' not in dlpage:
            issues['complete'].append('same-name historical-size discrepancy not labelled: '+sample)
# The original source ZIP is shown either with a real file or as explicitly pending.
original_zip = 'popstarter-documentation-stuff-wiki-git-20240731.zip'
if original_zip not in os.listdir(os.path.join(SITE, 'downloads')):
    if 'Original wiki Git history ZIP — not yet hosted' not in dlpage:
        issues['complete'].append('original contributed wiki Git ZIP silently omitted')
# Missing source notes and community credit must not disappear on subsequent rebuild.
history_page = open(os.path.join(SITE, 'history.html'), encoding='utf-8').read()
credits_page = open(os.path.join(SITE, 'credits.html'), encoding='utf-8').read()
for phrase in ('The 15 original news bulletins', 'Linux CUE2POPS source',
               'Light-gun module example correction', 'WIP05 USB Quickstarter erratum'):
    if phrase not in history_page:
        issues['complete'].append('missing recovered historical note: ' + phrase)
if 'Original wiki community thanks (April 2016)' not in credits_page:
    issues['complete'].append('original 2016 collective community credit missing')

# every entry has an anchor on its page
entries = json.load(open(os.path.join(ROOT, 'research', 'entries.json'), encoding='utf-8'))
CAT_PAGE = {'cheats':'cheats','patches':'compatibility','trojans':'compatibility','igr':'igr',
            'config':'config','storage':'storage','launch':'storage','vmc':'multidisc',
            'multidisc':'multidisc','troubleshooting':'troubleshooting','history':'history'}
def slug(s): return re.sub(r'[^a-z0-9]+','-',s.lower()).strip('-')
missing_anchor = 0
for e in entries:
    pg = CAT_PAGE.get(e.get('category',''), 'index')
    pth = os.path.join(SITE, pg+'.html')
    if os.path.exists(pth):
        if f'id="{slug(e.get("name",""))}"' not in open(pth, encoding='utf-8').read():
            missing_anchor += 1
            if missing_anchor <= 8:
                issues['complete'].append(f'entry has no card anchor: {e.get("name")} (-> {pg}.html)')
if missing_anchor > 8:
    issues['complete'].append(f'... +{missing_anchor-8} more entries without anchors')

print(f"AUDIT of {len(htmls)} pages")
total = 0
for k, v in issues.items():
    print(f"\n== {k.upper()} ({len(v)}) ==")
    for line in v[:40]:
        print("  -", line)
    if len(v) > 40:
        print(f"  ... +{len(v)-40} more")
    total += len(v)
print(f"\nTOTAL ISSUES: {total}")
# docs-site.yml runs this under `set -eu` in a step labelled "Audit (hard gate)", but the script
# used to end here, so it exited 0 no matter what it printed and the gate could never fail. Arm it.
if total:
    print("FAILED: the gate is armed; fix the issues above or the site will not publish.")
    sys.exit(1)
