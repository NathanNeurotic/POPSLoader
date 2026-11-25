# Redo Verification — POPSLoader, Chunk F1 (system.lua-heavy Lua findings)

**Subject:** `~/workspace/Sable-audit-redo/Redo-POPSLoader.md`
**Clone:** `~/workspace/audit-clones-2026-11-13/POPSLoader` at pin `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (HEAD re-checked, tree clean; read-only throughout).
**Method:** refute-first. Every cited line opened in context; every census re-derived with my own scripts/greps against the pin; defeating evidence (extra branches, pre-normalizing callers, shadowing definitions, load order, test-harness consumers outside the report's search scope) hunted before accepting any claim.
**Assigned:** RE-POPS-043, 055, 070, 079, 080, 081, 090, 091, 092, 093.

---

### RE-POPS-043 — VERIFIED

- The local normalizer at `bin/POPSLDR/system.lua:2526-2547` has accepting branches only for QWERTY (2528), DVORAK (2531), AZERTY (2534), QWERTZ (2537) and ABNT (2540), then falls through to `return PLDR.KEYBOARD_LAYOUT_QWERTY` (2546). A repo-wide search for `"ABC"` / ABC handling in `system.lua` + `ui.lua` finds **no accepting branch anywhere**: only the constant definition `PLDR.KEYBOARD_LAYOUT_ABC = "ABC"` (2508), the two false comments (2545, 6241), the ui.lua row table / layout_order, and the ui.lua fallback (below).
- Every consumer routes through that normalizer, and I found *more* than the report lists: encode (5904), snapshot (5967), apply (6015), load (6451/6453) — plus the report's unlisted sites at 4910, the public wrapper `PLDR.NormalizeKeyboardLayout` (4916-4917, a pure delegate to the local), 5132, and the settings-commit merge at 6630. The public wrapper means there is no second, divergent normalizer hiding anywhere.
- ui.lua side confirmed: `layout_order` includes `"ABC"` (2533), a complete ABC row definition exists (2570-2578), the Settings row cycles through `layout_order` (4691, 5092-5098), and the settings commit normalizes the draft (4548-4549), as does `UI.SyncSettingsDraftFromRuntime` (7504-7505, also unlisted by the report).
- PathEditor fallback / load order, as tasked: `_NormalizeLayout` (ui.lua:2609-2618) delegates to `PLDR.NormalizeKeyboardLayout` whenever it exists and only then falls back to its own ABC-accepting branch (2614-2615). Load order makes the delegate always present: `etc/boot.lua:181` runs `require("system")`; system.lua defines `PLDR.NormalizeKeyboardLayout` at 4916 and only afterwards loads ui.lua via `pcall(require, "ui")` at 4978. So in the real load order the fallback branch **never runs**. `_CurrentRows` (2619-2626) therefore gets `"QWERTY"` for an ABC selection and returns the QWERTY rows (its ABC fallback at 2623 fires only for a nil rows lookup, which QWERTY never produces). `Open` sets `layout_key` through the same delegate (2644).
- False comments confirmed verbatim: system.lua:2545 and 6241 assert "ABC remains selectable / stays selectable"; ui.lua:4812-4817 sets the Reset-Defaults value to `"ABC"` and immediately normalizes it — producing QWERTY.
- Fix sanity: adding one ABC comparison to the single local normalizer is LESS-NOT-MORE correct; every consumer already routes through it, and the ui.lua fallback then agrees instead of being dead.

### RE-POPS-055 — VERIFIED-DRIFT

- Re-derived by my own script against the pin: the `PLDR.I18N` literal spans system.lua:2568-4843 = **2,276 lines** and **172,314 bytes** (raw byte slice, exact) — both figures exactly as reported. Entry census by parsing each language block: **FR 304, DE 305, PT 305, ES 304, IT 305, HU 317, SK 409 = 2,249 entries** — exactly as reported. `PLDR.L` at 4844-4854 returns the input untouched for EN and reads only the active language's sub-table, as claimed; the block is bin2c-embedded (Makefile:208-210, via the token-preserving minifier) and constructed in the main chunk.
- **Corrected figure:** the denominator is wrong. system.lua at the pin is **571,596 bytes** (`wc -c` and git blob size agree), not 568,668 bytes. The I18N share is therefore 172,314 / 571,596 = **30.1%** (the report's "30%" survives rounding). The "~19% of lines" benefit also survives: 2,276 / 11,784 = 19.3%. No other figure in the finding is affected; the 200-local-cap citations check out (the comments are at 5172 and 5796, report said 5795/5171 — off by one, immaterial).
- Fix sanity: lazy per-language load is a justified structural exception as argued; not re-litigated here beyond noting the measured boot-cost limb remains INFERRED, exactly as the report labels it.

### RE-POPS-070 — VERIFIED

- Read `BuildCoverCandidates` end-to-end (ui.lua:241-291): the non-HDD branch builds `artdir = (devroot or dir).."ART/"` (279-280) from the VCD path's device root and returns exactly `artdir..name.."_COV.png"` (plus the UDPFS beside-the-game second probe, 284-289). **ART_LOCATION is never consulted** — no reference to it, to `PLDR.ART_LOCATION`, or to any pops/pops_art variant anywhere in the function. The details path is the same shape (`devroot.."ART/"..name..".txt"`, ui.lua:564).
- Repo-wide grep for `ART_LOCATION|ArtLocation|art_location` across Lua + C/C++ finds *only* plumbing: system.lua encode (5913), snapshot (5975), apply (6038-6039), default (6250), parse (6402), assign (6484-6485), commit merge (6587-6588) — plus two sites the report did **not** list, the commit return field (6637) — and ui.lua snapshot (3175-3178), validate (4495), commit opts (4524), direct assign (4580), plus two more unlisted ui.lua sites: Reset-Defaults (4836-4837) and the settings dirty check (5392). No lookup consumer exists anywhere.
- The Settings row is indeed gone: the only ui.lua:5218-5221 trace is the EXP35 comment stating the value "is kept inert in the settings file only so older sidecars still parse" — quoted accurately by the report.
- Net: the "~10 live sites" claim is if anything understated (≈14 code sites by my count). Mechanism, inertness, and the ignore-on-load fix all hold.

### RE-POPS-079 — VERIFIED-DRIFT

- Read all four functions in full (system.lua:9880-10023). The two parsers' loops are structurally identical as claimed: `PLDRGC1` first-line check, `S ` signature check against `PLDR.GameListCacheSignature()`, `G `/`H ` accumulation, `\r$` stripping, and the `sig_ok`/`#games == 0` rejection — `PLDR.LoadGameListCache` (9899-9926) returns games/hidden, `PLDR.HDD.ReadCache` (9991-10023) assigns `PLDR.HDDCACHE`/`HDDCACHE_HIDDEN`. The writers (`SaveGameListCache` 9880-9895 vs `HDD.CreateCache` 9944-9989) share the header/signature/`G`/`H` line construction and differ only in storage mechanics and in how the hidden set is iterated, as the report's framing allows. A repo-wide `PLDRGC1` search finds no third parser or builder.
- **Corrected figures:** the parallel "Codex F5" size-cap lines are **9904** (LoadGameListCache) and **9996** (ReadCache), not 9906 / 10001 as printed (9906 is the post-read data check; 10001 is a parse comment). The duplication mechanism and the drift-cost argument are unaffected.

### RE-POPS-080 — VERIFIED-DRIFT

- Zero callers, proven repo-wide: a full-tree grep for `ResolveHddGamePartitionReadablePath` (Lua, C/C++, Python harness, docs excluded only for prose mentions — none exist) returns **exactly 1 occurrence, its own definition** at system.lua:944. It is a `local function`, so no dynamic/global access path exists.
- Live twin confirmed: `ResolveHddPartitionReadablePath` (system.lua:886-921, report said 887-923) is called at 1038, exported as `PLDR.ResolveHddPartitionReadablePath` at 1897-1898, and used from ui.lua (257, 304, 585). The dead body is a near-verbatim subset as claimed — same `ParseHddPartitionMount` guard, same recorded-prefix probe (`GetRecordedHddMountPrefix` + `BuildMountedReadablePath` + `ProbePathExists`), same mount-and-probe tail — differing in that it lacks the live twin's embedded-prefix probe (895-901) and calls `MountHddGamePartitionTracked` instead of `MountHddPartitionTracked` with a slot.
- **Corrected figure:** the dead function is **26 lines (944-969)**, not 29. The report's 29 is its location-range width (944-972), which runs into the next function's comment header at 971; deleting 944-970 (function + trailing blank) is the clean cut. Benefit overstated by ~3 lines; the deletion itself is safe and LESS-NOT-MORE correct.

### RE-POPS-081 — WEAKENED

Full reasoning (the duplication is real; the fix's safety claim is overstated):

- What holds: the three helpers exist exactly as cited — plain `EnsureTrailingSlash` (system.lua:23-31, exported `_G.EnsureTrailingSlash` at 32; the `_G` export has no consumer outside system.lua), `EnsureTrailingSlashNormRaw` (167-171, `NormalizeFsPathRaw` then strip-trailing-`/+` then append), and `NormalizeDirPath` (221-230), which re-implements the slash guarantee inline (225-228) instead of calling either helper; `JoinPath` (232-239) builds on the third. The plain form has exactly the 7 call sites the report lists (1548, 1784, 10292, 10533, 10534, 11128, 11463).
- Where the fix's premise fails: the fix asserts the normalizing form "is safe for every current plain-form call site, whose inputs are already device paths." Tracing every plain call site's input upstream, that is **not proven for all of them, and two classes are demonstrably not pre-normalized**:
  1. **10534** — `EnsureTrailingSlash(System.currentDirectory())` takes the raw OS cwd with no `NormalizeFsPathRaw` pass at that site (contrast 10533's `APP_DIR_LOCAL`, which genuinely is pre-normalized: it is produced by `ResolveAppDirLocal`, whose returns are all `EnsureTrailingSlashNormRaw` outputs, 190/214/218).
  2. **1784 and 11463** — `gamelocation` is a caller-supplied argument. Inside `RunPOPStarterGame` the only normalization applied before the 11463 use and before `ResolveLaunchPopstarterPath` (→1784) is `policy.normalize` (10924), which is `NormalizeIsraPath` (10334-10336) — it rewrites an `isra:` prefix and does **not** collapse backslashes or duplicate slashes. Upstream, `PLDR.GAMEPATH` / UI roots are code-constructed canonical `mass:/POPS/`-style strings in practice, but nothing in the call chain *guarantees* that spelling.
  The two helpers are also observably different functions, not spellings of one rule: plain preserves backslashes and duplicate/trailing slash runs and returns `nil` for `nil`; NormRaw converts `\`→`/`, collapses `/+`, strips all trailing slashes before appending one, and returns `"/"` for `nil` (via `NormalizeFsPathRaw(nil) == ""`). Sites 10292/11128 (`pops_root` from `policy.normalize` or literal `"<dev>:/POPS/"` constructions, 10929-10961) and 1548 (root from `GetMX4SIOMassRootNow`, whose identity roots are canonical `mass:/`/`massN:/` strings, or `PLDR.MX4SIO.ROOT`) are canonical in practice, so consolidation would very likely change nothing on real hardware paths — but "safe for every current call site" is an assertion the code does not establish, and the report itself rates the fix Risk: Med, which is where this belongs.
- True scope: keep the finding as a duplication/over-engineering observation (three helpers, one inline re-implementation — verified). The consolidation fix should be re-scoped from "safe, just rename" to "consolidate after auditing 10534 and the two `gamelocation` sites, or keep the plain helper for raw-cwd/caller-input sites." That is a weaker, conditional fix than the one printed.

### RE-POPS-090 — VERIFIED

- My own full-text search across all Lua, `src/*.cpp/*.c/*.h`, **and** `tools/host_harness.py` (a scope the report did not claim but which could have hidden consumers) returns exactly one occurrence — the definition — for each of the four: `PLDR.GetBootKind()` (system.lua:2153-2155), the **global** `CYCLE_CLAMP` (4972-4976; its sibling `CLAMP` at 4966 is genuinely called throughout ui.lua), local `GetBootOccupiedPfsSlot()` (10364-10377; its helper `ExtractLaunchPfsSlot` is used at 1045-11146 in five other places, as claimed), and `STOP()` (etc/boot.lua:179).
- The only other mentions of `GetBootKind` anywhere are prose in DECISIONS.md/STATE.md/docs describing it as a public API — no code caller. Deletion is safe as a code matter (whether a documented-but-uncalled public API should be kept is a maintainer call, not a correctness issue).

### RE-POPS-091 — WEAKENED

Full reasoning (four of five limbs hold; limb (d) is refuted by a consumer outside the report's search scope):

- (a) `PLDR.EnsureTrailingSlashNorm` (system.lua:5615-5617): verified dead — the public wrapper's exact name occurs only at its definition; all internal uses call the local `EnsureTrailingSlashNormRaw` directly. (Overlap note: this limb belongs to the same helper family as RE-POPS-081 — not a duplicate finding, since 081 never mentions this wrapper, but the two fixes should be landed together.)
- (b) `PLDR.HDD_FS_VALUES` (5695): verified dead — one occurrence repo-wide; ui.lua hard-codes the identical list as `HDD_FS_SEQ` at ui.lua:5161, as claimed.
- (c) `PLDR.MX4SIO.PREFIX_HINT`: verified dead as a *read* — occurrences are only the default `PREFIX_HINT = nil` (2224), the probe function `DetectMX4SIOPrefixHint()` (4950-4956, a `doesFileExist` on `.boot_mx4sio` via `JoinPath(APP_DIR_LOCAL, …)`), and its assignment at load time (4957). Nothing reads the field. The per-boot probe cost claim holds.
- (e) `PLDR.HDD.USECACHE = false` (2204): verified — the 2202-2203 comment itself calls it "a dead legacy flag now," and no code reads it (the other USECACHE hit, 9687, is a historical comment).
- (d) `UI.ResolveSelectedVcdPath` (ui.lua:6851): **the "dead export" conclusion is refuted.** The report's literal claim — never referenced by system.lua or C — is true, but incomplete in the way that matters: `tools/host_harness.py` test **T54** deliberately consumes the export. At tools/host_harness.py:2334-2335 the harness hard-fails if it is missing ("UI.ResolveSelectedVcdPath is not exported -- the join step is untestable again"), and at 2375 it calls `UI.ResolveSelectedVcdPath(entry, gp)` across eight device cases (the issue-#570 MX4SIO join regression). The export is intentional test surface, commented as such at ui.lua:6845-6850. Deleting it, as the printed fix directs, would break T54 and re-blind the exact regression the test was written to pin.
- True scope: delete (a), (b), (c) (probe + assignment + default together) and (e) as printed; **keep (d)** or, if the export is ever removed, remove/rework T54 in the same change with the loss of coverage stated.

### RE-POPS-092 — VERIFIED

- Independently re-ran the key-set comparison with my own script: parsed all 2,249 I18N entries (426 unique keys) out of system.lua:2568-4843, then searched every key (in both raw-escaped and unescaped form) against all string occurrences outside the I18N block in system.lua + ui.lua + images.lua + etc/boot.lua. Result: **exactly the report's 20 entries are stale, and no others.** (My first pass flagged only 14 because "Cover/details folder" occurs in a ui.lua *comment* at 5218; excluding comments — as the report explicitly does, noting it survives "only inside a code comment" — the count is exactly 20.)
- Every one of the 20 listed locations was opened and checked individually; all 20 line numbers are exact:
  - SMB warning (old wording) ×6: FR 2772, DE 3079, PT 3387, ES 3695, IT 4002, HU 4358. The live notification at ui.lua:3920 uses the different wording ("…Games list but won't boot without them --\ninstall via Settings > SMB modules, then Save"), which has its own separate entries sitting immediately adjacent (e.g. FR 2771 vs stale 2772). SK carries the live wording (4751) but not the stale one — the "Slovak already dropped it" claim holds. SK likewise has no "Cover/details folder" entry.
  - "Cover/details folder" ×6: FR 2629, DE 2936, PT 3244, ES 3552, IT 3859, HU 4198 — the removed ART_LOCATION row's label (see RE-POPS-070); its only other in-tree occurrence is the EXP35 comment.
  - Hungarian-only orphans ×8: "ART (at root)" 4155, "Don't Save" 4214, "POPS (beside game)" 4306, "Profile defaults restored" 4315, "Save Settings" 4331, "Save your changes before leaving?" 4332, "X = Keep      O = Revert" 4377, "X = Select      O = Cancel" 4378 — none occurs as a source string anywhere outside the I18N block.
- Defeating-evidence hunt for dynamic construction: `PLDR.L` is sometimes called with variables (e.g. modal labels, `UI._SMB_LABELS`), but the two composed-string orphans are positively explained — ui.lua:1137-1139 `PadHintPair` now *composes* "X = " .. `PLDR.L(word)` .. "      O = " .. `PLDR.L(word)` from word-level keys (call sites 7062 "Select"/"Cancel", 7320 "Keep"/"Revert"), so the whole-string keys can never be looked up. No concatenation anywhere builds any of the other listed keys.
- Cross-reference, not a duplicate: limb (b) is the translation residue of the same EXP35 removal as RE-POPS-070's plumbing residue; the two findings cover different artifacts and both stand.
- Fix sanity: deleting untranslatable-by-construction entries is safe and LESS-NOT-MORE correct.

### RE-POPS-093 — VERIFIED

- Both definitions opened: system.lua:10181-10187 (local, nil/empty-guarded, used by `DeriveGameNameFromSelection` at 10270) and ui.lua:122-125 (local, `tostring`-coercing, parenthesized to one return value, used at its single ui.lua call site 3355). Both bodies are the identical operation `string.gsub(s, "%.[Vv][Cc][Dd]$", "")`, as claimed; the guard difference is cosmetic (both return `""` for nil/empty input).
- Load-order feasibility of the fix, checked: ui.lua already consumes system.lua globals (`JoinPath`, `CLAMP`) and system.lua loads first (`require("system")` from boot.lua; ui.lua required at system.lua:4978). One subtlety the fix must respect: the system.lua definition sits at 10181, *after* the ui.lua require at 4978, so ui.lua must reference the shared function as a global at call time (its call site is inside a render function, executed long after system.lua finishes loading) rather than aliasing it at ui.lua load time. As printed ("calling the shared one at its single ui.lua call site"), the fix does exactly that and works.
- The ui.lua comment block at 99-103 documenting the past truncation bug in this operation is as described (the block sits at 98-103, directly above the faded-palette comment that precedes the definition).

---

## Closing tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 5 | RE-POPS-043, 070, 090, 092, 093 |
| VERIFIED-DRIFT | 3 | RE-POPS-055, 079, 080 |
| WEAKENED | 2 | RE-POPS-081, 091 |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |
| **Total** | **10** | |

No finding is refuted outright. The two WEAKENED findings keep their core mechanisms; what shrinks is their fixes (081's consolidation is not provably behavior-identical at three call sites; 091's five-item deletion list must drop limb (d)).

## Candidates (new observations, not verdicts)

- **CAND-F1-1 (extends RE-POPS-093's surface):** a third inline copy of the .VCD-strip grammar exists at system.lua:9585 — `PLDR.HDD.GameEntryDisplayKey` inlines `string.gsub(base, "%.[Vv][Cc][Dd]$", "")` instead of calling the local `StripVcdExtension` defined later in the same file. (The `.hide` rewrites at 8669/8700 use the same pattern with a different replacement and are a related but distinct operation.) If 093's consolidation happens, this site should be swept into it.
- **CAND-F1-2 (doc residue of RE-POPS-090):** DECISIONS.md:300, STATE.md:128 and docs/archive/LAUNCH_HYGIENE.md:150 describe `PLDR.GetBootKind` as a consumed public API ("all consume this one resolver" / "public APIs for any…"). If 090's deletion is accepted, those three prose sites become stale in the same change; if it is not accepted, the docs are the argument for keeping it — either way the docs and the code currently disagree about whether it has consumers.
