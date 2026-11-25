#!/usr/bin/env python3
"""Build Sable-MASTER-INDEX.md by extraction from the 45 audit report files.
Extraction only — no new findings, no re-judging. Statuses/revisions/top-tier
flags are transcribed from the SUMMARY addenda and the round files' own
revision sections (see REVISED map below, each entry traceable to those texts)."""
import re, os
from collections import Counter, OrderedDict

BASE = os.path.expanduser("~/workspace/Sable-audit")
IDPAT = r'((?:RIPTOPL|LAUNCHSTATION|POPSLOADER|SMS|PS2SERVERS)-\d{3}|X-\d{2})'
HEADRE = re.compile(r'^(#{2,4})\s+' + IDPAT + r'\s*(?:/|—|–)\s*(.*?)\s*$')
# Round-7 variant (POPSLoader tarball section): internal IDs R7-T01…T26, stated
# at Sable-POPSLoader-ROUND7.md:119 to map to POPSLOADER-071…096 in benefit
# order — i.e. strictly Tnn -> POPSLOADER-(070+nn). Applied only to that file.
THEADRE = re.compile(r'^#{2,4}\s+R7-(T\d{2})\s*(?:/|—|–)\s*(.*?)\s*$')
ANYHEAD = re.compile(r'^#{1,4}\s')

FILES = [
    ("Sable-RiptOPL.md","RiptOPL"), ("Sable-Launchstation.md","Launchstation"),
    ("Sable-POPSLoader.md","POPSLoader"), ("Sable-Simple-Media-System.md","SMS"),
    ("Sable-PS2-Servers.md","PS2-Servers"),
    ("Sable-RiptOPL-ROUND2.md","RiptOPL"), ("Sable-Launchstation-ROUND2.md","Launchstation"),
    ("Sable-POPSLoader-ROUND2.md","POPSLoader"), ("Sable-Simple-Media-System-ROUND2.md","SMS"),
    ("Sable-PS2-Servers-ROUND2.md","PS2-Servers"),
    ("Sable-RiptOPL-ROUND3.md","RiptOPL"), ("Sable-Launchstation-ROUND3.md","Launchstation"),
    ("Sable-POPSLoader-ROUND3.md","POPSLoader"), ("Sable-Simple-Media-System-ROUND3.md","SMS"),
    ("Sable-PS2-Servers-ROUND3.md","PS2-Servers"),
    ("Sable-RiptOPL-ROUND4.md","RiptOPL"), ("Sable-Launchstation-ROUND4.md","Launchstation"),
    ("Sable-POPSLoader-ROUND4.md","POPSLoader"), ("Sable-Simple-Media-System-ROUND4.md","SMS"),
    ("Sable-PS2-Servers-ROUND4.md","PS2-Servers"),
    ("Sable-RiptOPL-ROUND5.md","RiptOPL"), ("Sable-Launchstation-ROUND5.md","Launchstation"),
    ("Sable-Simple-Media-System-ROUND5.md","SMS"), ("Sable-PS2-Servers-ROUND5.md","PS2-Servers"),
    ("Sable-Simple-Media-System-ROUND6.md","SMS"),
    ("Sable-RiptOPL-ROUND7.md","RiptOPL"), ("Sable-Launchstation-ROUND7.md","Launchstation"),
    ("Sable-POPSLoader-ROUND7.md","POPSLoader"), ("Sable-Simple-Media-System-ROUND7.md","SMS"),
    ("Sable-PS2-Servers-ROUND7.md","PS2-Servers"),
    ("Sable-RiptOPL-ROUND8.md","RiptOPL"), ("Sable-Launchstation-ROUND8.md","Launchstation"),
    ("Sable-Simple-Media-System-ROUND8.md","SMS"),
    ("Sable-RiptOPL-ROUND9.md","RiptOPL"), ("Sable-RiptOPL-ROUND9-MODULES.md","RiptOPL"),
    ("Sable-RiptOPL-ROUND9-THIRDPARTY-A.md","RiptOPL"),
    ("Sable-RiptOPL-ROUND9-THIRDPARTY-B.md","RiptOPL"),
    ("Sable-Simple-Media-System-ROUND9.md","SMS"),
    ("Sable-SUMMARY.md","Cross"),
    ("Sable-CROSSREPO-ROUND2.md","Cross"), ("Sable-CROSSREPO-ROUND3.md","Cross"),
    ("Sable-CROSSREPO-ROUND4.md","Cross"), ("Sable-CROSSREPO-ROUND5.md","Cross"),
    ("Sable-CROSSREPO-ROUND7.md","Cross"), ("Sable-CROSSREPO-ROUND9.md","Cross"),
    # Verification phase (2026-11-14): one file, four repos — repo derived
    # from each finding's ID prefix (see PREFIX_REPO below).
    ("Sable-VERIFICATION-NEW-FINDINGS.md","BY-ID"),
    ("Sable-VERIFY2-NEW-FINDINGS.md","BY-ID"),
]
PREFIX_REPO = {'RIPTOPL': 'RiptOPL', 'LAUNCHSTATION': 'Launchstation',
               'POPSLOADER': 'POPSLoader', 'SMS': 'SMS',
               'PS2SERVERS': 'PS2-Servers', 'X': 'Cross'}

EFFTOK = r'(XS|S|M|L|Trivial|One character|One token|One line|~?\d+ lines?)'
RISKTOK = r'(Near zero|Negligible|Minimal|None|Low|Medium|Med|High)'

def norm_cat_tail(rest):
    m = re.search(r'\s*/\s*Category\s+(.+?)\s*$', rest)
    if not m: return rest, None
    nums = re.findall(r'\d+', m.group(1).split('(')[0])
    return rest[:m.start()].rstrip(), ('/'.join(nums[:2]) if nums else None)

def parse_conf(raw):
    raw = raw.strip().rstrip('.')
    segs = [s.strip() for s in raw.split(';') if s.strip()]
    grades = []   # (grade, tag)
    extras = []   # standalone READ/INFERRED segments
    for s in segs:
        m = re.match(r'(High|Medium|Med|Low)\b', s)
        if m:
            t = re.search(r'\b(READ|INFERRED)\b', s)
            grades.append((m.group(1), t.group(1) if t else None))
        elif re.match(r'(READ|INFERRED)\b', s):
            extras.append(re.match(r'(READ|INFERRED)\b', s).group(1))
    if grades:
        gset = []
        for g, _ in grades:
            if g not in gset: gset.append(g)
        tags = []
        for _, t in grades:
            if t and t not in tags: tags.append(t)
        for e in extras:
            if e not in tags: tags.append(e)
        if 'INFERRED' in raw and 'INFERRED' not in tags: tags.append('INFERRED in part')
        if 'READ' in raw and not tags and False: pass
        out = '/'.join(gset)
        if tags: out += ' (' + '; '.join(tags) + ')'
        return out
    if extras:
        out = '; '.join(dict.fromkeys(extras))
        if 'INFERRED' in raw and 'INFERRED' not in out: out += '; INFERRED in part'
        return out
    return raw[:40] if raw else None

def parse_fields(body):
    cat = effort = risk = conf = None
    for ln in body:
        if not re.match(r'\s*-\s', ln):  # fields live on bullet lines
            continue
        if cat is None:
            m = re.search(r'(?:\*\*)?Category:(?:\*\*)?\s*(\d+(?:\s*/\s*\d+)?)', ln)
            if m: cat = m.group(1).replace(' ', '')
        if effort is None:
            m = re.search(r'(?:\*\*)?Effort:(?:\*\*)?\s*' + EFFTOK + r'(?:\s*[–—-]\s*(XS|S|M|L))?', ln)
            if m: effort = m.group(1) + (('–' + m.group(2)) if m.group(2) else '')
        if risk is None:
            m = re.search(r'(?:\*\*)?Risk:(?:\*\*)?\s*' + RISKTOK + r'(?:\s*[–—-]\s*(Low|Medium|Med|High))?', ln)
            if m: risk = m.group(1) + (('–' + m.group(2)) if m.group(2) else '')
        if conf is None:
            m = re.search(r'(?:\*\*)?Confidence:(?:\*\*)?\s*(.+)$', ln)
            if m: conf = parse_conf(m.group(1))
        if cat and effort and risk and conf: break
    return cat, effort, risk, conf

results = {}; order = []
for fname, repo in FILES:
    path = os.path.join(BASE, fname)
    lines = open(path, encoding='utf-8').read().splitlines()
    heads = []
    for i, ln in enumerate(lines):
        m = HEADRE.match(ln)
        if m: heads.append((i, m.group(2), m.group(3)))
        elif fname == 'Sable-POPSLoader-ROUND7.md':
            tm = THEADRE.match(ln)
            if tm: heads.append((i, 'POPSLOADER-%03d' % (70 + int(tm.group(1)[1:])), tm.group(2)))
    for j, (i, fid, rest) in enumerate(heads):
        end = heads[j+1][0] if j+1 < len(heads) else len(lines)
        body = []
        for k in range(i+1, end):
            if ANYHEAD.match(lines[k]): break
            body.append(lines[k])
        title, cat = norm_cat_tail(rest)
        bcat, effort, risk, conf = parse_fields(body)
        if cat is None: cat = bcat
        if fid not in results:
            row_repo = PREFIX_REPO[fid.rsplit('-', 1)[0]] if repo == 'BY-ID' else repo
            results[fid] = dict(id=fid, repo=row_repo, title=title, cat=cat or '—',
                                effort=effort or '—', risk=risk or '—',
                                conf=conf or '—', src=fname)
            order.append(fid)

# ---- Round-7 variant (RiptOPL): Sable-RiptOPL-ROUND7.md lists its 15 findings
# in a "## Findings index" table (ID | Source | Title (short) | Cat) and writes
# the bodies in three formats HEADRE does not match. Titles/Cats are taken from
# the index table (the report's own short forms); Effort/Risk/Confidence are
# taken from the bodies where the source gives them, else '—' (see index §5).
def parse_riptopl_round7():
    path = os.path.join(BASE, 'Sable-RiptOPL-ROUND7.md')
    lines = open(path, encoding='utf-8').read().splitlines()
    table = {}   # fid -> (source, short title, cat)
    for ln in lines:
        m = re.match(r'^\|\s*(RIPTOPL-\d{3})\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*(\d+)\s*\|', ln)
        if m: table[m.group(1)] = (m.group(2).strip(), m.group(3).strip(), m.group(4))
    found = {}
    def add(fid, effort=None, risk=None, conf=None):
        if fid in table and fid not in results and fid not in found:
            src_, title, cat = table[fid]
            found[fid] = dict(id=fid, repo='RiptOPL', title=title, cat=cat,
                              effort=effort or '—', risk=risk or '—', conf=conf or '—',
                              src='Sable-RiptOPL-ROUND7.md')
    # (a) Assembly: "### Title: ..." blocks under the grouped 281…285 header.
    #     Paired to index rows by the distinctive token each title shares with
    #     the index table's short title (block order in the file is candidates
    #     1,2,3,5,4 against the table's numbering for the last two).
    ASM_KEYS = [('GSHandler', 'RIPTOPL-281'), ('mips_memcpy', 'RIPTOPL-282'),
                ('Hook_ExecPS2', 'RIPTOPL-283'), ('dve_set_reg', 'RIPTOPL-284'),
                ('Dead exported symbols', 'RIPTOPL-285')]
    try:
        a0 = next(i for i, ln in enumerate(lines) if ln.startswith('### RIPTOPL-281'))
        a1 = next(i for i, ln in enumerate(lines) if ln.startswith('## TASK 2'))
    except StopIteration:
        a0 = a1 = 0
    blocks, cur = [], None
    for ln in lines[a0:a1]:
        if ln.startswith('### Title:'):
            cur = [ln]; blocks.append(cur)
        elif cur is not None:
            cur.append(ln)
    for blk in blocks:
        for key, fid in ASM_KEYS:
            if key in blk[0]:
                _, effort, risk, conf = parse_fields(blk)
                add(fid, effort, risk, conf)
    # (b) Scripts: "### Finding S-n — <title> — Cat X (...), READ" headings; the
    #     index table's Source column ("scripts S-3") gives the S-n -> ID map.
    #     Bodies carry no Effort/Risk fields; Confidence is the heading's own
    #     trailing READ / READ + INFERRED tag.
    smap = {}
    for fid, (src_, _, _) in table.items():
        m = re.search(r'(S-\d)$', src_)
        if m: smap[m.group(1)] = fid
    for i, ln in enumerate(lines):
        m = re.match(r'^### Finding (S-\d)\s*—', ln)
        if m and m.group(1) in smap:
            cm = re.search(r'(READ(?:\s*\+\s*INFERRED[^,]*)?)\s*$', ln)
            add(smap[m.group(1)], None, None, parse_conf(cm.group(1)) if cm else None)
    # (c) Docs: "### Docs — <title>" blocks, in the index table's order; bodies
    #     carry a Severity bullet only — no Effort/Risk/Confidence fields exist.
    doc_ids = [fid for fid in sorted(table) if table[fid][0] == 'docs']
    doc_heads = [ln for ln in lines if ln.startswith('### Docs — ')]
    for fid in doc_ids[:len(doc_heads)]:
        add(fid)
    for fid in sorted(found):
        results[fid] = found[fid]; order.append(fid)

parse_riptopl_round7()

# ---- Round-9 variant (RiptOPL third_party pass B): Sable-RiptOPL-ROUND9-
# THIRDPARTY-B.md uses the same shape as RiptOPL round 7 — a "## Findings
# index" table (ID | Component | Title | Cat) with bodies as "### Title: ..."
# blocks that HEADRE does not match. Titles/Cats are taken from the index
# table; Effort/Risk/Confidence from the bodies. Blocks are paired to table
# rows in file order (the index order): exact-title pairing is impossible
# because the table's short title for RIPTOPL-601 drops the word "PSUManager"
# that its block title carries, while RIPTOPL-600's two titles are identical.
def parse_riptopl_round9_thirdparty_b():
    path = os.path.join(BASE, 'Sable-RiptOPL-ROUND9-THIRDPARTY-B.md')
    lines = open(path, encoding='utf-8').read().splitlines()
    table = {}   # fid -> (title, cat)
    for ln in lines:
        m = re.match(r'^\|\s*(RIPTOPL-\d{3})\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*(\d+)\s*\|', ln)
        if m: table[m.group(1)] = (m.group(3).strip(), m.group(4))
    blocks, cur = [], None
    for ln in lines:
        if ln.startswith('### Title:'):
            cur = [ln]; blocks.append(cur)
        elif ANYHEAD.match(ln):
            cur = None
        elif cur is not None:
            cur.append(ln)
    for fid, blk in zip(sorted(table), blocks):
        if fid in results: continue
        _, effort, risk, conf = parse_fields(blk)
        results[fid] = dict(id=fid, repo='RiptOPL', title=table[fid][0], cat=table[fid][1],
                            effort=effort or '—', risk=risk or '—', conf=conf or '—',
                            src='Sable-RiptOPL-ROUND9-THIRDPARTY-B.md')
        order.append(fid)

parse_riptopl_round9_thirdparty_b()

# ---- Statuses, transcribed from SUMMARY addenda + round revision sections ----
REVISED = {
 'RIPTOPL-008': 'REVISED (R2 — reframed; remainder filed as RIPTOPL-048)',
 'RIPTOPL-021': 'REVISED (R2 — expanded; whole-tree copy filed as RIPTOPL-047)',
 'RIPTOPL-026': 'REVISED (R5 — plumbing clause narrowed)',
 'RIPTOPL-044': 'REVISED (R4 — ioman-side call site cleared; core defect stands)',
 'RIPTOPL-064': 'REVISED (R5 — extended: second location in PC genvmc)',
 'RIPTOPL-291': 'REVISED (R8 — formally extended: 10 further skip-to-pass instances in 9 files; fix shape unchanged, coverage extended)',
 'RIPTOPL-301': 'REVISED (R8 — narrowing recorded in the finding: round 7’s “no self-comparisons” corpus negative is narrowed — the dict-literal self-reference shape was outside the round-7 scan; the round-7 claim stands for the patterns it scanned)',
 'LAUNCHSTATION-017': 'REVISED (R2 — still true, changed form)',
 'LAUNCHSTATION-047': 'REVISED (R3 R3-R2 — census corrected upward)',
 'LAUNCHSTATION-051': 'REVISED (R3 R3-R3 — narrowed and strengthened)',
 'LAUNCHSTATION-052': 'REVISED (R3 R3-R1 — four copies, not three)',
 'LAUNCHSTATION-064': 'REVISED (R4 R4-R1 — downgraded to latent hardening)',
 'LAUNCHSTATION-072': 'REVISED (R4 R4-R3 — split; aes_reference.c struck from deletion list; full verification — WEAKENED further: of the seven proposed deletions only quic.c + smbdirect.c are proven empty/deletable (2 of 7); aes_reference.c is the server’s only AES and must stay; sync.c, smb2-share-enum.c, smb2-data-security-descriptor.c and smb2-data-reparse-point.c are UNVERIFIABLE-HERE — deletion rests on a --gc-sections link test that cannot run in this VM)',
 'LAUNCHSTATION-085': 'REVISED (R5 settlement — proven waste, closed)',
 'POPSLOADER-006': 'REVISED (R3 REV-006 — fix changed: extract-or-archive; R7 R7-REV-006 — narrowed: disposition covers the bdm_assault half only; usbhdfsd.irx has no source in the tarball)',
 'POPSLOADER-011': 'REVISED (R7 R7-REV-011 — rationale corrected: the CI parity check cannot compare the committed dump; see POPSLOADER-066)',
 'POPSLOADER-010': 'REVISED (R3 REV-010 — pademu copies a semantic fork)',
 'POPSLOADER-016': 'REVISED (R3 REV-016; R4 REV-016 addendum)',
 'POPSLOADER-033': 'REVISED (R3 REV-033 — merge shape/effort revised)',
 'SMS-014': 'REVISED (R2 R2-1 — narrowed)',
 'SMS-017': 'REVISED (R2 — corrected by cross-repo evidence)',
 'SMS-027': 'REVISED (R2 R2-3 — replaced by SMS-038)',
 'SMS-028': 'REVISED (R2 R2-2 — narrowed)',
 'SMS-057': 'REVISED (R6 R6-REV-1 — sink list completed: m_BrowserIBCIdx direct reads)',
 'SMS-068': 'REVISED (R6 R6-REV-2 — twelfth site added: SMS_History.c:140)',
 'PS2SERVERS-021': 'REVISED (R3 addendum — at-cap disagreement split to PS2SERVERS-062)',
 # ---- Verification phase (2026-11-14): WEAKENED verdicts become REVISED ----
 # (full narrowed conditions in the index §4 ledger, VERIFY-N entries; the
 # three WEAKENED findings that are also full/partial duplicates — RIPTOPL-405,
 # RIPTOPL-408, RIPTOPL-468 — are retired as CROSS-REF instead, see CROSSREF.)
 'RIPTOPL-016': 'REVISED (verification — WEAKENED: survives only for smb_share via the unterminating share-selection memcpy at ethsupport.cpp:1307; config/GUI writers terminate the other fields)',
 'RIPTOPL-308': 'REVISED (verification — WEAKENED: post-print crash scenario defeated by stdio pipe buffering (executed); survives only for a clean non-zero exit after flush)',
 'RIPTOPL-413': 'REVISED (verification — WEAKENED: division traps stand; cluster_buf overrun only in the tail loop when pages_per_cluster × pagesize > 16400)',
 'RIPTOPL-415': 'REVISED (verification — WEAKENED: only the mtime[1] OOB indexing survives; the string half is defeated by the sole EE producer, which terminates all fields)',
 'RIPTOPL-421': 'REVISED (verification — WEAKENED: “never registers” holds only in the [1,2) and [3,4) TiB bands; (2,3) TiB registers undersized, exactly 2/4 TiB registers a 0-sector device)',
 'RIPTOPL-425': 'REVISED (verification — WEAKENED: icmp_dest_unreach only; icmp_time_exceeded is compiled out — IP_FORWARD is unconditionally 0)',
 'RIPTOPL-459': 'REVISED (verification — WEAKENED: fires only on a malformed 16-byte non-terminated fill; no valid dotted-quad IPv4 can trigger it)',
 'RIPTOPL-462': 'REVISED (verification — WEAKENED: unwritten-tail read unreachable with the sole in-tree caller (count = 20 = MAX_CONNECTIONS); connect is not log-silent — only a failure-specific log/event and an error return are missing)',
 'RIPTOPL-473': 'REVISED (verification — WEAKENED: zero-EUI-64 outcome holds only for the sceCdRI failure sub-case; on sceCdRM-only failure the GUID is already written and valid)',
 'SMS-115': 'REVISED (verification — WEAKENED: shipped Player flow defeats the “valid 5.1” trigger (_check_ac3 clamp + SPDIF routing); survives for non-SPDIF with m_Channels == 0, or a non-Player caller)',
 'SMS-116': 'REVISED (verification — WEAKENED: same Player guard chain as SMS-115; survives for non-SPDIF with m_Channels == 0, or a non-Player caller)',
 'SMS-117': 'REVISED (verification — WEAKENED: exclude_mask walk stands (passes 63 at the 9th round), but n advances by 1 per round, not 7 — additional_excluded_chns needs ~64 rounds, not 10)',
 'SMS-133': 'REVISED (verification — WEAKENED: the claimed multi-byte over-read cannot occur (the total-bits test bounds every fall-through read); only a 0-bit read at endbyte == storage touches ptr[0] one byte past)',
 'SMS-140': 'REVISED (verification — WEAKENED: the −1 arm is defeated by the joint_intensity[j] > 0 guard; the bounded loop only consumes bits — bit-stream desync via an intra-struct OOB read, not a steered write)',
 'SMS-142': 'REVISED (verification — WEAKENED: two integer divisions, not three (:1397 is float); MIPS integer div-by-zero does not trap — quotient UNPREDICTABLE, not a guaranteed crash)',
 'SMS-151': 'REVISED (verification — WEAKENED: the callee writes *apStartSec before the failing chain call; only the loop extent is uninitialised, not the start sector)',
 'SMS-153': 'REVISED (verification — WEAKENED: i is uint8_t and wraps at 256 — the UB window is exit i ∈ [32,255], not an arbitrarily large counter)',
 'SMS-164': 'REVISED (verification — WEAKENED: only the TCP branch is reachable in-tree (err_tcp NULLs the PCB, then re-bind); the UDP branches are latent — no in-tree entry path)',
 'LAUNCHSTATION-079': 'REVISED (verification — WEAKENED: the 336-byte superblock copy excludes cluster_size (offset 340, hard-set to 1024) and clusters_per_block (348) — those sinks are not card-driven via the copy; the pagesize/pages_per_cluster sinks hold)',
 'PS2SERVERS-013': 'REVISED (verification — WEAKENED: Python standalone+Core only; Go Edge has writer exclusion (reserveWriter; -EBUSY) — “every edition” defeated)',
 'PS2SERVERS-042': 'REVISED (verification — WEAKENED: fake handlers + guest bypass re-executed, but h2_tree_connect/h2_close always raise struct.error and kill the thread; h2_write reports Count=0)',
 'PS2SERVERS-071': 'REVISED (verification — execution qualification C-2: the offset-0 hypothetical is backstopped by a second clamp (server.go:498-500); the wrong-sector oracle defect stands; mutation run environment-blocked)',
 'X-18': 'REVISED (verification — WEAKENED: chain exact for the dash_apps.c Edit-metadata starter only; the second writer (filer_actions.c:1924 make_title_cfg, unspaced) is correct)',
 'X-49': 'REVISED (verification — WEAKENED: census tallies exact, but the union sentence is refuted by RiptOPL pademu ds34usb.c (carries neither defect) — true union 9/10 carry ≥1 defect, 1 carries none)',
 # ---- Full verification phase (2026-11-14): WEAKENED verdicts become REVISED ----
 # (narrowed conditions quoted in the index §4 ledger, VERIFY2-N entries.
 # SMS-123, revised in phase 1, is WITHDRAWN again in this phase — see WITHDRAWN.
 # X-07 moves from CROSS-REF to REVISED here. LAUNCHSTATION-072 was already
 # REVISED and is narrowed further in place, above.)
 'RIPTOPL-001': 'REVISED (full verification — WEAKENED: the 53,655,730 B total is exact, but the plain and incebtion/ sets are two different themes’ footage, not duplicate copies; the recoverable saving is roughly one format per theme, not ~35–45 MB)',
 'RIPTOPL-019': 'REVISED (full verification — WEAKENED: the opendir probe at supportbase.cpp:397 fires only for non-ISO candidate entries when folder browsing is enabled for that scan — not an unconditional per-entry probe)',
 'RIPTOPL-029': 'REVISED (full verification — WEAKENED: the plasma is a 32×32 Perlin texture refreshed 6 rows per frame (~192 pixels/frame, deliberately throttled), not a full-screen per-pixel per-frame CPU effect)',
 'RIPTOPL-031': 'REVISED (full verification — WEAKENED: sdk_stub holds 23 files of which 19 are the identical empty stub, not 20; the duplicated-name second tree stands)',
 'RIPTOPL-032': 'REVISED (full verification — WEAKENED: the four .irx have no source and no ps2.yaml rule, but the legacy Makefile:1182-1191 does contain bin2c embedding rules for them — unexplained inputs for the live build, not wholly rule-less files)',
 'RIPTOPL-040': 'REVISED (full verification — WEAKENED: the smb_dopen strcat overflow stands (1–2 bytes past name[256] for ≥255-char directory paths), but the unterminated-name/chdir cascade is defeated — the size−1 copy counts preserve the zeroed last byte, so strlen stays bounded)',
 'RIPTOPL-056': 'REVISED (full verification — WEAKENED: the two DES copies diverge in const-correctness, DES_Keys scope/alignment and local placement (~24 stripped diff lines, not 71); the smbinit copy does keep a static key buffer (function-local, des.c:451) — the stated presence-vs-absence divergence is wrong; “one copy patched” survives only for const)',
 'RIPTOPL-159': 'REVISED (full verification — WEAKENED: the PadManager::start() loop-structure overflow stands, but it is gated on pads actually opening — padCount_ increments only on startOne() success after padPortOpen; overflow needs four opened pads before an extra slot iteration (e.g. 1 pad + a multitap port))',
 'RIPTOPL-164': 'REVISED (full verification — WEAKENED: the strlen(NULL) crash, the guaranteed 4-byte static overwrite and the 136-byte frame over-read stand; the name-copy overrun is length-dependent (only for module names over 123 bytes) — the filed “≥13 + len” minimum is wrong, since the memcpy cursor advances by words)',
 'RIPTOPL-492': 'REVISED (full verification — WEAKENED: crc[512] exists only under #ifdef CONFIG_USE_CRC16, which is never enabled (its only define is commented out at mx4sio.h:37) — a latent 1 KiB cost if ever enabled, not resident IOP RAM in the shipped build)',
 'RIPTOPL-530': 'REVISED (full verification — WEAKENED: the JMP-macro and dummy_fs items stand, but the atad claim halves — only ATA_C_STANDBY_IMMEDIATE is duplicated (atad.c:92); ATA_C_FLUSH_CACHE occurs once, the next entry being the distinct FLUSH_CACHE_EXT)',
 'LAUNCHSTATION-011': 'REVISED (full verification — WEAKENED: both themes are embedded, but the embedded total is 215,856 B, not 359,840 B (that figure includes the unembedded boot.adp of LAUNCHSTATION-013); deleting one theme saves at most 141,936 B, not ~180 KB)',
 'LAUNCHSTATION-015': 'REVISED (full verification — WEAKENED: the 863-hit unsafe-string count and cited chains stand, but the concrete config-save heap overflow is not reachable as stated — every %s argument is a fixed-size SETTING array and the +8,192 B reserve covers the format overhead; survives as unbounded-API hygiene / defence-in-depth)',
 'LAUNCHSTATION-024': 'REVISED (full verification — WEAKENED: two persistence systems coexist and the 4,096-line settings UI edits both, but they deliberately write disjoint files (dash_store.c:5-9 never modifies LAUNCHSTATION.CNF) — the claimed overlapping writes are not shown; a consolidation opportunity, not a demonstrated divergence bug)',
 'LAUNCHSTATION-030': 'REVISED (full verification — WEAKENED: the memalign(128, 512×1024) at dash_font.c:80 is the SJIS/ELISA glyph atlas texture, exactly sized to its declared 512×1024 PSMT8 texture and lazily allocated — not dashboard-face scratch; the claimed ~384 KB saving does not follow)',
 'LAUNCHSTATION-032': 'REVISED (full verification — WEAKENED: of the four named scripts only stale_code_audit.sh is a genuine unreferenced one-off; audit_r3z_settings.py, check_ds34_build.py and copy_test_pack.py are live CI/test infrastructure — the deletable set is 1 file, not 3–6)',
 'LAUNCHSTATION-042': 'REVISED (full verification — WEAKENED: the two URL parsers share only a ~20-line host/IP prefix plus parallel skeletons (52 vs 40 lines; tails diverge) — not near-identical ~70-line functions; the ~100+ removable-lines estimate overstates a merge)',
 'LAUNCHSTATION-043': 'REVISED (full verification — WEAKENED: only the usmb2/unfs4 receive loops are true near-duplicates; smbman’s GetSMBServerReply matches no id at all, the two MD4 files are independent implementations, and the UTF-16 pairs convert different encodings (ASCII↔ vs UTF-8↔) — the three-way single-sourcing programme does not follow as stated)',
 'LAUNCHSTATION-048': 'REVISED (full verification — WEAKENED: the write-path segment test uses the wrong constant name, but PKO_MAX_WRITE_SEGMENT and PKO_MAX_READ_SEGMENT are numerically equal (both structs 14 B → both segments 1446), so no oversize segment can be emitted today — a latent identifier typo only; the dirent half is refuted outright (net_fio.c:649 forces termination))',
 'LAUNCHSTATION-105': 'REVISED (full verification — WEAKENED: the ynDialog half stands in full (strcpy into msg[512] at gui.c:20, exceeded by the lang.c and installer caller families); the nonDialog half narrows — no caller that can exceed its 2,400-byte buffer (gui.c:111) was found; a latent same-shape sink, not a dialog several callers already exceed)',
 'LAUNCHSTATION-122': 'REVISED (full verification — WEAKENED: the buffer/cap mismatch is real (name[65] vs keyboard cap 31), but modalKeyboard never truncates on confirm — the only max_len truncation is on cancel (dash_widgets.c:587), and the caller discards the buffer then; the cap blocks insertions at ≥31 chars — an editing constraint, not silent truncation)',
 'LAUNCHSTATION-147': 'REVISED (full verification — WEAKENED: des_cbc_crypt has no multiple-of-8 check, but it is already static and its only callers are inside the validating tdes_cbc_crypt (size always 8; tdes validates (size & 7) at :436-439) — exposure only via a future edit inside kelf_signer.c itself; a latent in-file foot-gun, materially narrower than filed)',
 'LAUNCHSTATION-156': 'REVISED (full verification — WEAKENED: apaPassCmp compiling to return 0 in the OSD build stands (no APA_ENABLE_PASSWORDS), but the input-side DES runs are conditional — apaEncryptPassword runs only when the argument actually carries a non-empty password field; a plain partition-name parse performs no DES run at all)',
 'LAUNCHSTATION-160': 'REVISED (full verification — WEAKENED: the silent drop stands (hub.c:427-429 logs only via dbg_printf, a no-op without DEBUG), but the 512 B cap is not a MINI_DRIVER effect — maxStaticDescSize is 0x200 in both configurations (usbd.c:40/:54); survives only as “512 B cap + silent drop in release builds”)',
 'LAUNCHSTATION-185': 'REVISED (full verification — WEAKENED: only the argc == 3 fall-through survives; the claimed trailing-pair drop is refuted — pairs are consumed from index 2 and the continuation test is exactly correct, so no complete pair is ever dropped. WARNING: the originally proposed fix’s loop-condition half (i1 + 1 < argc) should NOT be applied — it would read one argv slot past the last complete pair. The sole caller applyXPARAM (init.c:1355) never passes pairs at all)',
 'LAUNCHSTATION-213': 'REVISED (full verification — WEAKENED: only the SMB2.CNF half is a contradiction (CHANGELOG.md:52’s claim is false — shares live in LAUNCHSTATION.CNF, dash_settings.c:563-564); the smb1:/ half is not a contradiction — both phrasings are true at different layers and the code itself uses the smb1:/ phrasing (dash_browser.c:301 reconciles the two))',
 'LAUNCHSTATION-218': 'REVISED (full verification — WEAKENED: four sites deny a root LICENSE exists, not five — the fifth (docs-site/content/ecosystem.html:4, “no single root licence”) remains true, because the root LICENSE’s scope is limited to original Launchstation code, and is struck; the four-site finding stands)',
 'POPSLOADER-002': 'REVISED (full verification — WEAKENED: the byte identities are exact, but usbd.irx.mx4sio is already aliased to the usbexfat blob (embed_assets.cpp:149-153,210), not embedded — the remaining saving is 83,008 B (ilink usbd + udpfs usbhdfsd), not 131,508 B)',
 'POPSLOADER-007': 'REVISED (full verification — WEAKENED: only 25 of the 67 IMG PNGs are embedded (243,578 B); the other 42 (87,097 B) are loose-only with no second copy — the duplication covers the embedded 25, not the ~330,675 B folder upper bound)',
 'POPSLOADER-024': 'REVISED (full verification — WEAKENED: a full md5 census of .research/assets/ finds exactly 6 exact-duplicate image pairs (6 redundant copies = 57,552 B), not “at least 9”; the root loose assets stand as cited)',
 'POPSLOADER-036': 'REVISED (full verification — WEAKENED: the text-assert population stands (11 of 62 checks are pure source-text asserts — roughly a fifth), but the re-read count overstates: 25 read_text sites in total including the initial loads, of which 15 re-read the two already-loaded Lua sources, not ≥25 re-reads)',
 'POPSLOADER-041': 'REVISED (full verification — WEAKENED, mechanism REPLACED: the endpoint walks are count-bounded by while (epCount--), so a zero bLength stalls on one descriptor but terminates — the filed infinite-loop mechanism is refuted. The real hang: epCount = interface->bNumEndpoints − 1 (ds34bt.c:117, ds34usb.c:132 DS3 branch) underflows to −1 when bNumEndpoints == 0, making the do-while effectively non-terminating. The missing NULL checks and the DS4 epCount = 20 hard-code stand; the fix should add an epCount < 0 / bNumEndpoints == 0 guard)',
 'POPSLOADER-044': 'REVISED (full verification — WEAKENED: the gutted debug block, discarded locals and the microsecond unit error stand (ui.lua:6670-6699; flag default false at :1270), but the “counters only ever reset, never read” clause is imprecise — DebugPadLast is read by the block’s own comparison (:6676) and NavEventCount is incremented by live code (emit_nav, :6596); its value is simply never consumed anywhere)',
 'SMS-034': 'REVISED (full verification — WEAKENED: the vendored font packs with space-laden vendor paths are proven, but “unused members ride along” was never proven (INFERRED in the original) — the packs are alternative per-language sets sharing bare names, and two code-referenced names (greek.mtf, latin2.mtf) appear in no pack; whether any given .mtf is ever used is not determinable from the repo)',
 'SMS-041': 'REVISED (full verification — WEAKENED: the :1504 half stands (unbounded strcpy of m_pPath into lPath[512] at SMS_Player.c:1502-1504, paths legitimately built to 1024 B); the :1060 half is refuted — the container m_pName is a ≤8-char format constant (“MPEG(PS)” is the longest), never a file name, so the lBuff[128] overflow cannot occur)',
 'SMS-045': 'REVISED (full verification — WEAKENED: boundedness verified everywhere claimed, including all six MOV sites (_tbl_fits + explicit NULL checks — SMS-015’s withdrawal stands); the unchecked-result half survives only at the M3U pair (SMS_ContainerM3U.c:308-312,366-371), SMS_FileContext.c:1233-1238 and :1976-1978, and SMS_Container.c:351-352 — the MOV six and FileContext :2069 are checked)',
 'SMS-049': 'REVISED (full verification — WEAKENED: the unchecked SMSCDVD appends are real, but matched components are ≤129 B (TocEntryCopy truncates to the 129-byte field), not 255, and cumulative growth in one FindPath descent is bounded by the pathname already copied into s_DirName[1024] — overflowing m_Pathname requires a >1023-byte apPath that first overflows s_DirName itself at :657/:685)',
 'SMS-072': 'REVISED (full verification — WEAKENED: the CDDA_Fill last-sector modulo defect stands, but single-sector files are saved by the sibling start-sector branch (SMS_FileContext.c:474-477, no modulo); the surviving trigger needs (m_Size + m_Offset) % 2352 == 0 AND at least two sectors, via the non-streaming CDDA_Fill path)',
 'SMS-090': 'REVISED (full verification — WEAKENED: the m_Idx == m_Cnt one-past write in subtitle Reset is real and reachable (SMS_SubtitleContext.c:917-922), but the “Prepare never run ⇒ NULL m_pPackets” state is not shown reachable as stated; the Reset callers are in SMS_PlayerControl.c (:774,816,1348), not SMS_Player.c)',
 'SMS-091': 'REVISED (full verification — WEAKENED: the GUIMenu_ShowItem hide-walks are genuinely unbounded in code (SMS_GUIMenu.c:362-375), but for the sole caller (aPos = 4, SMS_GUIMenuSMS.c:2342) they stop after one step onto a never-hidden neighbour in both directions — no out-of-bounds walk is reachable in the shipped menu; latent hardening only)',
 'SMS-181': 'REVISED (full verification — WEAKENED: the USBD stubs do return false success (interface.c:216-229, USB_RC_OK = 0), but the public header does disclose them — “// these aren’t implemented:” at iop/USBD/include/usbd.h:248 — defeating the “no hint” framing; the defect is the dishonest return value, not an undisclosed stub)',
 'PS2SERVERS-011': 'REVISED (full verification — WEAKENED: the SESSION format is implemented exactly twice, once per language (Python launcher/session_stats.py; Go internal/sessionstats), plus ~4-line record adapters per Python server — not three times plus per-server dicts; UDPFS’s private dict holds shutdown totals, a different output, and NFS does not participate at all. The filed −150-line estimate is not supported)',
 'PS2SERVERS-037': 'REVISED (full verification — WEAKENED: _signature_of stats every file in the scanned directories and refresh() rebuilds on change, but the sweep is throttled (RESCAN_INTERVAL = 5.0 s), runs only from the games.csv handler (lookup() deliberately never rescans), and is flat by default (root + CD/DVD) unless recursive mode is opted in; measured 0.8 ms over 300 files)',
 'PS2SERVERS-038': 'REVISED (full verification — WEAKENED: the core is executed-proven (a standalone copy of udpbd_server.py dies with ModuleNotFoundError for the launcher package at :419; its device implementations are 752 lines of launcher-package code), but the premise “every other server is self-contained” is false — http_server.py:47 imports launcher at top level (see PS2SERVERS-116) and SMB1/SMB2 import launcher.session_stats lazily in main(). Narrowed: UDPBD is the only server whose functional device implementations live in the launcher package)',
 'PS2SERVERS-093': 'REVISED (full verification — WEAKENED: the bare return at test_ra_credentials.py:76-78 is real, but the filed CI consequence is refuted — no Windows job runs this module (the achievements fixed list and the windows-storage lists omit it; its only CI run is Ubuntu discovery, where the test executes fully), and the achievements matrix is 2 Windows + 1 Ubuntu + 2 macOS, not “both Windows”. Survives as a latent one-line hygiene defect: if ever run on Windows, the POSIX-permissions test would report a phantom pass instead of a visible skip)',
 'PS2SERVERS-106': 'REVISED (full verification — WEAKENED: the scratch-environment setUp is duplicated in exactly 2 files (test_about_page.py:86-108 ≈ test_settings_feedback.py:24-46), not 5 — the census overcounts by 2.5×; launcher.main_gui() does not exist and the claimed directlink helper is an import block. The 9-fold Tk guard sub-claim holds exactly)',
 'X-07': 'REVISED (full verification — WEAKENED: the PS2-Servers half (three UDPFS editions) and Launchstation’s precompiled IRX stand, but the RiptOPL headline falls — the per-edition udpfs_core.c/udprdma.c are 122–125 B #include shims into udpfs_shared, not copies (the round-2 correction to RIPTOPL-008); what is triplicated is the header set (6 headers ×3; mprintf.h ×5). Survives as header triplication + three server editions + one precompiled IRX. Was a pass-1 cross-reference (CROSS-REF) until this pass)',
 'X-21': 'REVISED (full verification — WEAKENED: every named streaming copy path and all four SMS sub-defects confirm, but “in every path” is falsified by SMS’s _copy_file_to_mc (GUIFileCtxMenu.c:143-196), a buffered import path that deletes the destination on write failure — survives for every streaming path; the fix’s scope shrinks by one path that already behaves)',
 'X-45': 'REVISED (full verification — WEAKENED: PS2-Servers’ auto-tag pruning and POPSLoader’s hard-coded “1.4.4” release workflow verify fully, but the SMS half falls in part — the destructive rolling-tag race is already mitigated in-tree at the pin (in-place update, per-family concurrency groups, converter retry-wait), so the prescribed single-writer fix is largely obsolete; survives as a two-repo finding)',
 'X-54': 'REVISED (full verification — WEAKENED: 19/19 .irx.xz payloads decompress byte-identical to the plain .irx copies (286,561 B exact) and build/CI consume only the .xz forms, but “nothing reads them” falls — tools/compress_irx.py reads every plain .irx as the regeneration path. The dead-duplication defect and the deletion fix stand, narrowed from “unreferenced” to “no build-time consumer; they are regeneration inputs”)',
}
WITHDRAWN = {'LAUNCHSTATION-065': 'WITHDRAWN (R4 R4-R2 — refuted)',
 'RIPTOPL-513': 'WITHDRAWN (verification phase 2026-11-14 — REFUTED: defect absent; the prescribed fix is an identity transformation)',
 'RIPTOPL-443': 'WITHDRAWN (verification phase 2026-11-14 — REFUTED: claimed trigger defeated by the sole guarded caller; latent-only)',
 'SMS-015': 'WITHDRAWN (verification phase 2026-11-14 — REFUTED: its own proposed fix already exists at the pin — the _tbl_fits guard)',
 # ---- Full verification phase (2026-11-14): 14 REFUTED verdicts become WITHDRAWN ----
 'RIPTOPL-051': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: size is u32, so size <= 0 is a live == 0 exit at mcemu.c:845,896)',
 'RIPTOPL-348': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: test_ra_ps1.py:137 generates the raVcdBootName calls into a compiled, executed harness)',
 'LAUNCHSTATION-100': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: usmb2_readdir sits inside the never-defined USMB2_FEATURE_OPENDIR with zero callers; the live smb2man.c directory path clamps)',
 'LAUNCHSTATION-127': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: the escape helpers fail rather than truncate and the checked bounds cap every input below every destination — truncation arithmetically unreachable)',
 'LAUNCHSTATION-214': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: shouldHideHddAtaDevices exists (main_startup.c:746-756) and is consumed; README.md:181 is substantively correct)',
 'X-57': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: POPSLoader PROVENANCE.json records both .udpfs files — headline false as filed; residue filed as X-59)',
 'PS2SERVERS-104': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin)',
 'PS2SERVERS-105': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin)',
 'PS2SERVERS-109': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin)',
 'PS2SERVERS-110': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin)',
 'PS2SERVERS-111': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin)',
 'SMS-013': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: the video-ring allocation already sits inside the video-stream branch at SMS_Player.c:1716-1741)',
 'SMS-089': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED: the preflight walk returns at SOF0/SOS before entropy data; DRI is length-bearing and walked correctly)',
 'SMS-123': 'WITHDRAWN (full verification phase 2026-11-14 — REFUTED as a live defect: the Huffman segments tile exactly; max reachable offset = last valid index on all 7 codebooks. Three-step history in §4: withdrawn in-text at filing, reopened in verification phase 1 (VERIFY-C3, rationale falsified), refuted on reachability in phase 2; the SMS-160 bounds-pairing survives as fix guidance)'}
# ---- Verification phase: duplicate retirements (consistency census §1) ----
# The later filing becomes a cross-reference to the canonical earlier finding.
CROSSREF = {
 'RIPTOPL-344': 'CROSS-REF (→ RIPTOPL-158 — full duplicate, census D-1; verification phase 2026-11-14)',
 'RIPTOPL-468': 'CROSS-REF (→ RIPTOPL-093 — full duplicate, census D-2)',
 'RIPTOPL-454': 'CROSS-REF (→ RIPTOPL-045 — full duplicate, census D-3)',
 'RIPTOPL-411': 'CROSS-REF (→ RIPTOPL-086 — full duplicate, census D-4)',
 'RIPTOPL-455': 'CROSS-REF (→ RIPTOPL-208 — full duplicate, census D-5)',
 'RIPTOPL-444': 'CROSS-REF (→ RIPTOPL-085 — full duplicate, census D-6)',
 'RIPTOPL-405': 'CROSS-REF (→ RIPTOPL-149 — full duplicate, census D-7)',
 'RIPTOPL-416': 'CROSS-REF (→ RIPTOPL-169 — full duplicate, census D-8)',
 'RIPTOPL-501': 'CROSS-REF (→ RIPTOPL-006 — full duplicate, census D-9)',
 'RIPTOPL-408': 'CROSS-REF (→ RIPTOPL-163 — partial duplicate merged, census D-10)',
 'RIPTOPL-445': 'CROSS-REF (→ RIPTOPL-040 — partial duplicate merged, census D-11)',
 'X-17': 'CROSS-REF (→ LAUNCHSTATION-041 — same-round core duplicate, census D-13)',
 'X-23': 'CROSS-REF (→ PS2SERVERS-014 — revalidation converted to cross-reference, census D-15)',
}
for fid, r in results.items():
    if fid in WITHDRAWN: r['status'] = WITHDRAWN[fid]
    elif fid in REVISED: r['status'] = REVISED[fid]
    elif fid in CROSSREF: r['status'] = CROSSREF[fid]
    elif re.match(r'X-(0[1-9]|1[0-6])$', fid): r['status'] = 'CROSS-REF'
    else: r['status'] = 'STANDING'

with open(os.path.join(BASE, 'index-scratch.tsv'), 'w', encoding='utf-8') as f:
    for fid in order:
        r = results[fid]
        f.write('\t'.join([r['id'], r['repo'], r['title'], r['cat'], r['effort'], r['risk'], r['conf'], r['status'], r['src']]) + '\n')

print("TOTAL:", len(results), dict(Counter(r['repo'] for r in results.values())))
miss = [(r['id'], r['cat'], r['effort'], r['risk'], r['conf']) for r in results.values()
        if '—' in (r['cat'], r['effort'], r['risk'], r['conf'])]
print("MISSING-FIELD ROWS:", len(miss))
for m in miss: print("  ", m)
SC = re.compile(r'^(XS|S|Trivial|One character|One token|One line|~?\d+ lines?)$')
qw = [r for r in results.values() if r['status'] == 'STANDING' and SC.match(r['effort']) and r['risk'] == 'Low']
print("QUICK WINS (STANDING, S-class effort, Risk Low):", len(qw))
for r in sorted(qw, key=lambda x: (x['repo'], x['id'])): print("  QW", r['repo'], r['id'], "| cat", r['cat'], "| eff", r['effort'])
