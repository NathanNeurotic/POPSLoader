# Verification — RE-RIPTOPL-232 through RE-RIPTOPL-265

Verifier: adversarial, refute-first. Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`
pinned at `2e347d5ac885cd0ff73e9ad4143781946396f492` (HEAD verified before work;
`git status --porcelain` empty at end — clone stayed clean / read-only).
Report under audit: `~/workspace/Sable-audit-redo/Redo-RiptOPL.md`.

| Finding | Verdict | One-line evidence (file:line) |
|---|---|---|
| RE-RIPTOPL-232 | VERIFIED-DRIFT | 16-retry loops exist with no delay, but at `modules/usb/usbmass_bd/src/scsi.c:289` (read) and `:339` (write), not :310-330/:356-375 |
| RE-RIPTOPL-233 | VERIFIED | Unaligned refill + slot key at `modules/bdm/libbdm/src/bd_cache.c:160-164` (`read(...,sector,...,8)`, `c->sector[blkidx_best] = sector`); geometry 8×512×32 = 128 KiB at `:9-10` |
| RE-RIPTOPL-234 | VERIFIED | `modules/network/smap_udpbd/src/xfer.c:201-214` holds `tx_sema` across `DelayThread(100)` loop; sibling `modules/network/udpfs_smap/src/xfer.c:253-277` releases/re-acquires per attempt |
| RE-RIPTOPL-235 | VERIFIED | Delay-free spin `src/platform/system.cpp:277-280` (`retry = 100; while (retry-- > 0 && fileXioDevctl(...) < 0) ;`) |
| RE-RIPTOPL-236 | VERIFIED | `src/ui/guioverlay.cpp:54` calls `drawArtHud()` every frame when `gEnableDebug`; 224-byte buffer + 32-conversion `snprintf` at `:145,211` |
| RE-RIPTOPL-237 | VERIFIED-DRIFT | 8 inner + 4 outer + 1 logo draws at `src/ui/guisplash.cpp:57-67`, but only when `tapAlpha > 0` (`:57`), not unconditionally every frame |
| RE-RIPTOPL-238 | WEAKENED | Select list walk is dead in shipped builds (`modules/network/SMSTCPIP/sockets.c:862-889`, `lwip_select` gated at `:671` under `FULL_LWIP`, export stubbed in `exports.tab:17`), but the semaphore/`rcvevent` bookkeeping in the same function is live |
| RE-RIPTOPL-239 | REFUTED | The 57 files are run in CI: `.github/workflows/ps2build.yml:71` runs `tools/run_tests.sh -k`, whose loop at `tools/run_tests.sh:5-9` globs every `.github/scripts/test_*.py` |
| RE-RIPTOPL-240 | VERIFIED | All 18 listed suites have no `subprocess`/compile step and assert over source text; worst example exact at `.github/scripts/test_mx4sio_host_boot.py:15-16` including embedded `\n` + indentation |
| RE-RIPTOPL-241 | VERIFIED | Vacuous/either-way CHECKs at `tests/host/test_config.cpp:56` and `:131`; unasserted counters at `tests/host/test_vmc_groups.cpp:16-17,29-36` — reproduced run: `97 groups, 1034 distinct titles, 12 duplicate entries, 8 odd-shaped ids` then `PASS` |
| RE-RIPTOPL-242 | VERIFIED | Skip-to-pass at `tools/run_tests.sh:8`, `.github/scripts/test_iso9660_records.py:112`, `test_install_ports.py:405,411`, plus merged sites `test_zso_validation.py:166-169`, `test_ripps2_art_port.py:131-138`, `test_ripps2_gui_port.py:192-196`, `test_neutrino_cheats.py:19-21,207-210` |
| RE-RIPTOPL-243 | VERIFIED | Extractor/scaffold duplication is pervasive (own census over all 278 suites: 107 `def function(`, 43 `def read(`, 78 `failures = []`); divergent index vs brace-counting extractors at `test_config_escape_roundtrip.py:8-10` vs `test_net_recv_poll.py:16-29` |
| RE-RIPTOPL-244 | VERIFIED | Global monkey-patch at `.github/scripts/hostmap.py:41-55` (`pathlib.Path.read_text = _read_text`, `unhost()` rewrites `host::` calls to pre-refactor names); 18 importers total (11 first-half + 7 second-half listed) |
| RE-RIPTOPL-245 | VERIFIED | Hand-written Python MIPS interpreter at `.github/scripts/test_ee_hook_context.py:19-95` (136 lines total), docstring itself says "not MIPS execution" |
| RE-RIPTOPL-246 | VERIFIED-DRIFT | Dead pre-C++ branches verified in the listed files (e.g. `test_pad_handoff.py:18-19,106-108`; old `src/*.c` paths absent, `src/core/pad.cpp`/`src/app/opl.cpp`/`src/platform/util.cpp` present) — but there are **seven** suites, not six |
| RE-RIPTOPL-247 | VERIFIED | Lossy round-trip pinned as characterisation at `tests/host/test_config.cpp:2-4` and `:102-107` (`gsm_x = 1;` written back flat); finding itself correctly labels the external impact INFERRED/Low |
| RE-RIPTOPL-248 | VERIFIED | `flavours.yml` explicitly names 154 distinct `test_*.py` of 278 in tree (own census matches); glob runner is `tools/run_tests.sh:5-9` — two mechanisms, already drifted |
| RE-RIPTOPL-249 | VERIFIED | ~150-line `shell: python` step at `.github/workflows/docs-sync.yml:43-160`; same External Tools entries written as Markdown f-string (`:68`) and HTML f-string (`:78`); no test references it |
| RE-RIPTOPL-250 | VERIFIED | Pins in `.github/requirements-docs.txt:1-4`; inline duplicates at `.github/workflows/docs-sync.yml:184` and `flavours.yml:350`; single-source uses at `wiki-publish.yml:96` (as `src/.github/requirements-docs.txt`) and flavours wiki job `:355` |
| RE-RIPTOPL-251 | VERIFIED-DRIFT | Main claim holds: `.github/workflows/ps2build.yml:69-71` has no `pip install` anywhere, `requirements.txt:1` is `PyYAML==6.0.3`, four cited suites `import yaml` — but the merged note that `test_ra_language_isolation.py` is "unwired/dormant" is wrong (see 239) |
| RE-RIPTOPL-252 | VERIFIED | Format gate is `h,c`-only at `.github/workflows/check-format.yml:5-19,31-37`; counts reconcile under the stated scope (130 `.cpp` repo-wide outside `third_party`; 115 `.cpp` / 254 `.c` / 431 `.h` under `src`/`include`/`ee_core`/`modules`); local mechanism at `Makefile:541-546` differs and ignores are not passed to CI |
| RE-RIPTOPL-253 | VERIFIED | Dead Makefile: only `.c` EE rules at `Makefile:1197-1203`, no `.cpp` rule; drift verified (assets `tools/assets.py:49-60` 104+24 glyph names vs Makefile PNG list missing `psbbn_bg`/`glyph_*`; `INTERNAL_LANGUAGE_C` at `Makefile:1213` points at nonexistent `src/lang_internal.c`, real generated path `tools/assets.py:117`); repo itself says so at `docs/PS2BUILD-MIGRATION.md:75,112` |
| RE-RIPTOPL-254 | VERIFIED | Hand-maintained size table (7 entries, three historical iLink sizes in comment) at `src/sources/vcdsupport.cpp:1699-1707`, used at `:1712-1717,1758-1765,1768-1798` |
| RE-RIPTOPL-255 | VERIFIED | Stale comment at `include/tar.h:4-8`; structs at `:53-63`; contradicted by kind table at `src/platform/tar.cpp:59-62` and CHT use at `src/sources/supportbase.cpp:1761-1784` |
| RE-RIPTOPL-256 | VERIFIED | Mixed style at `include/pad.h:6-21`: 12 `constexpr int` vs `#define KEY_CROSS/CIRCLE/TRIANGLE/R1` at `:15-18`; repo-wide grep found no `#ifdef KEY_` / `defined(KEY_` use requiring macro form |
| RE-RIPTOPL-257 | VERIFIED | `modules/bdmassault/usbd.irx.ilink` and `usbd.irx.usbexfat` both 48,500 bytes, identical SHA-256 `5ea4818ba1cf5207…` (recomputed); dedupe note at `modules/bdmassault/PROVENANCE.md:24-25` |
| RE-RIPTOPL-258 | VERIFIED | `modules/hdd/atad/ORIGIN.txt` item 4 (lines 17-20) says `.path` assignment is DROPPED; code assigns it at `modules/hdd/atad/src/ps2atad.c:359` |
| RE-RIPTOPL-259 | VERIFIED | `modules/freepad/` contains only `PROVENANCE.md:3-6`; `.github/scripts/install_coherent_freepad.sh` exists nowhere else in tree (grep: sole hit is the note itself); `*.irx` ignored at `.gitignore:15`; Makefile builds padman from stock SDK freepad at `Makefile:1121` |
| RE-RIPTOPL-260 | VERIFIED | `tools/download_lng.sh:5-10` clones branch `main` + `git reset --hard origin/main`; "pinned" claim at `tools/assets.py:5`; pinned contrasts at `tools/download_lwNBD.sh:6-9`, `tools/download_cfla.sh:5-9` |
| RE-RIPTOPL-261 | VERIFIED | Scratch dirs in version anchor exclusion list at `tools/assets.py:203-204` (`.claude`, `.agents`, `.codex`, `.codex-tmp-nhddl`, `.codex-tmp-wle-r3z`) |
| RE-RIPTOPL-262 | VERIFIED | Legacy-Makefile docs verified line-by-line: `README.md:443`, `docs/GSM.md:211-216`, `docs/LANGUAGES.md:27,76,88-99`, `lng/README.md:24-26,42,67,82`, `docs/IGR.md:110-117,120,204`, `docs/AUTOLAUNCH-GLOBAL-SETTINGS.md:139`, `docs/HTTP.md:168-169`; live truths in `ps2.yaml:609,644` (unconditional `GSM_1080P`) and `tools/build_configuration.py:7-10,37-40` (15 configurations incl. `extras`/`extras_ds5`/`diag`, no `-extra1`/`pademu1`) |
| RE-RIPTOPL-263 | VERIFIED-DRIFT | Stale status text is real but the flavours sentence is at `docs/PS2BUILD-MIGRATION.md:101`, not inside the cited `:103-106` (rolling-release sentence is `:104`, open items `:106`); workflow comment at `.github/workflows/flavours.yml:401-405` verified |
| RE-RIPTOPL-264 | VERIFIED | Badge/doc say 31 (`README.md:40`, `docs/LANGUAGES.md:69`); script count: `tools/assets.py` TRANSLATIONS = 33, `Makefile:191-193` = 33, `lng/fork/` = 33 `.yml` files |
| RE-RIPTOPL-265 | VERIFIED | All cited flat paths absent and all actual paths present: `docs/APA-SAFETY.md:43,47,49,50`, `docs/GSM.md:223-224`, `docs/HTTP.md:161,164` (doubled `tools/tools/`; real `tools/pc/http/tests/run.sh` exists), `docs/RETROACHIEVEMENTS.md:520`, `docs/LANGUAGES.md:29-30` |

## Reasoning for non-VERIFIED verdicts

### RE-RIPTOPL-232 — VERIFIED-DRIFT
Mechanism holds: `SCSI_MAX_RETRIES 16` at `scsi.c:14`; both loops retry the full
`scsi_cmd_rw_sector` call with no delay and no permanent-error early exit, returning
`-EIO` only after all 16 fail. Citations are off: the read loop is at `scsi.c:289-296`
and the write loop at `scsi.c:339-346`, not :310-330 / :356-375. The status function is
at `usb_mass.c:305-326`, not :317-340. One further narrowing: reset recovery is **not**
performed on every failed attempt — `usb_bulk_manage_status` (`usb_mass.c:320-323`)
calls `usb_bulk_reset(dev, 3)` only when the CSW read failed, the signature/tag
mismatch, or `csw.status == 2`. A plain check-condition failure (status 1) retries 16
times without a reset. The fix (reduce to ~3 attempts) remains sane and LESS-compliant.

### RE-RIPTOPL-237 — VERIFIED-DRIFT
The draw count is exact when the glow is visible: 8 inner taps (`guisplash.cpp:60-61`),
4 outer taps (`:63-64`), plus the logo itself (`:67`) = 13. But the taps are gated by
`if (tapAlpha > 0)` at `:57`, where `tapAlpha = alpha * strength * 0.16` — during the
fade-in/out ends of the splash (small `alpha`) `tapAlpha` truncates to 0 and only the
single logo draw happens. "13 full-logo draws every frame for the whole boot splash"
overstates that edge. Core judgement (deliberate effect, ~30% saving from dropping the
4 outer taps = 4/13) stands.

### RE-RIPTOPL-238 — WEAKENED
True part: in shipped builds `lwip_select` is compiled only under `FULL_LWIP`
(`sockets.c:671`, gate at `:623/:630`) and its export slot is `ps2ip_Stub`
(`exports.tab:17`), and `ps2.yaml:199-201` builds SMSTCPIP with no `FULL_LWIP`
define — so `select_cb_list` is always empty and the `while (1)` list walk at
`sockets.c:862-889` does one wasted traversal per event.
Defeating/narrowing evidence for the rest: `event_callback` is not select-only
machinery. The same semaphore protects the `sock->rcvevent++ / --` and
`sendevent` updates at `sockets.c:843-856`, and `rcvevent` is consumed by the
**ungated** `lwip_recvfrom` non-blocking check at `sockets.c:375`
(`(flags & MSG_DONTWAIT) && rcvevent <= 0` → `EWOULDBLOCK`) — a live path in
shipped builds. The semaphore is also created only once (`if (!selectsem)`), not
per event. So the prescribed fix as worded ("gate list walk/semaphore creation")
would break live recv bookkeeping if the semaphore half were applied. True scope:
gate/delete only the `select_cb_list` walk; keep semaphore creation and the
event-counter update.

### RE-RIPTOPL-239 — REFUTED
The central claim — 57 files "referenced by no workflow", "silently inert", "no
run-all entry point" — does not hold. `.github/workflows/ps2build.yml:71` (the
workflow that runs on every push/PR) runs `tools/run_tests.sh -k`, and
`tools/run_tests.sh:5-9` loops `for t in .github/scripts/test_*.py` — i.e. every
one of the 57 named files **is** executed in CI, transitively through the glob
runner. The finding's stated census method (concatenate workflow YAML, match
filenames + the two flavours glob patterns) simply missed this transitive glob —
a method its own sibling findings describe correctly (RE-RIPTOPL-248 acknowledges
the ps2build/rolling glob runner; RE-RIPTOPL-251 states ps2build runs the full
suite via `run_tests.sh`). Consequences that fall with it: `test_pccf.py` and
`test_ratls_host.py` are wired, so the `tests/pccf/*` and `tests/ratls/host_main.c`
suites are not "only" driven by unwired scripts; and the proposed fix (add a loop
job) would duplicate a loop that already runs.
What survives, narrowly: the counts themselves are exact (57 files, 12,240 lines
— recomputed), the RA/VMC cluster counts are right, and the `tests/smb2-live/`
sub-claim stands on its own: `tests/smb2-live/run.sh` is invoked by no workflow
(its exit-2 prerequisite gate is at `run.sh:53-55`, the no-server `readreply` case
at `run.sh:233`), so `browse.c` (258 lines), `keepalive.c` (407) and
`readreply.c` (163) have no CI coverage. That residual is a much smaller finding
than the one filed.

### RE-RIPTOPL-246 — VERIFIED-DRIFT
Every cited dead branch verified, and the dead side is absent at the pin
(`src/pad.c`, `src/opl.c`, `src/bdmsupport.c`, `src/guigame.c`, `src/vmcsaves.c`,
`lng_tmpl/_base.yml` do not exist; the `.cpp` alternatives do). But the finding
says "six suites" in its heading, body and fix while listing **seven**:
`test_pad_handoff.py`, `test_ps1_duplicates.py`, `test_screen_pos_per_mode.py`,
`test_ripps2_boot_video_mode.py`, `test_ripps2_vmc_saves.py`,
`test_udpbd_read_only.py`, `test_zso_validation.py`. Corrected count: 7.

### RE-RIPTOPL-251 — VERIFIED-DRIFT
Main finding verified in full (no `pip install` step anywhere in `ps2build.yml`;
four cited `import yaml` suites at the cited lines; three sibling workflows do
install `requirements.txt`). The merged W13-008 half also holds for the
`udpfs-host-tests` job (no install step; `test_udpfs_transport.py:8` and
`test_udpfs_shared_transport.py:3` import yaml; job header is at
`flavours.yml:320`, steps run to ~:343). Drift: the merged note calls
`test_ra_language_isolation.py` "currently dormant because the file is unwired
(W13-001)" — it is not unwired; it runs via `ps2build.yml` → `tools/run_tests.sh`
(see RE-RIPTOPL-239), where it has exactly the same uninstalled-PyYAML exposure,
so the exposure is broader than the merged note states, not dormant.

### RE-RIPTOPL-263 — VERIFIED-DRIFT
Substance verified: `rolling-release.yml:122-136` uses `tools/assets.py` +
`tools/build_edition.py` (no `make` build), `configurations.yml:23-42` runs
17 edition/configuration entries × 2 toolchains including `ra` and `diag`-family,
`docs/BUILD-CONFIGURATIONS.md` lists 15 configurations, and the stale comment at
`flavours.yml:401-405` is exact. Citation drift: the "flavours.yml builds the main
flavour only" sentence is at `docs/PS2BUILD-MIGRATION.md:101`, not within the
cited `:103-106`; `:104` (rolling-release) and `:106` (open items) are correct.
The finding's own fairness note about the `:3-7` banner is also accurate.

## Candidates (new defects noticed while verifying — not merged into verdicts)

1. **Same stale tar comment in the .cpp**: `src/platform/tar.cpp:9` repeats the
   "RiptOPL wires only TAR_KIND_ART" claim that RE-RIPTOPL-255 files against
   `include/tar.h:4-8`. The 255 fix should be applied to both places or the
   comment will still mislead from the implementation file.
2. **Scratch-dir exclusion list is duplicated**: the five agent scratch dirs
   filed in RE-RIPTOPL-261 at `tools/assets.py:203-204` also appear verbatim in
   the dead Makefile's anchor at `Makefile:111` (`CODE_ANCHOR`). It disappears
   if RE-RIPTOPL-253's Makefile deletion lands, but 261's fix as scoped only
   cleans the `assets.py` copy.
3. **`test_ra_language_isolation.py` PyYAML exposure is live, not dormant**:
   it imports yaml (`test_ra_language_isolation.py:9`), is not named in
   `flavours.yml`, and runs via `ps2build.yml` → `tools/run_tests.sh` with no
   PyYAML install — an additional instance of RE-RIPTOPL-251's main defect,
   beyond the four suites that finding lists.

## Tally

VERIFIED: 27 · VERIFIED-DRIFT: 5 (232, 237, 246, 251, 263) · WEAKENED: 1 (238) ·
REFUTED: 1 (239) · BLOCKED-ENV: 0 — total 34 findings (232–265).
