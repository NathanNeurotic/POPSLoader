#!/usr/bin/env python3
# Build the self-contained POPStarter documentation site from the recovered corpus.
import os, re, json, html, shutil, hashlib
import markdown as MD

ROOT = os.path.dirname(os.path.abspath(__file__))
WIKI = os.path.join(ROOT, 'wiki')
RES  = os.path.join(ROOT, 'research')
DL   = os.path.join(ROOT, 'downloads')
ASSET= os.path.join(ROOT, 'assets')
SITE = os.path.join(ROOT, 'site')
if os.path.isdir(SITE):
    shutil.rmtree(SITE, ignore_errors=True)   # clean build — no stale files from renamed slugs
for d in ('wiki', 'downloads', 'img', 'data'):
    os.makedirs(os.path.join(SITE, d), exist_ok=True)

# ---------- policy ----------
# NOTE: docs.google.com / spreadsheet were removed 2026-06-22 (maintainer call) so the community
# compatibility lists + submission forms render as live links again. ElOtroLado/el_patas/dead webhosts stay banned.
BANNED_HOSTS = re.compile(r'(elotrolado|el[_-]?patas|elpatas|byethost|epizy|000webhost)', re.I)
# Excluded from the published site: DISCS_POOPER (policy) + two archives Malwarebytes
# flagged 2026-06-23 (Disc_Combining_Kits.7z = Generic.Malware/Suspicious; POPStarter_
# ELFs-BATCHER_05062016.7z = ML/Anomalous 96%) -- heuristic FPs on old homebrew packers,
# but AV-flagged binaries on GitHub Pages risk an abuse takedown. The link-rewriter below
# uses this same regex, so their download links are dropped too (no broken links).
EXCLUDE_DL   = re.compile(r'disc[s]?[_-]?pooper|disc[_-]?combining[_-]?kits|popstarter[_-]?elfs[_-]batcher', re.I)
# Decorative-emoji strip for the rendered site (no AI-generic look). PRESERVES the PS2
# button glyphs the recovered docs use: U+2715 (Cross/X) + the geometric shapes
# U+25A0-25FF (Circle/Triangle/Square, never in these ranges anyway).
EMOJI_OUT = re.compile(
    "[\U0001F000-\U0001FAFF"
    "\U00002600-\U00002714\U00002716-\U000027BF"   # symbols/dingbats EXCEPT U+2715 (PS2 Cross)
    "\U00002B00-\U00002BFF"
    "\U00002300-\U000023FF"
    "\U00002139\U0000FE0F\U0000FE0E\U0000200D\U000020E3]+")
def strip_emoji(s):
    return EMOJI_OUT.sub('', s)
POPS_BINS    = ('POPS.ELF', 'POPS.PAK', 'POPS_IOX.PAK', 'IOPRP252.IMG')
POPS_MD5 = {
    'POPS_IOX.PAK': 'a625d0b3036823cdbf04a3c0e1648901',
    'POPS.ELF':     '355a892a8ce4e4a105469d4ef6f39a42',
    'IOPRP252.IMG': '1db9c6020a2cd445a7bb176a1a3dd418',
}
# redistributable homebrew launcher (r13 Beta 2019-06-05) — MD5 reference, not a Sony binary
# MD5s of the POPSTARTER.ELF / .KELF inside the builds THIS SITE HOSTS, computed
# from those zips. The previous pair (97afa02d / a654a0a9) matched none of the
# three, under a heading telling people to verify their copy -- so anyone who
# followed the instruction got a mismatch and had no way to tell why.
HOMEBREW_MD5 = {
    'r13 Beta 2019-06-05 — POPSTARTER.ELF':  '4a39d44dfb477ea747f5ca5e39ee011e',
    'r13 Beta 2019-06-05 — POPSTARTER.KELF': '60feebee5c3a3e466adb490e0852314b',
    'r13 RIP 06 2017 — POPSTARTER.ELF':      '784a0ace5e4fc02574d3a9d5be74af7e',
    'r13 RIP 06 2017 — POPSTARTER.KELF':     '3a2bc50b43f2834d83e2b1d5798182e1',
    'r13 WIP 06 OBT 2017 — POPSTARTER.ELF':  '62efc58f5a4013f1a4aabafc57d7feef',
    'r13 WIP 06 OBT 2017 — POPSTARTER.KELF': '3315b21654d38ec322d12099875f1ef9',
}

# ---------- corpus ----------
entries = json.load(open(os.path.join(RES, 'entries.json'), encoding='utf-8'))
def md_text(name):
    p = os.path.join(RES, name)
    return open(p, encoding='utf-8').read() if os.path.exists(p) else ''
sections_md   = md_text('sections.md')
ambiguities_md= md_text('ambiguities.md')

# recovered downloads (apply exclusions)
dl_files = []
if os.path.isdir(DL):
    for f in sorted(os.listdir(DL)):
        if EXCLUDE_DL.search(f):       # DISCS_POOPER excluded per policy
            continue
        dl_files.append(f)
dl_basenames = {f.lower() for f in dl_files}

# recovered images: map basename(lower) -> filename
img_map = {}
if os.path.isdir(ASSET):
    for f in os.listdir(ASSET):
        img_map[f.lower()] = f

SLUG_RE = re.compile(r'[^a-z0-9]+')
def slug(s):
    return SLUG_RE.sub('-', s.lower()).strip('-')

# wiki page slugs present
wiki_pages = {}
for f in sorted(os.listdir(WIKI)):
    if f.endswith('.md') and f != 'browse.md':
        page = f[:-3]
        wiki_pages[page.lower()] = page

# unique slug per page (two pages can otherwise collide, e.g. popstarter-batcher / popstarter_batcher)
SLUG_RE = re.compile(r'[^a-z0-9]+')
def slug(s):
    return SLUG_RE.sub('-', s.lower()).strip('-')
PAGE_SLUG = {}
_used = set()
for _low, _pg in sorted(wiki_pages.items(), key=lambda kv: kv[1].lower()):
    s = slug(_pg); n = 2
    while s in _used:
        s = f"{slug(_pg)}-{n}"; n += 1
    _used.add(s); PAGE_SLUG[_low] = s
def wiki_slug(page_lower):
    return PAGE_SLUG.get(page_lower, slug(page_lower))

def safe(name):   # matches fetch_blobs.safe -> the on-disk filename form
    return ''.join(c if (c.isalnum() or c in '-_.') else '-' for c in name).strip('-')

# ---------- link/markdown processing ----------
MDX = ['tables', 'fenced_code', 'sane_lists', 'attr_list', 'nl2br', 'toc']   # toc = heading IDs so #anchors resolve
GFM_ALERT = {'NOTE': ' Note', 'TIP': ' Tip', 'IMPORTANT': ' Important',
             'WARNING': ' Warning', 'CAUTION': ' Caution'}

def strip_provenance(md):
    md = re.sub(r'^(<!--.*?-->\s*)+', '', md, flags=re.S)          # leading comment block
    md = re.sub(r'<!--.*?-->', '', md, flags=re.S)                  # any stray comments
    md = re.sub(r'^#\s+\S.*\n', '', md, count=1)                    # drop the bare "# slug" h1
    # drop the wiki page's own trailing nav footers ("### [Index]", "## Related stuff") — on a
    # merged/section page they become orphan headings that pollute the right-rail TOC.
    md = re.sub(r'(?im)^#+\s*\[?\s*\**\s*(index|related stuff)\s*\**\s*\]?(\([^)\n]*\))?\s*$', '', md)
    # the page chrome supplies the real <h1>; demote any remaining body H1 (the wiki author's
    # "# **Title**") to H2 so each rendered page has exactly one H1.
    md = re.sub(r'(?m)^#(\s)', r'##\1', md)
    return md.strip()

def first_provenance(md):
    m = re.search(r'primary snapshot:\s*(\d+)', md)
    return m.group(1) if m else None

def rewrite_and_clean(html_str):
    # 1. strip banned-host links -> keep text only
    def kill_link(m):
        href, text = m.group(1), m.group(2)
        if BANNED_HOSTS.search(href):
            return text
        if EXCLUDE_DL.search(href):
            return text
        if 'consolecopyworld' in href.lower():   # piracy-adjacent (scene cracks) -> mention only
            return text
        # bitbucket wiki page -> local
        wm = re.search(r'/popstarter-documentation-stuff/wiki/([A-Za-z0-9_%.\-]+)', href)
        if wm:
            import urllib.parse
            tgt = urllib.parse.unquote(wm.group(1)).lower()
            if tgt in wiki_pages:
                return '<a href="' + BASE + 'wiki/' + wiki_slug(tgt) + '.html">' + text + '</a>'
            return text
        # bitbucket download -> local file if recovered (and not excluded)
        dm = re.search(r'/downloads/([^"\'>]+)$', href)
        if dm:
            import urllib.parse
            fn = urllib.parse.unquote(dm.group(1))
            if EXCLUDE_DL.search(fn):
                return text
            if fn.lower() in dl_basenames:
                return '<a href="' + BASE + 'downloads/' + html.escape(fn) + '">' + text + '</a>'
            return text  # not recovered -> drop link, keep text
        # ShaolinAssassin's dead downloads-listing page -> our local Downloads page
        if re.search(r'popstarter-documentation-stuff/downloads/?$', href):
            return '<a href="' + BASE + 'downloads.html">' + text + '</a>'
        # commit-hash autolinks (md5 rendered as /commits/<hash>) -> plain text
        if '/commits/' in href:
            return text
        # surviving external link: if the VISIBLE TEXT is a long bare URL (often a full
        # Wayback-wrapped URL), show a readable domain label instead of the raw URL.
        t = text.strip()
        if re.fullmatch(r'https?://\S+', t) and len(t) > 40:
            real = t
            wb = re.search(r'web\.archive\.org/web/\d+\w*/(https?://.*)$', t)
            via = ''
            if wb:
                real, via = wb.group(1), ' <span class="via">via Wayback</span>'
            dom = re.sub(r'^https?://(www\.)?', '', real).split('/')[0]
            return '<a href="%s">%s</a>%s' % (href, html.escape(dom), via)
        return m.group(0)
    html_str = re.sub(r'<a href="([^"]*)"[^>]*>(.*?)</a>', kill_link, html_str, flags=re.S)
    # 2. rewrite <img src> to local recovered asset
    def fix_img(m):
        src = m.group(1)
        base = os.path.basename(src.split('?')[0])
        import urllib.parse
        base = urllib.parse.unquote(base)
        if base.lower() in img_map:
            return m.group(0).replace(src, BASE + 'img/' + html.escape(img_map[base.lower()]))
        return ''  # un-recovered remote image -> drop (avoid hotlink/404)
    html_str = re.sub(r'<img[^>]+src="([^"]+)"[^>]*>', fix_img, html_str)
    # redact BARE banned-host URLs left as plain text (GitHub Pages/Jekyll auto-linkifies them).
    # docs.google removed 2026-06-22 (maintainer call) — the community compat lists/forms stay LIVE.
    html_str = re.sub(
        r'https?://[^\s<>")]*?(?:elotrolado|el[_-]?patas|elpatas|byethost|epizy|000webhost)[^\s<>")]*',
        '<em>[external link removed per policy]</em>', html_str, flags=re.I)
    # (R5) fix double-escaped numeric entities (&amp;#38; -> &) that render as literal "&#38;"
    html_str = re.sub(r'&amp;#(x?[0-9a-fA-F]+);', r'&#\1;', html_str)
    return html_str

def render_md(md, strip_prov=True):
    global BASE
    if strip_prov:
        md = strip_provenance(md)
    # normalize the full-width multiplication sign the wiki used in hex ("mode 0×04",
    # "$COMPATIBILITY_0×05") back to ASCII 0x so copy-paste into CHEATS.TXT matches.
    md = re.sub(r'0×([0-9a-fA-F])', r'0x\1', md)
    # recovered tables carry leading tabs/spaces before each "| ... |" row, which
    # markdown treats as indented content -> table (and its inline links) never render.
    md = re.sub(r'(?m)^[ \t]+\|', '|', md)
    # recovered tables put a BLANK LINE between every row -> markdown renders only the header and
    # treats the data rows as literal text. Collapse blank lines between consecutive table rows.
    for _ in range(3):
        md = re.sub(r'(?m)^(\|[^\n]*)\n(?:[ \t]*\n)+(?=\|)', r'\1\n', md)
    # protect double-underscores in path/partition names (__.POPS, __common, __.<game>) from
    # markdown's bold parser, but NOT inside code spans/fences OR verbatim HTML tables
    # (recovered tables are emitted as raw <table> html and must pass through untouched).
    parts = re.split(r'(```.*?```|`[^`]+`|<table[\s\S]*?</table>)', md, flags=re.S)
    for i in range(0, len(parts), 2):
        seg = parts[i]
        # Shaolin used long runs of underscores/equals as section dividers. Rendered as text they
        # never wrap and blow out the page width. Turn standalone divider lines into a real <hr>
        # (must happen BEFORE the __ escaping below, which would otherwise mangle them).
        seg = re.sub(r'(?m)^[ \t]*[_=]{5,}[ \t]*$', '\n\n<hr>\n\n', seg)
        seg = seg.replace('__', r'\_\_')
        parts[i] = seg
    md = ''.join(parts)
    out = MD.markdown(md, extensions=MDX)
    return rewrite_and_clean(out)

FP = os.path.join(ROOT, 'firstparty')
def firstparty(name):
    p = os.path.join(FP, name)
    return render_md(open(p, encoding='utf-8').read(), strip_prov=False) if os.path.exists(p) else ''
def firstparty_raw(name):
    p = os.path.join(FP, name)
    return open(p, encoding='utf-8').read() if os.path.exists(p) else ''

# ---------- shell ----------
SECTIONS = [
    ('index',           'Home',            ''),
    ('getting-started', 'Getting Started', ''),
    ('storage',         'Storage Backends',''),
    ('cheats',          'Cheats',          ''),
    ('compatibility',   'Patches & TROJANs',''),
    ('igr',             'IGR & Hotkeys',   ''),
    ('config',          'Config Table',    ''),
    ('multidisc',       'Multi-disc & VMC',''),
    ('troubleshooting', 'Troubleshooting', ''),
    ('downloads',       'Downloads',       ''),
    ('history',         'History',         ''),
]
BASE = ''

def shell(title, body, active, base=''):
    homecls = ' class="active"' if active == 'index' else ''
    ps = []
    for sid, label, em in SECTIONS:
        if sid == 'index':
            continue
        cls = ' class="active"' if sid == active else ''
        ps.append(f'<a href="{base}{sid}.html"{cls}>{label}</a>')
    psnav = '\n'.join(ps)
    plcls = ' class="active"' if active == 'popsloader' else ''
    refcls = lambda sid: ' class="active"' if active == sid else ''
    return f'''<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} · POPStarter Docs</title>
<meta name="description" content="Resurrected, searchable POPStarter documentation — cheats, patches, config, storage, multi-disc, IGR, downloads, and the POPSLoader fork.">
<link rel="stylesheet" href="{base}assets/style.css">
</head><body data-base="{base}">
<header class="topbar">
  <button class="menu-btn" aria-label="Menu"></button>
  <a class="brand" href="{base}index.html">
    <span class="psbtns"><i class="tri">&#9651;</i><i class="cir">&#9711;</i><i class="cro">&#10005;</i><i class="squ">&#9633;</i></span>
    POPStarter <small>DOCS</small></a>
  <div class="search">
    <input id="q" type="search" placeholder="Search cheats, patches, config bytes…  ( / )" autocomplete="off">
    <kbd>/</kbd>
    <div id="results"></div>
  </div>
</header>
<div class="layout">
  <nav class="sidebar">
    <a href="{base}index.html"{homecls}>Home</a>
    <h4>POPSLoader · this project</h4>
    <a href="{base}popsloader.html"{plcls}>POPSLoader docs</a>
    <a href="{base}launch-arguments.html"{refcls('launch-args')}>Launch arguments</a>
    <h4>POPStarter · documentation</h4>{psnav}
    <h4>Reference</h4>
    <a href="{base}glossary.html"{refcls('glossary')}>Glossary</a>
    <a href="{base}commands.html"{refcls('commands')}>Command index</a>
    <a href="{base}faq.html"{refcls('faq')}>FAQ &amp; known bugs</a>
    <a href="{base}known-issues.html"{refcls('known-issues')}>Known issues</a>
    <a href="{base}compatibility-table.html"{refcls('compat-table')}>Compatibility table</a>
    <a href="{base}thread-study.html"{refcls('thread-study')}>Community knowledge</a>
    <a href="{base}credits.html"{refcls('credits')}>Credits</a>
    <a href="{base}wiki/index.html">All wiki pages</a>
    <h4>Related projects</h4>
    <a href="https://nathanneurotic.github.io/Open-PS2-Loader">RiptOPL (OPL) docs ↗</a>
    <a href="https://ps2homebrewstore.com">PS2 Homebrew Store ↗</a>
  </nav>
  <main class="content">{body}</main>
  <aside class="toc"><div class="toc-h">On this page</div><nav id="toc-nav"></nav></aside>
</div>
<footer>
  <p><b>POPStarter Documentation Archive</b> — community-recovered from the Wayback Machine
  (ShaolinAssassin's <code>popstarter-documentation-stuff</code> wiki) and krHACKen's r13 changelog,
  cross-checked and merged across snapshots. Built for the POPSLoader project.</p>
  <p class="prov-inline">POPStarter is krHACKen's homebrew launcher. <b>POPS</b> is Sony's PS1-on-PS2
  emulator and is <b>not</b> distributed here — it is referenced by checksum only. “TROJAN” is POPStarter's
  own name for a patch file, <b>not</b> malware. Some external links were intentionally removed. Built on the
  documentation of <b>ShaolinAssassin</b> and <b>krHACKen</b> — see <a href="{base}credits.html">Credits</a>.</p>
</footer>
<script src="{base}assets/app.js"></script>
</body></html>'''

def write(path, content):
    content = strip_emoji(content)
    with open(os.path.join(SITE, path), 'w', encoding='utf-8') as f:
        f.write(content)

# ---------- cards ----------
CONF_BADGE = {'primary': 'primary', 'secondary': 'secondary', 'community': 'community',
              'inferred': 'inferred', 'unconfirmed': 'unconfirmed'}
def card(e):
    name = html.escape(e.get('name', '?'))
    conf = (e.get('confidence') or '').lower()
    badge = f'<span class="badge {CONF_BADGE.get(conf,"secondary")}">{html.escape(conf or "n/a")}</span>' if conf else ''
    cat = f'<span class="cat-chip">{html.escape(e.get("category",""))}</span>'
    parts = [f'<div class="card" id="{slug(e.get("name","")) }"><h3>{name} {badge} {cat}</h3>']
    for f_, lbl in (('effect', 'Effect'), ('scope', 'Scope'), ('conflicts', 'Conflicts')):
        if e.get(f_):
            parts.append(f'<div class="field"><b>{lbl}:</b> {html.escape(str(e[f_]))}</div>')
    if e.get('example'):
        parts.append(f'<div class="ex">{html.escape(str(e["example"]))}</div>')
    if e.get('provenance'):
        parts.append(f'<div class="prov"> {html.escape(str(e["provenance"]))}</div>')
    parts.append('</div>')
    return '\n'.join(parts)

def cards_for(cats):
    out = []
    for e in entries:
        if e.get('category') in cats:
            out.append(card(e))
    return '<div class="cards">' + '\n'.join(out) + '</div>' if out else '<p>(none)</p>'

def section_prose(title_keys):
    """Pull section narratives whose TITLE LINE matches — so each block lands on exactly one page."""
    if not title_keys:
        return ''
    blocks = re.split(r'\n##\s+', sections_md)
    found = []
    for b in blocks:
        title = b.split('\n', 1)[0].lower()
        if any(k in title for k in title_keys):
            found.append('## ' + b)
    return render_md('\n'.join(found), strip_prov=False) if found else ''

CAT_PAGE = {'cheats': 'cheats', 'patches': 'compatibility', 'trojans': 'compatibility',
            'igr': 'igr', 'config': 'config', 'storage': 'storage', 'launch': 'storage',
            'vmc': 'multidisc', 'multidisc': 'multidisc', 'troubleshooting': 'troubleshooting',
            'history': 'history'}
ACRO = {'ps1','ps2','usb','hdd','smb','vmc','igr','osd','bios','vcd','mmce','mx4sio','elf','kelf',
        'pmc','cd','d2ls','ule','khn','pops','popstarter','ppf','irx','faqs','poc2'}
def pretty(page):
    out = []
    for w in page.replace('_', ' ').split('-'):
        out.append(w.upper() if w.lower() in ACRO else (w[:1].upper() + w[1:]))
    return ' '.join(out)

# ---------- ambiguity callouts ----------
def parse_ambiguities():
    items = []
    for blk in re.split(r'\n##\s+\d+\.\s*', '\n' + ambiguities_md):
        t = blk.strip()
        if not t or t.lower().startswith('# flagged') or t.startswith('>'):
            continue
        t = re.sub(r'```.*?```', '', t, flags=re.S).strip()
        if len(t) < 30:
            continue
        low = t.lower()
        sev = 'info'
        if any(k in low for k in ('unconfirmed', 'no primary', 'absent', 'does not exist', 'red ')):
            sev = 'red'
        elif any(k in low for k in ('collision', 'two separate', 'amber', 'conflict', 'swap')):
            sev = 'amber'
        # (R3) strip author-facing editorial directions that leaked into reader callouts —
        # the "present it in a RED box" UI instructions, "Confidence:" tokens, process notes.
        t = re.sub(r'(?i)\s*[-–—]?\s*Present\b[^.]*?\b(?:box|tag|warning|treatment|records?)\b[^.]*\.', '', t)
        t = re.sub(r'(?i)\bPresent (?:a caveat|a clarifying note|both numbers|a note)\s*:\s*', '', t)
        t = re.sub(r'(?i)\s*Confidence:\s*[^.\n]*\.?', '', t)
        t = re.sub(r'(?i)\s*;?\s*\bNOT byte-diffed[^.\n]*\.?', '', t)
        t = re.sub(r'(?i)\s*;?\s*\bflag (?:that|as|it)\b[^.\n]*\.?', '', t)
        t = re.sub(r'(?i)\s*[-–—]?\s*Each carries a recommended UI treatment[^.\n]*\.?', '', t)
        t = re.sub(r'[ \t]{2,}', ' ', t).strip(' -–—:;\n')
        if len(t) < 30:
            continue
        items.append((sev, t))
    return items
AMBIG = parse_ambiguities()
def callouts_matching(keys):
    out = []
    for sev, t in AMBIG:
        if any(k in t.lower() for k in keys):
            title = {'red': ' Unverified / caution', 'amber': ' Conflicting sources', 'info': ' Nuance'}[sev]
            out.append(f'<div class="callout {sev}"><div class="h">{title}</div>{html.escape(t)}</div>')
    return '\n'.join(out)

# ---------- search index ----------
search = []
def idx(title, cat, text, url, cap=8000):
    # cap raised from 520 -> 8000: a 520-char slice hid deep mentions (exFAT, 60Hz) from search.
    t = re.sub(r'\s+', ' ', (text or ''))[:cap]
    # add the $-stripped form of every $COMMAND so "forcepal" matches "$FORCEPAL" (and ranks the
    # doc, not the download). Cheap alias layer, no app.js change needed.
    extra = ' '.join(sorted(set(m.lower() for m in re.findall(r'\$([A-Za-z_][A-Za-z0-9_]*)', title + ' ' + t))))
    search.append({'title': title, 'cat': cat, 'text': (t + ' ' + extra).strip(), 'url': url})

# natural-language synonym/alias cards — map the phrasings real users type ("60hz", "black
# screen", "memory card") onto the right destination, which the literal index misses.
SYNONYMS = [
    ('Force PAL · 50/60 Hz · video standard', 'cheats.html#forcepal',
     '60hz 50hz 60 hz 50 hz pal ntsc video standard region force pal forcepal nopal black and white colour patch_8 patch_9'),
    ('Black screen on exit / IGR / BOOT.ELF', 'igr.html',
     'black screen on exit boot.elf incompatible igr loader disable patch_9 hangs after game freezes returning to launcher'),
    ('exFAT USB (BDM Assault)', 'storage.html#device-matrix',
     'exfat usb format fat32 bdm assault bdma usbexfat cluster size driver substitution usbd.irx usbhdfsd.irx'),
    ('Memory card / VMC / saves', 'multidisc.html',
     'memory card vmc virtual memory card saves save game slot0 slot1 vmcdir shared memory card does not save'),
    ('Widescreen / 16:9', 'cheats.html#widescreen',
     'widescreen 16:9 16 by 9 ultra widescreen eyefinity fov field of view aspect ratio stretched'),
    ('My cheats do nothing', 'cheats.html',
     'cheats not working cheat does nothing CHEATS.TXT uppercase filename ignored safemode $safemode hdtvfix does nothing on hdd'),
    ('USB not detected', 'troubleshooting.html',
     'usb not detected drive not found $usbdelay $413 config byte usb delay not reading flash drive'),
    ('Device support matrix (USB / HDD / MX4SIO / MMCE / iLink / ATA / SMB)', 'storage.html#device-matrix',
     'device backend matrix supported devices mx4sio mmce sd2psx memcard pro2 ilink ata internal hdd apa pfs udpbd udpfs udp block device ethernet network which devices work'),
    ('Hugopocked fixes — per-game compatibility patches', 'compatibility.html#hugopocked',
     'hugopocked fixes per game patch compatibility install vmc folder basename warcraft spider-man yu-gi-oh resident evil tekken 3 castlevania symphony of the night freeze flicker graphics crash archive password not working game'),
]
def build_synonyms():
    for title, url, alt in SYNONYMS:
        idx(title, 'find', alt, url)

# ---------- related-section funnel for raw wiki pages ----------
REL = [
    (('cheat', 'code'), 'cheats', 'Cheats'),
    (('compat', 'automated', 'rip-off', 'game-comp'), 'compatibility', 'Patches & TROJANs'),
    (('igr', 'hotkey'), 'igr', 'IGR & Hotkeys'),
    (('config',), 'config', 'Config Table'),
    (('usb', 'hdd', 'smb', 'pfs', 'irx', 'ps1cd', 'hddosd', 'radhost'), 'storage', 'Storage Backends'),
    (('multi-disc', 'vmc', 'pmc', 'd2ls', 'disc'), 'multidisc', 'Multi-disc & VMC'),
    (('bug', 'faq', 'widescreen', 'scanline', 'smooth', 'trouble', 'ds34'), 'troubleshooting', 'Troubleshooting'),
    (('quickstart',), 'getting-started', 'Getting Started'),
    (('timeline', 'chrono', 'changelog', 'proto', 'poc2', 'version', 'apps-last', 'related', 'batcher', 'ule'),
     'history', 'History'),
]
def related_section(low):
    sid = wiki_section_of(low)
    if sid in ('reference', 'index'):
        return '<p style="margin-top:26px"><a class="pill" href="index.html">← All wiki pages</a></p>'
    label = next((l for s, l, e in SECTIONS if s == sid), 'Home')
    return f'<p style="margin-top:26px"><a class="pill" href="../{sid}.html">Related curated section → {label}</a></p>'

# Taxonomy: assign EVERY recovered wiki page to one curated section. Drives both the grouped
# wiki index and the per-section "every wiki page in this topic" backlink — so none of the 63
# pages is orphaned behind a flat list (the #1 navigation finding from the audit).
WIKI_SECTION = {
    'quickstart-hdd': 'getting-started', 'quickstart-smb': 'getting-started', 'quickstart-usb': 'getting-started',
    'usb-mode': 'storage', 'hdd-mode': 'storage', 'smb-mode': 'storage', 'ps1cd-mode': 'storage',
    'popstarter-hddosd': 'storage', 'pfsshell': 'storage', 'irx-loader': 'storage', 'radhostclient': 'storage',
    'vcd': 'storage', 'ule_khn': 'storage',
    'special-cheats': 'cheats', 'cheat-engine': 'cheats',
    'ps1-codes-in-ps1-raw-format': 'cheats', 'ps1-codes-in-ps2-raw-format': 'cheats',
    'compatibility': 'compatibility', 'automated': 'compatibility', 'game-compatibility': 'compatibility', 'rip-off': 'compatibility',
    'igr': 'igr', 'hotkeys': 'igr', 'igr-textures': 'igr', 'bios-osd-handlers': 'igr',
    'configuration-table': 'config',
    'multi-disc': 'multidisc', 'vmc': 'multidisc', 'vmc-to-pmc': 'multidisc', 'pmc-to-vmc': 'multidisc', 'd2ls': 'multidisc',
    'known-bugs': 'troubleshooting', 'troubleshooting-games': 'troubleshooting', 'faqs': 'troubleshooting',
    'help': 'troubleshooting', 'debug-mode': 'troubleshooting', 'smooth': 'troubleshooting', 'scanlines': 'troubleshooting',
    'widescreen': 'troubleshooting', 'ps1-widescreen-codes': 'troubleshooting', 'ds34': 'troubleshooting',
    'ps1-special-devices': 'troubleshooting', 'ps1_buttons': 'troubleshooting', 'general-note': 'troubleshooting',
    'timeline': 'history', 'chronology': 'history', 'history': 'history', 'version': 'history', 'proto': 'history',
    'poc2-pops-00001-era': 'history', 'apps-last-version': 'history', 'popstarter-changelog': 'history',
    'cue2pops-and-toolbox-changelogs': 'history', 'popstarter9': 'history', 'popstarter10': 'history',
    'popstarter11': 'history', 'popstarter12': 'history', 'related-stuff': 'history', 'toolbox-commands': 'history',
    'popstarter-batcher': 'history', 'popstarter_batcher': 'history',
}
WIKI_GRID_EXCLUDE = {'home', 'index'}   # wiki-landing duplicates; the site has its own Home
def wiki_section_of(low):
    if low in WIKI_SECTION:
        return WIKI_SECTION[low]
    for keys, sid, label in REL:
        if any(k in low for k in keys):
            return sid
    return 'reference'

def section_wiki_grid(sid):
    """Complete tile index of every recovered wiki page classified to section `sid` —
    appended at the foot of each section so section -> wiki navigation is total."""
    items = []
    for low, page in sorted(wiki_pages.items(), key=lambda kv: kv[1].lower()):
        if low in WIKI_GRID_EXCLUDE:
            continue
        if wiki_section_of(low) == sid:
            items.append(f'<a class="tile" href="wiki/{wiki_slug(low)}.html"><b>{html.escape(pretty(page))}</b>'
                         f'<span>{html.escape(page)}</span></a>')
    if not items:
        return ''
    return (f'<h2 id="topic-index">All {len(items)} wiki pages in this topic</h2>'
            f'<p class="lead">Every recovered page filed under this section — including the deep-reference '
            f'pages not embedded above.</p><div class="grid">{"".join(items)}</div>')

# ---------- image gallery from cached source HTML ----------
# Gallery image keys are CACHED to _state/galleries.json so the site can be rebuilt
# without _html/, the 34 MB of raw Wayback snapshots. Those are deliberately NOT
# tracked: 186 of the 526 carry an AWS-key-shaped token (exactly 2 each, i.e. archive
# .org wrapper boilerplate, not a POPStarter secret) and GitHub push protection
# rightly refuses credential-shaped data in a public repo. Caching the extracted KEYS
# rather than the rendered HTML keeps rendering live, so img_map and markup changes
# still take effect on a cache-only rebuild.
GALLERY_CACHE_PATH = os.path.join(ROOT, '_state', 'galleries.json')
try:
    with open(GALLERY_CACHE_PATH, encoding='utf-8') as _gf:
        GALLERY_CACHE = json.load(_gf)
except Exception:
    GALLERY_CACHE = {}
GALLERY_FRESH = {}


def _gallery_keys_from_html(page, ts):
    """Extract the filtered image keys for a page from the raw snapshot, or None."""
    import urllib.parse
    HTMLD = os.path.join(ROOT, '_html')
    if not os.path.isdir(HTMLD):
        return None
    prefix = safe(page) + '__'
    target = os.path.join(HTMLD, f'{prefix}{ts}.html') if ts else None
    if not (target and os.path.exists(target)):
        cands = [x for x in os.listdir(HTMLD) if x.startswith(prefix)]
        if not cands:
            return []
        target = os.path.join(HTMLD, max(cands, key=lambda x: os.path.getsize(os.path.join(HTMLD, x))))
    raw = open(target, encoding='utf-8', errors='replace').read()
    keys, seen = [], set()
    for src in re.findall(r'<img[^>]+src="([^"]+)"', raw):
        b = urllib.parse.unquote(os.path.basename(src.split('?')[0]))
        key = b.lower()
        if key in img_map and key not in seen \
                and not any(s in key for s in ('avatar', 'sprite', 'emoji', 'icon-')) \
                and not re.search(r'playstation-(?:button|dpad)-', key):   # (R7) glyphs are now inline text
            seen.add(key)
            keys.append(b)          # keep the ORIGINAL case; the caption derives from it
    return keys


def page_gallery(page, ts, base='../'):
    ck = '%s|%s' % (page, ts or '')
    keys = _gallery_keys_from_html(page, ts)
    if keys is None:                       # no _html/: serve the cache
        keys = GALLERY_CACHE.get(ck, [])
    else:
        GALLERY_FRESH[ck] = keys
    out = []
    for b in keys:
        key = b.lower()
        if key not in img_map:
            continue
        cap = re.sub(r'^\d+-', '', os.path.splitext(b)[0]).replace('_', ' ').replace('-', ' ').strip()
        fn = html.escape(img_map[key])
        out.append(f'<figure><a href="{base}img/{fn}" target="_blank">'
                   f'<img src="{base}img/{fn}" alt="{html.escape(cap)}" loading="lazy"></a>'
                   f'<figcaption>{html.escape(cap)}</figcaption></figure>')
    if not out:
        return ''
    return f'<h2>Images &amp; screenshots</h2><div class="gallery">{"".join(out)}</div>'


def save_gallery_cache():
    """Refresh the tracked cache, but only from a build that actually had _html/."""
    if not GALLERY_FRESH:
        return
    os.makedirs(os.path.dirname(GALLERY_CACHE_PATH), exist_ok=True)
    merged = dict(GALLERY_CACHE)
    merged.update(GALLERY_FRESH)
    with open(GALLERY_CACHE_PATH, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(merged, fh, indent=1, sort_keys=True, ensure_ascii=False)
    print('  gallery cache: %d page(s) -> %s' % (len(merged), os.path.relpath(GALLERY_CACHE_PATH, ROOT)))



# ---------- embed full recovered wiki page content into a section (the DEPTH) ----------
def wiki_content(pages, intro=True):
    # Flow the embedded wiki pages as ONE document: bodies first (their H1s are demoted to
    # H2 so each reads as a section), then a SINGLE source byline, then any images grouped
    # at the end. Previously each page carried its own "from the recovered X wiki page"
    # provenance line + an inline gallery, which made the section look visibly stitched.
    bodies, galleries, sources = [], [], []
    for p in pages:
        low = p.lower()
        if low not in wiki_pages:
            continue
        real = wiki_pages[low]
        raw = open(os.path.join(WIKI, real + '.md'), encoding='utf-8').read()
        ts = first_provenance(raw)
        bodies.append(render_md(raw))                  # BASE is '' during build_sections -> root-relative links
        g = page_gallery(real, ts, base='')
        if g:
            galleries.append(g)
        sources.append(f'<a href="wiki/{wiki_slug(low)}.html">{html.escape(pretty(real))}</a>')
    out = '\n'.join(bodies)
    if intro and sources:
        out += ('<p class="prov-inline source-note"> Recovered from ShaolinAssassin\'s '
                + ' · '.join(sources) + (' wiki pages.' if len(sources) > 1 else ' wiki page.') + '</p>')
    out += '\n'.join(galleries)
    return out

# ---------- WIKI pages ----------
def build_wiki():
    global BASE
    BASE = '../'
    by_sec = {}
    for low, page in sorted(wiki_pages.items(), key=lambda kv: kv[1].lower()):
        raw = open(os.path.join(WIKI, page + '.md'), encoding='utf-8').read()
        ts = first_provenance(raw)
        body_html = render_md(raw)
        title = pretty(page)
        ws = wiki_slug(low)
        rel = related_section(low)
        prov = f'<p class="prov-inline"> Recovered from the ShaolinAssassin wiki' + (f' · snapshot {ts}' if ts else '') + '</p>'
        gal = page_gallery(page, ts)
        body = f'<h1>{html.escape(title)}</h1>{prov}{body_html}{gal}{rel}'
        write(f'wiki/{ws}.html', shell(title, body, None, base='../'))
        plain = re.sub(r'<[^>]+>', ' ', body_html)
        idx(title, 'wiki', plain, f'wiki/{ws}.html')
        if low not in WIKI_GRID_EXCLUDE:
            tile = f'<a class="tile" href="{ws}.html"><b>{html.escape(title)}</b><span>{html.escape(page)}</span></a>'
            by_sec.setdefault(wiki_section_of(low), []).append((page.lower(), tile))
    # grouped index keyed by Shaolin's taxonomy instead of one flat 63-tile wall
    SEC_LABEL = {sid: label for sid, label, em in SECTIONS}
    SEC_EM = {sid: em for sid, label, em in SECTIONS}
    SEC_LABEL['reference'] = 'Reference & tools'; SEC_EM['reference'] = ''
    order = ['getting-started', 'storage', 'cheats', 'compatibility', 'igr', 'config',
             'multidisc', 'troubleshooting', 'history', 'reference']
    blocks = []
    for sid in order:
        items = by_sec.get(sid)
        if not items:
            continue
        tiles = '\n'.join(t for _, t in sorted(items))
        href = '../index.html' if sid in ('index',) else f'../{sid}.html'
        head = (f'<h2>{SEC_EM.get(sid,"")} {SEC_LABEL.get(sid, sid.title())} '
                f'<a class="sec-jump" href="{href}">section →</a></h2>') if sid != 'reference' \
               else f'<h2>{SEC_EM["reference"]} {SEC_LABEL["reference"]}</h2>'
        blocks.append(head + f'<div class="grid">{tiles}</div>')
    total = sum(len(v) for v in by_sec.values())
    body = (f'<h1>All recovered wiki pages</h1><p class="lead">Every page from ShaolinAssassin\'s original '
            f'POPStarter wiki, recovered and merged across all archived snapshots ({total} pages), grouped by '
            f'topic. Each group links to its curated section.</p>' + ''.join(blocks))
    write('wiki/index.html', shell('All wiki pages', body, None, base='../'))
    BASE = ''

# ---------- DOWNLOADS ----------
DL_NOTES = [
    ('cue2pops', 'Also bundled inside the recovered Quickstarter packs.'),
    ('network_modules', 'The SMB IRX modules are inside the recovered SMB Quickstarter pack.'),
    ('ule_khn', 'uLaunchELF BOOT.ELF is inside the recovered USB Quickstarter pack.'),
    ('debug_and_halt', 'Included inside the recovered POPStarter r13 WIP 06 (2017-01-28) pack.'),
    ('sample_cheats', 'A sample CHEATS.TXT — the full CHEATS.TXT is recovered above.'),
    ('quickstarter_pack', 'Older pack; the 2020 .zip version is recovered above.'),
    ('radhostclient', 'Recovered above as RadHostClient_1.8a.7z.'),
    ('compatibility_modes', 'POPStarter compatibility-mode PATCH_#.BIN bundle.'),
    ('compatibility', 'POPStarter compatibility-mode PATCH_#.BIN bundle.'),
    ('trojan_7', 'krHACKen\'s final cumulative game-fix patch bundle (TROJAN_7.BIN, r7 2020-05-20).'),
    ('game_fixes', 'Per-game fix bundle.'),
    ('igr_behaviour', 'TROJAN_#.BIN IGR-behaviour modifiers.'),
    ('igr_textures', 'IGR menu texture pack (language-specific).'),
    ('igr_sample', 'Sample IGR textures.'),
    ('ppf_bunch', 'Config-table PPF patch pack.'),
    ('nopal_patch', 'Stock PATCH_9.BIN (disable PAL patcher).'),
    ('hddosd_sample', 'HDDOSD sample install files.'),
    ('batcher', 'PC batch-conversion helper.'),
    ('wip_05', 'Older pre-final POPStarter build.'),
    ('wip_06_obt', 'Older pre-final POPStarter build.'),
    ('r13_beta',       'Canonical final public POPStarter build (r13 Beta, 2019-06-05) — preferred over the RIP/WIP packages.'),
    ('r13_rip',        'Older r13 RIP 06 build — kept for history; use the 2019-06-05 r13 Beta for normal setup.'),
    ('disc_combining', 'Multi-disc preparation helpers — use with the manual DISCS.TXT / VMCDIR.TXT steps.'),
    ('ds3_modules_bt', 'DualShock 3 Bluetooth IRX module pack — optional, not needed for a normal storage setup.'),
    ('ds3_modules_usb','DualShock 3 USB IRX module pack — optional, not needed for a normal storage setup.'),
    ('forcepal_patch', 'PATCH_8.BIN / FORCEPAL artifact ($FORCEPAL equivalent) — do not combine with $NOPAL.'),
    ('cdmage',         'CDmage 1.02 B5 — PC tool for inspecting/repairing BIN/CUE images before conversion.'),
    ('pfsshell',       'pfsshell — PC utility for reading/writing the PS2 HDD PFS filesystem (HDD/PFS maintenance).'),
    ('cheats',         'The full recovered CHEATS.TXT command reference (plain text) — keep the name UPPERCASE on case-sensitive paths.'),
]
def dl_note(fn):
    low = fn.lower().replace('-', '_').replace(' ', '_').replace('%20', '_')
    for key, note in DL_NOTES:
        if key in low:
            return note
    return ''

def build_dl_manifest():
    mpath = os.path.join(ROOT, '_tmp', 'dl_manifest.tsv')
    if not os.path.exists(mpath):
        return ''
    def norm(s):
        return re.sub(r'[^a-z0-9]', '', os.path.splitext(s)[0].lower())
    have_map = {norm(x): x for x in dl_files}   # base-name -> actual hosted file (matches .7z<->.zip variants)
    mirrors = {}
    fp = os.path.join(ROOT, '_tmp', 'found_mirrors.tsv')
    if os.path.exists(fp):
        for l in open(fp, encoding='utf-8'):
            p = l.rstrip('\n').split('\t')
            if len(p) >= 2 and p[1].strip():
                mirrors[p[0].lower()] = p[1].strip()
    rows = []; n_rec = n_lost = n_mir = 0
    for l in open(mpath, encoding='utf-8'):
        p = l.rstrip('\n').split('\t')
        if len(p) < 2:
            continue
        fn, status = p[0], p[1]
        if norm(fn) in have_map:
            actual = have_map[norm(fn)]
            badge = '<span class="badge primary">recovered</span>'
            extra = '' if norm(actual) == norm(fn) and actual == fn else f' <span class="prov-inline">(as {html.escape(actual)})</span>'
            cell = f'<a href="downloads/{html.escape(actual)}" download>download ↓</a>{extra}'; n_rec += 1
        elif status == 'excluded':
            badge = '<span class="badge unconfirmed">withheld</span>'
            cell = 'Withheld per publishing policy'
        elif fn.lower() in mirrors:
            badge = '<span class="badge secondary">mirror</span>'
            cell = f'<a href="{html.escape(mirrors[fn.lower()])}">external mirror ↗</a>'; n_mir += 1
        else:
            badge = '<span class="badge unconfirmed">lost</span>'
            cell = 'Only the bitbucket download-<em>page</em> survives on Wayback'; n_lost += 1
        # For a RECOVERED row prefer the audited card note, keyed by the exact hosted
        # filename. dl_note() matches by substring, so 'quickstarter_pack' labelled all
        # four packs "Older pack; the 2020 .zip version is recovered above" -- including
        # the 2020 packs that ARE the current ones. dl_note() still serves the lost and
        # mirror-only rows, which have no card.
        note = ''
        if norm(fn) in have_map:
            note = DL_CARD_NOTES.get(have_map[norm(fn)], '')
        if not note:
            note = dl_note(fn)
        rows.append(f'<tr><td><code>{html.escape(fn)}</code></td><td>{badge}</td>'
                    f'<td>{cell}{(" — " + note) if note else ""}</td></tr>')
    return (f'<h2 id="archive-index">Complete original download index</h2>'
            f'<p class="lead">The full set of files ShaolinAssassin offered on the original bitbucket downloads '
            f'page — preserved here as a permanent record of <em>what once was</em> ({n_rec} recovered · '
            f'{n_mir} via mirror · {n_lost} lost). “Lost” means only the bitbucket download <em>page</em> (HTML) '
            f'survives in the Wayback Machine, not the binary — but many such files’ contents still live inside '
            f'the recovered packs above. Click a header to sort.</p>'
            f'<table data-sortable><thead><tr><th>File</th><th>Status</th><th>Where / note</th></tr></thead><tbody>'
            + ''.join(rows) + '</tbody></table>')

def human(n):
    for u in ('B', 'KB', 'MB'):
        if n < 1024: return f'{n:.0f} {u}'
        n /= 1024
    return f'{n:.1f} GB'
# ---- downloads page: purpose grouping (audited 2026-07-27) ----
# Cards are keyed by EXACT hosted filename. Do NOT fold these into DL_NOTES:
# dl_note() matches by substring and is shared with build_dl_manifest(), which
# labels lost/mirror-only files that have no card. Substring keys are what made
# the page tell a first-time visitor that the 2020 pack they need was "Older".
DL_GROUPS = [
    ("Start here: where will your games live?",
     "Pick the one that matches where you want your PS1 games stored. All three carry the same final launcher (Rev 13 Beta, 5 June 2019, byte-identical to the standalone release further down this page) and a step-by-step readme, so for most people this is the only file here they will ever need. You still supply the Sony POPS emulator yourself.",
     "PS2 + PC",
     ["POPStarter_USB_Quickstarter_Pack_20200209.zip", "POPStarter_HDD_Quickstarter_Pack_20200209.zip", "POPStarter_SMB_Quickstarter_Pack_20200209.zip"]),
    ("Turning a PS1 disc into a game file (PC)",
     "These run on your Windows PC, not on the PS2. CUE2POPS already ships inside all three packs above, so take these only if you want it on its own or your disc dump needs tidying up first.",
     "PC",
     ["CUE2POPS_2.3.zip", "cdmage1-02-1b5.zip"]),
    ("Filling a PS2 internal hard drive (PC)",
     "Skip this whole group unless you chose the internal hard drive. Two different ways to get your .VCD files into the __.POPS partition: with the drive plugged straight into your PC, or over your home network. Each comes as a look-alike pair, and the notes say which copy to take and why.",
     "PC",
     ["pfsshell-0.2a.7z", "pfsshell-0.2a.zip", "RadHostClient_1.8a.7z", "RadHostClient.zip"]),
    ("When one game misbehaves",
     "Drop-in files for a single problem game that glitches, crashes, or comes out at the wrong speed. Put one in that game's VMC folder to affect only that game, or in the POPS folder to affect all of them, and try one at a time.",
     "PS2",
     ["TROJAN_7.zip", "Compatibility_Modes.zip", "FORCEPAL_PATCH.7z", "NOPAL_PATCH.7z", "CHEATS.TXT", "SAMPLE_CHEATS.TXT"]),
    ("Optional add-ons",
     "None of this is needed to play a game. Come back once your setup is running.",
     "PS2",
     ["network_modules.7z", "DS3_modules_USB_20171017.7z", "DS3_modules_BT_20171017.7z", "IGR_textures_-_Chinese_pack.7z"]),
    ("Just the launcher",
     "The final POPStarter release on its own, for people who already have everything else, or who need the .KELF that no setup pack includes.",
     "PS2",
     ["POPStarter_r13_Beta_20190605.zip"]),
    ("Earlier builds, kept for the record",
     "Superseded. Nothing here does anything the 2019 release does not. They are kept because this is an archive, and because each one carries a document or a tool that the final release dropped.",
     "PS2",
     ["POPStarter_r13_RIP_06.zip", "POPStarter_r13_WIP_06_OBT_20170128.zip", "POPStarter_HDD_Quickstarter_Pack_20171027.7z"]),
]
DL_CARD_NOTES = {
    "POPStarter_USB_Quickstarter_Pack_20200209.zip": "Games on a USB stick. The final launcher for mass:/POPS, CUE2POPS for your PC, and the special uLaunchELF build (uLE_kHn 2019-11-10) that runs a .VCD straight from the file browser so you never rename an ELF.",
    "POPStarter_HDD_Quickstarter_Pack_20200209.zip": "Games on the PS2's internal hard drive. Same launcher, converter and special uLaunchELF, plus RadHostClient 1.8a for sending .VCD files to the __.POPS partition over your home network.",
    "POPStarter_SMB_Quickstarter_Pack_20200209.zip": "Games in a shared folder on your PC. Same launcher and converter, plus a ready-made mc0:/POPSTARTER folder of network modules and the two .DAT files you fill in with your IP address and share name. This is the one pack with no uLaunchELF.",
    "CUE2POPS_2.3.zip": "Converts a BIN/CUE disc dump into the .VCD file POPS actually reads: drag a .CUE onto the EXE, or run BULK_CUE2POPS.BAT for a whole folder. This standalone copy also carries POPS2CUE.EXE for converting back again, which the 2020 packs leave out.",
    "cdmage1-02-1b5.zip": "CDmage 1.02 Beta 5. Only needed if your dump came out as several .BIN files: it merges them into the single MODE2/2352 BIN/CUE that CUE2POPS expects.",
    "pfsshell-0.2a.7z": "Writes .VCD files into the __.POPS partition with the PS2 drive plugged straight into your PC. Take this copy of the two: it adds deba5er's pfs.bat and pfsdir.bat, the scripts the wiki's bulk-transfer tutorial uses. Run it on Windows XP, or in XP compatibility mode.",
    "pfsshell-0.2a.zip": "The same pfsshell 0.2a program and DLLs, byte for byte, without those two .bat helper scripts. Preserved because this is the copy the original archive served as a .zip.",
    "RadHostClient_1.8a.7z": "Drag .VCD files onto a window on your PC and they appear under host:/ on the PS2, ready to copy into __.POPS from uLaunchELF. Version 1.8a, the one the wiki's transfer guide assumes and the one bundled in the HDD pack.",
    "RadHostClient.zip": "Not a repackaging of the file above but the earlier 1.8 build, a genuinely different executable, and the only copy that still carries radad's original ReadMe explaining what the program does.",
    "TROJAN_7.zip": "TROJAN_7.BIN, krHACKen's cumulative per-game fix bundle (2020-04-02 / 2020-05-20 r7). Patches POPStarter globally for titles that glitch or freeze (e.g. Speedball 2100). Place in POPS/ or a game's VMC folder. Do not stack with Hugopocked per-game fixes.",
    "Compatibility_Modes.zip": "PATCH_1.BIN to PATCH_7.BIN, one per compatibility mode 0x01 to 0x07, with the README explaining what each mode fixes. Try one at a time; modes 1, 2, 3 and 5 are variants of the same hack and must never be combined.",
    "FORCEPAL_PATCH.7z": "PATCH_8.BIN, the file form of $FORCEPAL. Forces POPStarter's PAL patcher on and sets the BIOS region to Euro, for PAL discs whose bootsector lost its licence text.",
    "NOPAL_PATCH.7z": "PATCH_9.BIN, the file form of $NOPAL. Turns POPStarter's PAL patcher off. It is the opposite of the file above, so never use both, and it does not convert an NTSC game to PAL.",
    "CHEATS.TXT": "Every $ command POPStarter understands in one file, with the $ deliberately stripped so nothing fires by accident. Put it in your POPS folder and add the $ back to the lines you want, or copy those lines into a single game's CHEATS.TXT.",
    "SAMPLE_CHEATS.TXT": "A real filled-in cheat file (Crash Bash, annotated in Italian) showing how GameShark and Action Replay codes are laid out inside one game's folder. The worked example, not a command list.",
    "network_modules.7z": "The whole mc0:/POPSTARTER folder for network play: the six SMB modules, the two .DAT files to edit with your network settings, and a memory-card icon. It goes on the memory card, not next to your games. Newer than the copy inside the SMB pack, which has no icon and no 2023-dated usbd.irx / usbhdfsd.irx.",
    "DS3_modules_USB_20171017.7z": "DualShock 3 over a USB cable. Two IRX files that go loose in your POPS folder exactly as they are, never inside a game's VMC folder. Documented as working on the WIP 06 and RIP 06 launchers only, and not on the prototypes.",
    "DS3_modules_BT_20171017.7z": "The same thing over Bluetooth; only MODULE_2.IRX differs between the two packs. Same POPS-folder placement and the same launcher caveat as the USB pack.",
    "IGR_textures_-_Chinese_pack.7z": "Puts the \"return to the PlayStation 2 main menu?\" confirmation screen into Chinese. It is a .ppf you apply on your PC over your own POPS.ELF with a PPF patcher, not a folder drop-in. The only one of the seven language packs the wiki listed that survived.",
    "POPStarter_r13_Beta_20190605.zip": "Rev 13 Beta, 5 June 2019, the last public release. Its POPSTARTER.ELF is byte-identical to the one in all three packs above; what it adds is POPSTARTER.KELF, for installing a game into the PS2 Browser 2.00 (HDDOSD) as its own PP. partition, plus the full 38 KB changelog.",
    "POPStarter_r13_RIP_06.zip": "Rev 13 RIP 06, October 2017: the previous public release, and the exact launcher the 2017 hard-drive pack ships. The only package carrying FIXES.TXT, the list of games POPStarter auto-patches.",
    "POPStarter_r13_WIP_06_OBT_20170128.zip": "Rev 13 WIP 06 Beta 17, January 2017, the pre-RIP development line. Also the only surviving source of DEBUG_AND_HALT.PPF, and it bundles a CUE2POPS with POPS2CUE plus the SMB sample .DAT files.",
    "POPStarter_HDD_Quickstarter_Pack_20171027.7z": "The 2017 edition of the hard-drive pack, built on the RIP 06 launcher. Use the 2020 .zip instead; this is kept because it is the only place the older uLE_kHn 2016-07-23 browser survives.",
}
DL_CARD_PILL = {
    "POPStarter_USB_Quickstarter_Pack_20200209.zip": "PS2 + PC",
    "POPStarter_HDD_Quickstarter_Pack_20200209.zip": "PS2 + PC",
    "POPStarter_SMB_Quickstarter_Pack_20200209.zip": "PS2 + PC",
    "CUE2POPS_2.3.zip": "PC",
    "cdmage1-02-1b5.zip": "PC",
    "pfsshell-0.2a.7z": "PC",
    "pfsshell-0.2a.zip": "PC",
    "RadHostClient_1.8a.7z": "PC",
    "RadHostClient.zip": "PC",
    "TROJAN_7.zip": "PS2",
    "Compatibility_Modes.zip": "PS2",
    "FORCEPAL_PATCH.7z": "PATCH_8.BIN, the file form of $FORCEPAL. Forces POPStarter's PAL patcher on and sets the BIOS region to Euro, for PAL discs whose bootsector lost its licence text.",
    "NOPAL_PATCH.7z": "PATCH_9.BIN, the file form of $NOPAL. Turns POPStarter's PAL patcher off. It is the opposite of the file above, so never use both, and it does not convert an NTSC game to PAL.",
    "CHEATS.TXT": "Every $ command POPStarter understands in one file, with the $ deliberately stripped so nothing fires by accident. Put it in your POPS folder and add the $ back to the lines you want, or copy those lines into a single game's CHEATS.TXT.",
    "SAMPLE_CHEATS.TXT": "A real filled-in cheat file (Crash Bash, annotated in Italian) showing how GameShark and Action Replay codes are laid out inside one game's folder. The worked example, not a command list.",
    "network_modules.7z": "The whole mc0:/POPSTARTER folder for network play: the six SMB modules, the two .DAT files to edit with your network settings, and a memory-card icon. It goes on the memory card, not next to your games. Newer than the copy inside the SMB pack, which has no icon and no 2023-dated usbd.irx / usbhdfsd.irx.",
    "DS3_modules_USB_20171017.7z": "DualShock 3 over a USB cable. Two IRX files that go loose in your POPS folder exactly as they are, never inside a game's VMC folder. Documented as working on the WIP 06 and RIP 06 launchers only, and not on the prototypes.",
    "DS3_modules_BT_20171017.7z": "The same thing over Bluetooth; only MODULE_2.IRX differs between the two packs. Same POPS-folder placement and the same launcher caveat as the USB pack.",
    "IGR_textures_-_Chinese_pack.7z": "Puts the \"return to the PlayStation 2 main menu?\" confirmation screen into Chinese. It is a .ppf you apply on your PC over your own POPS.ELF with a PPF patcher, not a folder drop-in. The only one of the seven language packs the wiki listed that survived.",
    "POPStarter_r13_Beta_20190605.zip": "Rev 13 Beta, 5 June 2019, the last public release. Its POPSTARTER.ELF is byte-identical to the one in all three packs above; what it adds is POPSTARTER.KELF, for installing a game into the PS2 Browser 2.00 (HDDOSD) as its own PP. partition, plus the full 38 KB changelog.",
    "POPStarter_r13_RIP_06.zip": "Rev 13 RIP 06, October 2017: the previous public release, and the exact launcher the 2017 hard-drive pack ships. The only package carrying FIXES.TXT, the list of games POPStarter auto-patches.",
    "POPStarter_r13_WIP_06_OBT_20170128.zip": "Rev 13 WIP 06 Beta 17, January 2017, the pre-RIP development line. Also the only surviving source of DEBUG_AND_HALT.PPF, and it bundles a CUE2POPS with POPS2CUE plus the SMB sample .DAT files.",
    "POPStarter_HDD_Quickstarter_Pack_20171027.7z": "The 2017 edition of the hard-drive pack, built on the RIP 06 launcher. Use the 2020 .zip instead; this is kept because it is the only place the older uLE_kHn 2016-07-23 browser survives.",
}
DL_CARD_PILL = {
    "POPStarter_USB_Quickstarter_Pack_20200209.zip": "PS2 + PC",
    "POPStarter_HDD_Quickstarter_Pack_20200209.zip": "PS2 + PC",
    "POPStarter_SMB_Quickstarter_Pack_20200209.zip": "PS2 + PC",
    "CUE2POPS_2.3.zip": "PC",
    "cdmage1-02-1b5.zip": "PC",
    "pfsshell-0.2a.7z": "PC",
    "pfsshell-0.2a.zip": "PC",
    "RadHostClient_1.8a.7z": "PC",
    "RadHostClient.zip": "PC",
    "TROJAN_7.zip": "PS2",
    "Compatibility_Modes.zip": "PS2",
    "FORCEPAL_PATCH.7z": "PS2",
    "NOPAL_PATCH.7z": "PS2",
    "CHEATS.TXT": "edit + copy",
    "SAMPLE_CHEATS.TXT": "edit + copy",
    "network_modules.7z": "PS2",
    "DS3_modules_USB_20171017.7z": "PS2",
    "DS3_modules_BT_20171017.7z": "PS2",
    "IGR_textures_-_Chinese_pack.7z": "PC",
    "POPStarter_r13_Beta_20190605.zip": "PS2",
    "POPStarter_r13_RIP_06.zip": "PS2",
    "POPStarter_r13_WIP_06_OBT_20170128.zip": "PS2",
    "POPStarter_HDD_Quickstarter_Pack_20171027.7z": "PS2",
}
DL_INTRO = "Most people need exactly one file from this page. If you are setting POPStarter up for the first time, the only decision you have to make is where your PS1 games will live: on a USB stick, on the PS2's internal hard drive, or in a shared folder on your PC. Take the matching pack at the top and you get the launcher, the disc converter and a step-by-step readme in one download. Everything after that is a PC tool, a fix for one badly behaved game, an optional add-on, or an older build kept purely for the record. Nothing here is hidden or retired. Where two files look like the same thing in two archive formats, the note says whether they really are, because some are and some turn out to be different versions. The Sony POPS emulator files are not hosted here and never will be; check your own copies against the checksums listed above."


def build_downloads():
    def _card(f):
        size = os.path.getsize(os.path.join(DL, f))
        ext = (os.path.splitext(f)[1].lstrip('.').upper() or 'BIN')[:4]
        note = DL_CARD_NOTES.get(f) or dl_note(f)
        pill = DL_CARD_PILL.get(f, '')
        pill_html = f'<span class="pill">{html.escape(pill)}</span> ' if pill else ''
        desc = pill_html + human(size) + (f' · {html.escape(note)}' if note else '')
        idx(f, 'download', 'download archive ' + note, 'downloads.html')
        return (f'<a class="dl" href="downloads/{html.escape(f)}" download>'
                f'<span class="ext">{ext}</span><span><b>{html.escape(f)}</b>'
                f'<span>{desc}</span></span></a>')

    # Every hosted file must reach the page. Anything not yet grouped falls into a
    # visible catch-all rather than vanishing -- this is a preservation archive, so a
    # silently dropped download is the one unacceptable failure.
    grouped = [f for _t, _b, _d, fs in DL_GROUPS for f in fs]
    missing = [f for f in dl_files if f not in grouped]
    sections = []
    for title, blurb, _dest, files in DL_GROUPS:
        have = [f for f in files if f in dl_files]
        if not have:
            continue
        sections.append(f'<h2>{html.escape(title)}</h2><p class="lead">{html.escape(blurb)}</p>'
                        f'<div class="dl-grid">{"".join(_card(f) for f in have)}</div>')
    if missing:
        print('  WARNING: %d download(s) not in DL_GROUPS, shown under Uncategorised: %s'
              % (len(missing), ', '.join(missing)))
        sections.append('<h2>Uncategorised</h2><p class="lead">Recovered files not yet '
                        'sorted into a group above. Nothing here is retired.</p>'
                        f'<div class="dl-grid">{"".join(_card(f) for f in missing)}</div>')
    cards = sections
    md5 = '<div class="note-md5">' + '<br>'.join(
        f'<b>{html.escape(n)}</b> — MD5 <code>{h}</code>' for n, h in POPS_MD5.items()) + '</div>'
    hb_md5 = ('<h2>Homebrew launcher checksums</h2><p class="lead">The POPStarter launcher itself <b>is</b> '
              'redistributable homebrew. These are the MD5s of the files inside the builds hosted below, so you can identify a copy you already have as well as verify a download:</p>''<div class="note-md5">'
              + '<br>'.join(f'<b>{html.escape(n)}</b> — MD5 <code>{h}</code>' for n, h in HOMEBREW_MD5.items())
              + ' <span class="prov-inline">(<code>.KELF</code> = the encrypted form for HDDOSD <code>PP.&lt;game&gt;</code> installs)</span></div>')
    manifest = build_dl_manifest()
    # images that were referenced but never archived as the binary (preserve the record)
    lost_imgs = []
    sp = os.path.join(ROOT, '_state', 'assets_done.tsv')
    if os.path.exists(sp):
        have_i = {x.lower() for x in img_map.values()}
        seen = set()
        for l in open(sp, encoding='utf-8'):
            p = l.rstrip('\n').split('\t')
            if len(p) >= 2 and (p[1].startswith('FAIL') or p[1] == 'no-snapshot'):
                fn = p[0].split('/')[-1].split('?')[0]
                if fn.lower().rsplit('.', 1)[-1] in ('jpg', 'jpeg', 'png', 'gif', 'bmp') \
                        and fn.lower() not in have_i and fn.lower() not in seen:
                    seen.add(fn.lower()); lost_imgs.append(fn)
    img_ledger = ''
    if lost_imgs:
        img_ledger = ('<h2>Lost wiki images</h2><p class="lead">Comparison/screenshot images referenced by the '
                      'wiki that the Wayback Machine never archived as the actual image file. Recorded for '
                      f'completeness ({len(lost_imgs)}).</p><p>'
                      + ' '.join(f'<span class="pill">{html.escape(i)}</span>' for i in sorted(lost_imgs)) + '</p>')
    archive_card = ('<div class="archive-cta"><div class="h">Download the complete archive (offline)</div>'
                    '<p>Grab the <b>entire</b> recovered documentation set as one self-contained <code>.zip</code> — '
                    'all 63 wiki pages, every reference page (glossary, FAQ, command index, the full thread study), '
                    'the recovered downloads, the menu images, <i>and</i> the raw source markdown. Open '
                    '<code>index.html</code> inside it to browse the whole site offline. Contains '
                    '<b>no Sony binaries</b>.</p>'
                    '<a class="btn" href="popstarter-docs-archive.zip" download> Download the full archive (__ARCHIVE_SIZE__)</a>'
                    '</div>')
    body = f'''<h1>Downloads</h1>
<p class="lead">Every POPStarter-related file recovered from the archive, served locally so it never 404s again.
{len(dl_files)} files (POPStarter builds, Quickstarter packs, tools, patches &amp; cheat references) —
all verified to contain <b>no Sony emulator binaries</b>.</p>
<div class="callout info"><div class="h">Which of these do I need?</div>{html.escape(DL_INTRO)}</div>
{archive_card}
<div class="callout info"><div class="h">About POPS</div>The POPS emulator (Sony copyright) is <b>not</b>
distributed here. Verify your own legally-obtained files against the checksums ShaolinAssassin published:</div>
{md5}
{hb_md5}
{''.join(cards)}
{manifest}
{img_ledger}'''
    write('downloads.html', shell('Downloads', body, 'downloads'))

# ---------- SECTION pages ----------
def page(active, title, lead, body_html, topic_index=True):
    if topic_index:
        body_html += section_wiki_grid(active)
    body = f'<h1>{html.escape(title)}</h1><p class="lead">{lead}</p>{body_html}'
    write(active + '.html', shell(title, body, active))
    plain = re.sub(r'<[^>]+>', ' ', body_html)
    idx(title, 'section', lead + ' ' + plain, active + '.html')

def wiki_links(names):
    out = []
    for n in names:
        if n.lower() in wiki_pages:
            out.append(f'<a class="tile" href="wiki/{wiki_slug(n.lower())}.html"><b>{html.escape(pretty(n))}</b><span>full wiki page</span></a>')
        else:
            print(f"  !! wiki_links: '{n}' is not a known wiki slug — link dropped silently", flush=True)
    return '<div class="grid">' + '\n'.join(out) + '</div>' if out else ''

EQUIV_TABLE = '''<h2 id="equivalence">Equivalence map — one capability, three ways</h2>
<p class="lead">POPStarter frequently exposes the same capability as a CHEATS.TXT <code>$command</code>, a binary
<code>PATCH_#.BIN</code>, and/or a <code>TROJAN_#.BIN</code> — use whichever suits your setup. Click a header to sort.</p>
<table data-sortable>
<thead><tr><th>Capability</th><th>CHEATS.TXT</th><th>PATCH file</th><th>TROJAN file</th><th>Config byte</th><th>Notes</th></tr></thead>
<tbody>
<tr><td>Compatibility mode</td><td><code>$COMPATIBILITY_0x##</code></td><td><code>PATCH_#.BIN</code> (#=1–7)</td><td>—</td><td><code>$418–$41F</code> array</td><td>## is hex 01–07</td></tr>
<tr><td>Disable IGR</td><td><code>$NOIGR</code></td><td><code>PATCH_0.BIN</code></td><td>—</td><td>—</td><td>turns In-Game Reset off</td></tr>
<tr><td>IGR behaviour</td><td><code>$IGR0</code> … <code>$IGR5</code></td><td>—</td><td><code>TROJAN_0.BIN</code> … <code>TROJAN_5.BIN</code></td><td>—</td><td>0–2 open menu · 3–5 terminate</td></tr>
<tr><td>Disable PAL patcher</td><td><code>$NOPAL</code></td><td>stock <code>PATCH_9.BIN</code></td><td>—</td><td><code>$42A=0x00</code></td><td>PAL game runs native NTSC</td></tr>
<tr><td>Force PAL</td><td><code>$FORCEPAL</code></td><td><code>PATCH_8.BIN</code></td><td>—</td><td><code>$42A</code></td><td>PAL patcher + Euro region</td></tr>
<tr><td>480p output</td><td><code>$480p</code></td><td>—</td><td>—</td><td><code>$42A=0x02</code></td><td>not reliable on all titles</td></tr>
<tr><td>Per-game fix bundle</td><td>—</td><td>—</td><td><code>TROJAN_7.BIN</code></td><td>—</td><td>cumulative per-game fixes</td></tr>
</tbody></table>'''

DEVICE_MATRIX = '''<h2 id="device-matrix">Device &amp; storage backend matrix</h2>
<p class="lead">Where your VCDs can live and how the launcher reaches each device. Stock POPStarter ships
USB / internal-HDD / SMB. In the <a href="popsloader.html">POPSLoader fork</a>, the <b>BDMA&nbsp;Mode</b> setting
is the mass-storage <b>device selector</b> — <code>FAT32</code> (plain USB), <code>USBEXFAT</code> (exFAT USB),
<code>MX4SIO</code>, <code>MMCE</code>, or <code>ATA</code> (<b>exFAT internal HDD</b>) — so BDMA is what lets you
use exFAT USB, the <b>internal exFAT HDD</b>, and the other devices (MX4SIO, MMCE), not just exFAT-USB. <b>BDMA is
required for every device except an APA/PFS internal HDD.</b> Backends marked “untested” are wired as menu stubs
but not yet hardware-verified. Click a header to sort.</p>
<table data-sortable>
<thead><tr><th>Backend</th><th>Filesystem</th><th>How it's reached</th><th>Status</th></tr></thead>
<tbody>
<tr><td>Internal HDD (APA/PFS)</td><td>APA / PFS</td><td>native (no BDMA)</td><td> Working</td></tr>
<tr><td>Internal HDD (exFAT)</td><td>exFAT on the internal SATA/IDE drive</td><td>BDMA <code>ATA</code></td><td> New</td></tr>
<tr><td>USB</td><td>FAT32</td><td>BDMA <code>FAT32</code></td><td> Working</td></tr>
<tr><td>USB (exFAT)</td><td>exFAT</td><td>BDMA <code>USBEXFAT</code></td><td> Working</td></tr>
<tr><td>MX4SIO</td><td>FAT32 / exFAT — SD via SIO2 slot</td><td>BDMA <code>MX4SIO</code></td><td> Working</td></tr>
<tr><td>MMCE</td><td>SD2PSX / MemCard&nbsp;PRO2</td><td>BDMA <code>MMCE</code></td><td> Working</td></tr>
<tr><td>Disc (DKWDRV)</td><td>physical PS1 disc handoff</td><td>fork</td><td> Working</td></tr>
<tr><td>SMB&nbsp;(v1)</td><td>network share</td><td>POPStarter core + fork browser</td><td> Implemented — validating on hardware</td></tr>
<tr><td>iLink (IEEE&nbsp;1394)</td><td>exFAT over FireWire</td><td>BDM (fork)</td><td> Stub — untested</td></tr>
</tbody></table>
<div class="callout amber"><div class="h">BDMA Mode is the device selector — and exFAT isn't native POPS</div>
In the POPSLoader fork, <b>BDMA&nbsp;Mode</b> picks the mass-storage backend: <code>FAT32</code> (plain USB, no
special driver), <code>USBEXFAT</code> (exFAT USB), <code>MX4SIO</code>, <code>MMCE</code>, or <code>ATA</code>
(the <b>internal exFAT HDD</b> — newly added via R3Z3N's ATA BDM&nbsp;Assault drivers; built and CI-green,
validating on hardware). Everything except an APA/PFS internal HDD goes through BDMA — it loads the
<b>BDM&nbsp;Assault</b> driver set, which is how the launcher reaches exFAT USB, the exFAT internal HDD, and the
MX4SIO / MMCE devices. POPS itself still never reads an exFAT filesystem — BDMA presents the files to it. The
iLink backend extends the same BDM mechanism but is not hardware-tested yet. For large
FAT32/exFAT USB or HDD volumes, <b>32 KB or 64 KB allocation (cluster) size</b> is the confirmed-working format.</div>'''

HUGOPOCKED = '''<h2 id="hugopocked">Hugopocked fixes — the leading community compatibility pack</h2>
<p class="lead">When POPS' built-in fixes and the compatibility modes above aren't enough, <b>Hugopocked's per-game
fixes</b> are the most comprehensive and still-actively-maintained patch set for POPStarter. They pick up where
krHACKen's official fixes left off and push many titles that POPS gets wrong — freezes, garbled graphics,
flickering, invisible characters — over the line to fully playable. Combined with POPStarter's built-in fixes
and the compatibility modes, the great majority of the PS1 library runs correctly.</p>
<div class="callout info"><div class="h">How to install — per game, not global</div>Hugopocked fixes install
<b>differently</b> from the global <code>TROJAN_#.BIN</code> / <code>PATCH_#.BIN</code> files: you drop the fix
into <b>that game's own folder</b> — the same per-game folder that holds its VMC — matched to the VCD basename:
<ul>
<li>USB — <code>mass:/POPS/&lt;GameBasename&gt;/</code></li>
<li>Internal HDD — <code>hdd:/__common/POPS/&lt;GameBasename&gt;/</code></li>
<li>SMB — <code>smb:/POPS/&lt;GameBasename&gt;/</code></li>
</ul>
The pack ships as <code>Hugopocked_POPStarter_Fixes_(2023-08-11).rar</code> (archive password
<code>hugopocked</code>), with newer individual fixes posted since — e.g. an improved <b>Tekken&nbsp;3</b> fix
dated 2024-01-31. The <a href="https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/">Hugopocked
thread on PSX-Place</a> is for <b>patch installation only</b> (not general emulator-install support), and its
external download links are volatile.</div>
<div class="callout amber"><div class="h">Don't stack Hugopocked with TROJAN_7.BIN for the same game</div>
<code>TROJAN_7.BIN</code> is the <b>global cumulative</b> bundle (krHACKen + Hugopocked, 2020-04-02), dropped in
the POPS folder; Hugopocked's per-game fixes go <b>in the game's own folder</b>. Applying <b>both</b> to the same
title <b>adds</b> crashes — use one or the other.</div>
<p>Representative fixes from the pack (community-reported): <b>Warcraft II</b> (freezing), <b>Spider-Man</b>
(graphics), <b>Yu-Gi-Oh! Forbidden Memories</b> (flickering), <b>Resident Evil 3</b> (SLUS-00923, made finishable),
<b>Castlevania: Symphony of the Night</b> Japanese (<i>Akumajou Dracula X – Gekka no Yasoukyoku</i>), and
<b>Tekken&nbsp;3</b>. When a game shows a “black” or empty level it is often not a true black screen — the GTE
places the player's 3D coordinates off-stage, and a Hugopocked-style code repositions it back on screen.</p>
<div class="callout amber"><div class="h">SPU_IRQ_ON — an audio/SPU mode for non-terminating sound loops <span style="opacity:.8">(community-reported · placement to verify)</span></div>
Alongside the per-game fixes, Hugopocked is also reported to have offered an <b><code>SPU_IRQ_ON</code></b> audio/SPU
compatibility mode for titles that suffer <b>non-terminating sound loops or audio freezes</b>. Treat it as a
<b>medium-confidence, unverified</b> datapoint: its placement among the Hugopocked fixes is <b>still to be verified</b>,
and Hugopocked later reported <b>individual per-game fixes that supersede it</b>. If you hit a stuck audio loop, prefer
the game-specific Hugopocked fix where one exists; no package is mirrored here.</div>'''

COMMUNITY_FAILS = '''<h2 id="community-fails">Community-reported known-fails (not auto-fixed)</h2>
<p class="lead">A handful of titles were flagged as imperfect by testers in a single Portuguese community thread
(ps2home.forumeiro.com, 16 pages). These are <b>unverified, low-confidence datapoints</b> — symptom observations
only. They are <b>not</b> entries in POPStarter's automated per-game fix database below, and several titles here
<i>do</i> have authoritative auto-fixes in that database under their exact disc IDs, so your results may differ.</p>
<div class="callout amber"><div class="h">Community-reported, not auto-fixed — symptoms only, no settings implied</div>
The thread also published guessed compatibility-mode numbers for these games; those trial-and-error guesses are
<b>deliberately omitted</b> here because they conflict with the authoritative auto-fix database. Treat the list as
"things one tester saw," not a recommended configuration:
<ul>
<li><b>Need for Speed 3</b> — in-game music does not play.</li>
<li><b>Final Fantasy Anthology (Final Fantasy VI)</b> — sound errors in menu and battle sequences.</li>
<li><b>SaGa Frontier II</b> — heavy slowdown during battles. <i>(Our auto-fix DB does carry SaGa Frontier 2 entries — check there first.)</i></li>
<li><b>Tales of Phantasia</b> — reportedly needs its voice files extracted to behave.</li>
<li><b>Valkyrie Profile (CD1)</b> — reported trouble saving past the opening.</li>
<li><b>Ace Combat 3</b> — graphical errors specific to the PAL release.</li>
<li><b>Tobal 2 (English-patched)</b> — slowdowns. <i>(Our auto-fix DB lists Tobal 2 v1.1 SLPM-86033 — see the database below.)</i></li>
</ul></div>'''

def quickref(cats, label='Cross-sourced quick-reference cards (provenance-tagged)'):
    c = cards_for(cats)
    if not c or '(none)' in c:
        return ''
    return f'<details class="deep"><summary>{label}</summary>{c}</details>'

def build_sections():
    page('cheats', 'Cheats — CHEATS.TXT',
         'POPStarter\'s embedded cheat engine. Codes live in a CHEATS.TXT in the game\'s VMC folder; '
         'always start it with <code>$SAFEMODE</code>. The full recovered cheat documentation is below, '
         'followed by community additions and a quick-reference.',
         '<div class="callout red"><div class="h">Read these first — the four silent footguns</div><ul>'
         '<li><b>The file must be named <code>CHEATS.TXT</code> in UPPERCASE</b> on internal HDD/PFS — a '
         '<code>CHEATS.txt</code> is silently ignored (the real cause of most "my cheat / <code>$HDTVFIX</code> '
         'does nothing on HDD" reports).</li>'
         '<li><b><code>$SAFEMODE</code> only gates <i>raw</i> GameShark codes</b> — it delays them until after POPS '
         'startup. Named <code>$commands</code> (<code>$NOPAL</code>, <code>$IGR#</code>, <code>$WIDESCREEN</code>…) '
         'do <b>not</b> need it; it\'s harmless but unnecessary if your file has no raw codes.</li>'
         '<li><b>The external device mastercode <code>902377F4 0C0902EF</code> is for ps2rd / CodeBreaker only</b> — '
         '<b>do not</b> put it in <code>CHEATS.TXT</code>. The in-file mastercode is the per-game <code>C0</code> type.</li>'
         '<li><b>Copy <code>0x##</code> not <code>0×##</code></b> — paste hex with an ASCII <code>x</code>.</li></ul></div>'
         '<div class="callout info"><div class="h">Command nuances worth knowing</div><ul>'
         '<li><code>$NOPAL</code> (PAL→native NTSC) usually needs a <code>$YPOS_##</code> companion (e.g. '
         '<code>$YPOS_10</code>) to re-center the picture afterward.</li>'
         '<li><code>$HDTVFIX</code> is the <b>SetGsCrt hack</b> under a friendlier name (the original wiki lists it '
         'only as "SetGsCrt hack", and it is config byte <code>$412</code>, so all three names mean one setting). '
         'It turns interlacing <b>on</b>: 480i on NTSC, 576i on PAL. Use it for an HDTV that refuses the PS1\'s '
         '240p/288p over component and shows a green screen. If a game unexpectedly shows 480i instead of 240p, '
         'check for a stray <code>$HDTVFIX</code>. Don\'t use it as a default (CRT interlace flicker).</li>'
         '<li><code>$USBDELAY_#</code> patches POPS for <i>streaming</i> stalls (try +2–3) — it does <b>not</b> fix '
         '"USB not detected"; raise config byte <code>$413</code> for detection.</li></ul></div>' +
         callouts_matching(['cheat', 'safemode', 'master']) +
         wiki_content(['special-cheats', 'cheat-engine']) +
         firstparty('thread-cheats.md') +
         '<h2>Ready-to-use PS1 code lists</h2><p class="lead">Massive collections of PS1 GameShark/Action-Replay '
         'codes in POPS-ready format (large pages):</p>' +
         wiki_links(['ps1-codes-in-ps2-raw-format', 'ps1-codes-in-ps1-raw-format']) +
         quickref(['cheats']))

    page('compatibility', 'Compatibility — Patches & TROJANs',
         'PATCH_#.BIN files, $COMPATIBILITY modes, and TROJAN_# behaviour modifiers — three forms of the '
         'same capability. <b>“TROJAN” is POPStarter\'s name for a patch file, not malware.</b>',
         '<div class="callout info"><div class="h">“TROJAN” = patch file</div>In POPStarter docs a “TROJAN” '
         'is simply a binary patch/behaviour file. It is <b>not</b> malicious software.</div>'
         '<div class="callout info"><div class="h">Before you chase a patch — start from a clean CUE2POPS conversion</div>'
         'Many "no music / missing voices" reports are not a patch problem at all but a <b>conversion</b> problem: '
         'a disc converted without its CDDA (Red Book) audio tracks will never play that audio no matter which '
         'compatibility mode you set. <b>CUE2POPS</b> is the standard prep step that bakes the audio tracks (and '
         'multi-disc layout) into the <code>.VCD</code> POPStarter plays — community docs flag it as <b>essential</b> '
         'for games with CDDA soundtracks and for multi-disc titles. If audio is wrong, re-check the conversion first; '
         'only then reach for the patches and modes below. See the <a href="getting-started.html#usb">conversion '
         'walk-through</a> and grab the tool from the <a href="downloads.html">Downloads</a> page.</div>' +
         EQUIV_TABLE +
         '<div class="callout amber"><div class="h">Same filename, different file — check before you drop it in</div>'
         'Two patch names carry two unrelated roles across sources. <code>PATCH_9.BIN</code>: the stock '
         '<b>disable-PAL-patcher</b> patch (= <code>$NOPAL</code>) <i>and</i> the <b>disable-ELF-loader</b> fix '
         'krHACKen posted for the BOOT.ELF black-screen-on-exit bug. <code>PATCH_5.BIN</code>: a stock '
         'compatibility-mode patch <i>and</i> the custom <b>IGR texture pack</b> shipped in El_isra\'s POPSLoader. '
         'Confirm which one you have.</div>'
         '<div class="callout info"><div class="h">TROJAN_7.BIN — the farewell cumulative</div>'
         '<code><a href="downloads/TROJAN_7.zip" download>TROJAN_7.zip</a></code> (containing <code>TROJAN_7.BIN</code>, 2020-04-02 / 2020-05-20 r7) bundles krHACKen\'s + Hugopocked\'s per-game fixes. Although '
         'cumulative, it is applied <b>per game</b> — placed in that game\'s VMC folder (or the POPS folder), not stacked with separate '
         'Hugopocked patches for the same title. Download it from the <a href="downloads.html">Downloads</a> page or <a href="downloads/TROJAN_7.zip" download>directly here</a>. The digit is a slot, not a version; POPStarter validates the file '
         'header against the filename. Compatibility modes map to config bytes <code>$418</code>–<code>$41F</code> '
         '(the force-mode array) — see the <a href="config.html">Config Table</a>.</div>'
         '<h2 id="hardware-caveats">Hardware caveats — when the console itself is the problem</h2>'
         '<p class="lead">A few compatibility problems are not per-game at all — they come from the PS2 hardware '
         'revision rather than the disc. These are community-reported datapoints from the regional forums; treat '
         'them as field reports, not measured facts.</p>'
         '<div class="callout amber"><div class="h">PAL "M-chip" consoles + <i>older</i> POPS patches (community-reported)</div>'
         'Owners of certain PAL consoles described as having an <b>"M-chip"</b> reported that <b>older POPS patch sets '
         'fail to run</b> on their systems, where the same setup works on other consoles; the community workaround was '
         'to <b>use a newer POPStarter / POPS build</b>. <b>Why</b> this happens was never established in the source '
         'thread — treat the cause as unknown and the trigger (console revision, not the game) as the only reliable '
         'takeaway. <b>Terminology:</b> "M-chip" is forum shorthand; the actual Sony component is the <b>Mechacon</b> '
         '(the PS2\'s mechatronics controller IC, which varies by console revision) — search your model\'s Mechacon '
         'revision rather than "M-chip" if you want to research this.</div>'
         '<div class="callout amber"><div class="h">PS2 Slim + USB virtual memory card saves (era-specific, community-reported)</div>'
         'An <b>early-era community report</b> (a Portuguese PS2Home thread from the original USB-patch days, well '
         'before the canonical r13 build) describes Slim consoles where a PS1 save written to a <b>USB</b> VMC appears '
         'to take but then <b>vanishes after a power-off or reset</b>, while the same save on the <b>internal HDD</b> '
         'held. <b>We have not confirmed this still occurs on current POPStarter (r13, 2019)</b> — the original source '
         'itself lists "whether newer versions fix this" as an open question, and our verified r13 corpus documents no '
         'such defect either way. Treat it as a historical, low-confidence datapoint: if you can save reliably '
         'elsewhere but not to a USB VMC on a Slim, keep that game on the HDD. VMC behaviour is governed by config '
         'byte <code>$429</code> (see the <a href="config.html">Config Table</a>), not by anything Slim-specific in '
         'our docs.</div>' +
         HUGOPOCKED +
         COMMUNITY_FAILS +
         wiki_content(['compatibility']) +
         callouts_matching(['patch_7', 'patch_9', 'patch 7', 'patch 9', 'pal', 'libcrypt']) +
         '<h2 id="per-game">Per-game compatibility database</h2><p class="lead">krHACKen\'s integrated per-game fixes, LibCrypt '
         'cracks and compatibility modes — the full recovered database (Driver 2, Metal Gear Solid, DonPachi, '
         'Tomb Raider and hundreds more). '
         '<b>Prefer to search/sort it?</b> See the <a href="compatibility-table.html">searchable per-game table →</a></p>' +
         wiki_content(['automated']) +
         firstparty('thread-compat.md') + firstparty('thread-patches.md') +
         '<h2>More sources</h2>' + wiki_links(['Game-Compatibility', 'rip-off']) +
         quickref(['patches', 'trojans']))

    page('igr', 'IGR & Hotkeys',
         'In-Game Reset, the <code>mc0:/BOOT/BOOT.ELF</code> exit chain, and the in-game hotkeys.',
         callouts_matching(['igr', 'boot.elf']) +
         wiki_content(['igr', 'hotkeys', 'bios-osd-handlers', 'igr-textures']) +
         section_prose(['in-game reset']) +
         quickref(['igr']))

    page('config', 'Config Table ($410–$42F)',
         'POPStarter r13 stores a 32-byte configuration table at file offset <code>$410</code> inside '
         'POPSTARTER.ELF/.KELF. Each byte is one setting.',
         '<div class="callout info"><div class="h">$412: "SetGsCrt hack" and "$HDTVFIX" are one setting, '
         'under two names</div>'
         '<p>The table below is krHACKen\'s original wording, so <code>$412</code> appears there only as the '
         '<b>SetGsCrt hack</b>. That is the same switch this site and <code>CHEATS.TXT</code> call '
         '<code>$HDTVFIX</code>. Setting <code>$412</code> to <code>0x01</code> and putting <code>$HDTVFIX</code> '
         'in <code>CHEATS.TXT</code> do the identical job, and krHACKen said as much when he made it default-off '
         'in Beta 16: "add $HDTVFIX to your CHEATS.TXT, or patch the offset 412h of the ELF/KELF".</p>'
         '<p><b>One caveat on the original note.</b> It reads "helps with the HDTVs that can\'t deal with the '
         'interlaced resolutions thru component", which is back to front for what the byte actually does. The hack '
         'pins SetGsCrt\'s <i>interlace</i> parameter on, so switching it to <code>0x01</code> <b>turns interlacing '
         'on</b> (480i on NTSC, 576i on PAL). What it rescues are HDTVs that refuse the PS1\'s <b>240p/288p</b> '
         'over component and show a plain green screen instead. Read the original sentence as "can\'t deal with '
         'the [non-]interlaced resolutions" and it lines up. Corroborated on the psx-place thread, where a user '
         'stuck in 480i got 240p back by deleting a <code>$HDTVFIX</code> an installer had written for them.</p>'
         '</div>' +
         callouts_matching(['$41', '$42', 'byte', 'debug', 'hdtvfix', '412']) +
         wiki_content(['configuration-table']) +
         section_prose(['32-byte config']) +
         firstparty('thread-config.md') +
         quickref(['config'], 'Per-offset reference cards (cross-sourced summary)'))

    page('storage', 'Storage Backends',
         'Where the POPS folder, VCDs and support modules live on each device — USB, internal HDD, SMB, plus '
         'the modern MMCE / MX4SIO / exFAT backends — and the launch methods and per-mode ELF prefixes.',
         DEVICE_MATRIX +
         wiki_content(['usb-mode', 'hdd-mode', 'smb-mode', 'ps1cd-mode']) +
         section_prose(['storage backends', 'launch methods']) +
         firstparty('verified-setups.md') +
         '<div class="callout amber"><div class="h">SMB Apps entries: some later OPL betas need <code>smb0:</code>, not <code>smb:</code></div>'
         'The SMB layout above uses the bare <code>smb:/APPS/…</code> form in <code>conf_apps.cfg</code>. On <b>some '
         'later OPL betas</b> the SMB Apps-page path is <b>reportedly</b> only accepted in the <code>smb0:</code> form '
         '— i.e. <code>Crash Bandicoot=smb0:/APPS/SB.Crash Bandicoot.ELF</code> rather than the <code>smb:</code> form. '
         'If an SMB Apps entry refuses to launch on a recent OPL build, switch the prefix from <code>smb:</code> to '
         '<code>smb0:</code> and retry. (Community / cross-sourced report — not confirmed across every beta.)</div>' +
         firstparty('partition-games.md') +
         firstparty('thread-storage.md') +
         '<div class="callout info"><div class="h">Launching via OPL\'s Apps tab and getting a black screen?</div>'
         'If an HDD POPStarter ELF launched from OPL\'s <b>Apps</b> page black-screens with the <b>HDD&nbsp;LED stuck '
         'on</b>, OPL is usually waiting on a network/BDM/SMB device left on <b>Auto</b> — set the OPL devices you '
         'don\'t use to <b>Manual</b> or <b>Off</b>. This is a <i>launch-time</i> hang, distinct from the BOOT.ELF '
         '<i>exit</i> black-screen. See <a href="troubleshooting.html#two-black-screens">Troubleshooting → Two '
         'different black screens</a>.</div>' +
         '<h2>More wiki sources</h2>' +
         wiki_links(['popstarter-hddosd', 'pfsshell', 'irx-loader', 'radhostclient']) +
         quickref(['storage', 'launch']))

    page('multidisc', 'Multi-disc & VMC',
         'DISCS.TXT multi-disc swapping and the SLOT0/SLOT1 virtual memory cards, including VMCDIR.TXT redirection.',
         '<div class="callout info"><div class="h">Do it by hand — the DISCS_POOPER tool isn\'t hosted here</div>'
         'The old <code>DISCS_POOPER.EXE</code> PC tool just auto-generated the <code>DISCS.TXT</code> + '
         '<code>VMCDIR.TXT</code> set; it is <b>withheld per this site\'s policy</b> (any “Download: here” link in '
         'the recovered text below is dead). The manual method is simple and documented right here: put a '
         '<code>DISCS.TXT</code> listing every disc\'s VCD in <b>each</b> disc folder, and a <code>VMCDIR.TXT</code> '
         'naming disc&nbsp;1\'s VCD in the disc&nbsp;2/3 folders so they share one memory card. On internal HDD it is '
         'instead <code>IMAGE0.VCD</code>/<code>IMAGE1.VCD</code> in one <code>PP.</code> partition.</div>' +
         wiki_content(['multi-disc', 'vmc']) +
         section_prose(['multi-disc and virtual']) +
         '<h2>More wiki sources</h2>' + wiki_links(['vmc-to-pmc', 'pmc-to-vmc', 'D2LS']) +
         quickref(['multidisc', 'vmc']))

    page('troubleshooting', 'Troubleshooting & Display',
         'Boot/launch failures, USB-not-detected, HDTV/component fixes, widescreen, and game-specific lore.',
         '<div class="callout amber" id="two-black-screens"><div class="h">Two different black screens — don\'t confuse them</div>'
         '<b>Black screen + stuck HDD LED when launching an HDD POPStarter ELF from OPL\'s Apps page</b> is usually '
         'OPL waiting on a network/BDM/SMB device left on <b>Auto</b> — set the OPL devices you don\'t use to '
         '<b>Manual</b> or <b>Off</b> and it launches. That is <i>different</i> from the <b>black screen on IGR/exit</b>, '
         'which is an incompatible <code>BOOT.ELF</code> in the exit chain (fix: disable the ELF loader with stock '
         '<code>PATCH_9.BIN</code>, or replace/recompress <code>BOOT.ELF</code>).</div>'
         '<div class="callout info"><div class="h">Step 0 — see the actual error</div>Boot a <b>debug</b> '
         '<code>POPSTARTER.ELF</code> (build byte <code>FF</code> shows a full log; classic <code>00</code> shows a '
         'black wait-screen until the PS logo) so you read the real failure instead of guessing. The config table\'s '
         '<code>$410</code>/<code>$411</code> debug bytes and <code>DEBUG_AND_HALT.PPF</code> help here.</div>' +
         wiki_content(['known-bugs', 'troubleshooting-games', 'faqs']) +
         section_prose(['troubleshooting and display']) +
         firstparty('thread-troubleshooting.md') + firstparty('firstparty-extras.md') +
         '<h2>Display &amp; widescreen wiki pages</h2>' +
         wiki_links(['widescreen', 'ps1-widescreen-codes', 'scanlines', 'smooth']) +
         quickref(['troubleshooting']))

    page('getting-started', 'Getting Started',
         'Want to play a PS1 game on your PS2 with POPStarter? Here is the whole thing start-to-finish, kept '
         'deliberately simple. The rest of the site is reference for when you want to go deeper.',
         firstparty_raw('start-here.html').replace('<!--QUICKSTART-TILES-->',
             wiki_links(['quickstart-usb', 'quickstart-hdd', 'quickstart-smb'])),
         topic_index=False)

    page('history', 'History & Provenance',
         'The POPStarter timeline, krHACKen\'s changelog, and how this archive was recovered.',
         section_prose(['historical appendix']) +
         wiki_content(['timeline', 'chronology', 'poc2-pops-00001-era']) +   # proto.md = French dup of the changelog; kept as a standalone page
         '<h2>krHACKen\'s changelog</h2>' + wiki_content(['popstarter-changelog']) +
         firstparty('thread-history.md') +
         '<h2>More sources</h2>' + wiki_links(['apps-last-version', 'related-stuff']) +
         '<div class="callout info"><div class="h">How this archive was recovered</div>Every page was pulled '
         'from the Wayback Machine across all archived snapshots, extracted to markdown, de-duplicated, and merged '
         'so each page is more complete than any single live snapshot ever was. Downloads were recovered the same '
         'way and verified by magic-byte.</div>' +
         ('<details class="deep"><summary>Key facts (cross-sourced)</summary>' + cards_for(['history']) + '</details>'
          if any(e.get('category') == 'history' for e in entries) else ''))

# ---------- POPSLOADER (this project) ----------
REPO = os.environ.get('POPSLOADER_REPO') or os.path.dirname(ROOT)
GH = 'https://github.com/NathanNeurotic/POPSLoader/blob/dev/'
POPSLOADER_DOCS = [
    ('README.md', 'README — Overview'),
    ('STATE.md', 'STATE — status, invariants & known issues'),
    ('AGENTS.md', 'AGENTS — orientation & high-risk surfaces'),
    ('ARCHITECTURE.md', 'Architecture'),
    ('COMPONENTS.md', 'Components'),
    ('DECISIONS.md', 'Design decisions'),
    ('ROADMAP.md', 'Roadmap'),
    ('ROLLING_NOTES.md', 'Rolling notes'),
    ('EXPERIMENTAL_NOTES.md', 'Experimental notes'),
    ('QA_REGRESSION_MATRIX.md', 'QA regression matrix'),
    ('TESTING.md', 'Testing'),
    ('CONTRIBUTING.md', 'Contributing'),
    ('docs/LAUNCH_ARGUMENTS.md', 'Launch arguments'),
    ('docs/PRESERVATION_CONTRACTS.md', 'Preservation contracts'),
]
def pl_slug(path):
    return slug(os.path.basename(path)[:-3])
PL_MAP = {}
for _p, _t in POPSLOADER_DOCS:
    _s = pl_slug(_p)
    PL_MAP[os.path.basename(_p).lower()] = _s
    PL_MAP[_p.lower()] = _s

GHRAW = 'https://raw.githubusercontent.com/NathanNeurotic/POPSLoader/dev/'
def render_pl_doc(md):
    md = re.sub(r'^#\s+.*\n', '', md, count=1)   # drop the doc's own leading H1 (we add a title)
    md = re.sub(r'<!--.*?-->', '', md, flags=re.S)
    # GitHub-flavored alert blocks ("> [!NOTE]") render as literal "[!NOTE]" without this —
    # swap the marker line for a bold label so the blockquote keeps its formatting.
    md = re.sub(r'(?im)^>\s*\[!(\w+)\]\s*$',
                lambda m: f'> **{GFM_ALERT.get(m.group(1).upper(), " Note")}**', md)
    out = MD.markdown(md, extensions=MDX)
    def fix(m):
        href, text = m.group(1), m.group(2)
        low = href.lower().split('#')[0].lstrip('./')
        if low in PL_MAP:
            anc = ('#' + href.split('#', 1)[1]) if '#' in href else ''
            return f'<a href="{PL_MAP[low]}.html{anc}">{text}</a>'
        if href.startswith(('http://', 'https://', '#', 'mailto:')):
            return m.group(0)
        clean = href.lstrip('./').split('#')[0]
        if clean:
            return f'<a href="{GH}{clean}">{text}</a>'   # repo file -> GitHub
        return m.group(0)
    out = re.sub(r'<a href="([^"]+)"[^>]*>(.*?)</a>', fix, out, flags=re.S)
    # repo-relative images -> GitHub raw (so they resolve)
    out = re.sub(r'(<img[^>]+src=")([^"]+)(")',
                 lambda m: m.group(1) + (m.group(2) if m.group(2).startswith('http') else GHRAW + m.group(2).lstrip('./')) + m.group(3),
                 out)
    return out

def build_popsloader():
    os.makedirs(os.path.join(SITE, 'popsloader'), exist_ok=True)
    cards = []
    for path, title in POPSLOADER_DOCS:
        full = os.path.join(REPO, path)
        if not os.path.exists(full):
            continue
        md = open(full, encoding='utf-8', errors='replace').read()
        body_html = render_pl_doc(md)
        s = pl_slug(path)
        crumb = (f'<p class="prov-inline"><a href="../popsloader.html">&larr; POPSLoader docs</a> · '
                 f'<a href="{GH}{path}">view on GitHub ↗</a></p>')
        write(f'popsloader/{s}.html', shell(title + ' · POPSLoader', f'<h1>{html.escape(title)}</h1>{crumb}{body_html}', 'popsloader', base='../'))
        idx(title + ' (POPSLoader)', 'popsloader', re.sub(r'<[^>]+>', ' ', body_html), f'popsloader/{s}.html')
        cards.append(f'<a class="tile" href="popsloader/{s}.html"><b>{html.escape(title)}</b>'
                     f'<span>{html.escape(path)} · {os.path.getsize(full)//1024} KB</span></a>')
    intro = ('<div class="hero"><h1>POPSLoader <span class="g">— the modern launcher</span></h1>'
             '<p class="lead">POPSLoader is a menu-driven front-end for POPStarter: a Lua UI on the Enceladus '
             'runtime that lists your PS1 games with cover art and launches them — while adding device backends '
             'stock POPStarter never had. It is the project this documentation site lives in, maintained by '
             'Ripto&nbsp;/&nbsp;NathanNeurotic.</p>'
             '<div class="btn-row"><a class="btn" href="https://github.com/NathanNeurotic/POPSLoader">Source on GitHub ↗</a>'
             '<a class="btn ghost" href="getting-started.html">New to all this? Start here</a></div></div>'
             '<div class="callout info"><div class="h">How it relates to POPStarter</div>POPSLoader wraps the '
             'same POPS emulator and <code>POPSTARTER.ELF</code> documented across the rest of this site — think '
             'of it as the friendly launcher layer on top. Everything in the POPStarter reference applies underneath.</div>'
             '<h2>What it adds over stock POPStarter</h2><ul class="checklist">'
             '<li><b>Cover-art game browser</b> — a console-style menu of your PS1 library instead of renamed ELFs.</li>'
             '<li><b>Modern storage</b> — pick your device with <b>BDMA Mode</b>: FAT32 or exFAT USB, MX4SIO, MMCE (SD2PSX / MemCard PRO2), plus the APA internal HDD.</li>'
             '<li><b>Boots from anywhere</b> — memory card, MMCE, MX4SIO, or USB.</li>'
             '<li><b>In-launcher settings</b> — video standard, BDM mode, boot page, per-device game lists, hidden games.</li>'
             '<li><b>Multi-disc collapse</b>, <a href="launch-arguments.html">launch arguments</a> '
             '(boot straight to a device or game from your launcher), and HDD game-list caching.</li></ul>'
             '<div class="callout info"><div class="h">Supported devices &amp; status</div>'
             '<b>Working today:</b> internal HDD (APA/PFS), USB (FAT32 &amp; exFAT via BDMA), MX4SIO, MMCE '
             '(SD2PSX / MemCard&nbsp;PRO2), and physical disc (DKWDRV). <b>Newly added (via BDMA <code>ATA</code>, '
             'validating on hardware):</b> the <b>exFAT internal HDD</b>. <b>Wired but not yet working:</b> iLink, '
             'and SMB&nbsp;v1 — see the full <a href=\"storage.html#device-matrix\">device matrix</a>. '
             'Live status &amp; known issues live in <a href="popsloader/state.html">STATE</a>.</div>'
             '<div class="callout"><div class="h">Exit menu &amp; BOOT.ELF chaining (POPSLoader fork)</div>'
             'Press <b>Triangle</b> to open the launcher\'s Exit menu — <b>OSDSYS</b> (back to the PS2 browser), '
             '<b>Cancel</b>, or <b>BOOT.ELF</b>. <b>BOOT.ELF</b> chainloads <code>mc0:/BOOT/BOOT.ELF</code> '
             '(then <code>mc1:/BOOT/BOOT.ELF</code> as a fallback) — e.g. back to wLaunchELF, OPL, or your own boot '
             'menu — launched with <code>reboot_iop=0</code> for a clean handoff. '
             '<i>(Some third-party docs describe this as a &ldquo;Triangle&nbsp;=&nbsp;relaunch BOOT.ELF&rdquo; '
             'shortcut; in this fork Triangle opens the Exit menu and BOOT.ELF is one of its three choices.)</i></div>')
    body = intro + '<h2>Project documentation</h2><p class="lead">The living docs for the POPSLoader codebase. ' \
           'Rendered straight from the repository.</p><div class="grid">' + ''.join(cards) + '</div>'
    write('popsloader.html', shell('POPSLoader', body, 'popsloader'))
    idx('POPSLoader — the modern launcher', 'popsloader',
        'POPSLoader modern fork GUI launcher cover art game list MMCE MX4SIO USB exFAT APA HDD this project Enceladus Lua Ripto NathanNeurotic exit menu BOOT.ELF OSDSYS Triangle chainload wLaunchELF OPL reboot_iop quit',
        'popsloader.html')

# ---------- GLOSSARY ----------
GLOSSARY = [
    ('POPStarter', "krHACKen's homebrew launcher that runs PS1 games (as <code>.VCD</code> images) on a PS2 using Sony's built-in POPS emulator — the successor to POC2 / POPS-00001."),
    ('POPS', "Sony's official PS1-on-PS2 emulator (SLBB-00001), originally for the PSX DVR and PS2 HDD. POPStarter wraps it; it is <b>not</b> redistributed here (referenced by MD5 only)."),
    ('VCD', "The PlayStation Virtual-CD image format POPS plays. A PS1 disc rip becomes a <code>.VCD</code> via CUE2POPS."),
    ('VMC', "Virtual Memory Card — a file emulating a PS1 memory card, stored per-game so saves persist."),
    ('CHEATS.TXT', "The per-game text file holding POPStarter <code>$commands</code> and raw GameShark codes. <b>Must be UPPERCASE</b> on internal HDD/PFS or it is silently ignored."),
    ('IGR', "In-Game Reset — a button combo that resets or exits the running PS1 game without powering off. Configured with <code>$IGR0</code>–<code>$IGR5</code>."),
    ('ELF loader', "The POPStarter component that chains into <code>BOOT.ELF</code> on exit. An incompatible BOOT.ELF causes the black-screen-on-exit bug; disable it with stock <code>PATCH_9.BIN</code>."),
    ('BDM Assault (BDMA)', "The block-device backend layer. In the POPSLoader fork its <b>BDMA Mode</b> setting selects the mass-storage device — <code>FAT32</code> (plain USB), <code>USBEXFAT</code> (exFAT USB), <code>MX4SIO</code>, <code>MMCE</code>, or <code>ATA</code> (<b>exFAT internal HDD</b>) — by loading the BDM driver set. It is how you reach exFAT USB, the internal exFAT HDD, and the other devices, and is required for every device <i>except</i> an APA/PFS internal HDD."),
    ('POPSLoader', "The modern menu-driven front-end (this project) that lists PS1 games with cover art and adds MMCE / MX4SIO / exFAT backends. Built on the Enceladus Lua runtime by Ripto / NathanNeurotic."),
    ('wLE_kHn / uLE_kHn', "A uLaunchELF-based VCD browser/launcher for POPStarter. Tip: omit the game ID from the VCD filename for a cleaner list."),
    ('APA / PFS', "The PS2 HDD partition format (APA) and filesystem (PFS). POPStarter's internal-HDD payload lives on APA/PFS — never exFAT."),
    ('__.POPS', "The HDD partition-name prefix for the “new” HDD launch type — one VCD per <code>__.POPS</code> / <code>__.POPS0</code>–<code>9</code> partition. Scanned in order, not aliased."),
    ('__common/POPS', "The shared HDD folder (on the <code>__common</code> partition) holding the POPS emulator files plus per-game VMC and cover art."),
    ('SB. / XX. / PP. / __. prefixes', "Renamed-<code>POPSTARTER.ELF</code> prefixes per launch type: <b>SB.</b>=SMB, <b>XX.</b>=USB, <b>PP.</b>=partition-installed (HDDOSD/PSBBN, <code>PP.&lt;partition&gt;.ELF</code>), <b>__.</b>=legacy HDD."),
    ('POPS0–POPS9', "Numbered POPS folders at a device root. POPStarter scans <code>POPS</code> then <code>POPS0</code>…<code>POPS9</code>."),
    ('POPSTARTER.KELF', "The encrypted (KELF) form of <code>POPSTARTER.ELF</code> required by some HDDOSD / boot contexts."),
    ('KELF', "Sony's encrypted-ELF container format. <code>POPSTARTER.KELF</code> is the encrypted launcher."),
    ('SYSTEM.CNF', "The PS2 boot descriptor. For partition-installed POPS games it points <code>boot2</code> at <code>pfs:/IMAGE0.VCD</code>."),
    ('IMAGE0.VCD', "The fixed VCD filename used by HDDOSD / PSBBN partition-installed POPS games."),
    ('CUE2POPS', "The PC tool that converts a PS1 CUE/BIN rip into a POPS <code>.VCD</code>."),
    ('PFS_WRAP.BIN', "The embedded PFS wrapper POPStarter uses to read VCDs from the PS2 HDD."),
    ('IPCONFIG.DAT / SMBCONFIG.DAT', "The SMB network IP and share-credential files placed in <code>mc?:/POPSTARTER/</code> (note <code>.DAT</code>, not <code>.DAY</code>)."),
    ('smb0:', "POPStarter's mount point for the configured SMB network share."),
    ('title.cfg', "The OPL “APPS page” config pairing a renamed <code>POPSTARTER.ELF</code> with a game. Must be saved literally as <code>title.cfg</code> — not <code>.txt</code>."),
    ('PATCH_X.BIN', "A binary compatibility/visual patch dropped in the POPS folder. <code>PATCH_0</code>=disable IGR, <code>PATCH_5</code>=POPSLoader IGR textures, <code>PATCH_8</code>=force PAL, <code>PATCH_9</code>=disable PAL patcher / disable ELF loader."),
    ('TROJAN_X.BIN', "POPStarter's name for a behaviour/fix patch file — <b>not</b> malware. <code>TROJAN_0</code>–<code>5</code>=IGR behaviours; <code>TROJAN_7</code>=krHACKen + Hugopocked cumulative per-game fixes (2020-04-02), placed in the per-game VMC folder."),
    ('MX4SIO', "An SD-card adapter using the PS2 memory-card SIO2 port. A POPStarter side-module and a POPSLoader fork backend."),
    ('MMCE', "Memory-Card Emulator devices (SD2PSX, MemCard PRO2) exposing <code>mmce0:</code>/<code>mmce1:</code> via <code>mmceman</code>. Not a standard PS2 memory card."),
    ('DKWDRV', "DESR/DVD-ROM driver the fork hands off to for playing a <b>physical</b> PS1 disc."),
    ('DISCS.TXT', "The multi-disc list naming each disc's VCD, placed in <b>every</b> disc's per-game folder for in-game disc swapping."),
    ('VMCDIR.TXT', "Placed in the disc-2/3 folders, it points them at disc-1's VMC so a multi-disc game shares one memory card."),
    ('D2LS', "The “left stick is the D-pad” cheat. <code>$D2LS</code> leaves the pad digital; <code>$D2LS_ALT</code> leaves it analog."),
    ('$SAFEMODE', "Delays <i>raw</i> GameShark codes until after POPS startup. Needed only for raw codes — not for named <code>$commands</code> like <code>$NOPAL</code>."),
    ('$FORCEPAL / $NOPAL', "<code>$FORCEPAL</code> forces the PAL patcher + Euro region; <code>$NOPAL</code> disables the PAL patcher so a PAL game runs native NTSC."),
    ('$HDTVFIX', "The <b>SetGsCrt hack</b>, which is also config byte <code>$412</code> (<code>0x00</code> off by default, <code>0x01</code> on): one setting, three labels. It turns interlacing on (480i NTSC / 576i PAL) for HDTVs that refuse the PS1's 240p/288p over component and show a green screen instead. Can cause interlace flicker on CRTs, so don't use it by default."),
    ('SetGsCrt hack', "krHACKen's own name for the setting this site calls <a href=\"glossary.html#hdtvfix\">$HDTVFIX</a> and the recovered config table lists at byte <code>$412</code>. If you came from the old ShaolinAssassin wiki, this is the entry you are looking for. One caveat: the original note says it helps \"HDTVs that can't deal with the interlaced resolutions\", which is back to front, since enabling it turns interlacing <i>on</i>. See the <a href=\"config.html\">Config Table</a>."),
    ('Compatibility mode', "POPS per-game fix levels <code>0x01</code>–<code>0x07</code>, selectable as <code>$COMPATIBILITY_0x##</code> or a <code>PATCH_X.BIN</code>. The full mode→meaning map is only partly documented."),
    ('Hugopocked fixes', "The leading still-maintained community per-game patch pack for POPStarter — dropped into the game's own VMC folder (matched by VCD basename) to fix titles POPS gets wrong. Archive password <code>hugopocked</code>; don't stack with <code>TROJAN_7.BIN</code>. See the <a href=\"compatibility.html#hugopocked\">Hugopocked section</a>."),
    ('Enceladus', "The Lua runtime the POPSLoader UI is built on."),
    ('POC2 / POPS-00001', "The leaked early Sony PS1 emulator builds POPStarter evolved from; the historical USB method used manual HxD header patching."),
]
def build_glossary():
    items, az = [], {}
    for term, defn in sorted(GLOSSARY, key=lambda t: t[0].lower().lstrip('$_.')):
        s = slug(term)
        first = (term.lstrip('$_.').upper() or '#')[0]
        az.setdefault(first, []).append((term, s))
        items.append(f'<div class="gloss" id="{s}"><dt>{html.escape(term)}</dt><dd>{defn}</dd></div>')
        idx(term, 'glossary', re.sub(r'<[^>]+>', ' ', defn), f'glossary.html#{s}')
    jump = '<div class="az-jump">' + ' '.join(
        f'<a href="#{slug(v[0][0])}">{k}</a>' for k, v in sorted(az.items())) + '</div>'
    body = (f'<h1>Glossary</h1><p class="lead">Every POPStarter / POPSLoader acronym, prefix, file and '
            f'<code>$command</code> defined in one place ({len(GLOSSARY)} terms). Search any term up top, or jump:</p>'
            f'{jump}<dl class="glossary">' + '\n'.join(items) + '</dl>')
    write('glossary.html', shell('Glossary', body, 'glossary'))
    idx('Glossary — POPStarter terms & acronyms', 'glossary',
        'glossary define terms acronyms what is meaning ' + ' '.join(t for t, _ in GLOSSARY), 'glossary.html')

# ---------- COMMAND INDEX ----------
def build_commands():
    CATS = {'cheats', 'config', 'igr', 'patches', 'trojans', 'storage', 'launch', 'vmc', 'multidisc'}
    rows = []
    for e in sorted(entries, key=lambda e: (e.get('category', ''), e.get('name', '').lstrip('$').lower())):
        cat = e.get('category', '')
        if cat not in CATS:
            continue
        name = e.get('name', '?')
        eff = (e.get('effect') or e.get('scope') or '')
        url = f'{CAT_PAGE.get(cat, "index")}.html#{slug(name)}'
        rows.append(f'<tr><td><a href="{url}"><code>{html.escape(name)}</code></a></td>'
                    f'<td>{html.escape(cat)}</td><td>{html.escape(str(eff))[:200]}</td></tr>')
    body = (f'<h1>Command &amp; byte index</h1><p class="lead">Every documented POPStarter <code>$command</code>, '
            f'config byte, IGR hotkey and patch in one place ({len(rows)} entries) — click a name to jump to its '
            f'full card, or a header to sort.</p>'
            f'<table data-sortable><thead><tr><th>Name</th><th>Type</th><th>Effect</th></tr></thead>'
            f'<tbody>{"".join(rows)}</tbody></table>')
    write('commands.html', shell('Command index', body, 'commands'))
    idx('Command & byte index', 'reference',
        'every command $command config byte igr hotkey patch trojan list table index lookup browse all', 'commands.html')

# ---------- LAUNCH ARGUMENTS ----------
def build_launch_args():
    body = '''<h1>Launch arguments</h1>
<p class="lead">Boot POPSLoader <b>straight into a device's game list — or straight into a game</b> — from
whatever launcher you already use (OPL's <b>Apps</b> tab, uLaunchELF / wLaunchELF, an NHDDL-style entry).
The arguments go after the ELF path and are entirely optional: with none, POPSLoader just opens its normal
cover-art carousel.</p>

<div class="callout info"><div class="h">Where these go</div>Append the arguments to the POPSLoader ELF path
in your launcher entry, separated by spaces — e.g. an OPL <code>conf_apps.cfg</code> line or a wLaunchELF
shortcut: <code>mc0:/PS1_POPSLOADER/POPSLOADER.ELF -page=ata</code>.</div>

<h2 id="arguments">The arguments</h2>
<table>
<thead><tr><th>Argument</th><th>What it does</th></tr></thead>
<tbody>
<tr><td><code>-page=&lt;device&gt;</code></td><td>Open that device's game list (when used without <code>-game=</code>).</td></tr>
<tr><td><code>-mode=&lt;device&gt;</code></td><td>NHDDL-compatible <b>alias</b> for <code>-page=</code> — identical behaviour, same values.</td></tr>
<tr><td><code>-game=&lt;selector&gt;</code></td><td>Auto-launch a game. <b>Must be combined with <code>-page=</code>.</b></td></tr>
<tr><td><code>-debug</code></td><td>Show an on-screen boot-context diagnostic toast.</td></tr>
</tbody>
</table>

<h2 id="pages">Which device does each <code>-page=</code> value open?</h2>
<p>Values are case-insensitive. The two HDD pages are distinct: <code>ata</code> opens the new <b>exFAT</b>
internal drive (BDMA-ATA), while <code>hdd</code> / <code>pfs</code> / <code>apa</code> opens the classic
<b>APA/PFS</b> HDD.</p>
<table>
<thead><tr><th>Opens this page</th><th>Accepted <code>-page=</code> / <code>-mode=</code> values</th></tr></thead>
<tbody>
<tr><td><b>HDD (exFAT)</b> — BDMA ATA</td><td><code>exfat</code>, <code>ata</code>, <code>ata0</code>, <code>ataN</code></td></tr>
<tr><td><b>HDD (PFS)</b> — APA</td><td><code>hdd</code>, <code>hdd0</code>, <code>pfs</code>, <code>apa</code>, <code>apa0</code></td></tr>
<tr><td><b>USB</b></td><td><code>usb</code>, <code>mass</code></td></tr>
<tr><td><b>MX4SIO</b></td><td><code>mx4sio</code>, <code>mx4</code>, <code>sdc</code></td></tr>
<tr><td><b>MMCE</b> (SD2PSX / MemCard&nbsp;PRO2)</td><td><code>mmce</code></td></tr>
<tr><td><b>SMB (v1)</b> network share</td><td><code>smb</code></td></tr>
</tbody>
</table>
<p class="hint"> Not navigable: <code>i.Link</code>, which is unimplemented and has no route. The bare
<code>bdma</code> token is a no-op — use <code>ata</code> or <code>exfat</code> to reach the exFAT page. An
unrecognised value is ignored and the carousel just opens on its default page. (<code>smb</code> <b>does</b>
navigate — it was listed here as unimplemented for a long time and that was wrong.)</p>

<h2 id="auto-launch">Auto-launching a game (<code>-game=</code>)</h2>
<p>Combine <code>-page=</code> with <code>-game=</code> to boot straight into a specific title. The selector
format depends on the device:</p>
<table>
<thead><tr><th>Page</th><th><code>-game=</code> selector</th></tr></thead>
<tbody>
<tr><td>USB · MX4SIO · MMCE · <b>HDD (exFAT)</b></td><td>the <code>.VCD</code> filename, relative to that device's <code>POPS/</code> folder (for exFAT use <code>-page=ata</code>)</td></tr>
<tr><td>HDD (PFS)</td><td><code>&lt;PARTITION&gt;|&lt;VCD&gt;</code> — the POPS partition label, a literal <code>|</code>, then the <code>.VCD</code> name (e.g. <code>__.POPS|SLUS_007.42.RAMPAGE.VCD</code>)</td></tr>
</tbody>
</table>

<h2 id="examples">Examples</h2>
<pre>POPSLOADER.ELF -page=ata                              &larr; open the exFAT HDD game list
POPSLOADER.ELF -page=hdd                               &larr; open the APA/PFS HDD game list
POPSLOADER.ELF -mode=ata                               &larr; same as -page=ata (NHDDL style)
POPSLOADER.ELF -page=usb -game=Tekken 3.VCD            &larr; boot straight into a USB game
POPSLOADER.ELF -page=ata -game=Final Fantasy IX.VCD    &larr; auto-launch from the exFAT drive
POPSLOADER.ELF -page=hdd -debug                        &larr; open the HDD list + diagnostic toast</pre>

<div class="callout"><div class="h">Good to know</div><ul>
<li><b>Recovery:</b> hold <b>START</b> while booting to suppress any auto-launch and reach the menu — handy if an entry is mis-typed.</li>
<li><b>Spaces &amp; quotes:</b> game names with spaces work as-is; surrounding quotes are stripped. Don't pack two flags into one quoted value.</li>
<li><b>NHDDL parity:</b> <code>-mode=ata</code> exists because that's how NHDDL selects the internal ATA drive; in POPSLoader it opens the <b>HDD (exFAT)</b> page.</li>
<li>These are a <b>POPSLoader</b> feature — stock POPStarter has no launch arguments.</li>
</ul></div>'''
    write('launch-arguments.html', shell('Launch arguments', body, 'launch-args'))
    idx('Launch arguments — -page / -mode / -game / -debug', 'launch-args',
        'launch arguments page mode game debug ata exfat hdd pfs apa usb mmce mx4sio nhddl auto-launch boot '
        'straight into game list opl apps tab wlaunchelf ulaunchelf carousel navigate device token selector', 'launch-arguments.html')

# ---------- FAQ ----------
FAQ_CARDS = [
    ('Why is my game a black screen?',
     'Most often an incompatible <code>BOOT.ELF</code> in the IGR/exit chain (disable the ELF loader with stock <code>PATCH_9.BIN</code>), or a missing/wrong POPS file. Boot a debug build first to read the actual error.', 'igr.html'),
    ('How do I force PAL, or fix 50/60 Hz?',
     '<code>$FORCEPAL</code> forces the PAL patcher + Euro region; <code>$NOPAL</code> runs a PAL game in native NTSC. <code>PATCH_8.BIN</code> / <code>PATCH_9.BIN</code> are the binary equivalents. After <code>$NOPAL</code> you usually need <code>$YPOS_##</code> to re-center.', 'cheats.html#forcepal'),
    ('Does it support exFAT (USB or internal HDD)?',
     'Yes. Set POPSLoader\'s <b>BDMA&nbsp;Mode</b> to <code>USBEXFAT</code> for an exFAT USB drive, or <code>ATA</code> for an <b>exFAT internal HDD</b> (newly added). The same BDMA&nbsp;Mode setting also reaches <b>MX4SIO and MMCE</b> — it\'s the device selector for everything except an APA/PFS internal HDD. (POPS never reads exFAT itself; BDMA presents the files to it.)', 'storage.html#device-matrix'),
    ('My cheats do nothing — why?',
     '<code>CHEATS.TXT</code> must be <b>UPPERCASE</b> on internal HDD/PFS or it is silently ignored, and <i>raw</i> GameShark codes need <code>$SAFEMODE</code> on the first line (named <code>$commands</code> do not).', 'cheats.html'),
    ('My USB drive isn\'t detected',
     'Increase <code>$USBDELAY_#</code> (or config byte <code>$413</code>) and confirm a FAT32/exFAT format with 32K/64K clusters. <code>$USBDELAY</code> patches streaming — it does not fix detection; <code>$413</code> does.', 'troubleshooting.html'),
    ('Saves disappear after I reboot the PS2',
     'Reported on some PS2 Slim + USB-VMC setups (saves write then vanish); internal HDD is reliable. Make sure each game has its own VMC folder.', 'multidisc.html'),
    ('Which buttons open the IGR menu?',
     '<code>$IGR0</code>/<code>$IGR3</code> = L1+L2+R1+R2++↓ · <code>$IGR1</code>/<code>$IGR4</code> = Select+Start · <code>$IGR2</code>/<code>$IGR5</code> = L1+L2+R1+R2+Select+Start. (0–2 open the menu, 3–5 terminate POPS.)', 'igr.html'),
    ('How do I set up a multi-disc game?',
     'Put a <code>DISCS.TXT</code> listing every disc\'s VCD in each disc\'s folder, and a <code>VMCDIR.TXT</code> pointing discs 2/3 at disc 1\'s VMC so they share one memory card.', 'multidisc.html'),
    ('Is this legal? Where\'s the emulator?',
     'POPStarter and POPSLoader are homebrew launchers and are redistributable. The Sony POPS emulator is <b>not</b> included — you supply your own legally-obtained files (verify them by the published MD5s).', 'downloads.html'),
    ('What\'s the latest/canonical POPStarter build?',
     'Rev 13 Beta 2019/06/05 (USB drivers dated 2019-01-14) — the final public beta. It ships only the launcher, no Sony binaries.', 'history.html'),
    ('Does it support widescreen?',
     'Yes via GTE FOV hacks: <code>$WIDESCREEN</code> (16:9), <code>$ULTRA_WIDESCREEN</code>, <code>$EYEFINITY</code> (≈3×16:9). They don\'t fix HUDs/fonts/2D backgrounds and don\'t work on every game.', 'cheats.html#widescreen'),
]
# Consolidated known-issues matrix: (symptom, likely cause, fix-HTML). Every fact here is documented
# in depth elsewhere on the site — the "fix" cell links to that page. This is a scannable index, not
# a second source of truth.
KNOWN_ISSUES = [
    ('Black screen on IGR / exit (after a game runs)',
     'An incompatible <code>BOOT.ELF</code> sits in the exit chain.',
     'Disable the ELF loader with stock <code>PATCH_9.BIN</code>, or replace/recompress <code>BOOT.ELF</code>. <a href="troubleshooting.html#two-black-screens">details →</a>'),
    ('Black screen + stuck HDD LED launching an HDD ELF from OPL’s Apps page',
     'OPL is waiting on a network/BDM/SMB device left on <b>Auto</b>.',
     'Set the OPL devices you don’t use to <b>Manual</b> or <b>Off</b>. <a href="troubleshooting.html#two-black-screens">details →</a>'),
    ('Expected 240p but got 480i / 576i',
     '<code>$HDTVFIX</code> is active, either in <code>CHEATS.TXT</code> or as config byte <code>$412</code> (the old wiki calls that byte the "SetGsCrt hack").',
     'Remove <code>$HDTVFIX</code>, or set <code>$412</code> back to <code>0x00</code>. It turns interlacing on for displays that reject 240p/288p. <a href="config.html">details →</a>'),
    ('USB drive not detected',
     'USB access delay too low, or a poor format.',
     'Raise config byte <code>$413</code> (<code>$USBDELAY_#</code> only patches streaming, not detection); use FAT32/exFAT with 32K–64K clusters. <a href="troubleshooting.html">details →</a>'),
    ('exFAT USB not detected',
     'BDM modules not renamed.',
     'Place <code>usbd.irx</code> / <code>usbhdfsd.irx</code> in <code>mc?:/POPSTARTER</code> (BDMA); keep an internal HDD on APA/PFS. <a href="storage.html#device-matrix">details →</a>'),
    ('Cheats do nothing',
     'Lowercase <code>CHEATS.TXT</code> on a PFS volume, or raw codes with no <code>$SAFEMODE</code>.',
     'Use an UPPERCASE <code>CHEATS.TXT</code>; put <code>$SAFEMODE</code> on the first line for raw GameShark/AR codes. <a href="cheats.html">details →</a>'),
    ('A game’s CHEATS / VMC / fixes are ignored',
     'The per-game support folder name includes <code>.VCD</code> or uses the display title.',
     'Name the folder exactly the VCD basename (no <code>.VCD</code>); on HDD keep per-game fixes under <code>__common/POPS</code>. <a href="storage.html">details →</a>'),
    ('SMB share ignored / won’t connect',
     'Typos: <code>IPCONFIG.DAY</code> / <code>SMBCONFIG.DAY</code> / <code>poweroff.irc</code>, or wrong case.',
     'Use <code>.DAT</code> and <code>poweroff.irx</code> with correct case. <a href="storage.html">details →</a>'),
    ('SMB black screen / won’t launch',
     'Missing <code>SB.</code> prefix, or <code>smb:</code> vs <code>smb0:</code> mismatch.',
     'Use <code>SB.&lt;Game&gt;.ELF</code>; try the <code>smb0:</code> form on newer OPL betas. <a href="storage.html">details →</a>'),
    ('SMB boots but saves fail',
     'The share is read-only / guest has no write access.',
     'Grant write access so POPStarter can create <code>SLOT0.VMC</code> / <code>SLOT1.VMC</code>. <a href="storage.html">details →</a>'),
    ('Modern Windows / NAS unreachable over SMB',
     'SMB1/CIFS disabled, guest blocked, or port 445 closed.',
     'Enable SMB1 on an isolated network, or use a dedicated writable PS2 share. <a href="storage.html">details →</a>'),
    ('HDD returns to Browser / can’t find VCDs',
     'The <code>__.POPS</code> partition is missing its dot or has the wrong case (or a <code>+__.POPS</code> was created).',
     'Use exactly <code>hdd0:/__.POPS/</code> (VCDs) + <code>hdd0:/__common/POPS/</code> (common files). <a href="storage.html">details →</a>'),
    ('A POPS0–POPS9 game boots without its patches/handlers',
     'Support files live only in the main <code>POPS</code> folder.',
     'Copy <code>BIOS.BIN</code>, <code>PATCH_#.BIN</code>, <code>TROJAN_#.BIN</code>, <code>VMCDIR.TXT</code> into each <code>POPS#</code> folder (keep <code>POPS_IOX.PAK</code> + IGR textures in main). <a href="storage.html">details →</a>'),
    ('OPL Apps entry missing / launches nothing',
     'Saved as <code>title.cfg.txt</code>, wrong APPS folder, or a <code>boot=</code> mismatch.',
     'Save a plain <code>title.cfg</code> beside the ELF; <code>boot=</code> must match the ELF name. <a href="storage.html">details →</a>'),
    ('Final-build behavior (e.g. <code>$IGR5</code>, byte meanings) doesn’t match',
     'An older RIP/WIP build is in use.',
     'Use Rev 13 Beta 2019/06/05 — the canonical final public build. <a href="history.html">details →</a>'),
    ('SMB shows debug / status text',
     'SMB mode forces startup status text — it is not a "wrong build" signal.',
     'Ignore it; don’t chase a debug build. <a href="config.html">details →</a>'),
    ('Multi-disc swap / shared VMC fails',
     '<code>DISCS.TXT</code> / <code>VMCDIR.TXT</code> misplaced or wrong filenames.',
     '<code>DISCS.TXT</code> in every disc folder; <code>VMCDIR.TXT</code> in the later-disc folders, with exact VCD names. <a href="multidisc.html">details →</a>'),
    ('POPSLoader: hangs or black-screens at startup',
     'A stray <code>.irx</code> driver in the folder POPSLoader boots from. It loads '
     '<b>every</b> <code>.irx</code> beside the ELF, and one that waits on hardware you '
     'do not have will hang the boot.',
     'Move loose <code>.irx</code> files out of that folder, or keep them in an '
     '<code>IRX/</code> subfolder. Most likely if you run from a downloads folder or '
     'under an emulator. <a href="popsloader.html">details →</a>'),
    ('POPSLoader fork: USB / MX4SIO / MMCE games missing',
     'BDMA disabled, wrong mode, or <code>mc0</code> missing.',
     'Use <code>mc0</code>, enable BDMA, and select only the device mode you actually use. <a href="storage.html#device-matrix">details →</a>'),
    ('No saves to a physical PS1 memory card',
     'POPStarter is VMC-only (per-game virtual cards).',
     'Use the per-game VMC; physical-card saving isn’t supported. <a href="multidisc.html">details →</a>'),
    ('Only two controllers are recognized',
     'No multitap support.',
     'Only the first two pads work. <a href="faq.html">(by design)</a>'),
]
def render_known_issues():
    rows = ['<tr><td><b>Symptom</b></td><td><b>Likely cause</b></td><td><b>Fix</b></td></tr>']
    for sym, cause, fix in KNOWN_ISSUES:
        rows.append(f'<tr><td>{sym}</td><td>{cause}</td><td>{fix}</td></tr>')
    return ('<p>A consolidated index of the recurring problems and their fixes — each row links to the '
            'page with the full detail.</p>'
            '<table class="wiki"><tbody>' + ''.join(rows) + '</tbody></table>')

def build_faq():
    cards = []
    for q, a, url in FAQ_CARDS:
        s = slug(q)
        cards.append(f'<div class="card" id="{s}"><h3>{html.escape(q)}</h3>'
                     f'<div class="field">{a}</div><a class="pill" href="{url}">→ full details</a></div>')
        idx(q, 'faq', re.sub(r'<[^>]+>', ' ', a), f'faq.html#{s}')
    body = (f'<h1>FAQ &amp; known bugs</h1><p class="lead">Straight answers to the questions people actually ask, '
            f'each linking to the deep reference — followed by the recovered FAQ and known-bugs pages in full.</p>'
            f'<div class="cards">{"".join(cards)}</div>'
            f'<div class="callout info"><div class="h">Looking for a quick fix?</div>'
            f'See the consolidated <a href="known-issues.html">Known issues at a glance</a> matrix — '
            f'symptom → likely cause → fix for the problems people hit most.</div>'
            f'<h2>Recovered FAQ</h2>' + wiki_content(['faqs']) +
            f'<h2>Known bugs &amp; limitations</h2>' + wiki_content(['known-bugs']))
    write('faq.html', shell('FAQ & known bugs', body, 'faq'))

def build_known_issues():
    body = ('<h1>Known issues at a glance</h1>'
            '<p class="lead">The recurring POPStarter / POPSLoader problems and their fixes, in one place — '
            'each row links to the page that documents it in full. For the longer Q&amp;A and the recovered '
            'known-bugs pages, see <a href="faq.html">FAQ &amp; known bugs</a>.</p>'
            + render_known_issues())
    write('known-issues.html', shell('Known issues', body, 'known-issues'))
    idx('Known issues at a glance', 'faq',
        'known issues matrix consolidated troubleshooting black screen igr exit hdtvfix 480i usb not detected '
        'exfat cheats do nothing smb saves fail __.POPS partition pops0 pops9 title.cfg rip build multidisc vmc '
        'bdma multitap physical memory card', 'known-issues.html')
    idx('FAQ & known bugs', 'faq',
        'faq frequently asked questions help known bugs limitations black screen exfat force pal cheats not working saves usb not detected',
        'faq.html')

# ---------- COMMUNITY THREAD STUDY (the full mined field notes) ----------
def clean_research(md):
    # drop the research-process preamble; start at the first real section
    i = md.find('## ')
    if i < 0:
        i = md.find('## TIER 0')
    if i > 0:
        md = md[i:]
    md = md.replace("##  TIER 0 — krHACKEN AUTHORITATIVE (developer's own corrections/clarifications — add these FIRST and flag as canonical)",
                    "## Tier 0 — krHACKen, authoritative")
    md = re.sub(r'\*\*\[[\w /-]+\]\*\*\s*', '', md)               # **[known-bug]** category tags
    md = re.sub(r'\[FLAG:\s*([^\]]+)\]', r'(\1)', md)             # [FLAG: krHACKen] -> (krHACKen)
    md = re.sub(r'→\s*\*\*[\w/ &-]+\*\*\s*', '', md)              # "→ **section** " routing (keep trailing source paren)
    md = re.sub(r'\*?\*?\[(consolidates[^\]]*|high value|corrective)\]\*?\*?', '', md, flags=re.I)
    # "_author, pN, conf, STATUS_" italic trailers -> keep just "author, pN".
    # author may contain underscores (El_Patas, El_isra), so allow them inside.
    md = re.sub(r'_([^\n_]*(?:_[^\n_]*)*?,\s*p\d+)[^\n_]*_', r'*\1*', md)
    # italic trailers with a confidence word but no page number -> keep the author
    md = re.sub(r'_([^\n_]*(?:_[^\n_]*)*?),\s*(?:high|medium|low)\b[^\n_]*_', r'*\1*', md)
    md = re.sub(r'\(\s*\)', '', md)
    md = re.sub(r'[ \t]{2,}', ' ', md)
    return md.strip()

def build_thread_study():
    raw = md_text('thread-findings.md')
    if not raw:
        return
    body = ('<h1>Community knowledge — the PSX-Place thread</h1>'
            '<p class="lead">Every actionable finding mined from all 19 pages (380 posts) of the official '
            '<a href="https://www.psx-place.com/threads/popstarter.19139/">PSX-Place POPStarter thread</a> — '
            'krHACKen\'s own corrections (flagged authoritative), concrete per-game datapoints, failure signatures, '
            'and the modern device / fix history. Each item names the poster and thread page. This is the raw field '
            'record behind the curated reference pages — the most complete view of what the community has worked out.</p>'
            '<div class="callout info"><div class="h">How to read this</div>“Tier 0” items are the POPStarter '
            'author\'s (krHACKen) own statements — treat them as canonical. Everything else is community-reported with '
            'the poster and page cited; confidence varies, and unresolved cases are marked as such.</div>'
            + render_md(clean_research(raw), strip_prov=False))
    write('thread-study.html', shell('Community knowledge', body, 'thread-study'))
    idx('Community knowledge — PSX-Place thread findings', 'reference',
        'community knowledge thread findings krHACKen hugopocked El_Patas per-game compatibility TROJAN_7 TROJAN_8 '
        'King\'s Field Tomb Raider Crash Bandicoot Final Fantasy field notes ' + re.sub(r'<[^>]+>', ' ', render_md(clean_research(raw), strip_prov=False)),
        'thread-study.html')

# ---------- CREDITS ----------
CREDITS_SECTIONS = [
    ('POPStarter &amp; POPS', [
        ('krHACKen', 'Author of <b>POPStarter</b> and its official <code>CHANGES.TXT</code> changelog — the launcher this entire site documents. Nearly every behaviour, command, and config byte here is his work.'),
        ('Sony Computer Entertainment', 'Created <b>POPS</b>, the PS1-on-PS2 emulator POPStarter wraps. Acknowledged here by checksum only — it is <b>not</b> distributed.'),
    ]),
    ('Compatibility, patches &amp; fixes', [
        ('Hugopocked', 'The leading, still-maintained community <a href="compatibility.html#hugopocked">per-game fix pack</a> for POPStarter, plus countless individual game fixes.'),
        ('krHACKen', 'The <code>PATCH_#.BIN</code> / <code>TROJAN_#.BIN</code> compatibility-mode system, the LibCrypt cracks, and the cumulative fix bundles.'),
    ]),
    ('IGR menu textures', [
        ('gledson999, El_Patas, arkl1t32, LopoTRI', 'Community-made <a href="wiki/igr-textures.html">IGR menu texture packs</a> in Chinese, English, French, Spanish, Polish, Portuguese and German.'),
        ('The AssemblerGames community', 'Early POPS / POPStarter research and texture contributions.'),
    ]),
    ('Devices &amp; modern backends', [
        ('israpps (El_isra)', '<b>BDM Assault</b> (exFAT / BDMA), <code>MMCEMAN</code>, and much of the modern device tooling that lets POPStarter reach exFAT USB, MX4SIO and MMCE.'),
        ('saildot4k', '<b>BDMA-ATA</b> — the exFAT internal-HDD (ATA) backend for POPSLoader: implementation, fixes, feedback, and oversight that brought the <code>HDD (exFAT)</code> page to life.'),
        ('The Open PS2 Loader (OPL) project', 'The BDM device-backend ecosystem POPSLoader builds on — USB, MX4SIO, MMCE, ATA and iLink — and the patterns the fork mirrors. (OPL also ships a UDPBD network backend; POPSLoader does not.)'),
        ('Rick Gaiser', '<b>udpbd</b> — the UDP block-device network backend.'),
    ]),
    ('POPSLoader — the modern launcher', [
        ('israpps (El_isra)', 'Original <b>POPSLoader</b> project creator.'),
        ('Daniel Santos', 'Creator of the <b>Enceladus</b> runtime foundation POPSLoader is built on.'),
        ('Ripto / NathanNeurotic', 'Maintainer of this fork — maintenance, UI polishing, device backends, and release engineering.'),
        ('Berion', 'User-interface design and theme assets.'),
        ('nuno6573', 'Cover-art engine integrations and scripting (plus hardware testing).'),
        ('P4NCHOL1NO, VizoR, provato, TnA-Plastic, oldman63, and the community', 'Hardware testing on real PS2 consoles — the only thing that proves a launch path actually works.'),
    ]),
    ('This archive &amp; site', [
        ('The Internet Archive / Wayback Machine', 'Preserved ShaolinAssassin\'s lost wiki, the download archives, and the menu images — without it this archive could not exist.'),
        ('Retro-Jogos (Gledson\'s Portuguese guide)', 'Preserved the original documentation navigation taxonomy when the source wiki went dark.'),
        ('R3Z3N', 'Partition-install (<code>PP.</code>) documentation for HDDOSD / PSBBN games.'),
        ('PSX-Place', 'The community home of POPStarter, and the release thread mined for this site.'),
    ]),
]
def build_credits():
    feat = ('<div class="credit-hero"><div class="ch-tag"> Documentation</div>'
            '<h2>ShaolinAssassin</h2>'
            '<p>Author of the original POPStarter documentation wiki — <b>the single most important source this '
            'entire archive is built from</b>. Every reference page on this site exists because ShaolinAssassin '
            'took the time to document POPStarter for the community. This whole project is, first and foremost, a '
            'preservation of that work.</p></div>')
    blocks = []
    for title, people in CREDITS_SECTIONS:
        rows = ''.join(f'<div class="credit"><dt>{name}</dt><dd>{role}</dd></div>' for name, role in people)
        blocks.append(f'<h2>{title}</h2><dl class="credits">{rows}</dl>')
    body = ('<h1>Credits</h1><p class="lead">POPStarter, POPSLoader, and this documentation archive are the work '
            'of many people across more than a decade. This page credits them as accurately as the record allows.</p>'
            + feat + ''.join(blocks) +
            '<div class="callout info"><div class="h">Missing or mis-credited?</div>This is community work and the '
            'historical record is imperfect — if someone is missing or wrongly attributed, let the maintainer know '
            'and it will be corrected.</div>')
    write('credits.html', shell('Credits', body, 'credits'))
    idx('Credits — POPStarter, POPSLoader &amp; this archive', 'credits',
        'credits thanks acknowledgements who made authors contributors ShaolinAssassin krHACKen kHn POPStarter POPS Sony '
        'El_isra israpps Enceladus Daniel Santos Berion nuno6573 Hugopocked Ripto NathanNeurotic hardware testers '
        'gledson999 El_Patas arkl1t32 LopoTRI Rick Gaiser udpbd OPL Open PS2 Loader BDM Assault Retro-Jogos R3Z3N '
        'saildot4k BDMA-ATA ATA exFAT HDD backend TnA-Plastic provato oldman63 P4NCHOL1NO VizoR', 'credits.html')

# ---------- HOME ----------
def build_home():
    arch = section_prose(['architecture'])
    tiles = []
    for sid, label, em in SECTIONS:
        if sid == 'index': continue
        tiles.append(f'<a class="tile" href="{sid}.html"><b>{label}</b>'
                     f'<span>{ {"getting-started":"USB · HDD · SMB setup","storage":"Path maps & launch methods","cheats":"Every $command","compatibility":"Patches, modes & TROJANs","igr":"Reset, exit & hotkeys","config":"The 32-byte table","multidisc":"DISCS.TXT & VMC","troubleshooting":"Fixes & display","downloads":"Recovered files","history":"Timeline & sources"}.get(sid,"") }</span></a>')
    stats = (f'<div class="stat-row">'
             f'<div class="stat"><b>{len(wiki_pages)}</b><span>wiki pages recovered</span></div>'
             f'<div class="stat"><b>{len([e for e in entries])}</b><span>cross-sourced facts &amp; commands</span></div>'
             f'<div class="stat"><b>{len(dl_files)}</b><span>downloads served locally</span></div>'
             f'<div class="stat"><b>{len(img_map)}</b><span>images recovered</span></div></div>')
    body = f'''<div class="hero">
<h1>POPStarter <span class="g">Documentation</span></h1>
<p class="lead">Everything you need to play your PS1 game backups on a PS2 with POPStarter — recovered from
ShaolinAssassin's lost wiki, krHACKen's changelog and the community, merged and made fully searchable.</p>
<div class="btn-row">
  <a class="btn" href="getting-started.html"> New here? Start your first game</a>
  <a class="btn ghost" href="#reference">Browse the full reference</a>
</div>
{stats}
</div>

<div class="callout info"><div class="h">New to POPStarter? Read this first</div>POPStarter is a
<b>launcher</b> that plays your PS1 game backups using Sony's built-in PS1 emulator (POPS). You supply the
game and the emulator; POPStarter ties it together. The <a href="getting-started.html"><b>Getting Started
guide</b></a> walks you through your first game in about 15 minutes — start there. The sections below are the
deep reference, for when you need a specific answer.</div>

<h2 id="features">What POPStarter does</h2>
<p class="lead">A homebrew launcher for Sony's built-in PS1 emulator (POPS), with a decade of community fixes:</p>
<ul class="checklist">
<li><b>Plays your PS1 backups</b> as <code>.VCD</code> images — roughly 75–80% of the library runs well.</li>
<li><b>Four storage backends</b> — internal HDD, USB, SMB network share, and physical PS1 disc (plus MMCE / MX4SIO / exFAT in the <a href="popsloader.html">POPSLoader fork</a>).</li>
<li><b>Per-game saves</b> via Virtual Memory Cards (VMC), with multi-disc games sharing one card.</li>
<li><b>Cheats</b> (CHEATS.TXT <code>$commands</code> + raw GameShark), <b>In-Game Reset</b> &amp; exit hotkeys.</li>
<li><b>Display fixes</b> — PAL patcher, 480p, GTE widescreen (16:9), scanlines, geometry/position controls.</li>
<li><b>Compatibility patches</b> — per-game fix bundles, LibCrypt cracks, and 7 selectable compatibility modes.</li>
<li><b>Controller support</b> — analog stick, vibration/rumble, and stick→D-pad mapping for games that lack it.</li>
</ul>
<div class="callout info"><div class="h">Canonical build &amp; the legal line</div>The last public release is
<b>POPStarter Rev 13 Beta 2019/06/05</b> (USB drivers dated 2019-01-14). It ships <b>only the launcher</b> — the
Sony POPS emulator is <b>not</b> included anywhere; you supply your own legally-obtained files (verify them by the
<a href="downloads.html">published MD5s</a>). Questions and support live on the
<a href="https://www.psx-place.com/threads/popstarter.19139/">PSX-Place POPStarter thread</a>.</div>

<h2 id="reference">Full reference</h2>
<p class="lead">Already know your way around? Jump straight in — or use the search box up top to find any
command, byte, or file instantly.</p>
<div class="grid">{''.join(tiles)}</div>

<details class="deep"><summary>What's the difference between POPStarter, POPS, and POPSLoader?</summary>
{arch}</details>
'''
    write('index.html', shell('Home', body, 'index'))
    idx('POPStarter Documentation', 'home',
        'getting started new user how to play ps1 game setup cheats patches config storage multi-disc igr downloads '
        'overview POPS.ELF SLBB-00001 emulator launcher what is the difference between POPStarter POPS POPSLoader '
        + re.sub(r'<[^>]+>', ' ', arch), 'index.html')

# ---------- assets ----------
def copy_assets():
    src = os.path.join(ROOT, '_srcassets')        # generator-owned CSS/JS source
    os.makedirs(os.path.join(SITE, 'assets'), exist_ok=True)
    for f in os.listdir(src):
        shutil.copy2(os.path.join(src, f), os.path.join(SITE, 'assets', f))
    for f in dl_files:
        shutil.copy2(os.path.join(DL, f), os.path.join(SITE, 'downloads', f))
    for low, real in img_map.items():
        shutil.copy2(os.path.join(ASSET, real), os.path.join(SITE, 'img', real))

ARCHIVE_README = """POPStarter Documentation Archive  —  offline copy
=====================================================

This is a community-recovered, self-contained copy of the POPStarter documentation:
ShaolinAssassin's lost wiki (63 pages, recovered from the Internet Archive and merged
across snapshots), krHACKen's r13 changelog, the recovered downloads and menu images,
and a study of the official PSX-Place thread.

HOW TO USE
  Open  index.html  in any web browser to browse the whole site offline.
  (Full-text search needs the files served over http:// — most browsers block the
   local search-index fetch over file://. Browsing and all links work either way.)

WHAT'S INSIDE
  index.html, *.html, wiki/   the complete rendered site
  downloads/                  the recovered tools, builds, texture packs & CHEATS.TXT
  img/                        recovered menu / comparison images
  SOURCE/wiki/*.md            the raw recovered wiki markdown
  SOURCE/research/*           the cross-sourced corpus + the thread study

POLICY / LEGAL
  Contains NO Sony binaries. The POPS emulator (POPS.ELF, IOPRP252.IMG, POPS_IOX.PAK,
  POPS.PAK) is Sony-copyrighted and is NOT included anywhere in this archive — it is
  referenced by MD5 checksum only. POPStarter and POPSLoader are redistributable homebrew.

CREDITS
  ShaolinAssassin (the documentation), krHACKen (POPStarter), and the wider community.
  See credits.html. Live site: https://nathanneurotic.github.io/POPSLoader/
"""

def create_archive():
    import zipfile
    arc = os.path.join(SITE, 'popstarter-docs-archive.zip')
    with zipfile.ZipFile(arc, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _dirs, files in os.walk(SITE):
            for f in files:
                fp = os.path.join(root, f)
                if os.path.abspath(fp) == os.path.abspath(arc):
                    continue   # never zip the archive into itself
                z.write(fp, os.path.relpath(fp, SITE))
        for f in sorted(os.listdir(WIKI)):           # raw recovered source
            if f.endswith('.md'):
                z.write(os.path.join(WIKI, f), f'SOURCE/wiki/{f}')
        for f in ('entries.json', 'sections.md', 'thread-findings.md'):
            p = os.path.join(RES, f)
            if os.path.exists(p):
                z.write(p, f'SOURCE/research/{f}')
        z.writestr('README.txt', ARCHIVE_README)
    return os.path.getsize(arc)

def index_entries():
    for e in entries:
        cat = e.get('category', '')
        pg = CAT_PAGE.get(cat, 'index')
        txt = ' '.join(str(e.get(k, '')) for k in ('effect', 'scope', 'example'))
        idx(e.get('name', '?'), cat, txt, f'{pg}.html#{slug(e.get("name",""))}')
    idx('Partition-installed games (PP. / __. / IMAGE0.VCD)', 'storage',
        'PP prefix partition HDDOSD PSBBN IMAGE0.VCD pfs0 SYSTEM.CNF boot2 launch uLE_kHn partition installed hdd',
        'storage.html')

def parse_compat_db():
    """Parse the three current per-game sections of the recovered 'automated' DB into rows.
    Returns (name, disc_id, fix, cat) tuples; cat in {'mode','libcrypt','misc'}. The historical
    Changelog (an H2) and everything after it is skipped. The canonical rendering on
    compatibility.html (wiki_content) is left untouched — this is a structured second view."""
    src = open(os.path.join(ROOT, 'wiki', 'automated.md'), encoding='utf-8').read()
    SECT = {'compatibility modes': 'mode', 'libcrypt fixes': 'libcrypt', 'miscellaneous fixes': 'misc'}
    DEFAULT = {'mode': '', 'libcrypt': 'LibCrypt crack', 'misc': 'Miscellaneous fix'}
    cat, rows = None, []
    for ln in src.split('\n'):
        if ln.startswith('## '):            # reached the Changelog H2 -> stop capturing
            cat = None; continue
        h = re.match(r'^###\s*\*?\s*(.+?)\s*:?\s*\*?\s*$', ln)
        if h:
            cat = SECT.get(h.group(1).strip().strip('*').strip().lower()); continue
        if not (cat and ln.startswith('- ')):
            continue
        item = ln[2:].strip()
        note = ''
        m = re.search(r'\*\((.+?)\)\*\s*$', item)        # trailing *(annotation)*
        if m:
            note = m.group(1).strip(); item = item[:m.start()].strip()
        if ' : ' in item:
            left, fix = item.rsplit(' : ', 1)
        else:
            left, fix = item, DEFAULT[cat]
        fix = fix.replace('×', 'x').strip() or DEFAULT[cat]   # 0×04 -> 0x04
        idm = re.search(r'\(([^()]*)\)\s*$', left)        # last (...) = disc id
        if idm:
            disc, name = idm.group(1).strip(), left[:idm.start()].strip()
        else:
            disc, name = '', left.strip()
        rows.append((name, disc, fix, cat, note))
    return rows

def build_compat_table():
    rows = parse_compat_db()
    # plain-English labels shown beside the raw command token (source: recovered compatibility wiki).
    FIX_LABELS = {
        '$COMPATIBILITY_0x01': 'restores music/voices',
        '$COMPATIBILITY_0x02': '0x01 variant, keeps FMVs (MDEC)',
        '$COMPATIBILITY_0x03': 'alternative to 0x01',
        '$COMPATIBILITY_0x04': 'fixes slowdowns, flicker & glitches',
        '$COMPATIBILITY_0x05': "PAL Resident Evil: Director's Cut cutscenes",
        '$COMPATIBILITY_0x06': 'skips the BIOS OSD shell (startup freezes)',
        '$COMPATIBILITY_0x07': 'missing-texture fix — obsolete, breaks gamma',
        '$SUBCDSTATUS': 'CD-status (a 0x05 variant)',
        '$CODECACHE_ADDON_0': 'code-cache tweak for lag/stalls',
        '$NOVMC1': 'disables VMC slot 1',
        '$NOPAL': 'disables the PAL patcher',
    }
    def fixhtml(fix, cat):
        if cat in ('libcrypt', 'misc'):     # already plain-English; no command token
            return html.escape(fix)
        parts = []
        for tok in fix.split():
            cell = f'<code>{html.escape(tok)}</code>'
            lbl = FIX_LABELS.get(tok)
            if lbl:
                cell += f' <span class="ci-lbl">— {html.escape(lbl)}</span>'
            parts.append(cell)
        return ' + '.join(parts) if parts else html.escape(fix)
    trs = []
    for name, disc, fix, cat, note in rows:
        fixcell = fixhtml(fix, cat)
        if note:
            fixcell += f' <span class="ci-note">({html.escape(note)})</span>'
        trs.append(f'<tr data-cat="{cat}"><td>{html.escape(name)}</td>'
                   f'<td><code>{html.escape(disc)}</code></td><td>{fixcell}</td></tr>')
    n = len(rows)
    head = (f'<h1>Per-game compatibility — searchable</h1>'
            f'<p class="lead">Every game POPStarter auto-fixes in <b>Rev 13 Beta 2019/06/05</b> — '
            f'<b>{n}</b> entries across compatibility modes, LibCrypt cracks and miscellaneous fixes — '
            f'each fix shown as its raw command token plus a plain-English label. '
            f'Type to filter; click a column heading to sort. Source: the recovered '
            f'<a href="wiki/automated.html">automated</a> database, also shown in full on '
            f'<a href="compatibility.html#per-game">Compatibility</a>.</p>')
    toolbar = ('<style>'
               '.ci-toolbar{display:flex;gap:.6rem;align-items:center;flex-wrap:wrap;margin:1rem 0}'
               '.ci-toolbar input,.ci-toolbar select{padding:.45rem .7rem;border-radius:.4rem;'
               'border:1px solid rgba(255,255,255,.22);background:rgba(255,255,255,.06);color:inherit;font:inherit}'
               '.ci-toolbar #ci-count{opacity:.7;font-size:.9rem;margin-left:auto}'
               '.ci-table th{cursor:pointer;user-select:none;white-space:nowrap}'
               '.ci-lbl{opacity:.72}.ci-note{opacity:.65;font-size:.85em}</style>'
               '<div class="ci-toolbar">'
               '<input id="ci-q" type="search" placeholder="Filter by game or disc ID…" autocomplete="off">'
               '<select id="ci-cat"><option value="">All fixes</option>'
               '<option value="mode">Compatibility mode</option>'
               '<option value="libcrypt">LibCrypt crack</option>'
               '<option value="misc">Miscellaneous fix</option></select>'
               '<span id="ci-count"></span></div>')
    table = ('<table class="wiki ci-table" id="ci-table"><thead><tr>'
             '<th>Game</th><th>Disc ID</th><th>Fix</th></tr></thead><tbody>'
             + ''.join(trs) + '</tbody></table>')
    script = ('<script>(function(){'
              "var t=document.getElementById('ci-table'),q=document.getElementById('ci-q'),"
              "c=document.getElementById('ci-cat'),n=document.getElementById('ci-count');"
              'var tb=t.tBodies[0],rows=[].slice.call(tb.rows);'
              'function apply(){var s=(q.value||"").toLowerCase(),cc=c.value,k=0;'
              'rows.forEach(function(r){var a=!cc||r.getAttribute("data-cat")===cc;'
              'var b=!s||r.textContent.toLowerCase().indexOf(s)>=0;var sh=a&&b;'
              'r.style.display=sh?"":"none";if(sh)k++;});'
              'n.textContent=k+" / "+rows.length+" games";}'
              'q.addEventListener("input",apply);c.addEventListener("change",apply);'
              'var dir={};[].slice.call(t.tHead.rows[0].cells).forEach(function(th,i){'
              'th.addEventListener("click",function(){dir[i]=!dir[i];var d=dir[i]?1:-1;'
              'rows.slice().sort(function(a,b){var x=a.cells[i].textContent.trim().toLowerCase(),'
              'y=b.cells[i].textContent.trim().toLowerCase();return x<y?-d:x>y?d:0;})'
              '.forEach(function(r){tb.appendChild(r);});});});apply();})();</script>')
    write('compatibility-table.html', shell('Compatibility table', head + toolbar + table + script, 'compat-table'))
    idx('Per-game compatibility table (searchable)', 'compatibility',
        'searchable sortable filterable per-game compatibility database disc id compatibility mode libcrypt crack '
        'miscellaneous fix automated game list', 'compatibility-table.html')

def main():
    build_wiki()
    build_sections()
    build_downloads()
    build_popsloader()
    build_glossary()
    build_commands()
    build_launch_args()
    build_faq()
    build_known_issues()
    build_compat_table()
    build_thread_study()
    build_credits()
    build_home()
    build_synonyms()
    index_entries()
    copy_assets()
    with open(os.path.join(SITE, 'data', 'search-index.json'), 'w', encoding='utf-8') as f:
        json.dump(search, f, ensure_ascii=False)
    # bundle the whole site (+ raw source) into a downloadable offline archive, then patch
    # its human-readable size into the Downloads page placeholder.
    asize = create_archive()
    dlp = os.path.join(SITE, 'downloads.html')
    txt = open(dlp, encoding='utf-8').read().replace('__ARCHIVE_SIZE__', human(asize))
    open(dlp, 'w', encoding='utf-8').write(txt)
    print(f"  archive: popstarter-docs-archive.zip = {human(asize)}")
    # .nojekyll must exist or GitHub Pages runs Jekyll, which drops files and dirs
    # beginning with an underscore. This script rmtree's SITE on every build, so
    # without emitting it here a deploy silently removes it from gh-pages.
    open(os.path.join(SITE, '.nojekyll'), 'w', encoding='utf-8').write('')
    save_gallery_cache()
    pages = [p for p in os.listdir(SITE) if p.endswith('.html')]
    wk = len(os.listdir(os.path.join(SITE, 'wiki')))
    print(f"BUILT: {len(pages)} top pages + {wk} wiki pages, {len(search)} search entries, "
          f"{len(dl_files)} downloads, {len(img_map)} images -> {SITE}")

print("corpus:", len(entries), "entries,", len(wiki_pages), "wiki pages,", len(dl_files), "downloads,", len(img_map), "images,", len(AMBIG), "ambiguities")
if __name__ == '__main__':
    main()
