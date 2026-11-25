#!/usr/bin/env python3
"""Assemble Redo-MASTER-INDEX.md from the six reconciliation extraction files.
Parse-only sanity output by default; pass --write to emit the index."""
import re, sys, collections, pathlib

BASE = pathlib.Path.home() / "workspace/Sable-audit-redo"
REC = BASE / "reconciliation"

REPOS = [
    # (extraction file, display name, verify file, id prefix)
    ("RiptOPL.md", "RiptOPL", "Redo-VERIFY-RiptOPL.md"),
    ("Launchstation.md", "Launchstation", "Redo-VERIFY-Launchstation.md"),
    ("POPSLoader.md", "POPSLoader", "Redo-VERIFY-POPSLoader.md"),
    ("SMS.md", "SMS (Simple-Media-System)", "Redo-VERIFY-SMS.md"),
    ("PS2Servers.md", "PS2-Servers", "Redo-VERIFY-PS2Servers.md"),
    ("Cross.md", "Cross-repo", "Redo-VERIFY-Cross.md"),
]

STATUS = {"VERIFIED": "STANDING", "VERIFIED-DRIFT": "STANDING-DRIFT",
          "WEAKENED": "REVISED", "REFUTED": "WITHDRAWN", "BLOCKED-ENV": "BLOCKED-ENV"}

NEW_BASE = {"RiptOPL": ("RE-RIPTOPL-", 266), "Launchstation": ("RE-LAUNCH-", 93),
            "POPSLoader": ("RE-POPS-", 116), "SMS": ("RE-SMS-", 145),
            "PS2Servers": ("RE-SERV-", 217), "Cross": ("RE-X-", 32)}

def fmt_new_id(key, n):
    prefix = NEW_BASE[key][0]
    if key in ("RiptOPL", "Launchstation", "POPSLoader", "SMS", "PS2Servers"):
        return f"{prefix}{n:03d}"
    return f"{prefix}{n}"

def sections(text):
    """Split on '## ' headings -> {heading: body}"""
    out, cur, buf = {}, None, []
    for line in text.splitlines():
        if line.startswith("## "):
            if cur: out[cur] = "\n".join(buf)
            cur, buf = line[3:].strip(), []
        elif cur: buf.append(line)
    if cur: out[cur] = "\n".join(buf)
    return out

def bullets(body):
    """Parse '- RE-XXX: text' bullets (with continuation lines)."""
    res, cur_id, cur_txt = {}, None, []
    for line in body.splitlines():
        m = re.match(r"- (RE-[A-Z]+-?\d+)( \(sub-claim\))?: (.*)", line)
        if m:
            if cur_id: res[cur_id] = " ".join(cur_txt).strip()
            cur_id, cur_txt = m.group(1), [m.group(3)]
        elif cur_id and line.strip() and not line.startswith("#"):
            cur_txt.append(line.strip())
    if cur_id: res[cur_id] = " ".join(cur_txt).strip()
    return res

def parse_candidates(body):
    cands = []
    for block in re.split(r"^### ", body, flags=re.M)[1:]:
        lines = block.splitlines()
        head = lines[0].strip()  # e.g. "CAND-01"
        fields = {}
        cur = None
        for line in lines[1:]:
            m = re.match(r"- (Label|Mechanism|Locations|Proposed class|Justification): (.*)", line)
            if m: cur = m.group(1); fields[cur] = m.group(2)
            elif cur and line.strip() and not line.startswith("#"):
                fields[cur] += " " + line.strip()
        cands.append({"head": head, **fields})
    return cands

data = {}          # repo key -> dict
all_rows = {}      # ID -> row dict
extensions = collections.defaultdict(list)  # parent ID -> [note strings]
screening = {}     # repo key -> [candidate dicts with class resolved]
new_assign = {}    # (repo, cand head) -> new ID

for fname, disp, vfile in REPOS:
    key = fname[:-3]
    text = (REC / fname).read_text()
    sec = sections(text)
    rows = []
    for line in sec.get("Verdicts", "").splitlines():
        if not line.startswith("| RE-"): continue
        cells = [c.strip() for c in line.split("|")]
        # cells: ['', ID, Title..., Effort, Risk, Verdict, '']
        fid, verdict = cells[1], cells[-2]
        effort, risk = cells[-4], cells[-3]
        title = " | ".join(cells[2:-4])
        rows.append({"id": fid, "title": title, "effort": effort, "risk": risk,
                     "verdict": verdict, "status": STATUS[verdict], "repo": key,
                     "disp": disp, "vfile": vfile})
        all_rows[fid] = rows[-1]
    narrowed = bullets(sec.get("Narrowed scopes", ""))
    defeated = bullets(sec.get("Defeating evidence", ""))
    cands = parse_candidates(sec.get("Candidates", ""))
    data[key] = {"rows": rows, "narrowed": narrowed, "defeated": defeated,
                 "cands": cands, "disp": disp, "vfile": vfile}
    # resolve candidate classes
    prefix, nxt = NEW_BASE[key]
    for c in cands:
        cls = c.get("Proposed class", "").strip()
        if cls.startswith("NEW"):
            nid = fmt_new_id(key, nxt); nxt += 1
            c["class"], c["target"] = "NEW", nid
            new_assign[(key, c["head"])] = nid
        elif cls.startswith("EXTENSION"):
            m = re.search(r"(RE-[A-Z]+-?\d+)", cls)
            c["class"], c["target"] = "EXTENSION", m.group(1) if m else "?"
            extensions[c["target"]].append((key, c))
        elif cls.startswith("REJECTED"):
            c["class"], c["target"] = "REJECTED", ""
        else:
            c["class"], c["target"] = "UNPARSED:" + cls, ""
    screening[key] = cands

# ---------- sanity report ----------
tot_v = collections.Counter(); tot_s = collections.Counter()
eff_dist, risk_dist = collections.Counter(), collections.Counter()
for key, d in data.items():
    c = collections.Counter(r["verdict"] for r in d["rows"])
    tot_v.update(c)
    tot_s.update(collections.Counter(r["status"] for r in d["rows"]))
    eff_dist.update(r["effort"] for r in d["rows"]); risk_dist.update(r["risk"] for r in d["rows"])
    print(f"{key}: rows={len(d['rows'])} verdicts={dict(c)} narrowed={len(d['narrowed'])} defeated={len(d['defeated'])} cands={len(d['cands'])}")
print("TOTAL verdicts:", dict(tot_v), "sum:", sum(tot_v.values()))
print("TOTAL statuses:", dict(tot_s))
print("Effort values:", dict(eff_dist)); print("Risk values:", dict(risk_dist))
cls_tot = collections.Counter(c["class"] for cs in screening.values() for c in cs)
print("Candidate classes:", dict(cls_tot), "sum:", sum(cls_tot.values()))
print("New assignments:", new_assign)
qw = [r for r in all_rows.values() if r["status"] in ("STANDING", "STANDING-DRIFT", "REVISED")
      and r["effort"] == "S" and r["risk"] == "Low"]
print("Quick wins (S+Low among STANDING/STANDING-DRIFT/REVISED):", len(qw))
for key, d in data.items():
    for fid, txt in d["defeated"].items():
        print(f"DEFEATED {fid}: {txt}")
# consistency: narrowed keys == WEAKENED ids, defeated keys == REFUTED ids
for key, d in data.items():
    wk = {r["id"] for r in d["rows"] if r["verdict"] == "WEAKENED"}
    rf = {r["id"] for r in d["rows"] if r["verdict"] == "REFUTED"}
    assert wk == set(d["narrowed"]), (key, wk ^ set(d["narrowed"]))
    assert rf <= set(d["defeated"]), (key, rf - set(d["defeated"]))
print("Consistency checks passed.")

if "--write" not in sys.argv:
    sys.exit(0)

# ---------- build index ----------
out = []
out.append("# Redo Audit — Master Index (post-verification status ledger)")
out.append("")
out.append("Stage C reconciliation of the blind redo audit. Every one of the 863 redo findings, "
           "with its final status after the Stage B adversarial verification. Statuses:")
out.append("")
out.append("- **STANDING** — verification verdict VERIFIED; the finding stands exactly as filed in its redo report.")
out.append("- **STANDING-DRIFT** — verdict VERIFIED-DRIFT; the mechanism and fix stand, but citations or figures were corrected during verification. **The corrected values live in the verify report named in the row's note and supersede the redo report's numbers** — finding bodies were not rewritten.")
out.append("- **REVISED** — verdict WEAKENED; the defect is real but narrower than filed. The row's note states the narrowed true scope, which supersedes the filed scope.")
out.append("- **WITHDRAWN** — verdict REFUTED; the row's note states the defeating evidence. A matching WITHDRAWN note was added under the finding's heading in its redo report.")
out.append("- **NEW** — a distinct defect found by the Stage B verifiers (candidate screening class (a)); the full finding text is in `Redo-NEW-FINDINGS.md`.")
out.append("")
out.append("Fix-scope extensions (candidate screening class (b)) are recorded in the parent finding's note; "
           "they add locations/instances to an existing fix and carry no number of their own. "
           "Rejected candidates (class (c)) are listed with reasons in Appendix A. "
           "Pins: RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`, "
           "SMS `e65ced39a27e`, PS2-Servers `c5f021c4d386`. Nothing under `~/workspace/Sable-audit/` was read at any stage.")
out.append("")

for fname, disp, vfile in REPOS:
    key = fname[:-3]; d = data[key]
    out.append(f"## {disp}")
    out.append("")
    out.append("| ID | Title | Effort | Risk | Status | Note |")
    out.append("|---|---|---|---|---|---|")
    for r in d["rows"]:
        notes = []
        if r["status"] == "STANDING-DRIFT":
            notes.append(f"Mechanism stands; corrected citations/values in `{vfile}` supersede the filed ones.")
            if r["id"] == "RE-X-23":
                notes.append("One sub-claim refuted: the claimed second copy in `iop/hdl_info/apa.c` does not contain the error-sector pair (grep = 0 hits; it is a different malloc-based parser) — fix scope is the single `ps2hdd_osd` copy.")
        elif r["status"] == "REVISED":
            notes.append("Narrowed scope: " + d["narrowed"][r["id"]])
        elif r["status"] == "WITHDRAWN":
            notes.append("Defeating evidence: " + d["defeated"][r["id"]])
        for (ckey, c) in extensions.get(r["id"], []):
            notes.append(f"Fix-scope extension (Stage B, {ckey} {c['head']}): {c.get('Label','')}")
        note = " ".join(notes) if notes else "—"
        note = note.replace("|", "\\|")
        title = r["title"].replace("|", "\\|")
        out.append(f"| {r['id']} | {title} | {r['effort']} | {r['risk']} | {r['status']} | {note} |")
    # new findings for this repo
    news = [(c, new_assign[(key, c["head"])]) for c in screening[key] if c["class"] == "NEW"]
    if news:
        out.append("")
        out.append(f"### New findings — {disp} (Stage C, from Stage B candidates)")
        out.append("")
        out.append("| ID | Title | Status | Note |")
        out.append("|---|---|---|---|")
        for c, nid in news:
            lbl = c.get("Label", "").replace("|", "\\|")
            out.append(f"| {nid} | {lbl} | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `{vfile}`, {c['head']}). |")
    out.append("")

# Cross-repo new finding (RE-X-32) is under Cross above. Appendix A: screening.
out.append("## Appendix A — Candidate screening (all Stage B candidates)")
out.append("")
out.append("Every candidate recorded in the six verify reports, classified exactly once: "
           "NEW = numbered as a new finding in `Redo-NEW-FINDINGS.md`; EXTENSION = recorded in the parent finding's row above; "
           "REJECTED = not numbered, reason stated.")
out.append("")
for fname, disp, vfile in REPOS:
    key = fname[:-3]
    out.append(f"### {disp}")
    out.append("")
    out.append("| Candidate | Class | Parent / New ID | Reason |")
    out.append("|---|---|---|---|")
    for c in screening[key]:
        lbl = (c.get("Label", "") or c["head"]).replace("|", "\\|")
        just = c.get("Justification", "").replace("|", "\\|")
        tgt = c["target"] if c["class"] != "REJECTED" else "—"
        out.append(f"| {c['head']} — {lbl} | {c['class']} | {tgt} | {just} |")
    out.append("")

(BASE / "Redo-MASTER-INDEX.md").write_text("\n".join(out) + "\n")
print("WROTE Redo-MASTER-INDEX.md")
