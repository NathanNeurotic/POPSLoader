# Sable Audit — CROSS-REPO ROUND 7: Generated Artefacts (2026-11-14)

**Scope:** the generated-artefact class across all five repos — checked-in files that a
generator (in-repo script, Makefile rule, or documented transform) can reproduce:
bin2c/bin2s byte dumps, baked asset arrays, generated headers/tables, codegen outputs,
checked-in build products. Rounds 1–6 audited hand-written source; no round had audited
this class as a class. POPSLoader's `src/elf_loader/loader.c` is excluded here (it has its
own round-7 agent); every other POPSLoader artefact is in scope.

**Pins (verified live at start and end; clones NOT updated by this agent; nothing moved —
no staleness):**

| Repo | Branch | Pin == live HEAD |
|---|---|---|
| RiptOPL | rebuild/main | `2e347d5ac885cd0ff73e9ad4143781946396f492` |
| Launchstation | master | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` |
| POPSLoader | master | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` |
| Simple-Media-System | master | `e65ced39a27eee8d996e9257e21594d1cac1c93d` |
| PS2-Servers | main | `c5f021c4d38698860f56b03498adc261dbb8d8dd` |

**Read-only held:** all five clones `git status` clean at end. All regeneration tests ran
in `/tmp` copies or read-only check modes.

**Method:** (1) marker sweep (`GENERATED / do not edit / AUTO-GENERATED` headers),
byte-array-density scan of every tracked `.c/.h` (≥20 hex-array lines, >30% of file),
generator-name sweep (`gen_*`, `bake_*`, `build_*`, `sync_*`, `compress_*`), and Makefile
bin2c/bin2s rule census; (2) drift by git history (artefact's last commit vs its inputs'
last commit); (3) drift by **execution** wherever a generator runs without a PS2 toolchain
— re-run it against the in-repo inputs and byte-compare; (4) cross-repo md5 census over
every tracked file ≥64 B in all five repos (174 identical-content groups; the
generated-artefact-relevant ones are reported in §3).

---

## 1. Headline result

**Confirmed drift: ZERO.** Every generated artefact that could be regenerated or
self-checked in this environment matches its inputs **byte-for-byte, executed**:

| Artefact | Test | Result |
|---|---|---|
| SMS `src/SMS_IconsRGBA.c` (blob 27,764 B) | Re-ran `tools/bake_icons_rgba.py` with `ICON_DIR=theme/icons` (39 tracked PNGs) to /tmp; extracted `g_RGBA_Blob` from both files | **identical** |
| SMS `src/SMS_LoadingRGBA.c` (4,096 B) | Re-ran `tools/bake_loading_rgba.py` on `theme/icons/g_IconLoading.png` | **identical** |
| SMS `src/SMS_BallRGBA.c` (4,096 B) | No script exists; re-implemented the header-documented transform (RGBA, alpha `round(a·0x80/255)`, transparent RGB zeroed) from `theme/icons/g_IconBall.png` in PIL | **identical** |
| SMS `docs/data/search-index.js` + `.json` | Re-ran `node tools/build-docs-search-index.mjs` in a /tmp copy | **both md5 unchanged** |
| PS2-Servers `docs/data/search-index.json` (181 entries) | Re-ran `tools/build_docs_index.py` in a /tmp copy | **md5 unchanged** |
| Launchstation `res/sfx_ps2/*.adp` (8 files) | Ran the generator's own verifier, `scripts/gen_sfx.py --check` (exit 1 + `MISMATCH` lines on any mismatch; gen_sfx.py:175-190) | **exit 0, no mismatches** |
| SMS `irx/bdmfs_fatfs.irx` ↔ `.irx.xz` | `xz -dc` of the `.xz` vs the checked-in plain `.irx` (36,877 B) — the same equality the repo's own pin test asserts (`tools/test_bdmfs_fatfs_module.py:12-15`, incl. a SHA-256 pin of the plain file) | **identical** |

**Suspects raised: 1 — dissolved with evidence** (§4). **Hand-edit evidence: none** —
every generated file's git history moves in the same commits as its inputs or generator
(dash_font family: the same two commits touch generator and outputs; SMS_IconsRGBA.c:
the same commits as `theme/icons/`, e.g. `3da0622`). **New findings: 2 (X-52, X-53)** —
both are about the *absence of a gate / of inputs*, not about wrong bytes. The bytes,
today, are right everywhere they can be checked.

---

## 2. Census — generated artefacts by repo

Sizes are on-disk bytes at the pins. "Build-time only" = outputs are NOT checked in
(the healthy pattern; listed so the census is complete). Groups already filed in earlier
rounds are marked [filed] and not re-argued.

### RiptOPL — the cleanest repo in the family for this class
| Artefact / group | Generator | Inputs | Checked in? |
|---|---|---|---|
| `include/lang_autogen.h`, `src/lang_internal.c`, `lng/*.lng` | `tools/lang_compiler.py` (Makefile:1215, rules at Makefile:1220-1235) | `lng/tmpl/_base.yml`, `lng/fork/*.yml` (tracked) | **No — build-time only** |
| Host-test globals | `tests/host/gen_settings_globals.py` (emits to stdout for `tests/host/run.sh`) | `src/core/settings.cpp` + `include/*.h` | No — build-time only |
| EE-core/ELF/IRX embeds | `bin2c` (Makefile:222, rules :577-623) | build products | No — build-time only |
| `modules/debug/drvtif{,-ingame}.irx`, `tifinet{,-ingame}.irx`, `deci2.img` (5 files, 92,197 B) | none in-repo (Sony debug modules) | external | Yes — prebuilt, no source anywhere in the family; unverifiable (§5) |
| `modules/mcemu/mcemu_var.c` (3,418 B) | none (hand data table) | — | Yes — data, not generated output |
| `ship/` release snapshot incl. `ship/Example/…` duplicate tree (182 files, 9,637,271 B) | release packaging (`.github/scripts/package_release_app.py`) | the tree itself | Yes — [filed: RIPTOPL-002] |

### Launchstation — largest checked-in generated surface (17 files, 1,978,910 B in the groups below)
| Artefact / group | Generator | Inputs | Checked in? |
|---|---|---|---|
| `src/dash_font_data.c` (591,973 B; arrays 215,040 B) | `scripts/gen_dash_font.py` | `Roboto-Regular.ttf` — **not tracked** (script takes a path argument) | Yes |
| `src/dash_font_emotion_engine.c` (492,279 B) + `src/dash_font_emotion_engine_bold.c` (555,019 B) | `scripts/gen_dash_font.py` ("GENERATED … do not edit" headers) | `EmotionEngine-8ynA.ttf`, `EmotionEngineBold-YGnL.ttf` — **not tracked**; SHA-256 pins in `docs/font-generation.md:37-38` | Yes → X-53 |
| `src/font_uLE.c` (41,258 B) | the app's own font-dump code path (`src/draw.c:358` prints `unsigned char font_uLE[] = {…}`) — artefact carried by hand from the program's output | the running app | Yes — [filed as a text path: LAUNCHSTATION-012] |
| `res/sfx_ps2/*.adp` (8 files) | `scripts/gen_sfx.py` (procedural synthesis; has `--check`) | none (pure synthesis) | Yes — **verified byte-exact, §1** |
| `res/sfx/*.adp` (8 files) | none (original sound set) | — | Yes — source assets, not generated |
| `iop/__precompiled/udpfs_{ioman,ministack,smap}.irx`, `iop/__v10/{ps2dev9,ps2ip}.irx` | none in-repo (names declare provenance: precompiled / PS2SDK v10) | external | Yes — unverifiable (§5) |
| `ship/neutrino-ilink/{IEEE1394_bd_mini,iLinkman}.irx` | none in-repo | external | Yes |
| Cloud client header | `scripts/gen_cloud_client.py` → `.cloud-deps/include/wle_cloud_client.h` (gen_cloud_client.py:23) | build-time fetch | No — build-time only |
| Git hash header | `scripts/gen_githash.py` | git | No — build-time only |
| Blob embedding | `src/embed_blobs.S` (`.incbin`, build-time) | `res/` files | No — build-time only |
| Docs site | `docs-site/build.py` → `dist/` (build.py:181, default `--out dist`) | `docs-site/{content,static,manifest.json}` | No — `dist/` untracked |

### POPSLoader (loader.c excluded by scope)
| Artefact / group | Generator | Inputs | Checked in? |
|---|---|---|---|
| All embedded assets (PNG/IRX/ELF payloads) | `bin2c` (Makefile:70 `BIN2S`, rules :150-275) into `.o`; registry is hand-written `src/embed_assets.cpp` (extern decls) | `bin/POPSLDR/**`, `iop/embed/**`, `EMBED/builtin_font.ttf` | **Outputs no — build-time only**; inputs yes |
| `iop/embed/*.irx` (9 files) + `iop/embed/BDMASSAULT_MX4SIO/{usbd,usbhdfsd}.irx` | none in-repo for most; BDMAssault pair's source is the checked-in tarball [filed: REV-006] | external / tarball | Yes — bulk-import dates 2026-03-20; `ata_bd.irx` 2026-07-23 vs its in-repo source `iop/ata_bd_fast` last commit 2026-07-22 — consistent, cleared; udpfs trio 2026-10-12 |
| Duplicate payload copies across `bin/POPSLDR/`, `iop/embed/`, RiptOPL `ship/` | — | — | [filed: POPSLoader pass-1 embed-duplication finding; RIPTOPL-002] |

### Simple-Media-System — the most generated files, and the best verified
| Artefact / group | Generator | Inputs | Checked in? |
|---|---|---|---|
| `src/SMS_IconsRGBA.c` (142,962 B) | `tools/bake_icons_rgba.py` | `theme/icons/*.png` (39 files, tracked) | Yes — **verified byte-exact, §1** |
| `src/SMS_LoadingRGBA.c` (21,363 B) | `tools/bake_loading_rgba.py` | `theme/icons/g_IconLoading.png` | Yes — **verified byte-exact** |
| `src/SMS_BallRGBA.c` (21,370 B) | **no script in-repo** — header documents the transform | `theme/icons/g_IconBall.png` | Yes — **verified byte-exact** by re-implementation |
| `irx/*.irx.xz` (24 files) | `tools/compress_irx.py` (Makefile:97-100: `bin2c` of the `.xz` at build) | `.irx` build products of `iop/` sources + PS2SDK stock | Yes — dates audited (§4); stock-SDK members unverifiable (§5) |
| `irx/bdmfs_fatfs.irx` (36,877 B) beside its `.xz` | the module build (`tools/build_bdmfs_fatfs.sh`) | FatFs port source | Yes — **deliberate**: it is the reference file for the repo's own SHA-256 pin + xz-equality test (`tools/test_bdmfs_fatfs_module.py:12-15`). Not waste. |
| `include/s_iop_image.h` (373,784 B) | IOP image dump | console IOP image | Yes — [filed: SMS-002, dead] |
| `src/SMS_Data.c`, `SMS_DTS.c`, `SMS_Sounds.c`, `SMS_GSFont.c`, `SMS_JPEGData.c`, `SMS_OS.c`, `SMS_ConfigIcon.c`, `SMS_GUIcons.c` legacy arrays | none in-repo (2005-06 upstream data tables/blobs) | — | Yes — hand/upstream data, not generator output [text-form conversion filed pass 1; GUIcons dead set filed SMS-074] |
| `docs/`, `wiki/`, `docs/data/search-index.{js,json}` | `docs-site/build.py`, `tools/build-docs-search-index.mjs`; regenerated by `.github/workflows/docs.yml` | `docs-site/`, `wiki/` sources | Yes — [filed pass 1: generated outputs committed]; index **verified byte-exact** this round |

### PS2-Servers — one generated artefact, and it is gated
| Artefact / group | Generator | Inputs | Checked in? |
|---|---|---|---|
| `docs/data/search-index.json` | `tools/build_docs_index.py` | `docs/*.html` | Yes — **verified byte-exact**, and CI-gated: `.github/workflows/ci.yml:101` runs the generator + `git diff --exit-code` |
| WebUI assets | `//go:embed assets/*` (`native/ps2servers-edge/internal/webui/embed.go:5`) | hand-written `assets/{index.html,app.js,styles.css}` | Assets are source; embedding is build-time |
| `vendor/retroachievements/xerabora/client/src/{badge_data.c,sounds_data.c}` (579,172 B) | upstream xerabora codegen | upstream | Yes — vendored, inventory-only by framing |

**Census totals:** ~35 artefact entries/groups; 88 files / ≈6.89 MB in the enumerated
checked-in groups alone (excluding RiptOPL `ship/` 9.64 MB [filed], the docs sites
[filed], and POPSLoader `loader.c` [other agent]).

---

## 3. Cross-repo duplication within the class (Task 3)

The full-family md5 census (174 identical groups) shows the generated-artefact class has
**no new cross-repo duplication** beyond what earlier rounds already filed:

- The BDMAssault / POPStarter binary set (`usbd.irx.*`, `usbhdfsd.irx.*`, `POPSTARTER.ELF`,
  `SMSUTILS.irx`, `smbman.irx`, `ps2ip.irx`, … — md5 groups of 3-12 copies) is shared
  between RiptOPL (`modules/bdmassault/`, `ship/`) and POPSLoader (`bin/POPSLDR/`,
  `iop/embed/`) — already filed as RIPTOPL-002, the POPSLoader pass-1 embed-duplication
  finding, and REV-006 (tarball = source pin). **Referenced, not re-filed.**
- The docs stylesheet duplication is X-46. Referenced.
- The only other cross-repo identical *assets* are four controller-button PNGs —
  `L1.png`, `L3.png`, `R1.png`, `select.png` — byte-identical in RiptOPL `gfx/`,
  Launchstation `res/icons/`, and POPSLoader `bin/POPSLDR/IMG/`. These are shared
  *inputs* (each repo builds standalone; POPSLoader bin2c's its copies, Launchstation
  `.incbin`s its copies), a few KB in total. Census fact only: deleting copies across
  repos is not a net win, so no finding.

---

## 4. Suspects — raised and dissolved (Task 2)

**SMS udpfs trio vs `iop/SMSUdpfs` source — DISSOLVED.** Date test flagged it:
`irx/udpfs_{ioman,ministack,smap}.irx.xz` last committed 2026-07-15/2026-07-27, while
`iop/SMSUdpfs` shows a 2026-11-01 commit (`77c5a0a`) — source apparently ~3 months newer
than the shipped binaries. Commit inspection dissolves it: `77c5a0a` touches only
`iop/SMSUdpfs/ATTRIBUTION.md` (1 line, a docs link — "docs: point Neutrino links at
ps2max32/neutrino"). The last *code* change, `627d6dd` (2026-07-27, `smap/src/xfer.c` TX
retry bound), is the very commit that updated the `.xz` files. No code input is newer
than the artefact. Not a finding; the date heuristic alone would have false-positived.

Also date-cleared: SMS `smbman.irx.xz` vs `iop/smbman-sms` (both 2026-10-18);
SMS `bdmfs_fatfs.irx.xz` (2026-11-12, commit `a22658d` — the UTF-8 module change itself);
POPSLoader `iop/embed/ata_bd.irx` (2026-07-23) vs `iop/ata_bd_fast` source (2026-07-22);
Launchstation dash_font family (generator + all three outputs share commits 944a2fc,
021cbb9).

**Standing suspect count: 0.** Items that are *unverifiable* rather than suspect (no
positive staleness signal; inputs absent by design) are listed in §6, not here.

---

## 5. Findings

### X-52 / Checked-in generated artefacts have no drift gate in Launchstation or SMS — the checks exist (or are proven byte-stable) but nothing runs them / Category 7
- **Location(s):** Launchstation/scripts/gen_sfx.py:12,175-190 (`--check` mode: synthesises all 8 sounds, byte-compares `res/sfx_ps2/*.adp`, exits 1 on mismatch) vs Launchstation/.github/ (no workflow references `gen_sfx` — grep-verified across all five repos' `.github/` trees); Simple-Media-System/tools/bake_icons_rgba.py + bake_loading_rgba.py (no check mode; no `.github/` reference) vs their checked-in outputs Simple-Media-System/src/SMS_IconsRGBA.c, SMS_LoadingRGBA.c, SMS_BallRGBA.c (the third has no generator script at all — its transform exists only as a header comment in SMS_BallRGBA.c:1-3).
- **Problem:** The family's generated artefacts are currently byte-perfect everywhere they can be tested (six executed verifications, §1) — and almost nothing would notice if they stopped being perfect. The pattern for gating already exists three times inside the family: PS2-Servers' CI regenerates its index and fails on diff (`.github/workflows/ci.yml:101`, `git diff --exit-code`); SMS pins `irx/bdmfs_fatfs.irx` by SHA-256 with an xz-equality assert (`tools/test_bdmfs_fatfs_module.py:12-15`); POPSLoader pins its IRX blobs by SHA-1 + length in a host test (round-4 evidence). Launchstation wrote a `--check` verifier and wired it nowhere; SMS's bakes are deterministic and byte-stable (proven this round) but unchecked. The first hand-edit, missed re-bake, or partial regeneration in either repo ships silently — SMS's own history shows the failure mode is real: commit `1fb1314` is literally titled "Consolidate the icon source set into theme/icons/ (fix the re-bake trap)".
- **Fix:** Wire what already exists into the workflows that already exist: run `gen_sfx.py --check` in a Launchstation workflow; add a regen-and-diff step for the three SMS bakes (regenerate to a temp dir, `diff` against `src/` — the PS2-Servers step is the in-family template, ~4 lines each). No new tooling, no new files in the repos except the workflow lines; for SMS_BallRGBA.c, either fold the ball into `bake_icons_rgba.py` (it already special-cases `g_IconBall` in its slot table) or leave the header-comment transform as the spec the diff step re-implements.
- **Justification:** *(the fix adds CI lines — required justification)* It adds nothing to the shipped product and no new machinery; it points existing verifiers at existing artefacts. The alternative — trusting every future regeneration — is how the SMS re-bake trap happened the first time.
- **Benefit:** Drift in ~1.6 MB of checked-in Launchstation font/sfx artefacts and ~186 KB of SMS baked arrays becomes a red CI line instead of a silently wrong ELF; closes the only unguarded cell in the family's otherwise-pinned artefact table.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ for the absent wiring — grep of all five `.github/` trees; EXECUTED for the current byte-exactness of every artefact named)

### X-53 / Launchstation's dashboard font artefacts cannot be regenerated from the repo — their TTF inputs are not tracked / Category 7
- **Location(s):** Launchstation/src/dash_font_data.c (591,973 B), Launchstation/src/dash_font_emotion_engine.c (492,279 B), Launchstation/src/dash_font_emotion_engine_bold.c (555,019 B) — all headed "GENERATED by scripts/gen_dash_font.py, do not edit"; generator at Launchstation/scripts/gen_dash_font.py:14 (`python scripts/gen_dash_font.py path/to/Roboto-Regular.ttf` — the input is a command-line path); no `.ttf` is tracked anywhere in the repo (git ls-files, verified); provenance mitigation at Launchstation/docs/font-generation.md:37-38 (SHA-256 pins for `EmotionEngine-8ynA.ttf` and `EmotionEngineBold-YGnL.ttf`; Roboto unpinned, path shown as `/path/to/…` at :46).
- **Problem:** 1,639,271 B of checked-in arrays (≈586 KB of payload data) are the family's largest generated artefacts, and they are frozen: nobody can regenerate, extend (e.g. add a glyph), or even verify them from the repository alone. The SHA-256 pins prove whether an externally-held TTF is the right one — they cannot recover it if the holder's copy is lost. Every other repo's checked-in artefacts either carry their inputs (SMS theme PNGs, PS2-Servers docs HTML) or need none (gen_sfx synthesis). This is the one cell where input and output live in different worlds.
- **Fix:** Track the three input TTFs in the repo (e.g. under `scripts/font-inputs/`) next to the generator. Roboto is Apache-2.0 (notice already kept at `docs/licenses/Roboto-COPYRIGHT.txt` per docs/font-generation.md:23) and the Emotion Engine faces already carry a licence notice (`docs/licenses/Emotion-Engine-LICENSE.txt`, cited in dash_font_emotion_engine.c:4) — if either licence blocks redistribution, say so in font-generation.md and name the artefact frozen-by-licence, which is still better than frozen-by-accident.
- **Justification:** *(the fix adds files — required justification)* It adds input binaries, not code or machinery, and it is the only way the existing 1.6 MB of outputs remain a *generated* artefact rather than an unrepeatable one; the alternative (delete the outputs, generate at build) would move a Pillow/fontTools host dependency into every build for no size win.
- **Benefit:** The dashboard font set becomes reproducible and extensible from a fresh clone; the SHA-256 pins gain something to pin against.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — generator invocation, tracked-file census, docs pins all cited; the licence question is flagged in the fix rather than assumed)

---

## 6. What could not be tested, and why

- **No artefact whose regeneration needs the PS2 toolchain was regenerated** (no PS2SDK
  in this VM): SMS `irx/*.irx.xz` module payloads, POPSLoader's bin2c outputs, RiptOPL's
  bin2c embeds. For these, drift testing was limited to git-history comparison and
  in-repo invariants; where the inputs themselves are external (PS2SDK stock modules),
  even the history test has nothing to compare.
- **Unverifiable-by-design set (no staleness signal; inputs absent):** RiptOPL
  `modules/debug/*.irx` + `deci2.img` (Sony debug modules); Launchstation
  `iop/__precompiled/*.irx`, `iop/__v10/*.irx`, `ship/neutrino-ilink/*.irx`; POPSLoader
  `iop/embed/` members without in-repo sources (mx4sio/udpfs/bdmfs prebuilts — BDMAssault
  pair excepted, whose source is the REV-006 tarball); SMS stock-SDK `irx/*.irx.xz`
  members (`mcman`, `padman`, `sio2man`, `usbd`, `filexio`, `iomanx`); PS2-Servers
  vendored xerabora data (upstream-framed). These are provenance facts, not findings.
- **Launchstation font outputs could not be byte-tested** (X-53: inputs external), and
  `font_uLE.c` has no reproducible generator at all (its "generator" is the shipped app's
  own font-dump screen) — both are consistent by history and unverifiable by execution.
- **Binary contents were never disassembled**; all binary claims are hash/date/size
  level, as in every round.

## 7. Round-7 cross-repo totals

- Census: ~35 artefact entries/groups across 5 repos; 88 files / ≈6.89 MB enumerated in
  checked-in groups (excluding previously-filed `ship/` and docs-site groups and the
  out-of-scope `loader.c`).
- Executed regeneration/self-check verifications: **7 artefact groups, all byte-exact**
  (SMS icons ×3, SMS search index ×2 files, PS2-Servers search index, Launchstation sfx
  set, SMS bdmfs_fatfs pair).
- Confirmed drift: **0**. Suspects raised: 1, dissolved with evidence (§4). Standing
  suspects: **0**.
- Hand-edit evidence in git history: **none found**.
- New cross findings: **2 (X-52, X-53)**.

*End of cross-repo round 7.*
