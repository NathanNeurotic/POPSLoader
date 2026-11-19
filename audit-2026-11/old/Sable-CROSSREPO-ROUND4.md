# Sable Audit — ROUND 4: CROSS-REPO — build / CI / release machinery

- **Auditor:** Sable
- **Date:** 2026-11-14
- **Mode:** READ ONLY. No clone was updated, edited or pushed; all five verified `git status` clean at the end, HEADs at the pins below.
- **Relation to earlier rounds:** This file covers the layer rounds 1–3 did not compare: CI workflows, toolchain pins, release/tag machinery, the docs-palette fan-out (Task 2), and vendored-component versions beyond round 2's crypto scope (Task 3). It does **not** repeat X-01…X-40 or any per-repo finding; where a mechanism explains an earlier count (X-03's tags, X-15's workflow sprawl), the earlier ID is referenced, not re-filed. New findings start at **X-41**.
- **Rule:** LESS, NOT MORE — including about CI itself: several verdicts below are "leave it, with a sync rule", because the consolidation vehicle (a shared CI repo, a sync bot) would be a sixth thing to maintain.
- **Confidence labels:** READ = cited lines/commits were read at the pin. INFERRED = composed from READ facts, with the composition shown.

## Freshness header (required by the brief)

`git ls-remote origin HEAD` was run for all five repos at the start of this round. **Every live head exactly matches its round-3 pin — no repo has moved:**

| Repo | Live HEAD = pin | Branch |
|---|---|---|
| RiptOPL | `2e347d5ac885cd0ff73e9ad4143781946396f492` | rebuild/main |
| Launchstation | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` | master |
| POPSLoader | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` | master |
| Simple-Media-System | `e65ced39a27eee8d996e9257e21594d1cac1c93d` | master |
| PS2-Servers | `c5f021c4d38698860f56b03498adc261dbb8d8dd` | main |

One staleness note of a different kind (Task 2): the docs-palette fan-out **is** present in RiptOPL's and POPSLoader's repos but landed on `gh-pages` (RiptOPL) and `dev` (POPSLoader), not on the audited branches — verified by `merge-base --is-ancestor` (see §2).

**Headline result:** the CI layer repeats the code layer's pattern exactly. Two repos (RiptOPL, Launchstation) build with the *same* pinned SDK through a **hand-copied 1,370-line machinery** whose pins are byte-identical and whose code differs by a User-Agent string. The other three repos pin the same upstream toolchain three different ways (digest-pinned v1.0, mutable v2.0.0 tag, digest-only ghcr ref). The family's most-used action, `actions/checkout`, is pinned at **six different generations**, including three inside one repo. And the one time a design change had to reach all five docs sites (Task 2), it cost **15 PRs in three same-minute waves**, because four of the sites are copies of one design with no shared source. Against that, two genuine positives: mbedTLS is version-aligned (3.6.7) in both its consumers, and PS2-Servers is the only repo whose release machinery *cleans up after itself*.

---

# TASK 1 — Workflow census and comparisons

## 1.0 The census: 41 workflow files, 8,512 lines

Triggers abbreviated: P = push, PR = pull_request, S = schedule, D = workflow_dispatch, R = release event, C = workflow_call. "Toolchain pin" names only what decides reproducibility.

### RiptOPL (12 files, 2,222 lines) — ps2build SDK (`.github/ps2build-sdk.env`, weekly-bumped)

| File | Lines | Triggers | Builds / checks | Pin of note |
|---|---|---|---|---|
| ps2build.yml | 102 | P, PR, D | Compiler validation build (Korium/RA/IncebtIon channels), `claude/**` branches included | SDK env pins (shared with Launchstation, §1.1) |
| flavours.yml | 495 | P, PR, D | Full flavour matrix build; runs the host test suite (158 test-step lines); rebuilds checked-in POPSTARTER driver binaries and requires the checked-in copies to match | `ghcr.io/ps2dev/ps2dev@sha256:8fba50e…` for one job (flavours.yml:365) |
| configurations.yml | 107 | P, PR, D | Configuration matrix validation | setup-python @v6 tag, Python 3.12 |
| rolling-release.yml | 225 | P, PR, R, D | GCC rolling release publish | channel named by shared script `.github/scripts/release_channel.sh` |
| rolling-llvm.yml | 245 | P, PR, D | LLVM rolling release publish | same release_channel.sh; setup-python SHA `ece7cb0…` (# v6) |
| check-format.yml | 37 | P, PR (paths: `**.c/.h` only) | **clang-format gate** — the only one in the family (§1.3) | DoozyX/clang-format-lint-action @v0.18.2, clangFormatVersion 12 |
| ps2build-sdk-watch.yml | 279 | S, D | Weekly: detect newer ps2build SDK, cache it, open bump PR | twin of Launchstation's (§1.1) |
| ember-watch.yml | 222 | S, D | Watch upstream Ember, re-dispatch releases | POPSLoader has a 157-line speciated twin |
| neutrino-watch.yml | 75 | S, R, D | Watch upstream Neutrino (~10-day ticks), re-dispatch rolling releases | Launchstation twin: 83 lines, same ticks (its comment says so) |
| orbit-neutrino-watch.yml | 88 | S, D | Watch ORBIT Neutrino RA fork | no counterpart |
| docs-sync.yml | 222 | P, R, S, D | "Sync Project Links & Badges" — docs site maintenance | — |
| wiki-publish.yml | 125 | P, S, D, workflow_run | Rebuild GitHub wiki from rebuild/main + gh-pages | scripted twin: `.github/scripts/wiki_sync.py` + tests (§1.4) |

### Launchstation (6 files, 1,314 lines) — ps2build SDK (same env pins)

| File | Lines | Triggers | Builds / checks | Pin of note |
|---|---|---|---|---|
| compile.yml | 812 | P, PR, D | The build: ps2build SDK resolve/cache/install, host tests inside the job (the 212-test corpus is LAUNCHSTATION-009, not re-filed), kit assembly, `latest` release publish with ancestry guard (compile.yml:538,592-595) | checkout @v4 ×6 + one stray SHA |
| ps2build-sdk-watch.yml | 245 | S, D | Weekly SDK bump PR — twin of RiptOPL's 279-line version (144 diff lines) | §1.1 |
| neutrino-watch.yml | 83 | S, D | Neutrino watch, ticks copied from RiptOPL's ("Same ticks as RiptOPL's Neutrino Watch", its own comment) | — |
| docs-pages.yml | 70 | P, D | Build docs site (`docs-site/build.py`, docs-pages.yml:38) and publish | — |
| sync-wiki.yml | 72 | P, D | Clone `.wiki.git`, copy, push (sync-wiki.yml:43) | §1.4 |
| download-metrics.yml | 32 | S, D | Download counter (LAUNCHSTATION-027, not re-filed) | — |

### POPSLoader (10 files, 2,062 lines) — ps2dev container image

| File | Lines | Triggers | Builds / checks | Pin of note |
|---|---|---|---|---|
| compilation.yml | 253 | P, PR, D, repository_dispatch | Build + the family's best host-test gate: png harness, `host_harness.py`, `pad_harness.py`, `test_disc_layout.py`, docs_verify, translation-handoff unittest (compilation.yml:33-57) | container `ps2dev/ps2dev:v2.0.0` — **mutable tag** (compilation.yml:62-68) |
| rolling-release.yml | 576 | P, PR, R, D | Rolling release build + publish | same v2.0.0 container (:62-63) |
| experimental-release.yml | 501 | P, R, D | Experimental channel build + publish | same v2.0.0 container (:58-59) |
| official-release.yml | 131 | R, workflow_run | **Version-named release workflow**: name, concurrency group and verify-greps all hard-code 1.4.4 (official-release.yml:1,17,47-49) | §1.4 |
| docs-site.yml | 165 | P, PR, D | Docs site build/publish | — |
| research-network-driver-integrity.yml | 114 | PR, D | Byte-verification of the historical network archive (the CI-wired research scripts of REV-016) | — |
| ember-watch.yml | 157 | S, D | Ember watch | speciated twin of RiptOPL's 222-line version (307 diff lines) |
| wiki-sync.yml | 93 | P, D | Clone `.wiki.git`, copy, push (wiki-sync.yml:58) | §1.4 |
| opencode.yml | 32 | PR | AI comment bot (POPSLOADER-013, not re-filed) | `anomalyco/opencode/github@latest` — the family's only `@latest` action pin |
| retract-mislabeled-ember-beta.yml | 40 | P | Spent one-shot (POPSLOADER-012, not re-filed) | — |

### Simple-Media-System (6 files, 828 lines) — ps2dev container image, docker-run style

| File | Lines | Triggers | Builds / checks | Pin of note |
|---|---|---|---|---|
| compilation.yml | 308 | P, PR, D | Builds via `docker run ps2dev/ps2dev:v1.0@sha256:da02eb0…` (compilation.yml:27,134,174); host gates: rolling-release test, devmenu checks, language packs, stream tests (:59-67); publishes the moving `rolling` release | **digest-pinned v1.0** |
| sms-converter.yml | 327 | P, PR, D | PC-side converter tool build/test | — |
| smbman.yml | 48 | P, PR, D | smbman source-consistency + regression tests (smbman.yml:24) in the same v1.0 digest image (:31) | — |
| test-media.yml | 46 | P, R, D | Generated-media playback tests | — |
| docs.yml | 27 | P, PR, D | Docs build **check** gate: `docs-site/build.py --check` (docs.yml:16) | — |
| wiki.yml | 72 | P, D | Wiki copy via `docs-site/sync_wiki.py` (wiki.yml:3,54) | §1.4 |

### PS2-Servers (7 files, 2,086 lines) — no PS2 toolchain; Python + Go

| File | Lines | Triggers | Builds / checks | Pin of note |
|---|---|---|---|---|
| ci.yml | 152 | P, PR | Python unittest suites (ci.yml:39,50,97,149); Go via go-version-file (ci.yml:71-73) | setup-python SHA `6d4fd22…` (# v7.1.0), Python 3.12 |
| edge.yml | 254 | P, PR | Edge: `go test -race ./... -count=2` (edge.yml:56), CHD-tagged tests (:82), UDPFS negotiation tests | go-version-file in most jobs, **one hard-coded `go-version: "1.25"`** (edge.yml:196-199) — PS2SERVERS-054's intra-repo drift, referenced not re-filed |
| edge-build.yml | 466 | **C only** | **Reusable workflow** (`workflow_call`) building all Edge binaries — the family's only reusable workflow | setup-go SHA, go-version-file (:226-228) |
| release.yml | 606 | P (tags `v*`), D | Versioned release: binaries attached to the matching GitHub Release (release.yml:4,12) | — |
| release-on-main.yml | 489 | P, R, D | Rolling dev release: auto-tag `main-<run>-<sha7>` (release-on-main.yml:321,347), publish via softprops SHA-pinned action (:389), **and prune old dev releases to the newest KEEP** (:450-479) | §1.4 |
| attribution-policy.yml | 70 | P, PR | Repo attribution checks | setup-python with `python-version: "3.x"` — the family's only floating language version |
| udpfs-transport-replay.yml | 49 | PR, D | UDPFS Neutrino-compatibility replay tests | — |

## 1.1 (a) Duplicated workflow LOGIC across repos — the ps2build machinery is one codebase, copied

The two ps2build repos do not merely resemble each other; they carry **the same SDK-management codebase, twice**:

| Artifact | RiptOPL | Launchstation | Sameness (READ, diff) |
|---|---|---|---|
| SDK installer | `tools/ps2build_sdk.sh` — 459 lines | `scripts/ps2build_sdk.sh` — 459 lines | **4 diff lines total; the only code difference is the User-Agent string** (`RiptOPL-build/1.0` vs `Launchstation-build/1.0`, :70-71 in both) |
| SDK watcher | `.github/scripts/ps2build_sdk_watch.py` — 452 lines | `.github/scripts/ps2build_sdk_watch.py` — 452 lines | 10 diff lines |
| Watcher test | `.github/scripts/test_ps2build_sdk_watch.py` — 596 lines | same name — 567 lines | **87 diff lines — the test copies have drifted furthest** |
| Bump workflow | `.github/workflows/ps2build-sdk-watch.yml` — 279 lines | same name — 245 lines | 144 diff lines (per-repo branches/PR targets) |
| Pin file | `.github/ps2build-sdk.env` | `.github/ps2build-sdk.env` | **Values byte-identical**: same `PS2BUILD_SDK_TAG=sdk-v2026.11.10-1a473e7c`, same `PS2BUILD_SDK_SUMS_SHA256=02f4e5b8…`, same component string (`cmake=v2026.11.04 ninja=v1.13.2 ps2build=v2026.11.10 sdk-core=v2026.11.10 sdk-world=v2026.11.05 toolchain=v2026.11.04 tools=v2026.11.04 vcl=v2026.11.04`), same LLVM `v2026.11.05`. RiptOPL's file adds only its ogg/vorbis extras block |

So ~1,370 lines of installer+watcher exist in two copies that must be fixed twice, and the weekly automation each repo runs *separately* arrives at *identical* pins — the strongest possible evidence the duplication buys nothing: the outputs are the same, only the maintenance is doubled. → **X-41**.

Secondary copies, same pattern at smaller scale (all READ):
- **Neutrino watches**: RiptOPL 75 lines / Launchstation 83 — not byte-identical (different comparison methods: release-notes parsing vs SHA-256 of the upstream 7z), but Launchstation's carries the comment "Same ticks as RiptOPL's Neutrino Watch: the 1st, 11th and 21st, 05:41 UTC" — the schedule was copied even where the code wasn't.
- **Ember watches**: RiptOPL 222 / POPSLoader 157 — 307 diff lines; same job (watch upstream Ember → re-dispatch release workflows), speciated implementations.
- **Wiki publishing**: four implementations (§1.4).
- **Docs-site generators**: Launchstation `docs-site/build.py` (216 lines) and SMS `docs-site/build.py` (330 lines) share a design (same `content/` + `manifest.json` + `static/` layout) but have speciated — 492 diff lines; SMS's grew the search index and wiki sync. Same-origin, no longer copies; recorded under Task 2, not as a fix candidate.

## 1.2 (b) Toolchain / version drift for the same tool

**`actions/checkout` — six generations across the family** (READ, counted per repo):

| Repo | Pins used |
|---|---|
| RiptOPL | SHA `d23441a4…` (# v6.1.0) ×20 **and** tag `@v6` ×5 — two styles in one repo |
| PS2-Servers | SHA `3d3c42e5…` ×19 — uniform, the strictest repo |
| Simple-Media-System | tag `@v7` ×7 and SHA `3d3c42e5…` ×1 |
| POPSLoader | `@v4` ×5, `@v5` ×10, `@v6` ×1 — **three generations in one repo** |
| Launchstation | `@v4` ×6 and one different SHA `11d5960a…` — the oldest fleet |

The same spread repeats for the other shared actions: `actions/upload-artifact` appears as one SHA (×25) plus tags v4/v6/v7; `actions/setup-python` as two different SHAs plus tags v6/v7; `actions/cache/*` as SHA plus v4. No repo is *wrong* — the versions all work — but there is no family convention, and the tag-pinned repos (Launchstation, POPSLoader) accept whatever the tag serves while the SHA-pinned repos (PS2-Servers, mostly RiptOPL) do not. → **X-42**.

**The ps2dev toolchain image — three pinning postures, two SDK majors:**

| Repo | Reference | Posture |
|---|---|---|
| SMS | `ps2dev/ps2dev:v1.0@sha256:da02eb0870af…` (compilation.yml:27,134,174; smbman.yml:31) | **Digest-pinned, SDK v1.0** — reproducible, oldest major |
| POPSLoader | `ps2dev/ps2dev:v2.0.0` (compilation.yml:68; experimental-release.yml:59; rolling-release.yml:63) | **Mutable tag, SDK v2.0.0** — the only non-reproducible pin of the three |
| RiptOPL | `ghcr.io/ps2dev/ps2dev@sha256:8fba50ecc222…` (flavours.yml:365) | Digest-pinned but **no version tag in the reference at all** — the digest is the only record of which SDK it is |
| RiptOPL + Launchstation (main builds) | ps2build SDK env pins (§1.1) | A different distribution of the same upstream toolchain entirely, pinned to exact component releases |

SMS on SDK v1.0 is load-bearing (its legacy stack is the v1.0-era one — SMS-018/X-11 territory, not re-filed), so the *version* split is a product fact, not carelessness. What is carelessness-shaped is only POPSLoader's mutable tag: its three release workflows can silently change toolchains when v2.0.0 is re-pointed. → **X-43**.

**Language versions (mostly a positive):** Python is **3.12 everywhere it is specified** (RiptOPL configurations.yml:55, rolling-llvm.yml:80; PS2-Servers ci.yml:29, release.yml:112, edge.yml:48) — the one floating exception is PS2-Servers attribution-policy.yml:25 (`"3.x"`, a policy-check job, low stakes). Go exists only in PS2-Servers; its intra-repo version drift is PS2SERVERS-054 (referenced above), and cross-repo there is nothing to drift against.

## 1.3 (c) Checks present in one repo, absent where the same failure class already bit

- **Format gate — one repo of five.** RiptOPL's `check-format.yml` (37 lines) runs clang-format 12 (DoozyX action @v0.18.2) on push/PR touching `**.c/.h`. **Launchstation and SMS both carry a root `.clang-format`** — three repos, three different config files (md5s `403df320…` / `9b913e25…` / `2cc422f8…`; RiptOPL's and Launchstation's already differ in ~6 options) — **but no workflow in either repo runs it**, and POPSLoader has neither config nor gate. The failure class is not hypothetical for this family: the user's own 2026-10-22 lesson (four draft PRs, one failure a format gate) is recorded in the audit's standing context. Two repos own the config and skip the 37-line enforcement. → **X-44**.
- **Host-behaviour tests in CI — present everywhere (positive).** Every PS2 repo runs real host tests in its build path (POPSLoader's compilation gate is the strongest: compilation.yml:33-57), and PS2-Servers runs full unittest + `go test -race`. The round-1 X-04 problem (source-text scrapers) is about test *quality inside* repos — per-repo findings, not repeated here; the cross-repo fact is only that no repo lacks a gate entirely.
- **Docs build check — two of five.** SMS gates its docs build (`docs-site/build.py --check`, docs.yml:16) and POPSLoader runs `tools/docs_verify.py` in its compile gate (compilation.yml:52). RiptOPL's docs-sync and Launchstation's docs-pages *publish* without an equivalent pre-publish check visible in their workflows (READ of the three workflows).
- **Reusable workflows — one of forty-one files.** PS2-Servers' `edge-build.yml` is the family's only `workflow_call` reusable workflow. Every other shared behaviour in §1.1 is shared by copying. This is the mechanism whose absence X-41 documents; the verdict there explains why building more of them is not automatically the LESS move.

## 1.4 (d) Release machinery — five answers to "what is a build called"

(Relates to X-03's counts and X-15's sprawl; the mechanisms below are the new content.)

| Repo | Mechanism | Self-cleaning? |
|---|---|---|
| PS2-Servers | **Two channels, cleanly separated**: versioned `v*` tags → release.yml attaches binaries to the matching Release (release.yml:4,12); every main push → release-on-main.yml auto-tags `main-<run-number>-<sha7>` (release-on-main.yml:321,347), publishes a prerelease, then **prunes dev releases to the newest KEEP**, matching the exact tag shape by regex so hand-made tags are never selected (:450-479, regex at :472) | **Yes — the only repo that prunes.** Its 81 `main-*` tags (X-03) are a *bounded* backlog, not an accident |
| Launchstation | One moving tag, `latest`, re-pointed by compile.yml with an **ancestry guard**: "Refusing to move latest: <sha> is not an ancestor of GITHUB_SHA" (compile.yml:538,592-595) | n/a — one tag by design; the guard is the family's best moving-tag safety |
| SMS | Moving `rolling` tag/release for master builds + `v*` tags for versions (compilation.yml:6,207) — and its own comment records that **two workflows fire on the same push and race the same rolling tag** (:269) | No pruning needed (one tag), but the race is documented in-tree and unfixed |
| RiptOPL | Rolling channels (GCC + LLVM) named by a **shared script**, `.github/scripts/release_channel.sh`, consumed by both rolling workflows — the family's one genuinely shared release mechanism, and it lives *inside* one repo | Channel tags by design |
| POPSLoader | Three release workflows (rolling 576, experimental 501, official 131). The official one is **named for a single version**: `name: POPSLoader 1.4.4 Release`, concurrency group `popsloader-1.4.4-release`, and verification steps that grep for the literal strings `POPSLDR_VER = "v1.4.4"` and `Version=1.4.4` (official-release.yml:1,17,47-49) | The 1.4.4 file must be edited in at least four places — or copied — for the next version |

**Wiki publishing (the quiet fourth copy set):** Launchstation sync-wiki.yml:43, POPSLoader wiki-sync.yml:58 and SMS wiki.yml:54 each hand-roll the same clone-`https://github.com/${GITHUB_REPOSITORY}.wiki.git`-copy-push sequence in YAML (72/93/72 lines); SMS additionally has a scripted `docs-site/sync_wiki.py`. RiptOPL alone implements it as a tested Python program (`.github/scripts/wiki_sync.py`, with `test_wiki_sync.py` in its host suite) driven by wiki-publish.yml. → **X-48**.

---

# TASK 2 — The docs-palette fan-out, quantified

## 2.1 What happened (git history, READ)

One docs redesign — same commit subjects, same sequence — was landed in **all five repos** (rounds 2–3 said four; the fifth, POPSLoader, landed on `dev`, which is why a default-branch check missed it). Three waves, each merged in **the same 1–2 minutes in every repo**:

| Wave | Subject | PRs (RiptOPL / Launchstation / POPSLoader / SMS / PS2-Servers) | Merged (all repos) |
|---|---|---|---|
| 1 | "Docs site: softer dark-gray colour scheme" | #410 / #381 / #641 / #67 / #314 | 2026-11-13 **05:56–05:57** |
| 2 | "style(docs): apply subdued monochrome dark palette" (SMS: "adopt readable charcoal and gray palette") | #421 / #385 / #644 / #69 / #317 | 2026-11-14 **07:48** |
| 3 | "style(docs): complete neutral palette across hard-coded UI colors" | #422 / #386 / #645 / #70 / #318 | 2026-11-14 **08:18–08:19** |

**15 PRs minimum**, plus the per-repo branch commits each PR carried (the AA-contrast fixes — "darken button gradients…", "lift small cyan labels to AA contrast" — timestamped 13:43–13:52 on 11-13 in four repos), plus SMS's extra repo-specific pair ("unify SMS page-specific colors with charcoal palette" ×2, 11-14 08:10). Total palette-sequence commits across the five repos' histories: **≈35** (7 in RiptOPL, 6–7 in each other repo, READ from `git log --grep`).

Corroborating sameness: the work travelled on **identically named branches** in at least two repos (`style/complete-neutral-palette-20261114`, `style/neutral-documentation-palette-20261114` — `git branch --contains` on RiptOPL and POPSLoader), and wave-3's merge minute is identical to the minute across repos whose default branches are the audit pins themselves (Launchstation's pin `9fb0598a79f0` *is* its wave-3 commit; likewise SMS `e65ced39a27e`, PS2-Servers `c5f021c4d386`).

**Landing branches differ** (READ): Launchstation/SMS/PS2-Servers landed on their default branches; RiptOPL's landed on **gh-pages** (its docs branch — the commits are ancestors of `origin/gh-pages`, *not* of rebuild/main, verified by `merge-base --is-ancestor`); POPSLoader's landed on **dev** (not master). So the fan-out reached five repos but only three default branches — anyone auditing from default-branch pins alone undercounts it, as rounds 2–3 did.

## 2.2 Is there a shared source? No — one design, five hand-carried copies

- Four of the five sites share **one stylesheet lineage**: `style.css` is 1,900 lines (Launchstation `docs-site/static/assets/style.css`), 1,891 (SMS, two copies — below), 1,715 (PS2-Servers `docs/assets/style.css`); RiptOPL's gh-pages copy was restyled by the same wave. Wave 3 changed **the same ~326 lines** of it in Launchstation and SMS (326 changed lines each) and 322/306 in PS2-Servers/RiptOPL, and the colour-literal sets of the four wave-3 patches overlap almost completely (the same blue-gray family `#131c2d … #f0f0f0` appears in all four patches, READ from `git show`). The files are siblings, not byte-identical copies — each has drifted around a common core.
- **POPSLoader's site is its own design**: its wave-3 patch touches a disjoint colour set (`#1f2229`, `#252830`, …) — it paid the same 15-PR process for a *different* stylesheet.
- **SMS pays twice inside its own repo**: its wave-3 commit changes `docs-site/static/assets/style.css` **and** `docs/assets/style.css` with the identical 326-line diff, and at the pin the two files are **byte-identical** (md5 `17bb5910b70428fba496445aaa7f3ec2` both) — the generated site output is committed beside its source (the composition fact is SMS-004/X-02; the new fact is that it **doubles every fan-out edit** in this repo).
- No repo references another's stylesheet, a shared theme repo, or a sync mechanism for the CSS. The generators themselves (§1.1) are speciated siblings in Launchstation/SMS and unrelated elsewhere.

**The cost case for X-02, in one line:** a single design decision cost ~35 commits and 15 PRs because the design lives as five copies (six, counting SMS's doubled file) — and the *next* palette change will cost exactly the same again. → **X-46**.

---

# TASK 3 — Shared vendored components census (beyond round 2's crypto)

| Component | Carriers & versions (evidence) | Patch-level state | Verdict |
|---|---|---|---|
| **usmb2** (SMB2 client, sahlberg) | RiptOPL `modules/network/smb2man/usmb2/VENDORED.txt`: upstream commit `7171d08b52f0…` (2026-11-01) + `riptopl.patch`; Launchstation `iop/smb2man/README.md`: same commit `7171d08`, same patch | **Fully synced.** File-level diff of the two trees: identical except ONE comment line in `hmac-md5.c:68-69` (the attribution word "RiptOPL:" vs "Launchstation:" above the Latin-1-uppercase NTOWFv2 fix — the fix itself is present, identical code, in both) | **Leave — the family working as intended.** Recorded so nobody "fixes" the one-line comment diff into a fork. (Extends round 2's byte-identity proofs from crypto files to the whole subset.) |
| **libsmb2** (SMB server) | Launchstation only, and *not vendored*: `scripts/fetch_libsmb2.sh:9-10` pins upstream commit `a52c1571a1ff…` at build time + 2 local patches (round 3) | n/a cross-repo | **Leave.** The fetch-and-pin pattern is the cleanest vendoring in the family; nothing to align |
| **mbedTLS** | RiptOPL vendored in-tree: `third_party/mbedtls/include/mbedtls/build_info.h:37` = **3.6.7**. Launchstation fetched at build time: `scripts/build_cloud_tls.sh:6` `version="3.6.7"` | **Versions identical**; delivery opposite (vendored tree vs pinned download) | **Leave — aligned already.** A positive; no action. (RIPTOPL-006's globbing point is separate and not repeated.) |
| **FatFs** | RiptOPL live copy: `modules/bdm/bdmfs_fatfs/fatfs/include/ff.h:2,23` = **R0.16** (FF_DEFINED 80386), vendored from ps2sdk `329e2bb4…` + fjtrujy/FatFs `18cc3d9e…` per `modules/bdm/ORIGIN.txt`. POPSLoader: only inside the BDMAssault source pin (REV-006) — **both** of the tarball's generations are **R0.14b** (FF_DEFINED 86631; `__bdm_assault/src/bdmfs/include/ff.h:2,23` and `bdmfs_fatfs/src/include/ff.h:2,23`, extracted to /tmp and read). Launchstation/SMS carry no in-tree FatFs source | Two versions, two *roles*: a live driver vs an archival source pin for shipped binaries | **Leave both.** "Aligning" the pin to R0.16 would invalidate exactly what REV-006 says the pin is for. The version gap is a fact to know, not a defect |
| **SMSTCPIP** (PS2SDK lwIP stack) | RiptOPL `modules/network/SMSTCPIP/` (~11,072 lines of .c) vs SMS `iop/SMSTCPIP/` (~9,642 lines) — same PS2SDK base (no version string is stated in either tree; the file sets are the lwIP 1.4.1-era PS2 port). SMS round 3 verdicted SMS's copy **pristine upstream** | **All 19 shared .c files differ** (READ, md5 + diff): pbuf.c 826 diff lines, api_lib.c 1,066, etharp.c 969, mem.c 523, ip.c 431. RiptOPL's fork carries its own hardening series (its CI holds `test_smstcpip_*` host tests); SMS's is the untouched snapshot | **Leave separate; adopt X-32's cross-port discipline.** Different consumers (in-game stack vs media player), a merge would be a permanent two-consumer conditional. The risk is the UDPRDMA one (X-32) repeated: fixes landing in exactly one fork — RiptOPL's hardening has never had a route to SMS's copy. → **X-47** |
| **PS2SDK mcman** | Launchstation `iop/vmcman` = PS2SDK mcman + local VMC fixes, built twice (Launchstation round 3). No second in-tree mcman copy exists in the other four repos (find across all five: only `Launchstation/iop/vmcman` and the unrelated `RiptOPL/modules/mcemu`, a VMC *emulator* for games, not mcman) | Single carrier | **Leave.** Nothing to align against |
| **Fonts / assets** | Launchstation dashboard fonts are generated Roboto arrays (`src/dash_font_data.c:1-4`, generated by `scripts/gen_dash_font.py`); RiptOPL uses runtime FreeType faces (`include/fontsystem.h`). No shared font component exists | n/a | **Leave.** No common component to align (the per-repo font-size findings are LAUNCHSTATION-002 / RIPTOPL-011, not repeated) |

---

# NEW CROSS FINDINGS (X-41…)

### X-41 / The ps2build SDK machinery is one codebase hand-copied across two repos — identical pins, doubled maintenance
- **Category:** 2 (duplication) / 7 (build/CI)
- **Locations:** RiptOPL/tools/ps2build_sdk.sh (459 L) vs Launchstation/scripts/ps2build_sdk.sh (459 L) — 4 diff lines, the only code difference the User-Agent at :70-71; RiptOPL/.github/scripts/ps2build_sdk_watch.py (452 L) vs Launchstation/.github/scripts/ps2build_sdk_watch.py (452 L) — 10 diff lines; the watcher tests (596 vs 567 L) — 87 diff lines; .github/workflows/ps2build-sdk-watch.yml in both (279 vs 245 L); pin files .github/ps2build-sdk.env in both with **byte-identical values** (SDK_TAG `sdk-v2026.11.10-1a473e7c`, SUMS_SHA256 `02f4e5b8…`, identical component string)
- **Problem:** Two repos build with the same SDK, pinned to the same releases, resolved by the same installer and bumped by the same watcher — maintained as two copies. The copies' *tests* have already drifted 87 lines apart, so the pair is on the same trajectory as every other fork in this audit: fixes will land in one. Each repo's weekly watcher independently discovers the same upstream releases and opens the same bump PR against its own copy.
- **Fix:** A sync rule, not a shared-CI project: name one repo's installer+watcher the canonical text (RiptOPL's — its test copy is the superset), and when either changes, port the diff to the other in the same change, the way round 2 prescribed for the byte-identical crypto (Topic 5 verdict). Do **not** create a shared CI repo or submodule for this — that is a sixth repository to version and pin, i.e. more machinery, and PS2-Servers' edge-build.yml shows reusable workflows only pay inside one repo's trust boundary. Separately: re-sync the drifted test copies now (one 87-line port).
- **Benefit:** ~1,370 lines stop drifting independently; SDK bumps stay provably identical instead of coincidentally identical.
- **Effort:** S (re-sync + a note in both env files naming the canonical copy). **Risk:** Low. **Confidence:** High (READ — full diffs).

### X-42 / `actions/checkout` is pinned at six different generations across the family — including three inside POPSLoader
- **Category:** 7 (build/CI) / 3
- **Locations:** counted across all 41 workflows (READ): RiptOPL — SHA `d23441a4…` ×20 + `@v6` ×5; PS2-Servers — SHA `3d3c42e5…` ×19 (uniform); SMS — `@v7` ×7 + SHA ×1; POPSLoader — `@v4` ×5 + `@v5` ×10 + `@v6` ×1; Launchstation — `@v4` ×6 + SHA `11d5960a…` ×1. Same spread in upload-artifact (SHA ×25 + v4/v6/v7) and setup-python (2 SHAs + v6/v7)
- **Problem:** No family convention exists, and within RiptOPL and POPSLoader the pin style changes from file to file — evidence these files were written at different times by different sessions and never swept. The tag-pinned usages are the soft spot: a re-pointed or compromised tag silently changes what every build runs, which is precisely what the two SHA-pinning repos already protect against.
- **Fix:** Per repo, one sweep commit: pin every third-party action to a full SHA (the style PS2-Servers already holds uniformly and RiptOPL mostly holds), with the version kept as a trailing comment as PS2-Servers does (`# v7.1.0`). No cross-repo coordination needed beyond doing it in all five; no new tooling (a dependabot config would be *more* machinery — the audit's rule says the sweep, not the bot).
- **Benefit:** one reproducible, auditable action supply chain per repo; the next action bump is a diff, not a surprise.
- **Effort:** S per repo. **Risk:** Low. **Confidence:** High (READ, counted).

### X-43 / The same ps2dev toolchain image is pinned three incompatible ways — and POPSLoader's is a mutable tag
- **Category:** 7 (build/CI)
- **Locations:** Simple-Media-System/.github/workflows/compilation.yml:27,134,174 + smbman.yml:31 — `ps2dev/ps2dev:v1.0@sha256:da02eb0870af…` (digest-pinned); POPSLoader/.github/workflows/compilation.yml:68, experimental-release.yml:59, rolling-release.yml:63 — `ps2dev/ps2dev:v2.0.0` (bare tag); RiptOPL/.github/workflows/flavours.yml:365 — `ghcr.io/ps2dev/ps2dev@sha256:8fba50ecc222…` (digest only, no version in the reference)
- **Problem:** Three reproducibility postures for one upstream image. SMS's v1.0-vs-v2.0.0 major split is a legitimate product fact (its stack is v1.0-era) and is **not** flagged. The defects are narrower: (1) POPSLoader's three release workflows build with a tag that can be re-pointed upstream, so a "reproducible" release build isn't; (2) RiptOPL's digest-only reference records *which* SDK built the POPSTARTER drivers nowhere a human can read — the version exists only as a hash.
- **Fix:** POPSLoader: add the digest for v2.0.0 alongside the tag (copy SMS's `tag@sha256:` shape — one line in three files). RiptOPL: add a comment beside flavours.yml:365 naming the SDK version the digest corresponds to. Nothing else changes; the ps2build repos are unaffected.
- **Benefit:** every release build in the family becomes reproducible from its workflow file alone.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

### X-44 / Only RiptOPL's CI enforces formatting — Launchstation and SMS own `.clang-format` files no workflow runs
- **Category:** 7 (build/CI)
- **Locations:** RiptOPL/.github/workflows/check-format.yml (37 lines; DoozyX/clang-format-lint-action @v0.18.2, clangFormatVersion 12, paths-filtered to `**.c/.h`). Root configs exist at RiptOPL/.clang-format, Launchstation/.clang-format, Simple-Media-System/.clang-format (three different files — md5 `403df320…` / `9b913e25…` / `2cc422f8…`; RiptOPL's and Launchstation's differ in ~6 options); **grep of all 41 workflows finds clang-format in exactly one** (READ). POPSLoader has neither config nor gate
- **Problem:** Two repos carry the config — the stated intent to have a format — and never check it, so their trees drift until a human notices; the family's own history contains a format-gate failure burning a full PR round (2026-10-22, standing context). RiptOPL's gate also covers only `.c/.h`, not its C++ EE sources — noted as a scope fact, not expanded here (per-repo territory).
- **Fix:** Copy RiptOPL's 37-line workflow into Launchstation and SMS, pointed at their existing root configs (adjust the action's `extensions` to each repo's sources). No new config work — the files already exist. POPSLoader: leave (Lua + mixed C/C++; a gate there is a new decision, not a copy).
- **Benefit:** the format each repo already declares becomes the format its CI keeps; format surprises move from PR review to a 1-minute job.
- **Effort:** S. **Risk:** Low (first run may flag existing drift — that is the point; land it as warn-only for one cycle if the drift is large, INFERRED). **Confidence:** High (READ).

### X-45 / Release machinery: PS2-Servers prunes its auto-tags; POPSLoader's official-release workflow is hard-coded to version 1.4.4; SMS's rolling tag is raced by two workflows
- **Category:** 7 / 8 (build/CI, half-finished machinery)
- **Locations:** PS2-Servers/.github/workflows/release-on-main.yml:321,347 (auto-tag `main-<run>-<sha7>`), :450-479 (prune to newest KEEP, exact-shape regex at :472); Launchstation/.github/workflows/compile.yml:538,592-595 (moving `latest` + ancestry guard); Simple-Media-System/.github/workflows/compilation.yml:269 (own comment: two workflows fire on the same push and race the `rolling` tag); POPSLoader/.github/workflows/official-release.yml:1,17,47-49 (workflow name, concurrency group and two verify-greps all literal `1.4.4`)
- **Problem:** Three mechanism-level defects, one per repo, all invisible from the tag *counts* (X-03): (1) POPSLoader's official channel cannot release 1.4.5 — the file must be edited in ≥4 places or forked per version, guaranteeing a stale copy of it eventually runs; (2) SMS's `rolling` release is written by two workflows off the same push, with the survivor decided by timing (documented in its own comment, unfixed); (3) the contrast — PS2-Servers generates the family's worst tag volume and is the *only* repo whose machinery bounds it, while Launchstation's ancestry guard is the family's best moving-tag practice and exists in exactly one repo.
- **Fix:** POPSLoader: read the version from the tag/ref into the workflow's name-less steps (the greps can target `etc/boot.lua`'s value dynamically) — delete the four literals, keep the file. SMS: give `rolling` a single writer (the other workflow uploads artifacts only), per its own comment's diagnosis. No cross-repo machinery; if a second repo ever adopts auto-tags, copy PS2-Servers' prune step rather than inventing one.
- **Benefit:** the official channel survives its next version; the rolling tag gets one writer; the family's one cleanup pattern is named for reuse.
- **Effort:** S each. **Risk:** Low. **Confidence:** High (READ, including the in-tree comments).

### X-46 / The docs-palette fan-out: one design decision = ~35 commits and 15 PRs, because the design lives as five (in SMS, six) copies with no shared source
- **Category:** 2 (duplication) / 7 — the quantified cost case for X-02 (referenced, not re-filed)
- **Locations:** §2 of this file. Commits: waves merged 2026-11-13 05:56–57, 2026-11-14 07:48 and 08:18–19 in all five repos (PRs #410/#421/#422, #381/#385/#386, #641/#644/#645, #67/#69/#70, #314/#317/#318). Stylesheet copies: Launchstation/docs-site/static/assets/style.css (1,900 L), Simple-Media-System/docs-site/static/assets/style.css + Simple-Media-System/docs/assets/style.css (1,891 L, **byte-identical pair**, md5 `17bb5910…`), PS2-Servers/docs/assets/style.css (1,715 L), RiptOPL gh-pages assets/style.css; wave 3 changed the same ~326 lines in each
- **Problem:** The palette is one design maintained as hand-carried copies. Every change is produced once per repo (same-minute merges prove a single coordinated session doing the same work five times), reviewed five times, and — in SMS — *committed twice per change* because generated output sits beside its source. POPSLoader paid the same process for a different stylesheet, so even the "shared" part isn't shared there. There is no mechanism by which the next design change gets cheaper.
- **Fix:** The LESS fix is X-02's, now with a price tag: the docs sites leave the product repos (one site, one stylesheet, one palette commit per change). If the sites must stay in-repo, the fallback is narrower: SMS stops committing the generated `docs/` copy of the stylesheet (its build regenerates it), removing the ×2 inside that repo. Do **not** build a palette-sync bot or a shared-theme submodule pipeline — that is X-15's disease (automation maintained to maintain copies) applied to CSS.
- **Benefit:** the next design change costs 1 PR instead of 15; SMS's per-change CSS diff halves immediately under the fallback.
- **Effort:** M (site move) / S (SMS fallback). **Risk:** Low. **Confidence:** High (READ — git history, timestamps, md5s).

### X-47 / SMSTCPIP lives as two diverged forks (RiptOPL hardened, SMS pristine) with no cross-port route — the X-32 pattern on a second stack
- **Category:** 2 (duplication drift)
- **Locations:** RiptOPL/modules/network/SMSTCPIP/ (~11,072 lines of .c at the pin) vs Simple-Media-System/iop/SMSTCPIP/ (~9,642 lines); all 19 shared .c files differ (READ): pbuf.c 826 diff lines, api_lib.c 1,066, etharp.c 969, mem.c 523, ip.c 431. SMS's copy verdicted pristine-upstream in SMS round 3 (Task 4); RiptOPL's carries its local series (guarded by RiptOPL/.github/scripts/test_smstcpip_*.py host tests). Neither tree states an upstream version string (READ — version is identifiable only as the PS2SDK SMSTCPIP file set)
- **Problem:** Same disease as the UDPRDMA forks (X-32), second component: a security-relevant network stack exists in two repos at two patch levels, and every fix lands in exactly one. RiptOPL's hardening series has no route to the copy inside the media player, whose network surface (SMB/HTTP/UDPFS clients) is at least as exposed.
- **Fix:** X-32's prescription, applied here: do not merge (different consumers and IOP budgets); add the one-line cross-port note to both trees' attribution/origin records, and when either fork takes a *correctness/security* fix (as opposed to a consumer-specific change), port it to the other in the same change. The standing inventory above is the baseline that makes future drift measurable (19/19 files differ today — any *new* divergence is now countable).
- **Benefit:** the family's second network stack gets the same drift discipline as the first; no code changes today.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ — full file-set diff).

### X-48 / Wiki publishing is implemented four times — three hand-rolled YAML copies and one tested program
- **Category:** 2 / 7
- **Locations:** Launchstation/.github/workflows/sync-wiki.yml (72 L, clone at :43); POPSLoader/.github/workflows/wiki-sync.yml (93 L, clone at :58); Simple-Media-System/.github/workflows/wiki.yml (72 L, clone at :54) + docs-site/sync_wiki.py; RiptOPL/.github/workflows/wiki-publish.yml (125 L) driving .github/scripts/wiki_sync.py (with host tests, test_wiki_sync.py)
- **Problem:** The same job — clone the repo's `.wiki.git`, copy generated pages, push — is written four times, three of them as inline shell in YAML where it cannot be tested, and the three shell copies will drift independently (they already differ in temp paths and guards). RiptOPL's scripted version is the only one with tests and the only one whose logic can be run off-CI.
- **Fix:** Per repo, nothing today (each publishes only its own wiki; the copies are small). The LESS move is prospective: the next time any of the three YAML copies needs a real change, replace its inline shell with a small script in that repo, modelled on RiptOPL's — do not copy RiptOPL's script verbatim across repos (its inputs are RiptOPL's docs layout; a verbatim copy would be a fifth fork). Recorded so the pattern is a decision, not an accident.
- **Benefit:** names the duplication before it grows; zero code change now.
- **Effort:** S (when triggered). **Risk:** Low. **Confidence:** High (READ).

---

## What could not be compared, and why

- **The private `NathanNeurotic/old-ps2build-mirror`** (named in both repos' ps2build-sdk.env as the SDK fallback source): not accessible from this environment, so the mirror's contents and whether the two repos' fallback paths truly agree could not be verified — the *pins* agree (READ); the mirrored payloads are INFERRED identical from the shared SUMS_SHA256.
- **PS2-Servers' docs-site publishing path**: it has no docs workflow among its 7 files, and its palette commits landed directly on `main`; how its site reaches gh-pages (manual push, branch settings) is not determinable from workflow files alone — stated as a gap, not guessed.
- **ps2dev image contents** (v1.0 vs v2.0.0 SDK differences): images were not pulled in this read-only pass; §1.2 compares *pinning postures and stated versions*, not image contents.
- **Workflow runtime behaviour** (cache hit rates, the SMS rolling-tag race's actual winner, whether Launchstation's ancestry guard has ever fired): CI run history is not in the clones; all claims are from the workflow texts and git history at the pins.
- **POPSLoader's `dev` branch beyond the palette commits**: the fan-out's presence there is verified; a full dev-vs-master audit is per-repo work, out of this round's scope.

## Verification

All five clones re-checked at the end of this pass: HEADs at the round-3 pins (table in the header), `git status` clean in all five. The only writes this round made outside the audit folder were a two-file extraction of the BDMAssault tarball's `ff.h` headers under `/tmp` (read for Task 3's FatFs versions); no repo file was created, modified or deleted.
