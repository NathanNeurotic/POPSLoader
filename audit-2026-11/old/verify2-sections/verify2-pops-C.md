# FULL-VERIFICATION — POPSLoader worker C (POPSLOADER-031…047)

- Clone: `~/workspace/audit-clones-2026-11-13/POPSLoader`
- Pin verified before work: `git rev-parse HEAD` = `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (matches the assigned pin; clone untouched, read-only throughout).
- Stance: adversarial — each finding re-derived from the code at the pin; defeating guards/callers hunted for every Cat 6 item.
- POPSLOADER-033 was verified against the **narrowed** version in the MASTER-INDEX §4 revision ledger (REV-010 / REV-033, R3): "the pademu copies are a semantic fork, not drifting photocopies: -033's duplication verdict stands but its merge shape is understated — the realistic minimum is an L-effort refactor of two diverged APIs, not a build-glue change."

## 1. Verdict table

| ID | Verdict | Evidence (one line) |
|---|---|---|
| POPSLOADER-031 | VERIFIED | `system.lua:10843` `local use_minimal_hdd_popstarter_exec = false`; flag referenced only at 10844, 10859, 10873, 11155, 11278 — exactly the five cited branches, no other assignment anywhere. |
| POPSLOADER-032 | VERIFIED | Repo-wide `git grep` for all seven names returns only their definitions (system.lua:944, 4972, 5615, 10364, 11320; ui.lua:3223 `Reset = function`; images.lua:81); live twin `ResolveHddPartitionReadablePath` at system.lua:886, wrapped 1897, called in ui.lua. |
| POPSLOADER-033 | VERIFIED (narrowed) | Narrowed REV-033 holds: line counts 1719/1521 and 806/634 and diff counts 513 / 399 reproduce exactly; standalone copies carry `_start` + SifRpc server (ds34bt.c:1609-1632, 1675) while pademu copies have neither and are consumed only via the `PAD_*` macro layer in `modules/pademu/pademu.c:13-31` — a semantic fork, L-effort refactor, not build glue. |
| POPSLOADER-034 | VERIFIED | `power_level[report->Power]` at exactly ds34bt.c:1333, ds34usb.c:299, pademu/ds34bt.c:1276, pademu/ds34usb.c:304; sole guard `Power != 0xEE`; table is 6 entries (e.g. ds34bt.c:261-263); `u8 Power` (ds34bt.h:309); no clamp anywhere in any copy (only other write is the safe `report->Power = 0x05` press-emu assignment). |
| POPSLOADER-035 | VERIFIED | Non-DVRP probe loop `ps2atad.c:1241-1258` iterates `i < 2` with soft reset + select + probe per device; unconditional `devinfo[1].exists = 0;` at ps2atad.c:1286; DVRP path re-probes device 1 only after it (1288-1300); phantom-slave busy cap at ps2atad.c:491 (`delay > 100000`, comment "~4s instead of ~31s" at 443-450). |
| POPSLOADER-036 | WEAKENED | T42 text-assert block exact at host_harness.py:1776-1790 and 11 of 62 checks are pure source-text asserts, but the re-read count overstates: 25 `read_text` sites in total, only 15 of them re-reads of the two Lua sources already loaded at lines 23-24 (see §2). |
| POPSLOADER-037 | VERIFIED | `.research/build_site.py:12-13` top-level `if os.path.isdir(SITE): shutil.rmtree(SITE, ignore_errors=True)` plus top-level `makedirs`; corpus `print` at line 2375 sits before the `if __name__ == '__main__':` guard at 2376; script is live via `.github/workflows/docs-site.yml:64`. |
| POPSLOADER-038 | VERIFIED | `ps2atad.c:1183` `ata_get_security_status(device, devinfo, NULL);` in `sceAtaSecurityEraseUnit` (Export 12, comment at 1165, exports.tab:17); chain 1111-1114 → `ata_device_identify` (921-929) → PIO-in `ata_pio_transfer` type 2 writes 256 words through `cmd_state->buf16` (711-714); other two callers (1134, 1157) pass `param = ata_param` (1121, 1142); no in-repo caller of the export found by `git grep`. |
| POPSLOADER-039 | VERIFIED | `images.lua:46` `local IMG_FALLBACKS = {}`, read only at images.lua:64 inside `__index`; code-wide grep shows no write/population anywhere (remaining hits are docs recording it is now empty, e.g. COMPONENTS.md:353, DECISIONS.md:376 — the MISSING.png / default.png fallback removal). |
| POPSLOADER-040 | VERIFIED | `.research/build_site.py:903-904` `if len(records) != 34 or len(seen & from_head) != 19: raise ValueError(...)` inside `build_original_image_gap_index` (def at 876), which is called unconditionally in the history page build at line 1474; hard-coded prose counts present as cited ("all 63 wiki pages" line 1095; "2,140 commits" lines 966/971/1069). |
| POPSLOADER-041 | WEAKENED | Missing NULL checks and the DS4 `epCount = 20` / 21-iteration walk are real, but the claimed hang mechanism is wrong: the walk is count-bounded by `while (epCount--)` in both copies, so a zero `bLength` cannot loop forever (see §2 for the corrected, narrower claim and the real underflow hang). |
| POPSLOADER-042 | VERIFIED | `tools/test_disc_layout.py:12-13` are exactly `source.index("          -- An OPL-style _ICO.png")` and `source.index("          -- (EXP56:", start)` (anchors present at ui.lua:3591 and 3612); a missing anchor raises a bare `ValueError` from `str.index`; case count in the test loop is 3 × (2×3 + 4) = 30 as claimed. |
| POPSLOADER-043 | VERIFIED | `ui.lua:3266` `local placeholders = {}`, lookup at 3267, unreachable branch 3268-3288 rendering `PLDR.L("Not implemented yet")` at 3271, under the comment at 3263-3265 "No scenes are placeholders anymore"; no other write to `placeholders` exists. |
| POPSLOADER-044 | WEAKENED | Gutted block, discarded locals and the microsecond unit error all stand (ui.lua:6670-6699, flag default `false` at 1270), but the "counters only ever reset, never read" clause is imprecise: `NavEventCount` is incremented by live code and `DebugPadLast` is read by the block's own comparison (see §2). |
| POPSLOADER-045 | VERIFIED | `build_thread_study` (def .research/build_site.py:1984) calls `render_md(clean_research(raw), strip_prov=False)` twice on the same `raw`: line 1997 for the page body and line 2001 solely to strip tags for the search-index text. |
| POPSLOADER-046 | VERIFIED | First `SLUG_RE`/`slug` pair at .research/build_site.py:90-92, shadowed by an identical pair at 102-104 (bodies byte-identical: `SLUG_RE.sub('-', s.lower()).strip('-')`); the second definition is the one used by the `PAGE_SLUG` loop that follows. |
| POPSLOADER-047 | VERIFIED | `Clamp01` defined at ui.lua:14 (file-scope, used at ui.lua:25) and again, body-identical, as a nested local at ui.lua:1946 inside `WelcomeDraw.Play` (WelcomeDraw at ui.lua:1787), used at ui.lua:1971. |

## 2. Full reasoning for every non-VERIFIED verdict

### POPSLOADER-036 — WEAKENED

What survives, proven:

- The T42 example is exact. `tools/host_harness.py:1785-1786`: `elif _ui.count("UI.PendingHideDrop = entry") != 2:` fails the check, and 1788-1790 use `_ui.index("UI.PendingHideDrop ~= nil") > _ui.index("local ammount = #PLDR.GAMES")` — a string-position proxy for control flow.
- The text-only population is real and countable: the checks whose verdict is computed purely from substring / count / index assertions over re-read source text are T42, T43, T44, T46, T47, T48, T50, T51, T52, T53 and T55 — **11 of the 62 checks** (60 `check("T…")` calls plus the 2 boot-execution checks). 11/62 ≈ 18%, so "roughly a fifth" stands. (T45, T49 and T54 in the same region genuinely execute Lua — T45 via `E(...)` round-trips, T49 "driven for real", T54 drives the real join — so they are not part of the text-only set.)
- Numbering accretion is exact: there is no T4 (sequence runs T1, T2, T3, T5…), and T61/T62 sit at host_harness.py:366/406, before T7 at line 489.

What does not survive as written:

- "The same sources are also re-read from disk at least 25 times per run (`read_text` sites) instead of using the copies loaded at lines 23–24." Measured: there are **25 `read_text` call sites in total, including the initial loads at lines 23–24**. Per file: system.lua is read 10× in total (1 initial + 9 re-reads), ui.lua 7× (1 initial + 6 re-reads) — i.e. **15 re-reads of the two already-loaded Lua sources**, not ≥25. The remaining 8 sites are first reads of other files (main.cpp ×2, luasystem.cpp ×3, retrogem.cpp, Makefile, elf.c).

**Narrower surviving claim:** roughly a fifth of the harness (11 of 62 checks: T42–T44, T46–T48, T50–T53, T55) asserts source text rather than behaviour; the file contains 25 `read_text` sites in total, of which 15 re-read system.lua/ui.lua despite both being loaded once at lines 23–24; there is no T4 and T61/T62 precede T7. Fix and benefit unchanged.

### POPSLOADER-041 — WEAKENED

What survives, proven:

- No NULL checks in either connect path. `modules/ds34usb/iop/ds34usb.c:98` `usb_connect` fetches `device`/`config` and dereferences `config->bLength` at line 128 (`interface = (UsbInterfaceDescriptor *)((char *)config + config->bLength);`) and `endpoint->bmAttributes` in the walk, with no NULL test; `modules/ds34bt/iop/ds34bt.c:86` `bt_connect` does the same at line 111. Their own probes do check: ds34usb.c:87 `if (device == NULL)`, ds34bt.c:53-62 `device == NULL` / `config == NULL`.
- The DS4 hard-code is exact: ds34usb.c:135 `epCount = 20; // ds4 v2 returns interface->bNumEndpoints as 0`, and the do-while walk therefore runs 21 iterations regardless of the descriptor blob's real length.
- Cited ranges drift: usb_connect spans 98–~167 (walk at 138–154), bt_connect spans 86–~157 (walk at 121–142) — not 139–175 / 113–160 as filed, though both cited ranges land inside the functions.

What is refuted:

- "a zero `bLength` … loops forever on the IOP." Both walks are **count-bounded**, not length-bounded: ds34usb.c:152-154 and ds34bt.c:140-142 advance `endpoint = (UsbEndpointDescriptor *)((char *)endpoint + endpoint->bLength);` inside `do { … } while (epCount--);`. With `bLength == 0` the pointer simply stalls and the *same* descriptor is re-processed; the loop still terminates after `epCount + 1` iterations. Zero `bLength` cannot produce an infinite loop in either copy.

Corrected hang mechanism found in the same loop (folded in here, not filed separately — same location, same finding family): `epCount` is a signed `int` set to `interface->bNumEndpoints - 1` (ds34bt.c:117, ds34usb.c:132 for DS3). A device reporting `bNumEndpoints == 0` — a case the DS4 comment at ds34usb.c:135 itself documents as real — makes `epCount = -1`, and `while (epCount--)` then evaluates −1, −2, … (never 0), so the walk is effectively non-terminating while striding through memory by `bLength`. The BT copy and the DS3 branch have no equivalent of the DS4 hard-code guarding this.

**Narrower surviving claim:** both standalone connect callbacks (and, un-cited by the finding, both pademu copies at ds34bt.c:110/135-137 and ds34usb.c:121/145-147) dereference fetched device/config/endpoint descriptors with none of the NULL checks their probes perform, and walk the endpoint blob for a fixed count (21 for DS4) with no bound against the blob's actual length; a zero `bLength` stalls the walk on one descriptor for the remaining iterations rather than looping forever, while a zero `bNumEndpoints` underflows the signed `epCount` to −1 and makes the do-while effectively non-terminating in the BT and DS3 paths. Benefit (remove a hang/corruption-on-connect class for malformed/clone devices) stands; the proposed fix should add an `epCount < 0` / `bNumEndpoints == 0` guard alongside the NULL and `bLength == 0` checks.

### POPSLOADER-044 — WEAKENED

What survives, proven:

- The block is where cited: `bin/POPSLDR/ui.lua:6670-6699`, gated on `UI.InputConfig.DEBUG_INPUT_LOG`, whose default is `false` at ui.lua:1270 (the only other reference to the flag in the file).
- The logging body is gone: locals `up`/`down`/`cross`/`circle` at ui.lua:6677-6680 are computed from `UI.Pad.GPAD` and never used again in the block or anywhere else.
- The unit error is exact: both cadence tests compare `Timer.getTime()` deltas against `1000` (ui.lua:6676, 6689), and `Timer.getTime()` returns microseconds in this codebase (AGENTS.md:79: "`Timer.getTime()` returns MICROSECONDS, not milliseconds… returns raw `clock() - tick` ticks… `CLOCKS_PER_SEC == 1e6`"), so the "1-second" cadence fires every ~1 ms when the flag is on.

What does not survive as written:

- "maintains two timers whose counters are only ever reset, never read." `UI.Pad.DebugPadLast` **is** read — by the block's own comparison at ui.lua:6676. And `UI.Pad.NavEventCount` is not only reset: live code increments it in `emit_nav` at ui.lua:6596 (`UI.Pad.NavEventCount = (UI.Pad.NavEventCount or 0) + 1`, field declared at ui.lua:6496).

**Narrower surviving claim:** the debug block is gutted scaffolding — it computes and discards the four direction locals, and its two timer counters drive nothing: `DebugPadLast` is read only by the block's own (wrong-unit) comparison, and `NavEventCount`'s value is never consumed anywhere in the repo (incremented at ui.lua:6596, reset at 6686/6690, never tested or displayed). Deleting the block and the flag as proposed remains correct; a complete deletion should also drop the now-orphaned `NavEventCount` increment/field if the maintainer wants the counter gone entirely.

## 3. Notes on VERIFIED items where the original text needs a footnote

- **POPSLOADER-033 (VERIFIED, narrowed):** the narrowed REV-033 claim was verified, not the original merge shape. One original parenthetical is additionally inaccurate: the static tables `output_01_report`, `led_patterns`, `power_level` and `rgbled_patterns` are present in all four files, but `link_key` is present in only three — it has no definition or use in `modules/pademu/ds34usb.c` (present in modules/ds34bt/iop/ds34bt.c:273, modules/pademu/ds34bt.c:268, modules/ds34usb/iop/ds34usb.c:57). This does not affect the duplication verdict or the narrowed semantic-fork claim.

## 4. New findings

Zero. Two candidate observations were folded into the verdicts they belong to rather than filed separately: the `epCount = -1` underflow hang (same loop as POPSLOADER-041, §2) and the missing `link_key` in `modules/pademu/ds34usb.c` (a correction to POPSLOADER-033's parenthetical, §3). No other genuinely new, previously unfiled defect was found in this batch; reserved numbers POPSLOADER-117…120 are unused.
