# Adversarial Verification — Redo POPSLoader, Chunk G2 (build / CI / tarball structure)

Pin: `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (clone HEAD re-checked, clean tree).
Tarball tree: `/tmp/bdma-verify/BDMAssault-mx4sio` — note: mid-verification a parallel worker re-extracted the tarball one level deeper (`…/BDMAssault-mx4sio/BDMAssault-mx4sio/`). All tarball totals below were measured on the original flat tree and re-verified identical (total 4,951,196 B) on the nested tree before use.

Method: refute-first. Every cited file opened at the cited lines (workflows in full where cited); every number re-derived with independent commands.

---

### RE-POPS-042 — VERIFIED

- `opencode.yml` read in full (33 lines). Line 29: `uses: anomalyco/opencode/github@latest`; line 30–31: `env: DEEPSEEK_API_KEY: ${{ secrets.DEEPSEEK_API_KEY }}`; `permissions:` block at lines 17–21 with `id-token: write` at line 18 (the finding's parenthetical says line 17 — the block header; the token line itself is 18, immaterial). Cited range 27–32 is exact for the step.
- Contrast verified: `rolling-release.yml:568-571` carries the comment "Pinned to a full commit SHA (NOT @master): this third-party action runs WITH the MEGA…" above `uses: Difegue/action-megacmd@bf698c68edaf91143b2a52d3468595202011bf17 # v1.4.0`.
- Uniqueness verified: a grep for `@latest|@master|@main` across all 10 workflows returns only opencode.yml:29 (plus the MEGA comment mentioning `@master` as what *not* to do). The benefit claim's premises also check out: `ps2dev/ps2dev:v2.0.0` image pin (compilation.yml:68), `actions/checkout@v5`/`@v6` major pins.
- Fix sanity: pinning to a reviewed SHA is the repo's own demonstrated pattern; LESS-NOT-MORE clean.

### RE-POPS-045 — VERIFIED-DRIFT

Every byte figure in the finding re-derives **exactly**; only the pair census and one line anchor drift.

- Component + libbdm C/H (`bdm` + `bdmfs_fatfs` + `usbd` + `usbmass_bd` + `libbdm`, 50 files): **2,469,099 B** ✓. Merged C/H (`__bdm_assault` + `__usbd_bd_assault`, 43 files): **2,444,950 B** ✓.
- `ffunicode.c` = **1,959,389 B**; merged `bdmfs_ffunicode.c` = **1,959,397 B**; sum **3,918,786 B** ✓. Tarball total (all 119 files): **4,951,196 B** ✓. 3,918,786 / 4,951,196 = **79.15%** (finding: 79.1% ✓); 3,918,786 / 4,914,049 total C/H = **79.75%** (finding: 79.7% ✓). Both files are 15,593 lines; their diff is a single line (`#include "ff.h"` → `#include "include/ff.h"`).
- Pair diff re-run (best-match pairing of every merged C/H file against the components, full diff of all 43): **43 merged C/H files, 26 byte-identical, 17 differing** — the differing count **17 matches the finding/Appendix exactly**, and every delta is ≤6 substituted lines: include-path substitutions everywhere, plus the three `_start`/banner edits (`bdm_main.c`: MAJOR_VER 1→2 + `bdmfs_fatfs_start` chaining; `bdmfs_main.c` and `usbmass_bd_main.c`: `_start` renamed to the fused entry point, banner/IRX_ID edits) and the two `irx_imports.h` unions (merged 31 lines vs component 27/28 — a true union of the fused modules' imports). No merged copy carries a fix absent from its component.
- **Corrected figures:** the finding/Appendix claim "37 file pairs: 20 byte-identical / 17 differ". Under any straightforward pairing (basename after prefix-strip, or best-match), there are **43 pairs: 26 identical / 17 differ**. The audit appears to have undercounted the identical pairs by 6 (plausibly excluding some header pairs); the load-bearing half of the claim — 17 differing pairs, all mechanical — is exact.
- One anchor drift: `FF_CODE_PAGE 869` is at `bdmfs_fatfs/src/include/ffconf.h:87`, not `:101` as the finding states (the value and the `#if`-guarded table structure at ffunicode.c:38 are as described).
- Fix sanity: the CI-diff-gate alternative is the LESS option and the finding offers it; the generator option is justified in-finding as a net deletion of ~2.44 MB. No objection. Note the pair-count drift slightly *understates* the duplication (more identical pairs than claimed), so the finding's direction is conservative.

### RE-POPS-046 — VERIFIED

- Bundle steps read at the cited lines: `rolling-release.yml:228` and `experimental-release.yml:224` are the `git ls-files -z` lines inside the `source/` copy loops; both loops copy every tracked path except `POPSTARTER/` (which ships at the zip root instead), exactly as described.
- Re-derived with `git ls-files` + on-disk sizes at the pin: **609 tracked files, 30,417,169 B total** ✓ (exact). `.research/`: **312 files, 21,197,583 B** ✓ (exact) = 69.7% (finding: 70% ✓).
- The BDMAssault tarball inside the tree is `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz` at 1,466,084 B ("1.4 MB" ✓), and it is not under `POPSTARTER/`, so it is indeed copied into `source/` a second time alongside its extracted/embedded payloads.
- Fix sanity: excluding `.research/` (or dropping the `source/` copy) is a pure deletion; LESS-NOT-MORE clean. Partial thematic overlap with RE-POPS-050 (binaries tracked/shipped twice) is scope-distinct — 046 is about the release-zip payload, 050 about git tracking — not a duplicate.

### RE-POPS-051 — VERIFIED

- `src/elf_loader/loader.c`: **855,821 B, 8,740 lines** ✓ (exact, `stat` + `wc -l`); git-tracked ✓. Header lines 1–5 as cited; line 4: `unsigned int size_loader_elf = 139700;` ✓.
- Child source `src/elf_loader/src/loader/src/loader.c`: **442 lines** ✓.
- `src/elf_loader/Makefile`: `.PHONY: FORCE` (line 13); rule at lines 30–32 — `loader.c: src/loader/bin/loader.elf src/loader/src/loader.c FORCE` → `$(EE_STRIP)` → `$(BIN2C) … loader_elf` — so the blob is regenerated under FORCE on every build ✓. The comment at lines 27–29 states verbatim that "CI (compilation.yml / rolling-release.yml) validates blob parity by running bin2c on THIS file and cmp'ing against loader.c", confirming the finding's "carried purely as a checksum fixture" characterisation. Cited range 28–31 covers the comment tail and the rule.
- Fix sanity: untracking the generated file and having CI compare fresh-vs-fresh is sound and is a net deletion; the finding correctly identifies the CI parity step as the thing that must be re-pointed.

### RE-POPS-057 — VERIFIED

- Root `Makefile:338-339` states verbatim: "The iop/ata_bd_fast vendored source and its build rule below are kept but unused." The rule is at 340–341; the actually-embedded blob is built at 343–344 from `iop/embed/ata_bd.irx`, and CI checksum-pins that binary in all three build workflows (SHA-256 `16c5d9f0…f742f4`, matching the comment).
- "Built by nothing" re-derived: a repo-wide grep for `ata_bd_fast` outside its own tree returns only Makefile lines 338 and 340 — no workflow, script, doc, or prerequisite list ever names the rule's target `iop/ata_bd_fast/ata_bd.irx`.
- Line count: `ps2atad.c` 1,593 + `atad.h` 132 = **1,725 lines** ✓ (exact for the two cited source files; the whole tree incl. Makefile/exports/imports is 1,874 lines).
- Spot anchors hold: header "based on ATAD v2.7" (ps2atad.c:14); the SDK 3.1.0 / ATAD 2.9 divergence TODO at ps2atad.c:46–48 ✓; the phantom-slave probe cap comment/code at 444+ and 1243+ ✓.
- Fix sanity: delete tree + dead rule, keep the pin comment — pure deletion, LESS-NOT-MORE clean. (Consistent with, not duplicative of, RE-POPS-056/058: different artifacts.)

### RE-POPS-075 — VERIFIED

- `official-release.yml` read in full (131 lines). Hardcoded 1.4.4 at: name (line 1) ✓, concurrency group `popsloader-1.4.4-release` (line 17) ✓, verification greps `POPSLDR_VER = "v1.4.4"` / `Version=1.4.4` / `RELEASE_1.4.4.md` (lines 47–49) ✓, and asset/manifest text (lines 96–105: `PS1_POPSLOADER-1.4.4.zip`, manifest header, sha256sum list) ✓ — plus further instances the finding doesn't cite (lines 79–80, 93, 115–128: tag, title, notes file), which strengthen it.
- `retract-mislabeled-ember-beta.yml` read in full (40 lines). Trigger at lines 5–9: `push` to `master` with `paths: ['.github/workflows/retract-mislabeled-ember-beta.yml']` — it can only ever fire on its own edit ✓. `permissions: contents: write` (line 11) ✓. Its step exits 0 when the release is absent (lines 25–28) ✓, so it is inert automation going forward. (The finding's "it already performed its one deletion" is history that cannot be proven from the tree alone; everything checkable about the workflow's present inertness is exact.)
- Fix premise verified: the rolling workflow already derives its version from `etc/boot.lua` (`rolling-release.yml:311`, sed extraction of `POPSLDR_VER`), so parameterising official-release the same way uses an existing in-repo pattern. Deleting the retract workflow is a pure deletion. LESS-NOT-MORE clean.

### RE-POPS-103 — VERIFIED

- Gate blocks diffed directly: `compilation.yml:112-176`, `rolling-release.yml:106-170`, `experimental-release.yml:102-166` are each exactly 65 lines. `diff` between compilation↔rolling and compilation↔experimental shows only: six comment lines present in compilation's copy that the others' ranges start after, the pip-install line wrapped differently, and a trailing "Report ELF size" step in the release copies. The Lua-syntax gate (including the "it used to silently skip…" comment history, present in all three), the in-container host-harness step, the embedded-build-identity step and the bundle step are otherwise verbatim — triplication confirmed.
- Publish logic diffed directly: the inline Python heredocs (`rolling-release.yml:359-519`, 161 lines; `experimental-release.yml:350-501`, 152 lines) differ in exactly six substantive lines — notes path (`ROLLING_NOTES.md`/`EXPERIMENTAL_NOTES.md`), fallback notes text, channel name strings (×3), and the stale-asset prefix (`POPSLOADER-rolling-release`/`POPSLOADER-experimental`) — i.e. "only names/notes/tag changed" ✓, and "~170-line" is a fair rounding of 152–161. (The finding's experimental range 270–501 starts at the bundle step rather than the publish step at 334; the range does contain the publish program and the duplication claim is unaffected.)
- Fix sanity: one reusable workflow/composite + one parameterised `tools/` publish script is a consolidation, not an addition; risk is honestly rated Med. RE-POPS-104 is the acknowledged symptom of this triplication (cross-referenced inside 104 itself), not a hidden duplicate.

### RE-POPS-104 — VERIFIED

Gate matrix re-derived by grepping all three workflows' `lua-harness` jobs:

| Gate | compilation.yml | rolling-release.yml | experimental-release.yml |
|---|---|---|---|
| `png_decoder_harness.py` | line 33 ✓ | line 40 ✓ | **absent** |
| `host_harness.py` / `pad_harness.py` / `test_disc_layout.py` / `test_udpfs_config_runtime.py` | lines 41–44 ✓ | lines 48–51 ✓ | lines 44–47 ✓ |
| `docs_verify.py` | line 52 ✓ | **absent** | **absent** |
| translation tests | line 54 ✓ | line 53 ✓ | line 49 ✓ |
| `test_udpfs_integration.py` | line 57 ✓ | line 56 ✓ | line 52 ✓ |

Exactly as the finding states: rolling omits only `docs_verify.py`; experimental omits both `docs_verify.py` and `png_decoder_harness.py`. Cited ranges (compilation 49–55, rolling 28–57, experimental 31–53) all land on the harness jobs. The supporting quote also checks out — compilation.yml:45–51 comments that docs_verify "sat unwired and red" class drift is what the step exists to catch. Fix (one line per workflow, or inherit via 103) is minimal; LESS-NOT-MORE clean.

### RE-POPS-105 — VERIFIED

- `tools/test_udpfs_integration.py` read in full (117 lines). Structure exactly as described: lines 13–27 are real blob pins (SHA-1 git-blob hashes, sizes, ELF header checks); lines 83–94 cross-check `PROVENANCE.json` (SHA-256 + sizes + the CRLF upstream variant); lines 95–108 do byte comparisons against a kit zip when one is passed.
- The "integration" half (lines 35–79) counted: 40 `assert` lines in the range, of which 38 are source-text substring assertions (`assert "…" in ui/system/cpp/assets/make`, incl. two `not in` slice checks at 46/61 and the dual-check at 66); the loop asserts at 73–75 execute ×2 keys and at 77 ×3 keys, bringing executed substring checks to ≈44 — the finding's "~45 `assert "literal string" in file_text` checks" is accurate. Lines 78–79 are the only non-substring asserts in the range (file-existence). These checks pass on a comment containing the literal and fail on a behaviour-preserving rename, as claimed.
- The contrast file exists and is as described: `tools/test_udpfs_config_runtime.py` loads the real `system.lua` UDPFS validator into a lupa Lua runtime and executes it.
- Fix sanity: rename + migrate literals into the runtime harness over time, explicitly "do not add more substring asserts" — LESS-NOT-MORE clean.

### RE-POPS-106 — VERIFIED

- Full tracked-tree SHA-256 census re-run. `.research/assets/` duplicate groups — exactly six pairs, redundant bytes (one copy per pair) re-derived:
  - `1165364186-…-L2.png` / `3667653909-…-L2.png` — 867 B
  - `1712503932-…-R2.png` / `2283666138-…-R2.png` — 976 B
  - `2651471562-…-T.png` / `3050099753-…-T.png` — 1,423 B
  - `2984521000-…-Select.png` / `3405191067-…-Select.png` — 475 B
  - `2667142094-356screenshot1.gif` / `356screenshot1.gif` — 18,611 B
  - `1258137434-pops05_zps81df52b9.jpg` / `pops05_zps81df52b9.jpg` — 35,200 B
  - **Total redundant: 57,552 B** ✓ (exact).
- `OFFICIAL_NOTES.md` and `RELEASE_1.4.4.md`: both **1,841 B, SHA-256 `faa3da5d5149426c…`** — byte-identical ✓. Combined saving 57,552 + 1,841 = 59,393 B ≈ the claimed "−59 KB" ✓.
- One prose nuance (figures unaffected): the finding frames the pairs as "numeric-prefix name vs plain name", but four of the six pairs (L2, R2, T, Select) are numeric-prefix vs a *different* numeric-prefix name; only `356screenshot1.gif` and `pops05…jpg` pair a numeric name with a plain one. The pairs, names cited, and bytes are all exact.
- Fix sanity: deleting one member per pair is a pure deletion; the finding correctly conditions which name to keep on the site generator's references.

---

## Tally

| Verdict | Count | IDs |
|---|---|---|
| VERIFIED | 9 | 042, 046, 051, 057, 075, 103, 104, 105, 106 |
| VERIFIED-DRIFT | 1 | 045 (pair census 37/20 → corrected 43/26, differing count 17 exact; ffconf anchor :101 → :87; all byte totals exact) |
| WEAKENED | 0 | — |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |

## Candidates (new defects — not verdicts)

None. No new repo defect surfaced during re-derivation. Two non-defect observations: (1) RE-POPS-103/104 are a cause/symptom pair and RE-POPS-046/050 share a theme, but each pair is scope-distinct and cross-aware — no hidden duplicates among the assigned ten; (2) the tarball verification tree was re-extracted into a nested directory by a parallel worker mid-run — an environment event, not a repo issue; all tarball figures were re-verified after the move.
