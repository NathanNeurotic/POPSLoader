# Round 2 — Cross-Repo Topic 1: SELF-UPDATE, function-level diff

**Pins (READ, verified this run):** RiptOPL `2e347d5ac885cd0ff73e9ad4143781946396f492` (rebuild/main, #417 in history), Launchstation `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (master, #384 = commit `1882fe9`). Both clones `git status --porcelain` clean before and after; read-only throughout.
**Tagging:** every claim is READ (seen at the cited path:lines at the pin above) unless marked INFERRED.

---

## Comparison table

| Axis | RiptOPL | Launchstation |
|---|---|---|
| Updater entry / core | `src/ui/selfupdate.cpp:385-424` (`selfUpdateMenu`) + install worker `src/ui/selfupdate.cpp:252-348` | `src/dash_tools.c:923-1037` (`dashToolsCheckUpdates`) + `src/self_update.c:373-434` (`selfUpdateInstall`) |
| Portable / package helper | `src/platform/selfupdate.c:1-140` (sums/URL/revision/ELF parsing only) | `src/update_psu.c:1-364` (PSU locate/extract, RAM + file readers) |
| Header | `include/selfupdate.h:1-39` | `include/self_update.h:1-30` |
| **Total updater-exclusive size** | **603 lines** = 424 + 140 + 39 (READ, `wc -l`) | **1,151 lines** = `self_update.c` 434 + `update_psu.c` 364 + update block of `dash_tools.c:715-1037` (323) + header 30 (READ, `wc -l` + line spans) |
| Shared HTTPS stack (not counted above) | `src/platform/ratls.c` 459 + `src/sources/ratls_ps2.cpp` 304 = 763 lines; also serves RetroAchievements lookup (`include/ratls.h:1-5`) | `src/cloud_http.c` 1,312 + `include/cloud_http.h` 56; also serves Google Drive (`src/cloud_google.c`, `src/dash_tools.c` are other `cloudHttp*` users, READ via grep) |
| What is downloaded | The bare ELF asset itself (`RIPTOPL.ELF` / edition variants), `src/ui/selfupdate.cpp:54-72, 277-278` | A `.psu` package asset (`SELF_UPDATE_ASSET` = folder + `.psu`), `include/self_update.h:11`, `src/self_update.c:14` |
| Manifest / version source | `SHA256SUMS.txt` from the edition's release tag, fetched first, `src/ui/selfupdate.cpp:231-242` | GitHub API release JSON for tag `latest`, `src/dash_tools.c:897-905, 966-977` |
| Version comparison | Numeric build revision parsed out of the sums file's `.zip` names vs `suRevision(OPL_VERSION)`; offer iff strictly greater, `src/platform/selfupdate.c:55-103`, `src/ui/selfupdate.cpp:240` | Commit ancestry: a second GitHub API call `compare/<installed>...<latest>`; `ahead` = update, `diverged` = blocked outright, `src/dash_tools.c:814-887, 986-1015` |
| Verification (hash) | SHA-256 streamed with mbedTLS during download (`src/ui/selfupdate.cpp:186, 205`), finished and `memcmp`'d against the sums-file digest before any write, `src/ui/selfupdate.cpp:283-300` | SHA-256 computed inside the HTTP layer (`src/cloud_http.c:1160-1167, 1250-1258`), returned as a digest and `memcmp`'d in `src/self_update.c:296-303` against the API JSON asset `digest` parsed at `src/dash_tools.c:747-792` and hex-decoded at `src/self_update.c:140-160` |
| Signature verification | **None in either repo** (READ: no signature/Ed25519 code in either updater or its helpers; the digest arrives over the same cert-verified HTTPS channel as the file itself in both designs) | **None** (same) |
| ELF validation | `suLooksLikeElf`, `src/platform/selfupdate.c:135-140`: magic, 32-bit, LE, `ET_EXEC` (2), MIPS (8) — checked on the **first 20 bytes, mid-download, before the RAM buffer is even allocated**, `src/ui/selfupdate.cpp:170-191` | `looks_like_elf`, `src/self_update.c:210-215`: byte-for-byte the same six conditions — checked **after** full download + hash, on the ELF located inside the PSU, `src/self_update.c:306-317`; PSU container itself structurally validated first, `src/update_psu.c:71-181` |
| Journaling / recovery | None. No temp file, no rename, no backup, no resume — stated in the file header, `src/ui/selfupdate.cpp:1-13`; a part-way write "may be damaged" and the error names step + errno, `src/ui/selfupdate.cpp:248, 304-347` | None for the ELF. No temp/rename/backup, `src/self_update.c:216-243`. Two adjacent extras: stale legacy `.BAK` is deleted pre-install (`src/self_update.c:261, 279-288`), and the app folder's SAS timestamp is captured before and restored after the transaction (`src/self_update.c:396-402, 414-433`) |
| Retries | None. Redirects only: max 3, GitHub hosts only (see below) | None. Redirects only: max 5 (`for (redirect = 0; redirect < 6; …)`), `src/cloud_http.c:982, 1275` |
| Redirect trust | **Allowlist enforced**: `suSplitUrl` accepts only `github.com`, `release-assets.githubusercontent.com`, `objects.githubusercontent.com`, `src/platform/selfupdate.c:105-126`, applied per hop at `src/ui/selfupdate.cpp:146-158` | **No host allowlist on the updater path** (READ): `cloudHttpDownloadFdInternal` checks `cloud_google_media_host` only when a bearer token is present (`src/cloud_http.c:1000-1006`); redirect handling accepts any `https://` Location or a relative path, `src/cloud_http.c:1083-1110`. TLS certificate verification is still required (`src/cloud_http.c:437-438`), so this is a trust-scope difference, not an unauthenticated channel |
| RAM behaviour | Whole ELF held in RAM: buffer `malloc`'d at Content-Length, capped 8 MiB (`SU_ELF_MAX`), `src/ui/selfupdate.cpp:95, 184-207` | Whole **PSU package** held in RAM: `malloc(package_bytes)` plus a probe `malloc` of a 4 MiB reserve that must also succeed, cap 16 MiB, `src/self_update.c:15-19, 176-193, 410` |
| Free-space pre-check | **None in code** (READ: grep finds no free-space call in `selfupdate.cpp`). An orphan comment at `src/ui/selfupdate.cpp:250-251` describes cluster logic ("left to the write to report") that no code implements | Explicit: after sidecars are written, `free + old ELF size ≥ new size + 32 KiB` or refuse before touching the ELF, `src/self_update.c:343-350` |
| Boot devices allowed | Memory card (`mc0:`/`mc1:`) or BDM `massN:` only, `src/ui/selfupdate.cpp:128-142` | Eight prefixes: `mc`, `mass`, `usb`, `mmce`, `mx4sio`, `ilink`, `ata`, `hdd`, `src/self_update.c:22-51` |
| TLS trust root | Roots embedded in the binary (GitHub's Sectigo/ISRG roots), `include/ratls.h:78-82` | External CA bundle file `WLE-UPDATE-CA.PEM` must exist beside the ELF or in the settings folder; update refuses without it, `src/dash_tools.c:794-812, 941-947` |
| Restart | No auto-restart; "done" message only, `src/ui/selfupdate.cpp:417-423` (user relaunches) | No auto-restart; result text + modal say the session keeps running old code until restart, `src/self_update.c:360-365`, `src/dash_tools.c:1028-1036` |
| LAUNCHSTATION-017 status | n/a | **STILL TRUE, reframed** — see §4 |

---

## 1. Flow, step by step

### RiptOPL (READ, `src/ui/selfupdate.cpp` + `src/platform/selfupdate.c`)

1. **Gate.** Menu entry checks the boot location is updatable (MC or mass, MC filename fits 31 chars, `selfupdate.cpp:128-142`) and the build is versioned (`:387-395`).
2. **Network up.** On the I/O worker: refuse if a UDP transport owns the NIC, load ethernet modules, poll up to ~10 s for a non-zero DHCP/static config (`:219-233`).
3. **Fetch manifest.** `suFetch` GETs `/NathanNeurotic/RiptOPL/releases/download/<edition-tag>/SHA256SUMS.txt` (tag is per build edition: `rolling-korium/-incebtion/-ra/-llvm`, `:54-65`) via `raHttpsDownload` over verified HTTPS, following ≤3 redirects to allowlisted GitHub hosts only (`:146-158`). Body capped at 8 KiB, held in RAM (`:90, 160-168`).
4. **Parse + compare.** `suParseSums` extracts the exact-named ELF's SHA-256 and the release build number (from the `.zip` archive names in the same file; conflicting revisions reject the file), `src/platform/selfupdate.c:60-103`. Offer iff remote revision > local revision and > any revision already installed this session (`selfupdate.cpp:240`).
5. **User confirms** (`:409-411`).
6. **Download the ELF into RAM.** Same `suFetch`, streaming sink: the first 20 bytes are held aside and ELF-checked before allocation; the buffer is then `malloc`'d at Content-Length (≤8 MiB) and SHA-256 is updated per chunk (`:170-214, 277-289`).
7. **Verify.** Downloaded length must equal the allocation and the finished SHA-256 must `memcmp`-equal the sums digest, or nothing on the device has been touched (`:296-300`).
8. **Write in place.** `fileXioOpen(boot path, WRONLY|CREAT|TRUNC)` — with one retry using the alternate `dev:/path` vs `dev:path` spelling — then 16 KiB `fileXioWrite` chunks and close; steps 1/2/3 and errno reported on failure (`:303-347`). The header comment at `:303-305` says explicitly this is done *"as Launchstation does"* (READ — the port direction is documented in RiptOPL's own source).
9. **No restart, no cleanup** — there is nothing to clean: no second file was ever created (`:1-13, 417-423`). Session remembers `suInstalledRev` so the menu can re-offer a reinstall (`:102, 342, 396-400`).

### Launchstation (READ, `src/dash_tools.c` + `src/self_update.c` + `src/update_psu.c`)

1. **Gate.** Dashboard drains background storage work, requires the CA bundle file to be findable, and requires the dashboard IP network to already be ready (`dash_tools.c:935-953`).
2. **Fetch manifest.** Worker-thread GET to `api.github.com/repos/NathanNeurotic/Launchstation/releases/tags/latest` via `cloudHttpRequest` (`dash_tools.c:889-905`). From the JSON: `target_commitish`, and the `.psu` asset's `digest` (`sha256:…`, must be exactly 71 chars) and `size`, parsed by hand-rolled JSON scanners (`dash_tools.c:715-792`).
3. **Prove it is newer.** If the commit prefix doesn't already match, a second API call compares ancestry (`compare/<GIT_HASH>...<latest>`): `ahead` proceeds, `behind`/`identical` offer a reinstall, `diverged` **blocks** automatic replacement, unknown blocks with an error (`dash_tools.c:814-887, 979-1015`).
4. **User confirms** (`dash_tools.c:1011-1014`).
5. **Prepare install.** `selfUpdateInstall` re-validates the boot path against 8 device prefixes, splits parent/leaf, checks the device stack is writable, and captures the folder's SAS timestamp for later restoration (`self_update.c:373-409`).
6. **Allocate the package in RAM.** `malloc(package_bytes)` (≤16 MiB) **plus** a trial `malloc(4 MiB)` reserve that is freed on success — if either fails, the update is refused before anything is touched (`self_update.c:176-193, 410-412`).
7. **Download the whole PSU into RAM.** `cloudHttpDownloadMem` → `cloudHttpDownloadFdInternal` with a RAM sink (`src/cloud_http.c:833-867, 1289-1302`): verified TLS, ≤5 redirects (any HTTPS host), SHA-256 computed inside the download, chunked or Content-Length bodies both handled (`cloud_http.c:953-1277`).
8. **Verify.** Digest `memcmp` vs the API digest (`self_update.c:296-303`); then the PSU is structurally walked (directory records, exact entry counts for 2/4/8/9-file packages, per-entry size bounds) to locate the ELF (`update_psu.c:71-181, 213-222`); then the same 20-byte ELF header check as RiptOPL (`self_update.c:306-317`).
9. **Sidecars.** If `WLE-UPDATE-CA.PEM` or `BGM.ADP` are missing beside the ELF, they are extracted from the verified package; existing files are never overwritten; a failed extraction deletes its own partial file and aborts with the running ELF untouched (`self_update.c:319-341`, `update_psu.c:227-364`).
10. **Space check, then write in place.** Free space + old ELF size must cover the new ELF + 32 KiB (`self_update.c:343-350`), then `genOpen(path, WRONLY|CREAT|TRUNC)` and 16 KiB `genWrite` chunks over the running ELF, steps 1/2/3 reported on failure (`self_update.c:216-243, 351-358`).
11. **Restore + report.** SAS timestamp restored (warning prepended if that fails), RAM freed, result text tells the user to restart (`self_update.c:360-365, 413-433`).

---

## 2. Same flow rewritten, or genuinely different?

**The core is the same flow, hand-ported — and RiptOPL's source says so** (`selfupdate.cpp:303-305`: "Overwrite the booted ELF with the verified bytes, *as Launchstation does*"). Shared skeleton (READ, both repos):

- Fetch release metadata over cert-verified HTTPS from the project's own GitHub releases, before downloading anything.
- Obtain a SHA-256 for the payload from that same metadata channel; download the payload **entirely into RAM**; hash during/shortly after download; `memcmp` before any device write.
- Validate the payload is a MIPS ELF with the *identical* 6-condition, 20-byte header test (`suLooksLikeElf`, `src/platform/selfupdate.c:135-140` ≡ `looks_like_elf`, `src/self_update.c:210-215` — same byte offsets, same constants).
- Overwrite the running ELF **in place**: same path, `WRONLY|CREAT|TRUNC`, 16 KiB write chunks, no temp file, no rename, no backup, identical 1-open / 2-write / 3-close step numbering in the failure messages (RiptOPL `selfupdate.cpp:304-347`; Launchstation `self_update.c:216-243`).
- No journal, no resume, no retry, no signature, no auto-restart in either. A mid-write failure can brick the on-device ELF in both, and both say so to the user in almost the same words.

**Genuinely divergent steps** (READ):

| Step | RiptOPL | Launchstation |
|---|---|---|
| Payload unit | Bare ELF | PSU container (ELF + up to 8 sidecar/icon files), needing a 364-line container parser |
| "Newer?" proof | Integer revision compare, parsed from the sums file | GitHub commit-ancestry API; can prove *diverged* and refuse |
| Manifest format | `SHA256SUMS.txt` (also carries the version) | Release JSON asset `digest` field |
| ELF check timing | First 20 bytes, aborts download early, before allocation | Post-download, post-hash, inside the container |
| Download target | RAM only, by design | RAM only, by design — but a file-based path still exists in the tree as test-only code (§5) |
| Pre-write space check | None | Explicit free + old-size check with margin |
| Side effects beyond the ELF | None | Installs missing CA/BGM sidecars; preserves folder SAS timestamp; deletes stale `.BAK` |
| Device scope | MC + USB/BDM | + MMCE, MX4SIO, i.Link, ATA/HDD |
| CA trust | Embedded roots, nothing to lose on the card | A PEM file on the device that the update itself can (re)install from the package |
| Redirect policy | 3 hops, 3 named GitHub hosts | 5 hops, any HTTPS host (cert still verified) |
| Editions | 4 channels × 3 ELF names compiled in (`selfupdate.cpp:54-72`) | One `latest` tag, one asset |

So: **one design, two implementations, with Launchstation's carrying a second product (package/sidecar/timestamp management) bolted onto the same spine.** The divergence is mostly *scope*, not *approach* — except the version-proof (ancestry vs integer) and redirect policy, which are real design disagreements.

---

## 3. Which is smaller / simpler?

**RiptOPL, by roughly half.** 603 updater-exclusive lines vs Launchstation's 1,151 (table above). INFERRED decomposition of Launchstation's extra ~548 lines: PSU container handling ≈364 (`update_psu.c`), commit-ancestry version proof ≈150 of the `dash_tools.c` block (`:794-887` + relation handling), hand-rolled release-JSON parsing ≈78 (`:715-792`), SAS-timestamp + sidecar + space-check logic ≈90 of `self_update.c`. RiptOPL spends nothing on any of those categories.

Caveat on the shared stacks (READ sizes, INFERRED attribution): RiptOPL's HTTPS layer totals 763 lines and its download half (`raTlsDownload`/`raHttpsDownload`) has no other caller in the tree (grep: only `selfupdate.cpp:151`); Launchstation's `cloud_http.c` is 1,312 lines but is genuinely shared with Google Drive, and its download core (`cloudHttpDownloadFdInternal`, `cloud_http.c:953-1277`, ≈325 lines, plus the RAM-sink/write/chunked helpers at `:833-952`, ≈120) serves Drive file downloads too. Counting only updater-exclusive code is therefore the honest comparison, and it is the one in the table.

Hash machinery is **not** duplicated inside either repo: both call mbedTLS SHA-256 (RiptOPL `selfupdate.cpp:25, 186-300`; Launchstation inside `cloud_http.c:25, 1160-1258`). What *is* duplicated, in both repos, is the tiny hex-decode glue: RiptOPL `hexValue` + digest loop (`src/platform/selfupdate.c:15-24, 82-84`) vs Launchstation `hex_nibble` + `parse_expected_sha` (`src/self_update.c:127-160`) — same ~35-line idea written twice across the repos, and Launchstation additionally parses the `sha256:` prefix in two places (`dash_tools.c:772-773` validates it, `self_update.c:146-147` strips it again).

---

## 4. LAUNCHSTATION-017 re-read at `9fb0598a` — **STILL TRUE** (substance), CHANGED (framing)

Pass 1 said: *"downloads up to 16 MB into EE RAM (with a 4 MB reserve heuristic) beside a running dashboard… Fix: always stream the download to the target device (the code already has the card path — delete the RAM-sink path)."*

At the new head, after #384 (READ):

- **The RAM hold is still there and is now the *only* path.** `self_update.c:184-185` (function comment): *"The package is downloaded into RAM only: it fits when the heap holds it plus the reserve, otherwise NULL and the update is refused before anything is touched."* `update_ram_buffer` (`:176-193`) still caps at `UPDATE_MAX_ELF` = 16 MiB (`:15`) and still performs the 4 MiB reserve probe (`:19, 186-192`). `download_to_ram` calls only `cloudHttpDownloadMem` (`:195-207, 291-292`).
- **What #384 actually fixed** is the *other* half of the old design: the on-device staging file, rename and backup dance are gone; the verified bytes are written straight over the running ELF (`self_update.c:216-243, 351`), and the test suite now asserts the old machinery's absence (`tests/test_self_update.py:29`: `"Rename("`, `".PACKAGE"`, `".UPDATE"`, `"stage"` must not appear in `self_update.c`).
- **What is held is now larger in kind, not smaller:** the buffer holds the whole **PSU package** (ELF + CA + BGM + icons), and only the ELF slice (`ram + elf_pos`) is written out (`self_update.c:306, 351`); the rest of the package bytes occupy RAM for the duration. INFERRED: peak RAM ≈ package size, which is ≥ the ELF size RiptOPL holds.
- **The pass-1 fix is no longer available as described.** The "card path" pass 1 pointed at — the file-based PSU extractors (`selfUpdateExtractPsu`, `update_psu.c:183-199`; `selfUpdateExtractPsuSidecar`, `:335-353`) and the fd download (`cloudHttpDownloadFd`, `cloud_http.c:1279-1287`, whose own comment calls it the *"Historical self-update interface"*) — has **no production caller at this head** (READ, repo-wide grep: the only callers are `tests/test_app_packages.py:69-73` and presence-assertions in `tests/test_self_update.py:13-14`). Streaming to the device would now mean *reviving* dead code, not deleting the RAM path in favour of a live one.

**Verdict on 017: STILL TRUE** — a whole second executable (now: whole package) is held in EE RAM on a 32 MB machine, by deliberate design, with refusal instead of fallback when it doesn't fit. CHANGED only in that the staging-file half of the old complaint is fixed, and the RAM-only behaviour is now documented as intentional at `self_update.c:184-185`.

RiptOPL has the same exposure in miniature (READ): the whole ELF (≤8 MiB) is `malloc`'d in RAM (`selfupdate.cpp:95, 184-207`) — with one mitigation Launchstation lacks: the ELF header is rejected from the first 20 bytes *before* the allocation is made (`selfupdate.cpp:170-184`).

---

## 5. Duplicate machinery, per repo

**Across the two repos (same author, same week-scale porting):**

| Machinery | RiptOPL | Launchstation | Size |
|---|---|---|---|
| Verified-HTTPS GET + redirect follow | `ratls.c` 459 + `ratls_ps2.cpp` 304 (download half updater-only in practice) | `cloud_http.c` 1,312 (download core ≈445 of it) | Two full TLS/HTTP stacks, both on mbedTLS |
| SHA-256 over the download | mbedTLS, streamed in the sink, `selfupdate.cpp:186-300` | mbedTLS, inside the HTTP layer, `cloud_http.c:1160-1258` | Library shared; glue duplicated |
| Digest hex parsing | `src/platform/selfupdate.c:15-24, 60-103` | `src/self_update.c:127-160` + `dash_tools.c:747-792` | ≈35 lines each, written twice (thrice counting the JSON side) |
| ELF header test | `src/platform/selfupdate.c:135-140` | `src/self_update.c:210-215` | 6 lines, byte-identical logic |
| In-place overwrite + step errors | `selfupdate.cpp:303-347` | `self_update.c:216-243` | ≈45 / ≈28 lines, same shape |

**Inside Launchstation alone (READ):**

- **A second, fuller ELF validator already exists and is not used:** `checkELFheader(char *path)` at `src/elf.c:440-522` (~83 lines) validates ELF files for the launcher (callers in `filer_browser.c`, `main_actions.c`, `main_exploit_installer.c`). The updater can't call it directly — it takes a file path and the updater holds RAM bytes — but the header knowledge is duplicated, not shared.
- **Production-dead update machinery:** the file-based PSU entry points `selfUpdateExtractPsu` (`update_psu.c:183-199`), `selfUpdateExtractPsuMem` (`:201-211`, RAM→file extraction; live code uses only *Locate* + *SidecarMem*) and `selfUpdateExtractPsuSidecar` (`:335-353`) — ≈48 lines of wrappers plus the `PsuIn` file branch they keep alive (`in_open` `:57-68`, fd arms of `read_exact`/`in_seek` `:23-55`, ≈45 lines) — are reachable only from host tests at this head.
- `cloudHttpDownloadFd` (`cloud_http.c:1279-1287`): the pre-#384 updater's download entry, self-described as "historical", no production caller; a test asserts its *presence* (`tests/test_self_update.py:13-14`), so deleting it means deleting that assertion too.

**Inside RiptOPL alone (READ):**

- No second updater path exists — the file is notably single-path. Remaining nits: `suJoin`'s `suffix` parameter has exactly one call site, always `""` (`selfupdate.cpp:265`); the free-space comment at `selfupdate.cpp:250-251` describes a check the code never performs (documentation debt, not code duplication). RiptOPL also has unrelated ELF-magic constants for its game-ELF loader (`src/platform/system.cpp:99`, `src/platform/elfldr_noreset.cpp:32`), but `suLooksLikeElf`'s stricter class/type/machine test is not a copy of them.

---

## 6. LESS-NOT-MORE verdict

**Could one flow's SHAPE serve both programs? Yes — and it already does.** The spine (metadata-first → digest from the metadata channel → RAM download → hash-compare → 20-byte ELF test → `TRUNC`-in-place 16 KiB-chunk overwrite → step-numbered errors, no staging, no backup, no restart) is one shape, proven in both codebases, and RiptOPL's port comment shows it transferred without friction. If a third sibling appears, it should copy this shape verbatim and differ only in payload unit and "newer?" proof.

**Would a shared library be a win? No (INFERRED judgement, grounded in the READ sizes above).** The genuinely common core — ELF test (6 lines), hex/digest glue (~35), the overwrite loop (~30), redirect-following (~40) — is on the order of 100 lines per repo, while each program's HTTPS stack is welded to a different host application (RiptOPL's ratls also serves RetroAchievements and refuses while a UDP game transport owns the NIC, `include/ratls.h:76-82`; Launchstation's cloud_http also serves Google Drive with bearer-token rules, `cloud_http.c:966-973`). A shared PS2 updater library would add a cross-repo dependency, a versioning problem, and a third build to test on hardware, to save ~100 duplicated lines that have already diverged in exactly the places the programs differ (redirect policy, CA sourcing, device scope). These are separate ELFs in separate repos; the duplication is the cheap option here. The honest convergence target is the *shape* and the *checklist*, not the code.

**Deletable in each repo regardless of any sharing decision:**

- *Launchstation (≈90-100 lines, READ-dead):* the three file-based PSU wrappers and the `PsuIn` file branch they keep alive (`update_psu.c:183-211, 335-353` + `:23-68` fd arms), and `cloudHttpDownloadFd` (`cloud_http.c:1279-1287`) with its presence-asserting test lines. Keep `extract_elf`/`extract_sidecar` cores — the RAM entry points use them. This also resolves 017's loose end honestly: either revive the file path as a real low-RAM fallback, or delete it and own the RAM-only design — keeping it as test-only scaffolding is the worst of both.
- *Launchstation (small):* parse the `sha256:` prefix once — it is validated in `dash_tools.c:772-773` and stripped again in `self_update.c:146-147`.
- *RiptOPL (≈0 lines of code):* nothing structural. Fix or delete the orphan free-space comment at `selfupdate.cpp:250-251` — as written it promises a cluster check that does not exist, in the one file where a future reader will trust the comments most. If the check is wanted, Launchstation's 8-line version (`self_update.c:343-350`) is the shape to copy.
- *Policy, not code (both):* the redirect-policy divergence (§2) should be a decision, not an accident — RiptOPL's 3-host allowlist costs ~20 lines (`src/platform/selfupdate.c:105-126`) and Launchstation's updater downloads are the one place its otherwise bearer-gated host checks don't apply (`cloud_http.c:1000-1006`).

**Bottom line:** same updater, written twice, at 603 vs 1,151 lines — and the 2× is almost entirely Launchstation updating *more things* (a package, its sidecars, a timestamp, a commit-ancestry proof), not updating *worse*. The waste is not between the repos; it is the ~100 lines of dead file-based machinery Launchstation still carries for a design #384 replaced.
