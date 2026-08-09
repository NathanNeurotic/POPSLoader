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
