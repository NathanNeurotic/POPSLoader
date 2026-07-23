#!/usr/bin/env python3
"""Mechanically verify documentation claims against the actual source.

WHY THIS EXISTS
---------------
The 2026-07 docs overhaul used one fixer agent per document and they silently
skipped individual bullets -- the docs looked reviewed and were still wrong. Prose
review does not catch a settings-key count being off by one, or a phrase describing
a feature that was deleted three builds ago.

Everything here is checkable without judgement: counts, key lists, version stamps,
and phrases that must no longer describe current behaviour. It deliberately does NOT
try to review wording -- that is what a human is for.

Run:  python3 tools/docs_verify.py            (from the repo root)
Exit: 0 = clean, 1 = at least one FAIL.
"""

import os
import re
import sys

# Doc lines contain PS2 button glyphs; Windows consoles default to cp1252 and a
# findings dump must never die on the character it is reporting.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

failures = []
notes = []


def read(rel):
    path = os.path.join(REPO, rel)
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def fail(check, detail):
    failures.append((check, detail))


def note(check, detail):
    notes.append((check, detail))


# ---------------------------------------------------------------------------
# 1. Persisted settings keys: docs must not disagree with EncodeSettings.
#
# EncodeSettings in system.lua is the single source of truth for what actually
# lands in the .pldrs sidecar. Docs quote both a COUNT and a LIST, and both drift.
# ---------------------------------------------------------------------------
def check_settings_keys():
    sysl = read("bin/POPSLDR/system.lua")
    if sysl is None:
        fail("settings-keys", "bin/POPSLDR/system.lua not found")
        return

    m = re.search(r"local function EncodeSettings\(\)(.*?)\n\bend\b", sysl, re.S)
    if not m:
        fail("settings-keys", "could not locate EncodeSettings() in system.lua")
        return

    keys = re.findall(r'"([A-Z][A-Z0-9_]*)="\s*\.\.', m.group(1))
    # Only the SMB CONNECTION block is out of scope -- it is appended separately by
    # SmbAppendLines. SMB_MODULES is written by EncodeSettings itself and IS counted in
    # the docs, so excluding it made a stale count compare equal (a false negative that
    # hid exactly the drift this check exists to catch).
    keys = [k for k in keys if k == "SMB_MODULES" or not k.startswith("SMB_")]
    actual = len(keys)
    note("settings-keys", "EncodeSettings writes %d keys: %s" % (actual, ", ".join(keys)))

    for rel in ("STATE.md", "COMPONENTS.md", "ARCHITECTURE.md", "README.md"):
        txt = read(rel)
        if txt is None:
            continue
        for cm in re.finditer(r"\*\*(\d+)\s+keys\*\*", txt):
            claimed = int(cm.group(1))
            if claimed != actual:
                fail("settings-keys",
                     "%s claims **%d keys** but EncodeSettings writes %d" % (rel, claimed, actual))
        # A doc listing a key that no longer exists is worse than a wrong count.
        for km in re.finditer(r"`([A-Z][A-Z0-9_]{3,})`", txt):
            k = km.group(1)
            if k.endswith("_PATH") or k.startswith("SMB"):
                continue
            if k in ("PLDR", "POPS", "VCD", "ELF", "IOP", "APA", "PFS", "BDM",
                     "MC", "USB", "ATA", "HDD", "ART", "COV", "EXP", "NEW",
                     "README", "STATE", "TODO", "NOTE", "CI"):
                continue
            looks_like_setting = re.search(r"\b%s\s*=" % re.escape(k), sysl) is not None
            if looks_like_setting and k not in keys and ("PLDR." + k) not in sysl:
                note("settings-keys", "%s mentions `%s` which is not a persisted key" % (rel, k))


# ---------------------------------------------------------------------------
# 2. Phrases describing behaviour that no longer exists.
#
# Each entry: (phrase, why it must not appear, files that may legitimately keep it).
# Dated logs and archives are exempt -- a historical record SHOULD name a removed
# feature. Only docs that describe CURRENT behaviour are checked.
# ---------------------------------------------------------------------------
REMOVED_BEHAVIOUR = [
    ("No cover. Looked for",
     "the missing-cover caption was removed (EXP42)"),
    ("Square still toggles cover art",
     "Square no longer toggles cover art; it is a saved setting (EXP42)"),
    ("Square (□)** | Toggle cover-art preview",
     "the Square cover-art binding was removed (EXP42)"),
]

# These describe history, not current behaviour.
HISTORY_FILES = ("DECISIONS.md", "ROLLING_NOTES.md", "EXPERIMENTAL_NOTES.md",
                 "QA_REGRESSION_MATRIX.md")


def check_removed_behaviour():
    for rel in ("README.md", "STATE.md", "ARCHITECTURE.md", "COMPONENTS.md",
                "TESTING.md", "AGENTS.md", "CONTRIBUTING.md", "ROADMAP.md"):
        txt = read(rel)
        if txt is None:
            continue
        for phrase, why in REMOVED_BEHAVIOUR:
            for i, line in enumerate(txt.split("\n"), 1):
                if phrase in line:
                    # A line that explicitly marks it as removed/historical is fine.
                    low = line.lower()
                    if any(w in low for w in ("removed", "no longer", "was ", "used to",
                                              "gone", "deleted", "superseded")):
                        continue
                    fail("removed-behaviour",
                         "%s:%d still presents removed behaviour as current -- %s\n      %s"
                         % (rel, i, why, line.strip()[:120]))


# ---------------------------------------------------------------------------
# 3. Version stamps must agree with each other.
# ---------------------------------------------------------------------------
def check_version_stamps():
    cfg = read("bin/POPSLDR/title.cfg") or ""
    boot = read("etc/boot.lua") or ""
    notes_md = read("EXPERIMENTAL_NOTES.md") or ""

    cfgv = re.search(r"^Version=(\S+)", cfg, re.M)
    bootv = re.search(r'POPSLDR_VER\s*=\s*"v?([^"]+)"', boot)
    if not cfgv or not bootv:
        fail("version", "could not read the version stamp from title.cfg and/or etc/boot.lua")
        return
    if cfgv.group(1) != bootv.group(1):
        fail("version", "title.cfg says %s but etc/boot.lua says %s"
             % (cfgv.group(1), bootv.group(1)))
    build = cfgv.group(1)
    note("version", "build stamp is %s" % build)

    # The release notes tell testers which version to look for; a stale number there
    # is how a tester ends up reporting against the wrong build (this happened).
    claimed = set(re.findall(r"v1\.1\.1-dev-(EXP\d+)", notes_md))
    cur = re.search(r"(EXP\d+)", build)
    if cur and claimed and cur.group(1) not in claimed:
        fail("version", "EXPERIMENTAL_NOTES.md never mentions the current build %s" % build)
    if cur:
        head = "\n".join(notes_md.split("\n")[:12])
        stale = [e for e in re.findall(r"\*\*-?(EXP\d+)\*\*", head) if e != cur.group(1)]
        older = [e for e in stale if int(e[3:]) < int(cur.group(1)[3:]) - 1]
        if older:
            fail("version",
                 "EXPERIMENTAL_NOTES.md header still points testers at %s (build is %s)"
                 % (", ".join(sorted(set(older))), cur.group(1)))


# ---------------------------------------------------------------------------
# 4. Harness test count quoted in docs must match reality.
# ---------------------------------------------------------------------------
def check_harness_count():
    h = read("tools/host_harness.py")
    if h is None:
        fail("harness-count", "tools/host_harness.py not found")
        return
    actual = len(re.findall(r'^check\(', h, re.M))
    note("harness-count", "host_harness.py has %d check() calls" % actual)
    for rel in ("STATE.md", "AGENTS.md", "CONTRIBUTING.md", "TESTING.md"):
        txt = read(rel)
        if txt is None:
            continue
        for m in re.finditer(r"\*\*(\d+)/(\d+)\*\*", txt):
            a, b = int(m.group(1)), int(m.group(2))
            if a == b and abs(a - actual) > 1:
                fail("harness-count",
                     "%s claims **%d/%d** harness tests but there are %d" % (rel, a, b, actual))


# ---------------------------------------------------------------------------
# 5. Cover-art layout must be stated consistently wherever it appears.
# ---------------------------------------------------------------------------
def check_cover_layout():
    ui = read("bin/POPSLDR/ui.lua") or ""
    if '"ART/"' not in ui:
        note("cover-layout", "could not find the ART/ join in ui.lua; skipping")
        return
    if re.search(r'string\.match\(dir,\s*"\^\(%a\+%d\*:/\)"\)', ui):
        fail("cover-layout",
             "ui.lua still uses the %a+%d*: device prefix, which cannot match mx4sio0: "
             "(EXP56 replaced it with %w+:/)")
    for rel in ("README.md", "STATE.md", "ARCHITECTURE.md", "COMPONENTS.md"):
        txt = read(rel)
        if txt is None:
            continue
        if "POPS/ART/" in txt and "__common" not in txt.split("POPS/ART/")[0][-200:]:
            note("cover-layout",
                 "%s mentions POPS/ART/ -- verify it is the APA exception, not the "
                 "removable layout (removable is device:/ART/)" % rel)


for fn in (check_settings_keys, check_removed_behaviour, check_version_stamps,
           check_harness_count, check_cover_layout):
    try:
        fn()
    except Exception as exc:  # a broken check must not mask the others
        fail(fn.__name__, "check itself errored: %r" % exc)

print("=== docs_verify ===")
for c, d in notes:
    print("  note [%s] %s" % (c, d))
if failures:
    print()
    for c, d in failures:
        print("FAIL [%s] %s" % (c, d))
    print("\n%d FAILURE(S)" % len(failures))
    sys.exit(1)
print("\nOK -- no mechanical doc/source mismatches")
sys.exit(0)
