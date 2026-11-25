# W03 — Blind Redo Audit: RiptOPL `src/core/` + `src/app/` + `src/platform/`

- **Pin:** `2e347d5ac885cd0ff73e9ad4143781946396f492` (verified with `git rev-parse HEAD` before and after the read pass).
- **Scope:** every file in `src/core/` (17 files), `src/app/` (5 files), `src/platform/` (23 files) — 45 files, 24,908 lines (`wc -l`).
- **Rule applied:** LESS, NOT MORE. Fixes below prefer delete / simplify / consolidate. Anything that would ADD code carries an explicit justification.
- **Method:** every cited file was opened and read in this session; every line range was verified against the clone. Every count, byte total, and duplication claim comes from a script or command actually run (census/diff/grep outputs), never an estimate. INFERRED is stated wherever a conclusion is reasoned rather than read. No hardware or PS2SDK behaviour is claimed; performance findings are structural only.

---

## W03-001 — SYSTEM.CNF parser can return an unterminated key and reads before its bounds check

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/src/platform/ps2cnf.cpp:18`, `RiptOPL/src/platform/ps2cnf.cpp:42-71`
- **Problem:** Three defects in the BOOT2 parser, all READ at the cited lines:
  1. `CNFGetToken` line 18: `for (; isspace((int)*cnf) && cnf < end; cnf++)` — `*cnf` is dereferenced *before* `cnf < end` is evaluated (`&&` runs left to right), so entering with `cnf == end` reads one byte past the buffer.
  2. `CNFGetKey` (lines 42–71) takes no `end` bound at all, and its copy loop (line 54) writes the terminating NUL only on the whitespace branch. A token of `CNF_PATH_LEN_MAX` (64) or more graph characters exits the loop on the count bound with the caller's `bootfile` buffer never NUL-terminated; downstream string use then reads past it.
  3. The `else if (*line == '\0')` branch (lines 62–64) is unreachable: the loop condition already excludes `'\0'`, and the graph/space branches cover the remaining cases it could fire on. Dead code inside a parser.
- **Fix:** Check `cnf < end` before dereferencing in `CNFGetToken`; in `CNFGetKey`, always write `*key = '\0'` on loop exit (one line after the loop covers every path); delete the unreachable branch.
- **Benefit:** Removes an out-of-bounds read and a potential unterminated-string over-read on data parsed from a disc's SYSTEM.CNF — i.e. untrusted input.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-002 — Two different parsers for the same SYSTEM.CNF / BOOT2 job

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/src/platform/ps2cnf.cpp:16-122` (`CNFGetToken`/`CNFGetKey`/`ps2cnfGetBootFile`), `RiptOPL/src/platform/sysdisc.cpp:75` (`sysParseBoot2`)
- **Problem:** The tree parses SYSTEM.CNF twice with different rules. ps2cnf.cpp is token-based and case-sensitive; `sysParseBoot2` in sysdisc.cpp is a separate line scanner that matches "BOOT2" case-insensitively, including mid-token. The same disc can therefore yield a different boot path depending on which subsystem asks, and parser fixes (see W03-001) land in only one of them.
- **Fix:** Keep one parser — the ps2cnf one, once W03-001 is applied — and have sysdisc call it; delete `sysParseBoot2`. If the case-insensitive behaviour is load-bearing for real discs, fold that one rule into the surviving parser rather than keeping two implementations.
- **Benefit:** One parser to fix, one strictness level for a security-relevant input.
- **Effort:** M · **Risk:** Med (behavioural difference between the two is real; needs a disc-image test) · **Confidence:** High (READ)

## W03-003 — tar reader never validates the ustar header checksum, and size parsing ignores base-256

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/src/platform/tar.cpp:75` (`parseOctal`), `RiptOPL/src/platform/tar.cpp:278` (size read); checksum absence verified by grep — no `chksum`/`checksum` reference exists anywhere in tar.cpp
- **Problem:** tar archives here carry theme and art files, i.e. data that did not necessarily come from the user. The reader walks headers trusting the size field without ever verifying the header checksum field (offset 148) that exists precisely to detect a corrupt or crafted header. Separately, `parseOctal` only understands ASCII-octal sizes; a header using the base-256 binary size encoding is misread, producing a wrong stride for the header walk.
- **Fix:** Verify the header checksum before trusting a header (a ~10-line sum over the header block, standard ustar), and treat a base-256 size field as an unsupported archive rather than misparsing it. No new machinery beyond the checksum sum.
- **Justification (fix adds code):** The checksum sum is the smallest possible validation for input the code already walks blindly; the alternative — continuing to trust the size field — is the bug.
- **Benefit:** A corrupt or hostile .tar is rejected at the first bad header instead of steering the entry walk out of the buffer.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep census)

## W03-004 — Four tar finder functions duplicate one search

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/src/platform/tar.cpp:464` (`tarFind`), `RiptOPL/src/platform/tar.cpp:501` (`tarFindPrefix`), `RiptOPL/src/platform/tar.cpp:531` (`tarFindExact`), `RiptOPL/src/platform/tar.cpp:555` (`tarFindPrefixExact`)
- **Problem:** Four exported finders implement the same index sweep, differing only in match predicate (exact vs prefix) and in whether a not-yet-loaded archive is loaded first. The sweep body is repeated four times, so any fix to the walk (bounds, kind filtering) must be made four times.
- **Fix:** One internal sweep taking a match-mode flag; the four public names become one-line forwards or are removed in favour of the single entry point. Net code removed.
- **Benefit:** One walk to audit; the W03-003 validation lands in exactly one place.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-005 — The ~66-line platform prologue is copied into four files (and the app splits); the disc-timing constants inside it are dead in sysvmc.cpp

- **Category:** 2 (duplication) / 1 (dead code)
- **Locations:** `RiptOPL/src/platform/system.cpp:1-66`, `RiptOPL/src/platform/sysvmc.cpp:1-66`, `RiptOPL/src/platform/sysdisc.cpp:1-66`, `RiptOPL/src/platform/sysneutrino.cpp:1-66`; `RiptOPL/src/platform/sysvmc.cpp:15-23` (dead constants); same pattern in `RiptOPL/src/app/autolaunch.cpp:7-72` and `RiptOPL/src/app/lwnbdctl.cpp:7-72`
- **Problem:** Script-verified: the first 66 lines of the four platform files differ by only 2 lines (sysdisc), 4 lines (sysneutrino) and 8 lines (sysvmc) from system.cpp's — the include block and shared constants are copy-pasted per file. Inside that block, `SYS_DISC_DETECT_MS` / `SYS_DISC_REDETECT_MS` / `SYS_DISC_NODISC_MS` are defined in both sysdisc.cpp (where they are used, lines 161/185/186) and sysvmc.cpp:15-23, where grep shows no use at all. The app-layer splits repeat the pattern: autolaunch.cpp and lwnbdctl.cpp carry opl.cpp's full include block, including headers the file never uses (in lwnbdctl.cpp, grep finds zero uses of the tar, art-index and tex-cache facilities its includes import) and even opl.cpp-specific comments (the `sys/stat.h` mkdir note in lwnbdctl.cpp describes BDM autolaunch, a different file's business).
- **Fix:** Delete the unused `SYS_DISC_*` constants from sysvmc.cpp. For the prologue itself, trim each file's include block to what that file references (the compiler already enforces this per file); do not create a new shared mega-header — that would move the problem, not shrink it.
- **Benefit:** Removes dead constants and per-file include drift; each file states its real dependencies.
- **Effort:** S (constants) / M (include trim) · **Risk:** Low · **Confidence:** High (READ + diff/grep census)

## W03-006 — `USBA_crc32` keeps a 4× oversized table and rebuilds it on every call

- **Category:** 4 (size/memory) / 5 (performance, structural)
- **Locations:** `RiptOPL/src/platform/system.cpp:465-492`
- **Problem:** `crctab` is declared `unsigned int crctab[0x400]` (1,024 entries, ~4 KB) but the algorithm only ever indexes 256 entries — ~3 KB of BSS is permanently wasted. The 256-entry table is also rebuilt from scratch on every call instead of once. Separately, the CRC's seed is whatever value the table-build loop leaves behind rather than a named initial constant: the output is deterministic but non-standard, and other code (the `ul.*` name checksums) depends on its exact values, so the seed must NOT be "corrected" as part of this fix.
- **Fix:** Shrink the array to 256 entries and build the table once (function-local static with a built flag, or a plain static table). Leave the seed computation byte-for-byte as it is.
- **Benefit:** ~3 KB BSS back on a 32 MB console and removal of per-call table construction, with zero behavioural change.
- **Effort:** S · **Risk:** Low (Med if the seed is touched — don't) · **Confidence:** High (READ)

## W03-007 — `sysShutdownDev9` retries in a delay-free spin

- **Category:** 5 (performance, structural)
- **Locations:** `RiptOPL/src/platform/system.cpp:264-285` (retry loop at line 278)
- **Problem:** The DEV9-off path loops `while (retry-- > 0 && fileXioDevctl("dev9x:", DDIOC_OFF, ...) < 0)` with no delay or yield between attempts. Structurally, a failing devctl is retried at full speed for the whole retry budget, burning the thread for no benefit — the callee's state cannot change faster because we yielded.
- **Fix:** Add the same small bounded delay the codebase already uses in its other bounded waits (e.g. pad.cpp's poll delays), or cut the retry count. No new mechanism.
- **Benefit:** The shutdown path stops busy-spinning; behaviour otherwise identical.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-008 — APA partition helpers trust on-disk counts and indices

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/src/platform/hdd.cpp:405-437` (`hddGetPartitionInfo`), `RiptOPL/src/platform/hdd.cpp:438` onwards (`hddGetFileBlockInfo`)
- **Problem:** `hddGetPartitionInfo` clamps the on-disk sub-partition count only from above (`if (nsub > APA_MAXSUB)`, lines 423–424); a negative `nsub` read from a corrupt or crafted APA header passes through and the caller's loop/count logic inherits it. `hddGetFileBlockInfo` indexes `subs[stat.private_4]` — a value straight from on-disk file metadata — with no check that it lies within the caller's `subs` array.
- **Fix:** Clamp `nsub` at 0 as well as at `APA_MAXSUB`, and bounds-check the `private_4` index against the array length the caller passes (the function already receives a `max` for its output; the input side needs the same treatment).
- **Justification (fix adds checks):** Both values come from disk metadata, the classic untrusted-input case; two comparisons are the smallest possible guard.
- **Benefit:** Corrupt APA metadata produces an error instead of an out-of-bounds read.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-009 — Neutrino TOML sync carries two rewriters plus machinery that exists only to repair its own writes

- **Category:** 3 (overengineering) / 8 (redundant features)
- **Locations:** `RiptOPL/src/platform/sysneutrino.cpp:303` (`sysTomlTornTailCut`), `RiptOPL/src/platform/sysneutrino.cpp:382` (`sysSyncNeutrinoUdpfsToml`), `RiptOPL/src/platform/sysneutrino.cpp:522` (`sysTomlRewriteSmbArgs`)
- **Problem:** The same job — updating Neutrino's TOML config in place — is done two different ways in one file: a naive `strstr(toml, "\"ip=")` string patch for the UDPFS sync, and a full TOML lexer/rewriter for the SMB args. On top of that, `sysTomlTornTailCut` (~90 lines) exists solely to detect and cut file tails torn by this same code's in-place truncate-and-rewrite strategy, and both sync paths carry a restore-original-on-short-write fallback. A meaningful share of this subsystem is self-inflicted: complexity spent surviving a write strategy, duplicated across two implementations of the edit itself.
- **Fix:** One writer, one strategy: route both syncs through the existing lexer-based rewriter and write the result in one pass. Once writes are single-pass from a complete in-memory buffer, the torn-tail repair and the duplicate restore logic have nothing left to repair and can be deleted.
- **Benefit:** Removes an entire repair subsystem and a second TOML implementation; the remaining path is the one that already parses properly.
- **Effort:** L · **Risk:** Med (touches launch config writes; needs on-hardware launch checks per repo rules) · **Confidence:** High (READ)

## W03-010 — `sysWriteNeutrinoCheats` accumulates `snprintf` returns into a length with no truncation check

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/src/platform/sysneutrino.cpp:961-990` (accumulation at lines 974–978), weaker twin at `RiptOPL/src/platform/sysneutrino.cpp:1081` / line 1111 (`sysNeutrinoHandRA`)
- **Problem:** The cheat-file writer does `len += snprintf(text + len, size - len, ...)` in a loop over cheat pairs. `snprintf` returns the length it *would* have written, so the first truncation pushes `len` past `size`; from then on `size - len` is negative and converts to a huge `size_t` in the next call, turning a too-long cheat list into a heap overwrite. The number of pairs is bounded by the cheat system (up to 250), and the per-pair text is fixed-format, so whether a real configuration reaches the overflow depends on the buffer size versus pair count — but the pattern itself guarantees that *if* the text ever exceeds the buffer, the failure mode is corruption rather than truncation. The same accumulation pattern appears in `sysNeutrinoHandRA` (line 1111) with more tightly bounded inputs.
- **Fix:** Check each return: if `n < 0 || len + n >= size`, stop and fail the write. Or simpler — compute the required size first from the pair count (the format is fixed-width) and refuse up front. Either removes the negative-size conversion.
- **Justification (fix adds a check):** One comparison per append is the minimum that makes the existing code safe; no new abstraction.
- **Benefit:** A worst case that is currently memory corruption becomes a clean "cheats not written" failure.
- **Effort:** S · **Risk:** Low · **Confidence:** Med — the pattern and its consequence are READ; that a shipping configuration actually overflows the buffer is INFERRED (depends on the caller's buffer size vs. pair count).

## W03-011 — ELF program-header copies are unvalidated in two loaders, while a third loader in the same tree validates them

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/src/platform/elfldr_noreset.cpp:233` (`memcpy(eph[i].vaddr, pdata, eph[i].filesz)`), `RiptOPL/src/platform/system.cpp:1359` (`sysLaunchLoaderElf`), contrasted with `RiptOPL/src/platform/system.cpp:1308` (`sysPlaceIgrOverlay`)
- **Problem:** The PT_LOAD copy loops trust each program header's offset/filesz/vaddr against nothing — the blob size is never consulted. `sysPlaceIgrOverlay`, in the same file as one of the offenders, validates all three before copying, so the tree already contains the correct pattern; the other two paths predate or bypass it. The blobs are embedded/trusted today, which is why this is Low rather than High — but a truncated or patched embedded blob becomes an arbitrary copy.
- **Fix:** Apply the same three comparisons `sysPlaceIgrOverlay` already makes, in the two copy loops. No new helper needed; the pattern is in-tree.
- **Benefit:** Consistent validation across all ELF loading paths.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-012 — IOPRP patching runs `strcmp`/`strcpy` on fixed 10-byte ROMDIR names that need not be NUL-terminated

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/src/platform/ioprp.cpp:8` (`char fileName[10]`), `RiptOPL/src/platform/ioprp.cpp:43-58` (`patch_IOPRP_image`)
- **Problem:** ROMDIR entry names are a fixed 10-byte field, not a C string; a name that fills all 10 bytes has no terminator. The patch loop calls `strcmp(romdir_in->fileName, "CDVDMAN")` etc. and `strcpy(romdir_out->fileName, romdir_in->fileName)`, both of which read (and for `strcpy`, write) past the field when that happens. Legacy IOPRP images are exactly the kind of input where a full-width name occurs.
- **Fix:** Compare with `strncmp(..., 10)` and copy with a bounded copy of at most 10 bytes — the same treatment the field's format already implies.
- **Benefit:** Removes an over-read/over-write on legacy image parsing.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-013 — `sysDeleteFolder` uses a `malloc` result without a NULL check

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/src/platform/util.cpp:857-885`
- **Problem:** The recursive folder delete builds child paths into a heap buffer obtained from `malloc` and passes it to `sprintf` without checking for NULL. On a memory-tight console (see W03-019/W03-020 for how much static/lazy memory this app commits), an allocation failure here is a NULL dereference during a destructive operation.
- **Fix:** Check the allocation and bail out of the recursion on failure — the function's callers already handle a failed delete.
- **Benefit:** Allocation failure becomes a reported failed delete instead of a crash mid-delete.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-014 — `getFileSize` truncates file sizes to `int`

- **Category:** 6 (bugs)
- **Locations:** `RiptOPL/src/platform/util.cpp:48`
- **Problem:** `getFileSize` returns `int` from `lseek`, so any file at or above 2 GB — unremarkable for game images on the devices this app manages — reports a negative or wrapped size to every caller. Callers cannot distinguish "huge file" from an error return.
- **Fix:** Return the platform's off_t-width type (or `long`) and let callers that genuinely need an `int` range-check at their own boundary. If every in-tree caller is dealing with small files, the honest minimal fix is a clamp-to-INT_MAX with the error value reserved — but the return type is the lie; fix that.
- **Benefit:** Removes a silent size wrap on exactly the file class the app exists to manage.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; the set of affected callers is INFERRED — they were not all traced)

## W03-015 — `configWrite` stacks three separate save-safety mechanisms

- **Category:** 3 (overengineering)
- **Locations:** `RiptOPL/src/core/config.cpp:1496-1699` (`CONFIG_MAX_RESTORE_BYTES` at line 1496, `configWrite` at line 1498)
- **Problem:** A single save currently goes through three independent safety layers: a RAM snapshot-and-restore of the previous file (capped at 256 KB by `CONFIG_MAX_RESTORE_BYTES`), a read-back byte-compare with a rescue path, and a special single-open carve-out for memory cards — with per-device branching woven through them. The comments tie the layers to real incidents (issues #184/#245/#340), so this is not speculative machinery; but three overlapping mechanisms means three behaviours to reason about per device, and the snapshot layer alone can allocate up to 256 KB transiently on a 32 MB machine to protect a settings file.
- **Fix:** Consolidate to one mechanism — the read-back compare is the only one that verifies what actually landed — and delete the snapshot-restore layer and the device carve-outs it forced. This is a deliberate, hardware-test-first change, not a drive-by: if hardware shows a device genuinely needs its carve-out, that device keeps exactly one, documented.
- **Benefit:** One save path to validate; up to 256 KB of transient allocation gone; save failures have one meaning.
- **Effort:** M · **Risk:** Med (hardware-motivated history; repo rules require real-hardware validation before calling this done) · **Confidence:** High that the three layers coexist (READ); Med that one suffices (INFERRED — needs hardware evidence)

## W03-016 — `configRead` walks a five-rung filename fallback chain of accumulated migrations

- **Category:** 8 (half-finished/redundant features)
- **Locations:** `RiptOPL/src/core/config.cpp:1419-1495`
- **Problem:** Reading one config set tries, in order: the current filename, the wOPL filename, the carry-over directory with the current name, the legacy filename, and the carry-over directory with the legacy name. Each rung is a past migration that was never retired. The cost is not just code: with five candidate locations, "which file did my settings come from" has five answers, and every future rename adds a sixth rung instead of replacing one.
- **Fix:** Keep the current name plus at most one legacy rung (the one current users can still plausibly have), and delete the carry-over-directory duplicates — the carry-over concept is already handled at the settings-home level (see W03-017), so doing it again per-file is the redundancy.
- **Benefit:** Fewer silent sources for the same settings; migrations become finite.
- **Effort:** M · **Risk:** Med (an install old enough to need a deleted rung falls back to defaults once, then saves in the current name) · **Confidence:** High (READ)

## W03-017 — Settings-home discovery is a second, larger fallback labyrinth — and save-side discovery disagrees with load-side

- **Category:** 3 (overengineering) / 8 (redundant features)
- **Locations:** `RiptOPL/src/app/settingsio.cpp:938` (`tryAlternateDevice`), `RiptOPL/src/app/settingsio.cpp:853` (`tryMissingConfigPathRecovery`), `RiptOPL/src/app/settingsio.cpp:743` (`tryKnownBootConfigRecovery`), `RiptOPL/src/app/settingsio.cpp:2047` (`trySaveAlternateDevice`)
- **Problem:** When the boot home yields no config, load-side discovery cascades through: the config.path redirect, an APA-only chain, a known-boot-device recovery (two legacy locations on the boot device, with per-set re-reads and re-homing), then a broad recovery sweep (both MC slots × two locations, USB slots × two locations, MMCE slots), then a legacy mc?:OPL read with self-migration logic that itself branches on deferred/network boots. Save-side discovery (`trySaveAlternateDevice`) is a *separate* cascade with a *different* device order (boot device, MC, MMCE, BDM, HDD vs. load's MC, USB, MMCE, HDD). Each layer is individually justified in its comments by a field report; collectively they mean the settings home is decided by ~1,500 lines of branching state (boot class × device presence × which probe hit), and load and save can pick different homes for the same machine state.
- **Fix:** Collapse to one decision table used by both directions: (1) explicit custom path, (2) boot home, (3) the single legacy mc?:OPL migration read, (4) defaults homed at the boot home. Delete the broad multi-device sweep and the per-set recovery re-reads; a config on some *other* device than the boot device is what the custom-path setting exists for.
- **Benefit:** Load and save agree by construction; the "settings saved but never load back" class of bug (which the comments show recurring) loses its main mechanism.
- **Effort:** L · **Risk:** High if done casually — this is the most field-scarred code in scope; it should only move with a hardware test matrix per boot class, per repo rules · **Confidence:** High that the sprawl and the load/save order divergence exist (READ); the four-step table is a recommendation, INFERRED as sufficient

## W03-018 — Network IP settings are parsed with unchecked `sscanf`, while the RA host IP in the same file is parsed properly

- **Category:** 6 (bugs)
- **Locations:** `RiptOPL/src/app/settingsio.cpp:1931`, `:1936`, `:1950`, `:1952`, `:1954`, `:1956` (unchecked parses); contrast `RiptOPL/src/app/settingsio.cpp:1518-1544` (`configReadRA`)
- **Problem:** Six sites in `_loadConfig` do `sscanf(temp, "%d.%d.%d.%d", &ip[0], ...)` with no return check and no range check: a malformed stored value ("192.168.x", "999.1.1.1", trailing junk) leaves some octets at whatever the globals already held and others overwritten, silently producing a mixed old/new address. The same file's `configReadRA` does this correctly — it requires `sscanf(...) == 4` and range-checks every octet 0–255 — proving the pattern is known in-tree and simply wasn't applied to the network settings.
- **Fix:** Apply the `configReadRA` treatment to the six sites (check the count, range-check, keep the old value on failure). Six small identical edits; if a shared helper is preferred it qualifies under the house rule — the same logic would then exist in 7 places, and sharing removes code overall.
- **Benefit:** A hand-edited or corrupt conf_network.cfg can no longer produce a franken-IP that the UI then displays as if it were the stored one.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-019 — The per-cheat code cap reuses the flattened-list cap, sizing the lazy cheat table at ~1.03 MB; the constants are duplicated in ee_core

- **Category:** 4 (size/memory) / 2 (duplication)
- **Locations:** `RiptOPL/include/cheatman.h:39-41` and `:67` (`code_t codes[MAX_CHEATLIST]`), `RiptOPL/src/core/cheatman.cpp:454` (`ensureCheatTable`; the file's own comment at line 41 states "~1.03 MB cheat table"), `RiptOPL/ee_core/include/cheat_engine.h:27-29`
- **Problem:** `MAX_CHEATLIST` = `MAX_HOOKS*2 + MAX_CODES*2` = 510 is the cap for a *flattened list of all cheats' codes*. It is also used as the `codes[]` dimension *inside each cheat entry*, so the table costs 250 entries × 510 codes × 8 bytes ≈ 1.03 MB (the code's own comment confirms the figure) — allocated lazily, but committed in full the first time cheats are used, on a 32 MB console. No single cheat can legitimately carry 510 codes; the per-cheat dimension is simply the wrong constant reused. The same three constants are also defined a second time in `ee_core/include/cheat_engine.h`, so the two sides of the EE/ee_core interface can drift independently.
- **Fix:** Give the per-cheat array its own, honest cap (the largest code count a single cheat entry can hold by construction of the .cht parser) and size the table from that; keep the flattened-list cap only where a flattened list is meant. Leave the ee_core copy values identical — or better, note the pair must move together; generating one from the other is out of scope for a LESS fix.
- **Benefit:** The lazy table shrinks by roughly an order of magnitude (exact figure depends on the honest per-cheat cap chosen); one less silent coupling between two headers.
- **Effort:** S · **Risk:** Med (if any .cht in the wild carries more codes per cheat than the new cap, it truncates — the parser's own limits should set the number) · **Confidence:** High (READ + the file's own size comment)

## W03-020 — BGM keeps a 768 KB static ring buffer resident even though BGM is off by default

- **Category:** 4 (size/memory)
- **Locations:** `RiptOPL/src/core/bgm.cpp:29` (`BGM_RING_BUFFER_COUNT = 192`), `RiptOPL/src/core/bgm.cpp:72` (static buffer)
- **Problem:** `static char bgmBuffer[192][4096]` commits 768 KB of BSS unconditionally — the file's own comment confirms "768 KB buffer". BGM is an opt-in feature that defaults off (the settings default), so on a default install this memory is reserved for the entire session for a feature that never runs. The cheat table (W03-019) shows the tree already accepts the lazy-allocation pattern for exactly this situation; the BGM ring predates or bypasses it.
- **Fix:** Allocate the ring in `bgmStart` and free it in the stop path, mirroring the cheat table's lazy pattern. No size change, no behaviour change while playing.
- **Benefit:** 768 KB returned to the heap on every install that doesn't enable BGM — on this hardware, that is real headroom for art caches and lists.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-021 — `vmc_groups.cpp` ships dead data: malformed title IDs that can never match, and duplicated IDs

- **Category:** 1 (dead code)
- **Locations:** `RiptOPL/src/core/vmc_groups.cpp:14` onwards (the `titles_XEBP_100_*` tables)
- **Problem:** Script census over the file's string literals (run in this session): 1,144 ID-like literals extracted. Eight do not match the `XXXX_NNN.NN` shape every real title ID follows — `SLUS_20754`, `SLUS_20824`, `SCES_50422`, `SLES_50422`, `SCES_51154`, `SLES_51154` (missing the `.NN` suffix), `SLES-5350` (wrong separator and shape), and `SSCES_540.95` (five-letter prefix). A lookup keyed on real startup IDs can never equal these strings, so those entries are dead weight that also *fail to do their job* — the games they were meant to group will not group. Thirteen IDs appear more than once across the tables, including `SLES_546.24` and `SLUS_216.62` twice within a single group each, where the duplicate cannot change the result.
- **Fix:** Correct the eight malformed IDs to their real forms (they are recognisably typos of real IDs — missing suffix / doubled letter) and delete the within-group duplicates. Cross-group duplicates should be checked once against intent before removal.
- **Benefit:** Eight games group as intended; the table stops carrying entries that provably do nothing.
- **Effort:** S · **Risk:** Low · **Confidence:** High (script census, this session; the "typo of a real ID" reading is INFERRED from shape)

## W03-022 — `deinit` and `deinitEx` are the same ~90-line teardown written twice

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/src/app/opl.cpp:1278-1370` (`deinitEx`), `RiptOPL/src/app/opl.cpp:1372-1455` (`deinit`)
- **Problem:** Script-verified by extracting both bodies and diffing them: 93 vs 84 lines, and the *only* differences are the signature, the module-cleanup loop (deinitEx spares a second mode), and two `launchDiagMark` calls. Everything else — including the long ordering-rationale comment blocks about the art drain, bgm quiesce and fade — is verbatim. Teardown ordering is the most safety-critical sequence in the app (the comments document freezes caused by getting it wrong), and it now has to be maintained in two places; a fix applied to one is a latent bug in the other.
- **Fix:** Delete `deinit` as a separate body: implement it as `deinitEx(exception, modeSelected, -1)` — the spared-mode loop already degenerates to the plain loop when `modeSelected2 < 0` — and add the two diag marks unconditionally in the shared body (they are gated on `gLaunchDiag` at the call). One teardown remains.
- **Benefit:** One teardown sequence to keep correct; ~80 lines removed.
- **Effort:** S · **Risk:** Low (the diff proves the bodies are equivalent modulo the spared mode) · **Confidence:** High (READ + diff census)

## W03-023 — host.cpp builds a four-interface service layer with exactly one implementation of each interface

- **Category:** 3 (overengineering)
- **Locations:** `RiptOPL/src/app/host.cpp:26` (`OplUi`), `:74` (`OplApp`), `:98` (`OplLibrary`), `:115` (`OplLaunch`) — file is 292 lines
- **Problem:** `UiServices`, `AppServices`, `LibraryServices` and `LaunchServices` are abstract interfaces whose implementations (grep-verified across `src/` and `include/`) exist exactly once each, all in this file, and almost every method is a one-line forward to a free function that already existed (`guiMsgBox`, `::deinit`, `libViewActive`, …). The vtable layer buys nothing a direct call doesn't: there is no second implementation, no test double in-tree, and the forwarding bodies must be touched alongside every signature change anyway. INFERRED: if the seam exists to break a circular dependency, that is not visible from the code in scope.
- **Fix:** If no second implementation is planned, delete the interface layer and call the free functions directly; keep the `host` namespace only where it genuinely hides a dependency cycle, and say so in a comment. If a second implementation *is* planned, this finding is void — but then the plan should be written down where the next reader can find it.
- **Benefit:** ~290 lines of forwarding and four interface headers' worth of indirection removed from every call path that crosses the app/support boundary.
- **Effort:** M · **Risk:** Med (call sites are numerous) · **Confidence:** Med (single-implementation fact is grep-verified; whether the seam is load-bearing for the build graph is INFERRED)

## W03-024 — `PadManager::initialize` returns 1 on every path, making `startOne`'s failure branch dead; `keyPressed` lacks the bounds guard its siblings have

- **Category:** 1 (dead code) / 6 (bugs)
- **Locations:** `RiptOPL/src/core/pad.cpp:188-297` (`initialize`; `return 1` at lines 209, 235, 248, 256, 296), `RiptOPL/src/core/pad.cpp:1136` (`startOne`), `RiptOPL/src/core/pad.cpp:1049` (`keyPressed`)
- **Problem:** Every exit from `initialize` — not connected, not DualShock, no actuators, success — returns 1. `startOne` nevertheless treats `!initialize(pad)` as failure and returns 0, a branch that can never run; `startPads` therefore counts every opened port as started regardless of what init found. The return value is pure noise: it documents a contract the function does not honour. Separately, `keyPressed(id)` indexes `keyToPad[id]` with no range check, while `key`, `keyOn` and `setButtonDelay` in the same file all guard `id` to 1–16 first — an inconsistent guard that turns any out-of-range caller into an out-of-bounds read of a 17-entry table.
- **Fix:** Make `initialize` return void (delete the dead check in `startOne`) — or, if pad counting is supposed to reflect init success, return 0 on the not-connected path only; either way, one honest contract. Add the same two-line guard to `keyPressed` that its siblings already have.
- **Benefit:** Removes a dead branch and a fake contract from the pad bring-up path; closes the one unguarded index in the key API.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-025 — `readLeftJoy` writes the same deadzone switch twice

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/src/core/pad.cpp:311-370`
- **Problem:** The X and Y sensitivity switches inside `readLeftJoy` are the same five-case mapping (128/100/80/60/default 100) written out twice, once per axis. They must agree forever — a sensitivity tier added to one axis and not the other is an invisible bug.
- **Fix:** One tiny lookup (a 5-entry table or a 10-line local function) called for both axes. Qualifies under the house rule: identical logic in 2 places, sharing removes code.
- **Benefit:** ~20 lines removed; the two axes cannot drift.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-026 — `sfxGetDropDiag` is a stub that reports zeros for counters that no longer exist

- **Category:** 1 (dead code)
- **Locations:** `RiptOPL/src/core/sfx.cpp:305-312`; declared in `RiptOPL/include/sound.h:28`
- **Problem:** The function unconditionally writes 0 to both outputs. The drop counters it once reported belonged to the old multi-voice SFX pool, which the same file's comments explain was replaced by the shared-voice design — the thing being counted no longer exists. The debug HUD still calls it (outside this scope) and dutifully displays the zeros as data.
- **Fix:** Delete the function, its declaration, and the HUD call/display. If a drop counter is wanted again, it should count something the current design actually does.
- **Benefit:** Removes a diagnostic that reports fiction; one less API surface in sound.h.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; the HUD call site is outside scope and was confirmed by grep only)

## W03-027 — httpclient: an empty `HttpStreamEnd` kept "for symmetry", and `HttpSendGetRequest` skips the init guard

- **Category:** 1 (dead code) / 6 (bugs)
- **Locations:** `RiptOPL/src/platform/httpclient.cpp:157` (`HttpStreamEnd`), `RiptOPL/src/platform/httpclient.cpp:61` (`HttpSendGetRequest`), guard present at `:38-42` (`HttpEstabConnection`)
- **Problem:** `HttpStreamEnd` is an empty function retained for API symmetry with `HttpStreamStart` — a no-op every caller must still call and every reader must still check. In the same file, `HttpEstabConnection` guards on `HttpIsInitialized()` but `HttpSendGetRequest` does not, so the request path can run against an uninitialised stack if a caller reaches it first.
- **Fix:** Delete `HttpStreamEnd` and its call sites; add the same one-line guard to `HttpSendGetRequest`.
- **Benefit:** One less no-op in the API; consistent preconditions across the file's entry points.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep census of `HttpIsInitialized` uses)

## W03-028 — `sysCheckVMCEx` validates the VMC superblock geometry twice, with different rules

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/src/platform/sysvmc.cpp:138-282`
- **Problem:** The function checks the superblock's geometry in two separate passes that do not state the same rule — one accepts `page_size == 512`, the other merely `!= 0` — so which validation a bad image fails depends on which pass reaches it, and a fix to one pass silently leaves the other accepting what it rejected.
- **Fix:** Keep one geometry validation (the stricter, `== 512` rule, since that is what the rest of the VMC code assumes) at the top of the function and delete the second pass.
- **Benefit:** One rule for "is this a usable VMC image", stated once.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-029 — `lngGetFilePath` indexes `languages[langID - 1]` with no range check

- **Category:** 6 (bugs)
- **Locations:** `RiptOPL/src/core/lang.cpp:550`
- **Problem:** The function returns `languages[langID - 1].filePath` directly. A `langID` of 0 (or beyond the table) reads outside the array. Whether a caller can currently supply such an ID was not established in scope — the function's own contract does nothing to prevent it, and its neighbours in the language module do validate.
- **Fix:** Clamp/validate `langID` against the table count at the top of the function and return the default language's path (or NULL, matching what callers already handle for missing languages) when out of range.
- **Benefit:** One bad ID becomes a fallback instead of an out-of-bounds read.
- **Effort:** S · **Risk:** Low · **Confidence:** Med — the unchecked index is READ; caller reachability is INFERRED

## W03-030 — `fmChildren` re-lists from scratch on every ×4 growth step

- **Category:** 5 (performance, structural)
- **Locations:** `RiptOPL/src/core/filemgr.cpp:225`
- **Problem:** The directory-listing helper grows its result array by ×4 up to a 65,536-entry cap, and on each growth it re-runs the full directory enumeration (readdir + stat per entry) from the beginning rather than resuming. Structurally that makes listing a large folder quadratic in readdir/stat work, and the cap itself permits an allocation on the order of 9 MB for one folder listing on a 32 MB console (entry size × 65,536; INFERRED from the struct and cap as read).
- **Fix:** Enumerate once into the final pass (count first, or append without restarting), and lower the cap to something a real folder on a PS2 device can plausibly hold. No new machinery — the single-pass shape is the simpler one.
- **Benefit:** Large-folder listings stop re-statting the same entries repeatedly; worst-case allocation shrinks with the cap.
- **Effort:** M · **Risk:** Low · **Confidence:** Med — the restart-on-growth structure is READ; the ~9 MB figure is INFERRED arithmetic from read values

## W03-031 — Cheat-config save walks 250 key removals; load silently drops every pick after the first gap

- **Category:** 5 (performance, structural) / 6 (bugs)
- **Locations:** `RiptOPL/src/core/cheatconfig.cpp:103` (removal inside the save loop)
- **Problem:** Saving cheat selections loops over all 250 slots calling `configRemoveKey` for each — every call is a walk of the config key list, so a save is 250 list-walks before the writes even start. On load, the reader stops at the first missing `$CheatSelNNN` key, so a sparse key set (exactly what the save side produces after removals) silently drops every selection after the gap.
- **Fix:** On save, remove the `$CheatSel` prefix range in one pass over the key list instead of 250 searches. On load, skip missing indices instead of stopping — or, if stop-at-gap is the intended format contract, have save write a contiguous set; the two sides must agree, and today they don't.
- **Benefit:** Save cost stops scaling with the slot cap; stored selections survive a save/load round-trip.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-032 — ratls parses Content-Length two ways, one of them `atoi`; its body-length global is non-static

- **Category:** 6 (bugs) / 2 (duplication)
- **Locations:** `RiptOPL/src/platform/ratls.c:164` (`finishResponse`), `RiptOPL/src/platform/ratls.c:371` (`raTlsBodyLength`), `RiptOPL/src/platform/ratls.c:423-433` (`raTlsDownload` digit loop)
- **Problem:** `raTlsDownload` parses the length with a hand-rolled digit loop that cannot overflow its accumulator unnoticed, while `finishResponse` parses the same header with `atoi` — no overflow behaviour, no validation — so the two halves of one download disagree on what lengths are acceptable. Separately, `int raTlsBodyLength` at line 371 is a non-static global in a .c file, exporting a symbol nothing outside the file needs.
- **Fix:** Use the existing digit-loop parse in both places (delete the `atoi` path) and make the global `static`.
- **Benefit:** One length parser with one overflow story; one less exported symbol.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-033 — lwnbdctl writes the same bounded pad-start retry block twice

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/src/app/lwnbdctl.cpp:196-203` (`loadLwnbdSvr`), `RiptOPL/src/app/lwnbdctl.cpp:233-240` (`unloadLwnbdSvr`)
- **Problem:** Both the NBD load and unload paths contain the same ~8-line block: retry `startPads()` up to 100 times with `delay(50)`, then log if it never started — including near-identical explanatory comments. It is the same policy stated twice in one file, so a change to the bound or the logging must be made twice.
- **Fix:** One file-local helper (`startPadsBounded(const char *where)`) called from both sites. Qualifies under the house rule: identical logic, two places, sharing removes code.
- **Benefit:** ~10 lines removed; the retry policy has one home.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W03-034 — OSDHistory's least-used-slot eviction keeps the evicted slot's old timestamp

- **Category:** 6 (bugs)
- **Locations:** `RiptOPL/src/core/OSDHistory.cpp:225-260`
- **Problem:** When a new title takes over the least-launched slot in the history file, the slot's launch count is reset for the new title but its timestamp is not — the new entry inherits the previous title's last-played time. Any ordering or display that trusts the timestamp then misplaces the new title. (The file's 1776-byte icon write past the nominal array size was checked and is a documented, intentional HDDOSD quirk — not a finding.)
- **Fix:** Reset the timestamp alongside the count when a slot changes owner — one assignment at the takeover site.
- **Benefit:** History ordering by recency stops lying about freshly added titles.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ; the visible symptom depends on how the OSD consumes the file, which is outside this codebase)

---

## COVERAGE

**Pin:** `2e347d5ac885cd0ff73e9ad4143781946396f492` — verified before and after reading.

**Files read in full (44 of 45):**

- `src/core/` (17): OSDHistory.cpp, bgm.cpp, cheatconfig.cpp, cheatman.cpp, config.cpp, diagsave.cpp, filemgr.cpp, gsm.cpp, lang.cpp, pad.cpp, riptlite.cpp, settings.cpp, sfx.cpp, sound.cpp, vmc_groups.cpp (see caveat), vmcsaves.cpp, xparam.cpp
- `src/app/` (5): autolaunch.cpp, host.cpp, lwnbdctl.cpp, opl.cpp, settingsio.cpp
- `src/platform/` (22 of 23 in full): debug.cpp, diaglog.cpp, elfldr_noreset.cpp, hdd.cpp, httpcatalog.cpp, httpclient.cpp, ioman.cpp, ioprp.cpp, launchdiag.cpp, lz4.c, nbns.cpp, new.cpp, ps2cnf.cpp, ratls.c, selfupdate.c, sysdisc.cpp, sysneutrino.cpp, system.cpp, sysvmc.cpp, tar.cpp, util.cpp, zso.c

**Read with a stated method caveat (2):**

- `src/core/vmc_groups.cpp` (1,474 lines): lines 1–750 and 1350–end read line-by-line; the middle (751–1349) is homogeneous title-ID data tables and was covered by a Python census extracting and validating every string literal (1,144 IDs; results in W03-021). No code logic lives in that range — it is data tables only.
- `src/platform/md5.c`: lines 1–120 read line-by-line, remainder covered by grep. It is vendored, unmodified-looking RFC 1321 reference code; the only build integration fact relied on (built only in RA builds, caller in `src/sources/rahash.cpp`, outside scope) came from the Makefile and a grep, and md5.c produced no finding.

**In-scope files NOT read:** none. All 45 files in `src/core/`, `src/app/`, `src/platform/` were opened.

**Deliberately checked and excluded** (so they are not re-filed later): httpcatalog.cpp and selfupdate.c (bounded, careful parsing — no finding); nbns.cpp (`strncpy` + explicit NUL — safe); `strcpy(createParam.VMC_filename, path)` in sysvmc.cpp (path ≤ 255 into a 1024-byte field — safe); OSDHistory.cpp's oversized icon write (documented intentional HDDOSD behaviour); settings.cpp's table-driven design (clean); bgm.cpp's line-890 "HACK" (documented bgmMute workaround); the lwnbdctl `strcpy(config.defaultexport, gExportName)` (both buffers are 32 bytes and the source is filled with a bounded copy — no overflow established); opl.cpp's `bootDisplayPeek` mini-parser (a deliberate two-key pre-config peek, justified in its comments — not merged into W03-002, which is about the two *full* SYSTEM.CNF parsers).
