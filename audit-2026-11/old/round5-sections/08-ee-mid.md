# Round 5 — Section 08: EE `src/` mid tranche (third tranche of never-fully-read EE files)

- **Repo:** NathanNeurotic/Launchstation
- **Pin:** `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (`git log` verified at start and end of section work; `git status --porcelain` empty at end — read-only honored, no fetch/update)
- **Rules applied:** LESS NOT MORE; exact `path:line` citations; claims labelled READ / INFERRED; no secret-like values printed (locations only); no build/hardware claims; LAUNCHSTATION-001…096 not repeated (cloud subsystem size/duplication = -004/-031 stand).

## (a) Coverage ledger

Every line of each file below was read end-to-end in this section (line counts from `wc -l`):

| File | Lines | Notes |
|---|---|---|
| `src/cloud_google.c` | 1,635 | Drive API client: device-code link flow, JSON extraction, upload/download, backup history |
| `src/cloud_http.c` | 1,312 | HTTP/TLS transport: response parsing, chunked decoding, redirect handling, download-to-fd |
| `src/dash_ui.c` | 1,540 | Modal menus, hints, toasts, shared dashboard widgets |
| `src/dash_main.c` | 1,533 | Dashboard scene loop, scene-override stack, tab model |
| `src/dash_editor.c` | 1,494 | Text/hex editor, background IO job protocol |
| `src/dash_hdd.c` | 1,342 | HDD Manager: APA scan, PFS/HDL probes, create/remove/rename/format, header injection UI |
| `src/dash_widgets.c` | 1,339 | Modal keyboard, classic-UI overrides, IPv4 editor, file/folder picker |
| `src/dash_themes.c` | 1,308 | Theme model, 18 presets, validation, DASHBOARD.CNF + theme-folder persistence |
| `src/hdd_header_injector.c` | 1,160 | APA partition-header read/patch/write, SYSTEM.CNF extraction/editing |
| `src/kelf_signer.c` | 1,153 | KELF signing: key-store parsing, DES/3DES, ELF wrapping. Structure/locations only — no key material reproduced anywhere in this report |
| `src/mmce_backup.c` | 1,002 | MMCE backup/restore, fingerprint cache, history pruning |
| **Total** | **14,818** | |

Supporting headers consulted for constants only: `include/cloud_http.h` (body cap), `include/cloud_google.h` (link-flow return contract), `include/dash_internal.h` (`DASH_PATH_MAX` = 256 at :34, `DASH_THEME_NAME_MAX` = 32 at :213), `include/launchelf.h` (`MAX_PART_NAME` = 32 at :202).

## (b) Findings

### T8-F1 / `atoi()` on server-supplied Content-Length overflows before the range check / Category 6

- **Locations:** `src/cloud_http.c:596`, `src/cloud_http.c:644`, `src/cloud_http.c:668` (all in `read_response`), `src/cloud_http.c:1123` (download path)
- **Problem:** The Content-Length header value — fully server-controlled — is converted with `atoi()` into an `int` and only afterwards compared against `CLOUD_HTTP_BODY_MAX` (256 KiB, `include/cloud_http.h:10`). A header such as `Content-Length: 99999999999` overflows the `int` conversion first (undefined behaviour; in practice wraparound), so the value that reaches the range check is not the value the server sent. A wrapped negative or small-positive result passes a check the real length would fail, and the body handling then proceeds on a false length.
- **Fix:** Parse with `strtol` into a `long`, reject/clamp anything outside `0 … CLOUD_HTTP_BODY_MAX` before any use; treat an unparseable length as a protocol error.
- **Benefit:** Removes UB on untrusted network input at the single point where every response body size is decided.
- **Effort:** Small — four call sites, one shared helper.
- **Risk:** Low — behaviour for well-formed responses is unchanged.
- **Confidence:** READ

### T8-F2 / Hand-rolled JSON string extractor mis-handles escaped backslash, never decodes `\uXXXX`, and matches keys by first occurrence / Category 6

- **Locations:** `src/cloud_google.c:61–107` (`json_string` and its callers, e.g. `drive_find_child`'s first-`"id"` extraction)
- **Problem:** Three defects in the one parser every Drive response passes through. (1) The closing-quote test `end[-1] != '\\'` treats a string ending in an escaped backslash (`"…\\"`) as unterminated, so the scan runs past the true end of the string into following fields and returns corrupted contents. (2) `\uXXXX` escapes fall into the `default:` copy case and are passed through literally, so Drive file/folder names or IDs containing them are mangled. (3) Key lookup is `strstr(json, "\"key\"")` — first occurrence in the document wins, so a nested object carrying the same key name earlier in the payload shadows the intended field.
- **Fix:** Track escape state with a proper in-escape flag instead of the look-behind test; decode `\uXXXX` (at minimum to `?`/UTF-8 for the BMP); scope key searches to the object level actually being read.
- **Benefit:** Drive listings, backup-history lookups and uploads stop silently corrupting names/IDs on legal JSON the server is entitled to send.
- **Effort:** Medium — one function, but every caller’s assumptions need a pass.
- **Risk:** Low–medium — parser behaviour changes; mitigate by keeping the function signature and failure contract identical.
- **Confidence:** READ

### T8-F3 / Drive request builders ignore `snprintf` truncation / Category 6

- **Locations:** `src/cloud_google.c:718–735` (`drive_find_child` query), `src/cloud_google.c:1193–1195` (`drive_create_folder` body), `src/cloud_google.c:1317–1326` (`drive_upload_file` path/metadata)
- **Problem:** Query strings, JSON bodies and request paths are built with `snprintf` whose return value is not checked. On truncation the code proceeds as if the request were complete: a truncated Drive query silently searches for the wrong folder, and a truncated JSON body is sent malformed. The same file proves the checked pattern is available and intended — `cloudGoogleListBackupHistory` (`src/cloud_google.c:878–901`) and `cloud_recovery_path` (`src/cloud_google.c:968–975`) do test the returns.
- **Fix:** Check the return at these three sites and fail the operation (as the two correct sites already do) instead of sending a partial request.
- **Benefit:** Long folder/file names fail loudly at the client instead of creating/searching the wrong Drive object.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** READ

### T8-F4 / `Transfer-Encoding: chunked` detection is case-sensitive / Category 6

- **Locations:** `src/cloud_http.c:598`, `src/cloud_http.c:659`, `src/cloud_http.c:1140`
- **Problem:** All three transfer-decoding decisions test `strstr(value, "chunked")` case-sensitively. HTTP tokens are case-insensitive; a server answering `Transfer-Encoding: Chunked` is treated as identity-encoded, so chunk framing is delivered to the caller as body bytes and the connection state desyncs from the real message boundaries.
- **Fix:** Use a case-insensitive token test (the codebase already links `stricmp`/`strnicmp`-style helpers) at the three sites.
- **Benefit:** Interoperability with any conforming server, not just ones that happen to lowercase the token.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** READ

### T8-F5 / APA header injection rewrites 2 MB in place with no rollback and no readback verification / Category 6

- **Locations:** `src/hdd_header_injector.c:1142–1153` (`InjectHddPartitionHeaderFromSource`), write helper `src/hdd_header_injector.c:466–478` (`hddHeaderWriteSectors`)
- **Problem:** The injector reads 4,096 sectors of the partition header, patches them in memory, and writes them back sector-by-sector directly over the only on-disk copy. A failure part-way (power loss, IOP error, bad sector) returns an error but leaves a mixed old/new header on disk — the partition’s SYSTEM.CNF/icon area is then neither the old nor the new version — and even on success the result is never re-read to confirm the write landed. Distinct from LAUNCHSTATION-034 (that finding covers the self-updater overwriting the running ELF; this is the APA partition header on the HDD).
- **Fix:** After the write loop, re-read the sectors and compare against the patched image; report mismatch as failure. (A true rollback copy is a bigger change; verification alone converts silent corruption into a reported error.)
- **Benefit:** The most destructive write in the dashboard becomes detectable when it goes wrong instead of surfacing later as an unbootable partition.
- **Effort:** Small for readback-verify; medium for full rollback.
- **Risk:** Low.
- **Confidence:** READ

### T8-F6 / KELF signing key material is never scrubbed from stack copies / Category 6

- **Locations:** `src/kelf_signer.c:619–732` (`parse_key_store`), `src/kelf_signer.c:734–742` (`KelfSignValidateKeys`), `src/kelf_signer.c:981–1095` (`KelfSignElfToMemory`); key-store struct definition at `src/kelf_signer.c:92–107`
- **Problem:** Key-store material (structure/locations only — no values reproduced here) is copied into stack-resident `KelfKeyStore` instances and derived-key buffers in several functions and is never wiped before return. On a shared-console threat model this is minor, but the copies outlive the operation in freed stack frames and can surface in crash dumps or later stack reuse. (The presence of embedded key material itself is already covered by LAUNCHSTATION-007 and is not re-filed.)
- **Fix:** Zero the local key-store/derived-key buffers on every exit path of the three functions.
- **Benefit:** Shrinks the lifetime of signing material to the operation itself at near-zero cost.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** READ (absence of any scrubbing in the three functions)

### T8-F7 / `des_cbc_crypt` performs fixed 8-byte block copies with no size validation / Category 6

- **Locations:** `src/kelf_signer.c:396–423` (`des_cbc_crypt`); validating wrapper at `src/kelf_signer.c:436–439` (`tdes_cbc_crypt`)
- **Problem:** `des_cbc_crypt` loops in 8-byte steps issuing fixed 8-byte `memcpy`s with no check that `size` is a multiple of 8; a non-multiple size would read and write past the caller’s buffers on the final partial block. Today the defect is latent: the wrapper validates, and all direct callers pass 8 or 32. It is one future caller away from a live overflow in the signing path.
- **Fix:** Delete the unvalidated path or add the same size check the wrapper already performs; LESS-preferred form: route all callers through `tdes_cbc_crypt` and make `des_cbc_crypt` static-internal with an early return on bad size.
- **Benefit:** Removes a loaded foot-gun from the most sensitive file in the tree.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** INFERRED (latent — no current caller triggers it)

### T8-F8 / MMCE history newest/prune ordering is lexicographic, but same-second collision names sort backwards / Category 6

- **Locations:** `src/mmce_backup.c:136–164` (`newest_history`), prune selection in the same file, naming at `src/mmce_backup.c:486–517` (`unique_history_path`)
- **Problem:** When two backups land in the same second, `unique_history_path` names the later copies `WLE-<stamp>-01.<ext>`, `-02`, … Both “newest” selection and prune-victim selection compare names with plain `strcmp`. Because `'-'` (0x2D) sorts before `'.'` (0x2E), the base file `WLE-<stamp>.<ext>` sorts *after* every suffixed sibling: “newest” can return the older base copy, and pruning can delete a genuinely newer suffixed backup first.
- **Fix:** Compare by (timestamp, numeric suffix) instead of raw string order — or zero-pad so the base name carries `-00`.
- **Benefit:** Restore-from-newest and history pruning act on the backup the user expects in the same-second case.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** READ

### T8-F9 / Three near-identical recursive directory walks in `mmce_backup.c` / Category 2

- **Locations:** `src/mmce_backup.c:686–717` (`count_candidates`), `src/mmce_backup.c:742–786` (`process_tree`), `src/mmce_backup.c:920–963` (`scan_tree`)
- **Problem:** The same skeleton — `dread` loop, dot-entry skip, path join, recursing into subdirectories — is implemented three times, differing only in the leaf action (count / copy / fingerprint). Any fix to traversal behaviour (depth guard, error handling, skip rules) must currently be made three times and can silently diverge.
- **Fix:** One walker taking a leaf callback; delete the other two skeletons.
- **Benefit:** Net deletion; traversal fixes land once.
- **Effort:** Medium.
- **Risk:** Low–medium — the three walks run at different backup phases; keep call order identical.
- **Confidence:** READ

### T8-F10 / Scene-override stack loses one level when nesting exceeds depth 8 / Category 6

- **Locations:** `src/dash_main.c:1159–1175` (`dashPushSceneOverride` / `dashPopSceneOverride`)
- **Problem:** On push, `scene_override_depth` is incremented even when the store is skipped because the fixed stack (depth 8) is full. The matching pop then restores `NULL` instead of the 8th override, and every subsequent pop is off by one — the dashboard can lose its scene (black/no-render frame) after deeply nested full-screen tools exit. Current nesting is ~2, so this needs 9 nested overrides to bite.
- **Fix:** Only increment depth when the entry was actually stored (or refuse the push), keeping push/pop symmetric.
- **Benefit:** Removes a latent scene-loss desync ahead of any deeper tool nesting.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** INFERRED (latent at current call depth)

### T8-F11 / Unbounded `atoi`/digit accumulation overflows before clamping in theme and IPv4 parsers / Category 6

- **Locations:** `src/dash_themes.c:692` (`parseColor` decimal path), `src/dash_themes.c:737–742` (`parseInt`), `src/dash_widgets.c:690–705` (`ipParse`, accumulation at :697)
- **Problem:** Same defect class as T8-F1, on local file input: theme files and stored settings are parsed with `atoi()` / open-coded `v = v*10 + digit` loops over digit runs of unbounded length, and the range clamp is applied only after the conversion. A theme.cfg value like `brightness = 99999999999999999999` or a stored IP string with a long digit run overflows signed `int` (UB) before the clamp can run. The values are clamped eventually — the overflow happens first.
- **Fix:** Clamp inside the accumulation loop (stop accumulating once past the field’s maximum) or parse with `strtol` and clamp the `long`.
- **Benefit:** User-supplied theme/config files — an explicitly supported sharing format for themes — cannot invoke UB in the parser.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** READ

### T8-F12 / Theme-folder read and load are the same ~35-line routine twice; write and export repeat the mkdir preamble / Category 2

- **Locations:** `src/dash_themes.c:1046–1079` (`dashThemeFolderRead`) vs `src/dash_themes.c:1122–1159` (`dashThemeFolderLoad`); preamble at `src/dash_themes.c:1108–1119` (`dashThemeFolderWrite`) repeated at `src/dash_themes.c:1171–1182` (`dashThemeFolderExport`)
- **Problem:** Read and Load duplicate the entire root-iteration, 16 KiB text load, preset-seed, KV-parse, name-fallback, relative-path resolution and image-fallback sequence, differing only in destination (caller’s `DashTheme` vs the live theme + commit). The folder-create preamble is likewise copied between Write and Export. Any change to theme-folder semantics must be mirrored by hand.
- **Fix:** Extract one `loadThemeFolder(folder, DashTheme*)`; Load becomes that plus assignment/commit, Read becomes that alone. Same for the mkdir preamble.
- **Benefit:** Net deletion of ~40 lines; one place to fix theme-folder behaviour.
- **Effort:** Small–medium.
- **Risk:** Low — Load’s worker-safety note (Read is called off-thread) must be preserved in the shared helper’s contract.
- **Confidence:** READ

### T8-F13 / HDL game-title rename caps the title at partition-name length, silently truncating longer titles / Category 6

- **Locations:** `src/dash_hdd.c:700–727` (`actRenameGame`); buffer at `src/dash_hdd.c:702`, keyboard call at `src/dash_hdd.c:711`
- **Problem:** The rename buffer is deliberately sized for a full game title (`char name[64 + 1]`, fed from `p->game.Name`), but the keyboard is opened with max length `MAX_PART_NAME - 1` = 31 (`MAX_PART_NAME` = 32, `include/launchelf.h:202`) — the partition-name cap, apparently carried over from `actRename` (which correctly uses `MAX_PART_NAME - 3` for a 33-byte partition buffer). The modal keyboard clamps to `max_len` on confirm, so renaming a game whose title exceeds 31 characters silently cuts the title to 31 even if the user only edited its start.
- **Fix:** Pass the title’s real capacity (`sizeof(name) - 1`) to the keyboard for this call site.
- **Benefit:** Long HDL titles survive a rename intact.
- **Effort:** Small (one argument).
- **Risk:** Low.
- **Confidence:** READ for the code path (cap + clamp-on-confirm); INFERRED that fielded HDL titles exceed 31 characters (the 65-byte buffer choice in this same function is the in-file evidence)

## (c) REVISION-CANDIDATEs

None. Nothing read in this tranche contradicts LAUNCHSTATION-001…096. Two near-misses were checked and deliberately *not* filed as revisions or new findings:

- `prune_history`’s per-generation folder re-enumeration in `src/mmce_backup.c` **is** LAUNCHSTATION-077 — confirmed against the round-3 section text; not re-filed (T8-F8 is a distinct defect in the same file: name ordering, not re-enumeration).
- The unauthenticated redirect breadth in the updater download path is deliberate per the in-code comment at `src/cloud_http.c:1279` and adjacent to LAUNCHSTATION-034’s scope; the bearer-token paths themselves validate the host per hop (see checked-clean).

## (d) Checked-and-clean (candidates examined and dissolved, with reasoning)

**Cloud (`cloud_http.c` / `cloud_google.c`)**
- `cloudGoogleFinishLink` slow_down mapping (`src/cloud_google.c:651–653`) looks inverted but is correct: `strcmp(...)? 1 : 2` yields 2 for `slow_down` and 1 for `authorization_pending`, matching the contract in `include/cloud_google.h`.
- `download_write` MEM_FD path (`src/cloud_http.c:847–868`): the `*written > max_bytes - len` guard, copy-then-skip behaviour and SHA update ordering are all correct.
- `decode_chunked` (`src/cloud_http.c:528–556`): each chunk length is checked against the remaining buffered data before the `memmove`. Caveat noted, not filed: CRLF search uses `strstr` on the body region, bounded in practice by the NUL at `used` in the receive buffer.
- Bearer-token redirect discipline (`src/cloud_http.c:939–951`, `:1000–1006`, `:1014` with `cloud_google_media_host`): the token is only sent to `www.googleapis.com` and redirect targets are re-validated per hop.

**`hdd_header_injector.c`**
- `hddHeaderAttributeFileCapacity` capping at `APA_HEADER_SYSTEM_CNF_MAX_SIZE` (`src/hdd_header_injector.c:519–520`) is correct — the function is only used for system.cnf; disk-supplied offsets are validated (`:507`, `:533–540`) before the `raw_offset` use at `:643`.
- Single `genRead` sites (`:913`, `:741–744`) compare against the full expected size and fail with `-EIO` on short reads rather than proceeding on partial data.
- `hddHeaderDelay` busy-wait (`:91–98`) not filed — same class as existing LAUNCHSTATION-014.

**`kelf_signer.c`** (structure/locations only)
- The two output-size computations agree: `padded_content_size` (`src/kelf_signer.c:756–762`), `KelfSignGetOutputSize` (`:764–805`) and `load_elf_into_output` (`:924–979`) apply the same trailing-zero scan capped at `KELF_CONTENT_TRAILING_SCAN` (0x18), with the final ≤ max check at `:970`.
- `parse_key_store` line splitting is safe because `load_text_file` (`src/kelf_signer.c:561–601`) allocates `size + 1` and NUL-terminates.
- Embedded key-material constant (location only: `src/kelf_signer.c:158–160`) and key-file field specs (`:131–144`) fall inside LAUNCHSTATION-007’s scope — not re-filed.

**`mmce_backup.c`**
- `files_equal_serial` / `read_chunk` per-chunk open/close (`src/mmce_backup.c:166–186`, `:376–395`) initially looked wasteful; dissolved — MMCE permits one open file at a time (stated at `:250–251` for the fingerprint reader), so the pattern is forced by the device.
- `fp_read` cache (`:204–248`) tag/valid handling is sound; `read_sidecar` (`:293–316`) is strictly size- and tag-checked; `fingerprint_matches` skip-count bound (`:360–374`) correctly forces a full compare at `MMCE_FP_MAX_SKIPS`.

**`dash_editor.c`**
- `edIo` job ownership (`src/dash_editor.c:393–408`): on submit failure the caller-side helper frees job+text itself; on await-backout it sets `abandoned` and `edIoDone` (`:383–391`) frees later — so callers that return without freeing (e.g. `dashHexEditor` at `:1388`) are correct, not leaks.
- `hexSave` (`:1326–1367`) writes in place but reads back and compares, warning the file “may be partly changed” on mismatch — the residual risk is disclosed to the user, unlike T8-F5’s silent case.
- `editorMenu` ADD macro (`:766–785`) reaches exactly 16 items into `items[16]` when `ndocs > 1` — exactly at capacity, not over.
- `docRelines` realloc failure (`:67–74`) keeps the old line table and drawing clamps against it — OOM-only stale-table edge, acceptable.

**`dash_ui.c`**
- `dashModalMenu` L1/R1 paging (`src/dash_ui.c:988–999`) walks toward the current selection and terminates.
- `dashDrawHints` shrink loop (`:341–352`): a theoretical float divide-by-zero requires all labels empty; the result is clamped and the loop is bounded at 10 passes — judged filler, not filed.

**`dash_widgets.c`**
- Picker device list (`src/dash_widgets.c:967–976`): `dashDevicesList` is asked for at most `DASH_MAX_DEVICES - 1` rows, leaving exactly the one slot the LAUNCH-mode “Built-in commands” row appends — no overflow.
- `pickListDone` (`:919–945`) generation guard drops stale listings, results are capped at `PICK_MAX`, and the job’s file array is freed on every path shown.
- Modal keyboard cancel path (`:587` area) restores the caller’s buffer from the saved original before returning 0.

**`dash_themes.c`**
- `dashThemeSerialize` (`src/dash_themes.c:861–894`): the loop guard `len < cap - DASH_PATH_MAX - 64` reserves headroom larger than any single line the key table can emit (longest values bounded by `DASH_PATH_MAX` = 256 / `DASH_THEME_NAME_MAX` = 32), so the accumulated-`snprintf`-return pattern cannot actually truncate for table-generated content.
- `dashThemeFolderWrite`’s `dir[strlen(dir) - 1] = '\0'` trim (`:1110`) is safe because `themeRoots` (`:960–979`) only returns roots it has verified non-empty.
- `dashThemeValidate` (`:501–570`) clamps or defaults every enum/int/colour field the parser can set, including the legacy font marker migration at `:517–521`.

**`dash_hdd.c`**
- `partitionMenu` ADD macro fills at most 9 of `items[10]` (`src/dash_hdd.c:1000–1016`).
- `partCmp` order table (`:353–362`) matches its comment (system, PFS, HDL, other).
- `scanRun` Dopen-failure path (`:162–171`) leaves the parts array owned by the job, and `scan()` (`:373–389`) adopts or frees it — no leak.
- `pfsDone` (`:453–472`) guards `hm.parts != NULL`, so a probe completing after the manager has exited cannot write into freed state.
- `actCreate`’s `j->ret > 0` success test (`:640`) is consistent with the create path inside `injectMatching` (`:895`); the differing `== 0` tests in remove/rename match those drivers’ conventions as used in this file.

## (e) Still-unread

None within this section — all 11 assigned files were read end-to-end (14,818 lines). Out-of-section items referenced but not audited here: the `dashWorker*`, `getDir`, `mountParty` and HDL RPC implementations, and the `GameInfo` struct definition (relied on only via the in-file 65-byte buffer in T8-F13).
