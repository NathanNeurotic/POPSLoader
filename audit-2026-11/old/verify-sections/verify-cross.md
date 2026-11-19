# Sable Audit — VERIFICATION (adversarial re-derivation): Cross-repo X-18, X-31, X-49, X-50

- **Verifier role:** adversarial re-verification worker. Each finding was assumed WRONG and re-derived from source in the clones; original reports were used only to locate the claims, never as evidence.
- **Mode:** READ ONLY in all five clones. No clone was edited, updated, or committed to.
- **Date:** 2026-11-14

## Pin checks (verified at start AND end of this pass; `git status --porcelain` empty in all five at both checks)

| Repo | Expected pin (task) | Clone HEAD (full) | Clean |
|---|---|---|---|
| RiptOPL | `2e347d5ac885` | `2e347d5ac885cd0ff73e9ad4143781946396f492` | yes |
| Launchstation | `9fb0598a79f0` | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` | yes |
| POPSLoader | `29272cddbf01` | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` | yes |
| Simple-Media-System | `e65ced39a27e` | `e65ced39a27eee8d996e9257e21594d1cac1c93d` | yes |
| PS2-Servers | `c5f021c4d386` | `c5f021c4d38698860f56b03498adc261dbb8d8dd` | yes |

## Verdict table

| ID | Verdict | One-line evidence |
|---|---|---|
| X-18 | **WEAKENED** | Core chain re-derived exactly (Launchstation `src/dash_apps.c:180-181` spaced writer → RiptOPL LEGACY latch + verbatim key → exact-match miss → app dropped), but a second Launchstation writer (`src/filer_actions.c:1924`) writes the correct unspaced form, so only the dash_apps Edit-metadata path is broken — see reasoning. |
| X-31 | **VERIFIED** | RiptOPL `modules/network/udpfs_shared/src/udprdma.c:185,192-193` copies wire `hdr_word_count*4` (≤60 B) unchecked into the registered buffer; registered buffer is the 8-byte `udpfs_msg_result_reply_t` (`modules/network/udpfs_ioman/src/udpfs_packet.h:224-230`, registered `udpfs_shared/src/udpfs_core.c:91,94`); SMS `iop/SMSUdpfs/udpfs/src/udprdma.c:202-214` clamps on `hdr_size <= s->rx_hdr_size` and drains in 32-byte steps; round-9 `rx_hdr_size` note CONFIRMED (below). |
| X-49 | **WEAKENED** | Census tallies reproduce exactly (10 copies; A: 4 affected / 1 correct among 5 BT; B: 8 affected / 2 correct; no BT copy correct on both), but the finding's stronger "no copy free of both / all 10 carry at least one" sentence is refuted by RiptOPL `modules/pademu/ds34usb.c` (A not-applicable + B correct = carries neither) — see reasoning and full census. |
| X-50 | **VERIFIED-DRIFT** | Ranking re-derived: Launchstation IOP vmcman 0/3 checks, Launchstation EE `mc_card_view.c` 3/3, RiptOPL `sysCheckVMCEx` best gate — but the original RiptOPL line citations are wrong at this pin; corrected lines are `src/platform/sysvmc.cpp:179-181` (size-only), `:210-213` (full superblock), `:214-216` (strict probe), not `:177-193 / :230-238 / :236-238` — see reasoning. |

---

## X-18 — full reasoning (WEAKENED)

**What re-derivation confirms, link by link:**

- **Writer (broken path):** `Launchstation/src/dash_apps.c:177-188` (`editMetadata`) builds, and at `:191` writes via `dashWriteFile(meta, text, len)`, where `meta` is `<dir>title.cfg` from `dashLibMetadataPath` (`src/dash_lib.c:368`). Format strings, verbatim: `"title = %s\r\n"` (`dash_apps.c:180`), `"boot = %s\r\n"` (`:181`) — plus identically spaced `description = `, `author = `, `version = `, `category = ` (`:182-185`). The file is only created when no `title.cfg` already exists at that path (`genOpen(meta, FIO_O_RDONLY)` probe, `dash_apps.c:163-167`), and the user is then dropped into the text editor; saved unchanged, the spaced form is what lands on disk.
- **Classifier:** the file opens with two `#` comment lines (comments never latch a format). First key line `title = <name>`: `RiptOPL/src/core/config.cpp:129` `cfgClassifyLine` requires BOTH a space before `=` AND a trailing `;` for LIBCONFIG (`:155-163`); there is no `;`, so the file latches LEGACY (`configReadFileBuffer` latch at `:1140-1148`). RiptOPL's own comment concedes the case: `config.cpp:154` — `"title = Foo" -> hand-edited legacy: space, but no ';' -> stays LEGACY`.
- **Splitter:** legacy `splitAssignment` (`config.cpp:167-193`) copies the key verbatim up to `=`, so the stored key is `"title "` (trailing space) and the value keeps its leading space.
- **Lookup:** `ConfigSet::find` (`config.cpp:257-263`) is an exact `strncmp` over the stored key; `"title "` ≠ `"title"`. `appScanCallback` (`RiptOPL/src/sources/appsupport.cpp:735`) requires BOTH `configGetStr(APP_CONFIG_TITLE)` and `configGetStr(APP_CONFIG_BOOT)` (`include/appsupport.h:15-16`, file name `:19`); both keys carry the trailing space, so both lookups miss and the app is silently skipped (only a `LOG("APPSUPPORT item has no boot/title.")` on the failure branch). No error in either program. **Silent drop, not partial parse — confirmed.**
- **Launchstation's own reader is unaffected, as claimed:** `dashKvParse` (`src/dash_store.c:65-105`) trims the line, the value, and the key again after splitting (`:86,91,92`), so Launchstation reads its own spaced file fine.

**Why WEAKENED, not VERIFIED — the defeating scope evidence:** Launchstation has a **second, correct writer** the original finding never mentions:

- `Launchstation/src/filer_actions.c:1924` — `make_title_cfg()` writes `"title=%s\nboot=%s"` (unspaced, the dialect RiptOPL parses), to `<path>title.cfg` (`:1925-1932`).
- It is reachable from two UI surfaces: the legacy filer (`src/filer_browser.c:1589`) and the dashboard File Browser's "Create title.cfg" operation (`src/dash_browser.c:1203` `opTitleCfg`, menu entry `dash_browser.c:2824`).

So the claim as stated ("Launchstation writes a `title.cfg` dialect RiptOPL silently cannot read — app never appears") is true **only for the Apps → Edit metadata starter** (`dash_apps.c`). A user who creates `title.cfg` through the File Browser path gets a file RiptOPL reads correctly. No other RiptOPL reader rescues the spaced form (the config chain above is the only `title.cfg` reader; there is no trimming reader elsewhere), and no other Launchstation writer uses the spaced form. Corrected claim: *the `dash_apps.c` starter template (two lines, `:180-181`) is the family's only spaced writer; fix stays exactly as filed — emit the unspaced form there.*

## X-31 — notes on the VERIFIED verdict (incl. the round-9 note)

- Wire control: `hdr_word_count` is a 4-bit field, "0-60 bytes" (`RiptOPL/modules/network/udpfs_ioman/src/udprdma_packet.h:89`); `hdr_size = hdr_word_count * 4` at `udpfs_shared/src/udprdma.c:185` (max 60).
- Unchecked copies at `udprdma.c:192-193` (registered buffer) — no comparison against `s->rx_hdr_size` anywhere in the RiptOPL copy. The no-buffer branch (`:195-197`) reads the same `hdr_size` into `uint8_t dummy[UDPRDMA_MAX_APP_HDR]`; the macro is 32 (`udprdma_packet.h:103`), so that branch also overruns for `hdr_size > 32`. (Original text wrote `dummy[32]`; the source spells it via the macro — same size, not a drift.)
- Registered buffers: `_recv_with_result` registers a stack `udpfs_msg_result_reply_t result` (`udpfs_core.c:91`, registration `:94`) — 8 bytes by construction (`udpfs_packet.h:224-230`: 1 + 3 + 4, comment "Generic result reply (8 bytes)"); the shared write-done buffer `g_write_rx_buf` is `sizeof(udpfs_msg_write_done_t)` at `udpfs_core.c:23`. Overflow magnitude: up to 60 − 8 = 52 bytes past the registered buffer.
- SMS clamp, re-read in full: `Simple-Media-System/iop/SMSUdpfs/udpfs/src/udprdma.c:186-197` (comment naming this exact overflow), `:202-203` copy only when `hdr_size <= s->rx_hdr_size`, `:208-212` drain loop in `sizeof(dummy)` (32-byte) steps. **SMS clamps — confirmed.**
- **Round-9 note CONFIRMED:** in RiptOPL's `udprdma.c`, `rx_hdr_size` occurs exactly twice — the field declaration (`:71`) and the store in `udprdma_set_rx_app_header` (`:736`). It is never read anywhere in the RiptOPL tree (tree-wide grep returns only those two sites plus the SMS copy). In SMS it is read at the clamp (`udprdma.c:203`). The stored-but-never-read claim stands, and the prescribed clamp can indeed use the stored value directly.

## X-49 — full census re-derivation

**Enumeration (done independently, two nets):** (1) filename search `*ds34*` over all five trees; (2) distinctive-string net over all `.c/.h/.cpp/.py/.md` for `hid_LEDRumble`, `power_level`, `PS4_11_REPORT_LEN`, `PS3_01_REPORT_LEN`. Both nets return the same driver set: **10 IOP source copies** (5 BT + 5 USB) in three repos. Exclusions, verified: Simple-Media-System ships only binaries (`irx/ds34bt.irx.xz`, `irx/ds34usb.irx.xz`, no IOP source — cannot be entered); PS2-Servers contains no ds34 code at all; all 8 EE client libraries (`libds34bt.c`/`libds34usb.c` in Launchstation, POPSLoader, RiptOPL, SMS) contain no `power_level`, no `LEDRumble`, no `PS4_11` — neither defect site. RiptOPL pademu BT renames the builder to `hid_LEDRumbleCommand` (decl `modules/pademu/ds34bt.c:348`, def `:1144`) — caught by the string net, as in the original.

**Constants (verified per BT header):** `PS3_01_REPORT_LEN = 0x30` = 48 (e.g. `Launchstation/iop/ds34bt/iop/ds34bt.h:247`, `POPSLoader/modules/pademu/ds34bt.h:227`, `RiptOPL/modules/pademu/ds34bt.h:224`); `PS4_11_REPORT_LEN = 0x4D` = 77 (same headers `:251 / :231 / :228`). Every BT copy: buffer `u8 led_buf[PS4_11_REPORT_LEN + 2]` = 79 B, `size = 2`, DS4 branch `size += PS4_11_REPORT_LEN` → 79 B sent via `HID_command`. Affected memset zeroes `PS3_01_REPORT_LEN + 2` = 50 B → **29 uninitialised bytes sent**. Battery table in all 10 copies: `static u8 power_level[] = {0x00, 0x00, 0x02, 0x06, 0x0E, 0x1E}` — 6 entries, valid indices 0–5.

### Census table (every copy, both defects)

| # | Copy | Defect A (BT memset DS3-len / DS4-len) | Defect B (battery `power_level[]` index) |
|---|---|---|---|
| 1 | Launchstation `iop/ds34bt/iop/ds34bt.c` | **AFFECTED** — buffer `:1208`; DS4 memset `:1243` `PS3_01_REPORT_LEN + 2`; send `:1263` / `HID_command` `:1273` | **AFFECTED** — table `:261`; index `:1333`; guard `:1332` only `PSButtonState && Power != 0xEE` |
| 2 | Launchstation `iop/ds34usb/iop/ds34usb.c` | NOT-APPLICABLE — static `usb_buf[64+32]` `:62`; `LEDRumble` memset `sizeof(usb_buf)` `:414`; DS4 send fixed 32 B `:450` | **AFFECTED** — table `:45`; index `:299`; guard `:298` only `!= 0xEE` |
| 3 | POPSLoader `modules/ds34bt/iop/ds34bt.c` | **CORRECT** — buffer `:1208`; DS4 memset `:1243` `PS4_11_REPORT_LEN + 2`; send `:1263` / `:1273` | **AFFECTED** — table `:261`; index `:1333`; guard `:1332` only `!= 0xEE` |
| 4 | POPSLoader `modules/ds34usb/iop/ds34usb.c` | NOT-APPLICABLE — `usb_buf` `:62`; memset `sizeof` `:414`; send 32 B `:450` | **AFFECTED** — table `:45`; index `:299`; guard `:298` only `!= 0xEE` |
| 5 | POPSLoader `modules/pademu/ds34bt.c` | **AFFECTED** — buffer `:1147`; DS4 memset `:1181` `PS3_01_REPORT_LEN + 2`; send `:1200` / `:1208` | **AFFECTED** — table `:256`; index `:1276`; guard `:1275` only `!= 0xEE` |
| 6 | POPSLoader `modules/pademu/ds34usb.c` | NOT-APPLICABLE — `usb_buf` `:56`; memset `sizeof` `:446`; send 32 B `:484` | **AFFECTED** — table `:44`; index `:304`; guard `:303` only `!= 0xEE` |
| 7 | RiptOPL `modules/ds34bt/iop/ds34bt.c` | **AFFECTED** — buffer `:1208`; DS4 memset `:1243` `PS3_01_REPORT_LEN + 2`; send `:1263` / `:1273` | **AFFECTED** — table `:261`; index `:1333`; guard `:1332` only `PSButton && Power != 0xEE` |
| 8 | RiptOPL `modules/ds34usb/iop/ds34usb.c` | NOT-APPLICABLE — `usb_buf` `:62`; memset `sizeof` `:562`; sends 32 B (DS4 `:598`) / 48 B (DS5 `:617`, `#ifdef`-gated) from the fully zeroed buffer | **AFFECTED** — table `:45`; index `:338`; guard `:337` only `!= 0xEE` |
| 9 | RiptOPL `modules/pademu/ds34bt.c` (`hid_LEDRumbleCommand`) | **AFFECTED** — buffer `:1146`; DS4 memset `:1179` `PS3_01_REPORT_LEN + 2`; send `:1198` / `:1206` | **CORRECT** — table `:245`; index `:1252` on local `reported_power` (derived `:1236-1240`: press-emu → `0x05`, else `report->Power`); guard `:1251` `reported_power <= 0x05` |
| 10 | RiptOPL `modules/pademu/ds34usb.c` | NOT-APPLICABLE — `usb_buf` `:57`; memset `sizeof` `:399`; send 32 B `:437` | **CORRECT** — table `:45`; index `:333`; guard `:332` `report->Power <= 0x05` |

### My numbers vs the claimed numbers

| Measure | Claimed (original) | Mine (re-derived) | Match |
|---|---|---|---|
| Total IOP source copies | 10 | 10 (5 BT + 5 USB) | ✓ |
| Defect A, among BT copies | 4 affected / 1 correct | 4 affected (#1, #5, #7, #9) / 1 correct (#3, POPSLoader standalone BT) | ✓ |
| Defect A, USB copies | 5 not-applicable | 5 not-applicable (whole-buffer `sizeof` memset in all five) | ✓ |
| Defect B | 8 affected / 2 correct | 8 affected (#1–#8) / 2 correct (#9, #10, RiptOPL pademu pair) | ✓ |
| No copy correct on both | claimed | True **for BT copies** (the only copies where A can occur): #3 is A-only-correct, #9 is B-only-correct, the other three BT copies are correct on neither | ✓ (scoped) |

**Why WEAKENED despite the exact tallies:** the original finding's Problem text and census headline go one step further — "no copy free of both" / "all 10 copies ship at least one of the two" / "9 of 10 carry … the tenth still carries the battery defect". That step is **refuted by copy #10**, RiptOPL `modules/pademu/ds34usb.c`: defect A cannot occur there (USB report shape; the whole 96-byte `usb_buf` is zeroed at `:399` before the fixed 32-byte send at `:437`) and defect B is correctly clamped (`:332-333`). That copy therefore carries **neither** defect, and the true union is **9 of 10 copies carrying at least one defect, 1 copy (RiptOPL pademu USB) carrying none** — not 10 of 10. The per-defect tallies, both reference fixes, both fix transcriptions, and the "no BT copy correct on both" statement all stand unchanged; only the union/headline sentence overstates exposure by one copy.

## X-50 — full reasoning (VERIFIED-DRIFT)

**Check-by-check re-derivation (A = superblock geometry sanity, B = FAT index bounds, C = name termination):**

| Check | Launchstation IOP vmcman (worst) | Launchstation EE `src/mc_card_view.c` (best parser) | RiptOPL EE `sysCheckVMCEx` (best gate) |
|---|---|---|---|
| A. Geometry | **ABSENT.** Only magic (`iop/vmcman/src/main.c:1383-1386`) + version-digit check (`:1388-1389`) precede the raw copy of 0x150 page-0 bytes over the `mcman_setdevspec`-derived values (`main.c:1334-1354` derived; copy loop `main.c:1391-1393`). Card fields then divide/index downstream (e.g. `%`/`/` by `clusters_per_block` at `:1435,1439`). The local VMC mount validator checks only magic, cardtype, `pagesize ∈ {512,528}` and total file size (`iop/vmcman/src/mciomanx_backing.c:107-141`). | **PRESENT, strongest form.** `mcViewOpen` (`src/mc_card_view.c:191-286`): image size must be an exact power-of-two MiB raw or 528-byte ECC variant (`:205-219`); magic memcmp (`:227`); `page_size == 512` and `pages_per_cluster == 2` exactly (`:232`); `pages_per_block` nonzero and even (`:233-235`); `clusters_per_card × 2` == actual page count (`:236-238`); alloc offset nonzero and `< clusters_per_card` (`:239-241`); root cluster == 0 (`:243`); allocatable range = minimum of three derivations under "never trust a single field" (`:249-261`); zero usable = reject. No card-supplied divisor anywhere (strides are compile-time constants). | **PRESENT (gate shape).** Size-only path: magic 27-byte memcmp, `mc_type == 2`, `page_size == 512`, `pages_per_cluster != 0`, 64-bit-widened product == real file size (`src/platform/sysvmc.cpp:179-181`). Full-superblock path: magic, `mc_type == 0x2`, `page_size != 0`, `pages_per_cluster != 0`, `clusters_per_card != 0`, `(u64)size == (u64)pages_per_cluster × clusters_per_card × page_size` (`:210-213`), under the "Widen before multiplying untrusted geometry" comment (`:208-209`). Probe path adds strict form: `page_size == 512`, `pages_per_cluster == 2`, `pages_per_block >= 2` and even (`:214-216`). No FAT/name surface — correctly N/A for B/C, as filed. |
| B. FAT bounds | **ABSENT.** `McGetFATentry` (`main.c:3905-3931`) / `McSetFATentry` (`:3872-3902`) compute `ifc_index` from unbounded `fat_index` and index `ifc_list[32]` (`iop/vmcman/src/mcman-internal.h:312`) with no bound check in either function (both read in full). | **PRESENT.** `fatGet` rejects `dbl >= 32` (`mc_card_view.c:81`) — the exact bound vmcman lacks — and rejects indirect/FAT clusters that are 0 or `>= clusters_per_card` (`:84, :90`); `chainNext` rejects free-cluster links and next indices `>= alloc_usable` (`:114`); `chainRead` bounds the walk by index and step count (`:132`); `mcViewFatLocate` repeats the bounds independently (`:508, :511`). | NOT-APPLICABLE (gate walks no FAT) — as filed. RiptOPL IOP mcemu is likewise N/A: it consumes an EE-supplied spec (`modules/mcemu/mcemu_io.c:22-35` region; page emulation only, no superblock/FAT parsing). |
| C. Name termination | **PARTIAL only.** Card names reach `strlen` ×3 in `mcman_getdirinfo` (`main.c:2043-2044, 2050-2051`), `strcmp` (`:1405, :1411, :2615`), and an unbounded `strcpy(dirent->name, fse->name)` in `mcman_dread2` (`iop/vmcman/src/ps2mc_fio.c:283`, terminator written at `:284` *after* the copy). The one local termination fix covers only the *caller's* `EntryName` copy in `mcman_setinfo2` (`ps2mc_fio.c:389-392`), not card entry names. | **PRESENT, best placement.** `dirEntry` copies the 32-byte field into a 33-byte buffer and forces `name[32] = 0` inside the copy helper itself (`mc_card_view.c:165-176`, terminator `:176`), before any string use; the list API repeats it on output (`:350-351`); icon title copy also terminated (`:313`). | NOT-APPLICABLE (gate reads no directory entries) — as filed. |

**Ranking verdict:** confirmed on re-read — Launchstation holds both extremes in one repo (IOP vmcman: A absent, B absent, C partial; EE viewer: 3/3 in the strongest forms found), and RiptOPL's `sysCheckVMCEx` is the family's best *gate* (a different, correctly-scoped shape: it validates only fields its consumers use). No third implementation exists to disturb the ranking (POPSLoader: no in-repo card parser; SMS: stock SDK `mcman.irx` binary only — both grep-verified again this pass).

**The drift:** every Launchstation citation in the original reproduces at this pin to the line (vmcman `:1391-1393, :3872-3902, :3905-3931`, `ps2mc_fio.c:283`; `mc_card_view.c` `:74-132, :165-176, :191-286` and all sub-lines). The RiptOPL citations do not: the original's `sysvmc.cpp:177-193` (size-only), `:230-234` (full), `:236-238` (strict) correspond at this pin to **`:179-181`**, **`:210-213`**, and **`:214-216`** respectively, inside `sysCheckVMCEx` at `sysvmc.cpp:138`. Substance identical; lines corrected here. Hence VERIFIED-DRIFT, not VERIFIED.

## New candidate findings (X-58 upward)

**None.** Everything new surfaced by this pass is a correction to an existing finding's scope or citations, not a new code defect: the second correct `title.cfg` writer (folds into X-18, above), the defect-free RiptOPL pademu USB copy (folds into X-49, above), and the `sysvmc.cpp` line drift (folds into X-50, above). X-31's dummy-branch overrun was already inside X-31 as filed. No X-58+ is minted.

## Method / limits

- All verdicts are source-level at the pins above; no PS2 build or hardware exists in this VM, so runtime effects (stack-content disclosure, OOB-read landing bytes, controller/card behaviour) remain INFERRED, exactly as in the original findings.
- SMS's ds34 IOP binaries and SMS's stock `mcman.irx` binary were not disassembled; they are excluded from the censuses for the same reason the originals excluded them, and no claim is made about them either way.
