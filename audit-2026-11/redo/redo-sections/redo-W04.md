# W04 — Blind Redo Audit: RiptOPL `include/`, `ee_core/`, `elfldr/`

- Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`, HEAD verified `2e347d5ac885cd0ff73e9ad4143781946396f492` before reading.
- Scope read in full: `include/` (138 headers), `ee_core/` (66 files, C + assembly + Makefiles + linkfiles), `elfldr/` (3 files). 207 files total.
- Rule applied throughout: LESS, NOT MORE. Every count below comes from a script/command actually run during this audit.

---

## W04-001 — Hardcoded parental-lock master password in a public header

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/include/opl.h:56`
- **Problem:** A master password that disables the parental lock is compiled into the binary as a string literal `#define` in a header. (Value deliberately not reproduced here — location only.) Anyone with the source — i.e. anyone, this is a public repo — knows the override for every install's parental lock. The per-user password is a separate config key (`parental_lock_password`, `include/config.h:216`), so the master adds a universal backdoor on top of it.
- **Fix:** Delete the master-password define and the code path that accepts it, leaving only the user-set password. If a recovery path is genuinely needed, it should not be a constant in source.
- **Benefit:** Removes a universal, unchangeable credential from every shipped build.
- **Effort:** S · **Risk:** Low (feature removal is the point; users keep their own password) · **Confidence:** High — READ.

## W04-002 — IGR font: 7 punctuation glyphs are copies of the '?' bitmap

- **Category:** 6 (bugs/security — data correctness)
- **Locations:** `RiptOPL/ee_core/include/igrmfont.h:25,26,27,33,50,54,55,85`
- **Problem:** The 5×7 font table `igrmFontData[68][7]` contains the identical byte row `{0x0e, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04}` for 8 different characters (count verified by grep: 8 occurrences). One of them is `?` (line 54), where that bitmap is plausible; the other seven — `"` (25), `#` (26), `$` (27), `*` (33), `;` (50), `@` (55), `^` (85) — are placeholders that render as a question mark in the in-game menu. Any cheat name, path, or status text containing those characters displays wrong.
- **Fix:** Draw real 5×7 bitmaps for the seven characters and replace the placeholder rows. No code changes — the table is already indexed by ASCII 32..95, so the rows cannot simply be deleted.
- **Justification (fix adds data):** The characters are reachable in displayed text and currently render as a different character; correct glyph data is the smallest possible fix.
- **Benefit:** In-game menu renders `" # $ * ; @ ^` as themselves instead of `?`.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (rows compared byte-for-byte).

## W04-003 — Ten headers have no include guard at all

- **Category:** 6 (bugs/security — build robustness)
- **Locations:** `RiptOPL/include/OSDHistory.h` (101 lines), `RiptOPL/include/ioprp.h` (6), `RiptOPL/include/nbns.h` (25), `RiptOPL/include/ps2cnf.h` (3), `RiptOPL/include/xparam.h` (34), `RiptOPL/ee_core/include/cd_igr_rpc.h` (1), `RiptOPL/ee_core/include/gsm_api.h` (21), `RiptOPL/ee_core/include/gsm_defines.h` (94), `RiptOPL/ee_core/include/modules.h` (94), `RiptOPL/ee_core/include/tlb.h` (1)
- **Problem:** Grep-verified: these 10 headers have neither `#ifndef` guards nor `#pragma once` (no header in scope uses `#pragma once`; no duplicate guard names exist elsewhere). Most hold only declarations or macros, so double inclusion is currently benign — but `ee_core/include/modules.h` defines an `enum OPL_MODULE_ID` plus typedefs with no guard, so any TU that reaches it twice (directly or via two includers) is a hard compile error. The other 128 in-scope headers all follow the guard convention; these are the exceptions.
- **Fix:** Add the project's usual `#ifndef`/`#define`/`#endif` guard to each of the 10, named after the file like its neighbours.
- **Justification (fix adds lines):** ~3 lines per file prevents a real double-inclusion failure class, and matches the convention the other 128 headers already follow. This is the smallest change that closes the hole; no other restructuring.
- **Benefit:** `modules.h` (and the rest) become safe to include from anywhere, in any order.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (grep census over all 148 in-scope headers).

## W04-004 — GSM DTV mode constants defined in three places, in three styles

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/include/renderman.h:18,21`; `RiptOPL/ee_core/include/gsm_defines.h:34-35`; `RiptOPL/ee_core/src/gsm_api.c:28-34`
- **Problem:** `GS_MODE_DTV_576P` (0x53) and `GS_MODE_DTV_1080P` (0x54) are defined independently for the GUI (`renderman.h`), for the ee_core assembler (`gsm_defines.h`), and again in C inside `gsm_api.c`, whose own comment admits the copies must be "kept in sync" by hand. The styles also disagree: `renderman.h` uses a `#define` for 576P but `constexpr int` for 1080P; `gsm_defines.h:34-35` writes the two assignments bare, without the `.equ` every other line in that file uses.
- **Fix:** Within ee_core, delete the `gsm_api.c` copies and take the values from one ee_core-side header; in `gsm_defines.h` write the two lines with `.equ` like the rest of the file; in `renderman.h` use one style for both. The GUI/ee_core pair itself is cross-binary and can stay, with the sync comment kept.
- **Benefit:** One fewer hand-synced copy of a hardware-mode constant; a future mode renumber can't silently split the C and asm sides of ee_core.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (all three sites grep-verified).

## W04-005 — COMPAT_MODE_* bits defined at four sites; one redefinition is live today

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/ee_core/include/ee_core.h:59-66` (full set, modes 1–8); `RiptOPL/ee_core/include/patches.h:14` (`COMPAT_MODE_4` again); `RiptOPL/ee_core/src/asm.S:16-17` (modes 3 and 6 again); `RiptOPL/include/iosupport.h:97-104` (GUI-side full set)
- **Problem:** The same bit values are spelled out four times. The `patches.h:14` copy is not theoretical: `ee_core/src/syshook.c` includes both `ee_core.h` and `patches.h` (verified by grep), so that TU already gets a macro redefinition (benign only because the values happen to match, 0x08). `asm.S` re-derives modes 3 and 6 locally instead of taking them from the header it otherwise mirrors.
- **Fix:** Delete `COMPAT_MODE_4` from `patches.h` (its only includer-with-ee_core.h already has it) and delete the two local defines in `asm.S`, including `ee_core.h`'s values there instead. The `iosupport.h` GUI copy is cross-binary and can stay.
- **Benefit:** One definition per binary for the compat-bit meanings; removes a live redefinition warning and a drift trap.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ.

## W04-006 — GSMSourceGSRegs layout hand-mirrored in three representations

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/ee_core/include/igs_api.h:126-142` (`struct GSMSourceGSRegs`); `RiptOPL/ee_core/src/ra_overlay.c:46-59` (`struct ra_gs_source_regs`, same 11 u64 fields); `RiptOPL/ee_core/src/igrmenu.c:549-557` (raw `extern u64 GSMSourceGSRegs[11]` plus `SRC_PMODE`/`SRC_SMODE2`/`SRC_DISPFB1`/`SRC_DISPLAY1`/`SRC_DISPFB2`/`SRC_DISPLAY2` index macros); storage at `RiptOPL/ee_core/src/gsm_engine.S:57` (`.space 88`)
- **Problem:** One 88-byte block of recorded GS registers has three separate layout descriptions in the same binary. `ra_overlay.c`'s own comment says "Keep this layout in sync with struct GSMSourceGSRegs in igs_api.h / gsm_engine.S" — i.e. sync is manual. If a field is ever inserted or reordered in the engine, the struct, the duplicate struct, and the index macros must all move together or the overlays read the wrong registers.
- **Fix:** Have `ra_overlay.c` and `igrmenu.c` use the single `struct GSMSourceGSRegs` from `igs_api.h` (both are ee_core TUs; the header is in ee_core's own include dir) and delete `ra_gs_source_regs` and the `SRC_*` index macros.
- **Benefit:** One layout definition for a hardware-register block; the sync comment and two copies go away.
- **Effort:** M · **Risk:** Med (layout-critical data shared with assembly; verify field order matches before/after) · **Confidence:** High — READ (all three representations compared field-by-field; the "single header is includable" step is INFERRED from the shared include dir).

## W04-007 — Two macro families for the same GS registers in igs_api.h, plus a third copy in igrmenu.c

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/ee_core/include/igs_api.h:35-38` (`GS_BITBLTBUF 0x50`, `GS_TRXPOS 0x51`, `GS_TRXREG 0x52`, `GS_TRXDIR 0x53`); `RiptOPL/ee_core/include/igs_api.h:90-94` (`GS_GSBITBLTBUF 0x50`, `GS_GSTRXPOS 0x51`, `GS_GSTRXREG 0x52`, `GS_GSTRXDIR 0x53`, `GS_GSFINISH 0x61` duplicating `GS_FINISH 0x61` at line 39); `RiptOPL/ee_core/src/igrmenu.c:687-690` (the `GS_*` four defined yet again, locally)
- **Problem:** The same five register addresses carry two names in one header, and a third private copy in igrmenu.c. Both families are in use (`GS_GS*` in `igs_api.c:222-224`, `GS_*` in `igrmenu.c:731-799`), so neither is dead — they are pure aliases with no semantic difference.
- **Fix:** Keep one family (the `GS_*` names, which igrmenu.c already uses), point `igs_api.c` at it, and delete the `GS_GS*` aliases and igrmenu.c's local re-definitions (it can include the header).
- **Benefit:** One name per GS register address; three definition sites become one.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (definitions and call sites grep-verified).

## W04-008 — freeze_diag_screen.c re-implements freeze_diag_format.c's formatting helpers

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/ee_core/src/freeze_diag_screen.c:42-94` (`ln_str`, `ln_dec`, `ln_hex`, `ln_where`); `RiptOPL/ee_core/src/freeze_diag_format.c:22-49` (`put_str`, `put_dec`, `put_hex`) and `RiptOPL/ee_core/src/freeze_diag_format.c:304-321` (`put_where`)
- **Problem:** The two INGAMEDIAG-only files each carry a private copy of the same four operations: append a string, append decimal, append hex, and append a "module+offset" location — including the same module-table lookup logic in `ln_where`/`put_where`. The only difference is the sink type (fixed line buffer vs streaming buffer).
- **Fix:** Keep one implementation of the four helpers, parameterised by the sink the two files already share conceptually (or have screen.c call format.c's helpers through a tiny line-buffer adapter), and delete the other copy. If the host tests genuinely require both files to stay self-contained, say so in one comment and close this as accepted duplication — but today nothing in either file states that.
- **Benefit:** One copy of the number/location formatting to fix; the two diagnostic surfaces can't drift apart.
- **Effort:** M · **Risk:** Low (diagnostic-only code, host-tested) · **Confidence:** High — READ (both implementations read side by side; net-line win is INFERRED, roughly the size of one helper set).

## W04-009 — Five near-identical number-to-string converters in igs_api.c

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/ee_core/src/igs_api.c:79-152` (`u8todecstr` :79, `u16todecstr` :94, `u32todecstr` :109, `u32tohexstr` :124, `u64tohexstr` :139)
- **Problem:** Five static functions share one body shape — extract digits least-significant-first into a fixed-width, zero-padded, NUL-terminated field — differing only in input width (u8/u16/u32/u64) and radix (10/16). ~74 lines for what is one algorithm.
- **Fix:** Replace the five bodies with one static helper taking a u64 value, radix, and digit count; keep the five names only if call sites are numerous, otherwise call the helper directly and delete the wrappers.
- **Benefit:** One digit-conversion routine to verify; ~50 lines removed.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ.

## W04-010 — ioman.h documents a queue-removal function that does not exist

- **Category:** 1 (dead code — dead documentation)
- **Locations:** `RiptOPL/include/ioman.h:38-41`
- **Problem:** A doc comment ("removes all requests of a given type from the queue / @param type … / @return the count of the requests removed") sits between two real declarations, but no function declaration follows it, and a grep of `src/` + `include/` finds no implementation and no caller for any such removal function. The comment describes an API that was removed (or never landed), and a reader will hunt for it.
- **Fix:** Delete the orphaned comment block. (If the function is actually wanted, that's a separate feature decision — nothing in the tree calls it.)
- **Benefit:** The header stops advertising a nonexistent API.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (comment, absence of declaration, and absence of implementation all verified).

## W04-011 — Remove_Padhook is declared but never defined and never called

- **Category:** 1 (dead code)
- **Locations:** `RiptOPL/ee_core/include/padhook.h:25`
- **Problem:** `void Remove_Padhook(void);` is declared in the header, but a recursive grep of all of `ee_core/` finds no definition and no call site — only the declaration itself. (Contrast with the genuinely-used hook installers in the same subsystem, which are defined in `padhook.c` / `cheat_api.c` and called.) Anyone calling it would fail to link.
- **Fix:** Delete the declaration.
- **Benefit:** Header stops promising a function the binary doesn't have.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (grep over the whole ee_core tree).

## W04-012 — tar.h's header comment claims CFG/CHT kinds are unwired; the code wires them

- **Category:** 7 (build/CI/repo clutter — stale documentation with a deletion trap)
- **Locations:** `RiptOPL/include/tar.h:4-8` (comment), `RiptOPL/include/tar.h:53-63` (`TarEntryCfg`, `TarEntryCht`); contradicted by `RiptOPL/src/platform/tar.cpp:61-62` and `RiptOPL/src/sources/supportbase.cpp:1761-1784` (outside this worker's scope; found by grep while checking the structs for users)
- **Problem:** The comment says "RiptOPL wires ONLY the ART kind… the CFG/CHT kinds are kept intact so they can be wired later." That is no longer true: `tar.cpp` registers all kinds in its table (using `sizeof(TarEntryCfg)` / `sizeof(TarEntryCht)` as the on-disk entry strides), and `supportbase.cpp` actively reads cheats out of `CHT/cht.tar` via `tarFind(TAR_KIND_CHT, …)`. The comment invites a future cleanup to delete two structs that are load-bearing for the cache file layout.
- **Fix:** Rewrite the comment to state what is actually wired (ART and CHT at minimum) and that the entry structs define on-disk stride and must not be resized without bumping `ARC_VERSION`. Delete nothing.
- **Benefit:** Removes a comment that points a future editor at deleting live, format-defining types.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (header read in full; consumers grep-verified).

## W04-013 — utf8.h defines a 364-entry table and a function body in the header

- **Category:** 4 (size/memory)
- **Locations:** `RiptOPL/include/utf8.h:21-49`
- **Problem:** The header defines `static const uint8_t utf8d[]` (the Hoehrmann DFA table, 364 bytes) and a non-inline function `uint32_t static utf8Decode(...)` — note also the reversed qualifier order. Because both are header definitions, every including TU gets its own copy of the table. Grep-verified includers: `src/gfx/fntsys.cpp` and `src/gfx/textshape.cpp` — two copies today, and one more for every future includer.
- **Fix:** Declare `utf8Decode` in the header and move the table plus function body into a single `.cpp`. (Marking the function `static inline` would not help — the table is the bulk and would still duplicate.)
- **Justification (fix adds a file):** It removes a 364-byte table copy per includer and is the standard declaration/definition split the rest of the tree uses; net binary size goes down, not up.
- **Benefit:** One copy of the DFA table in the binary regardless of includer count.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (header read in full; includer count from grep).

## W04-014 — opl.h includes <debug.h> twice and mixes include-path styles

- **Category:** 2 (duplication, minor)
- **Locations:** `RiptOPL/include/opl.h:33` and `RiptOPL/include/opl.h:43` (both `#include <debug.h>`); `RiptOPL/include/opl.h:45` (`#include "config.h"`) vs `RiptOPL/include/opl.h:48` (`#include "include/hddsupport.h"`)
- **Problem:** The same SDK header is included twice, 10 lines apart, in the project's most-included header; and sibling project headers are pulled in with two different path conventions (`"config.h"` bare vs `"include/…"` prefixed) in the same include block, which only both work because of how the include path happens to be set up.
- **Fix:** Delete the second `<debug.h>` include and spell the project includes one way.
- **Benefit:** One less redundant include in a header everything pulls in; one include convention to reason about.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (line numbers grep-verified).

## W04-015 — Launch diagnostics are switched off by a hardcoded header constant, not a build option

- **Category:** 8 (half-finished/redundant features)
- **Locations:** `RiptOPL/include/launchdiag.h:41` (`#define LAUNCH_DIAG 0`); consumers `RiptOPL/elfldr/loader.c` and `RiptOPL/src/platform/launchdiag.cpp` (grep-verified: 3 use sites outside the header)
- **Problem:** A complete diagnostic system — staged background-colour markers plus a counted white-flash refusal code for failed game handoffs, documented at length in the header — is compiled out in the shipped tree because the toggle is a literal `0` in the header. Every other optional feature in this tree is gated by the build (e.g. the flavour flags in `ee_core/Makefile`: IGS, RETROACHIEVEMENTS, GSM1080P, PADEMU). Enabling launch diagnostics requires editing a source header, so in practice the code is dead in every normal build and rots untested.
- **Fix:** Either gate it from the Makefile like the other flavours (`-DLAUNCH_DIAG=1` opt-in, header keeps `#ifndef` default 0), or — if nobody uses it — delete the marker calls and the refusal-flash machinery. Keeping a hand-edited header constant is the worst of both.
- **Benefit:** The feature becomes reachable through the normal build switch, or the dead machinery stops costing maintenance.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (header and loader read in full; use-site count from grep).

## W04-016 — pad.h mixes constexpr and #define for one sequential key enum

- **Category:** 7 (repo clutter, minor)
- **Locations:** `RiptOPL/include/pad.h:6-21`
- **Problem:** The `KEY_*` constants 1–16 are declared as `constexpr int` except four in the middle of the sequence — `KEY_CROSS` (10), `KEY_CIRCLE` (11), `KEY_TRIANGLE` (12), `KEY_R1` (13) — which are `#define`s. Nothing in the header explains the split; a reader cannot tell whether those four must stay macros (e.g. for a preprocessor conditional somewhere) or whether it's an editing accident. The same mixed style appears for the GS modes in `renderman.h` (see W04-004).
- **Fix:** Make all 16 one style (constexpr, matching the majority), unless a `#ifdef KEY_…` use exists — in which case comment why those four are macros.
- **Benefit:** One obvious-correct way to add the next key constant.
- **Effort:** S · **Risk:** Low · **Confidence:** Med — READ for the header itself; INFERRED that no preprocessor use requires the macro form (no such use was searched for across the whole tree).

---

## Checked and deliberately NOT filed

- `ee_core/include/padpatterns.h` pattern/mask tables: entry counts verified equal for all 7 pattern/mask pairs by script (22/22, 19/19, 18/18, 16/16, 24/24, 25/25, 23/23) — no mask/table-size mismatch.
- `GSMFlags` struct (`ee_core/src/gsm_api.c`) vs `.space 20` in `gsm_engine.S`: sizes agree.
- `DTV_1080P` block in `gsm_engine_adv.S` is `#ifdef GSM_1080P`-gated and the Makefile forwards the flavour flag — an intentional variant build, not dead code.
- Header-declared ee_core functions checked against definitions across C and assembly: the asm.h hooks, `dve_*`, `Enable/Disable_GSBreakpoint`, and `HookSetupThread` are all defined in `.S` files or `cheat_api.c`. Only `Remove_Padhook` (W04-011) has no definition.
- `include/dialogs.h` placeholder enum slots (`CFG_ENABLEUDPBD`, `CFG_NETBOOTPROTOCOL`, `COMPAT_RETIRED_DOWNLOAD_DEFAULTS`): the file itself documents that the IDs must be preserved for dialog-ID stability — deliberate, not dead weight.
- The class-plus-free-function-forwarder pattern in many `include/` headers: several headers document that host-test harnesses scrape the exact free-function signatures, which justifies the forwarders; not filed.
- No in-scope header is never-included (basename search across `src/`, `include/`, `ee_core/`, `elfldr/`, `modules/` found zero).

---

## COVERAGE

All 207 in-scope files were opened and read in full:

- `include/` — 138 headers, 12,511 lines (count from `wc -l`): every file from `achievements.h` through `xparam.h`, including the large ones (`opl.h` 565, `dialogs.h` 464, `ds34common.h` 426, `themes.h` 379, `config.h` 374, `vcdsupport.h` 366).
- `ee_core/` — 66 files: all of `ee_core/include/` (incl. `padpatterns.h`, `igrmfont.h`, `gsm_defines.h`, `modules.h`), all of `ee_core/src/` C sources (`igrmenu.c`, `padhook.c`, `patches.c`, `igs_api.c`, `iopmgr.c`, `freeze_diag_*.c`, `ra*.c`, `syshook.c`, `tlb.c`, `util.c`, `main.c`, `modmgr.c`, `gsm_api.c`, `cheat_api.c`, `cd_igr_rpc.c`, `igrmbox.c`, `igrovl_stub.c`), all assembly read as code (`gsm_engine.S` 1330 lines, `cheat_engine.S`, `asm.S`, `gsm_engine_adv.S`, `dve_reg.S`, `crt0.S`, `patches_asm.S`), `ee_core/igrovl/` (main + linkfile), `ee_core/tests/` (both freeze-diag host tests), `ee_core/Makefile`, `ee_core/linkfile`, `ee_core/debug_colors_doc.sh`.
- `elfldr/` — 3 files: `loader.c` (475 lines), `Makefile`, `linkfile`.

**Files NOT read: none.** Every in-scope file was read. Two out-of-scope files (`src/platform/tar.cpp`, `src/sources/supportbase.cpp`) were grep-checked only, solely to verify whether an in-scope header's types have users (W04-012); no findings are filed against them.
