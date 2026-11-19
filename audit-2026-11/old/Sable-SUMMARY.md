# Sable Audit — SUMMARY (all five repos)

- **Auditor:** Sable
- **Date:** 2026-11-13 (pass 1, delivered same day; see "What is NOT finished" — the user has already warned this will need further rounds, and the gaps are listed honestly at the end)
- **Mode:** READ ONLY. No repo file was edited, nothing committed/pushed, no branches/PRs/issues/workflows created in any target repo. Every per-repo agent verified `git status` clean; the parent spot-checked headline citations in all five clones (results in PROGRESS.md).
- **Rule applied throughout:** LESS, NOT MORE. Every fix in the per-repo files is a removal, a simplification, or — only where a real bug is cited — the smallest bounded fix using an idiom the same codebase already has. No new layers, frameworks, config options, wrappers, fallbacks, retries, backup systems, or logging systems are recommended anywhere in this audit.

## Pins (fresh clones from github.com, checked 2026-11-13 10:03 PST; full table in PINS.md)

| Repo | Branch | HEAD | Tracked files |
|---|---|---|---|
| RiptOPL | rebuild/main | `677812185ac5aab96bf697f21919a5729307ec4a` | 2,380 |
| Launchstation | master | `8cd3329a98c09a570bfbf60137717edd42324990` | 1,065 |
| POPSLoader | master | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` | 609 |
| Simple-Media-System | master | `b9a5c882d6d632914faa4ff8dc080f1ecd51bfd7` | 1,012 |
| PS2-Servers | main | `5179b4bb1f488ef2eb91956c8792e2194dda2fca` | 596 |

**Totals: 168 findings** — RiptOPL 36, Launchstation 32, POPSLoader 25, Simple-Media-System 35, PS2-Servers 40.

## The one-sentence verdict

These are not five bloated programs; they are five *accumulations* — every agent session left its branches, its tags, its docs copy, its test-as-grep file, its backup mechanism and its second implementation behind, and almost nothing was ever deleted. The code inside each feature is often fine. The cost is that every feature exists two or three times, every repo carries a second repo inside it (docs site, research archive, release kit, test corpus), and the PS2 ELFs ship languages, fonts, network stacks and subsystems most users never touch.

---

## Cross-repo duplicates (each listed ONCE, with every location)

### X-01 / Every PS2 program ships every language to every user
Three different implementations of the same mistake, plus a fourth variant:
- Launchstation: 9 languages compiled as C arrays into the ELF — `LAUNCHSTATION-001` (Launchstation/src/lang.c:5-56), even though external .LNG loading exists in the same file.
- POPSLoader: 7–8 languages as inline Lua tables parsed on every boot — `POPSLOADER-003` (bin/POPSLDR/system.lua:2558-~4840), with the same data *also* kept as TSV (`POPSLOADER-022`, plus a binary XLSX of the TSV).
- Simple-Media-System: every pack tracked twice and **all 19 diverged** — `SMS-005`; and the pack format is exact-count, so one added string invalidates all packs — `SMS-022`.
- RiptOPL: 35 translations maintained as a fork overlay on top of a downloaded set — `RIPTOPL-033`.
**Simplest fix, once, everywhere:** English (fallback) embedded; every other language a data file loaded only when selected. The loading code already exists in Launchstation; the data files already exist in POPSLoader (TSV) and SMS.

### X-02 / The same media stored as GIF *and* MP4, and generated docs committed as product
- RiptOPL: `docs/assets` 53.7 MB, the same three UI tours ×4 (plain + variant dir, GIF and MP4) — `RIPTOPL-001`; 70 docs files incl. dated checkpoint archaeology — `RIPTOPL-025`; README (1,116 lines) doubling as manual+changelog+spec — `RIPTOPL-035`.
- Launchstation: docs-site 17.4 MB with the same demos as GIF and MP4 (≥7.7 MB duplicated) — `LAUNCHSTATION-008`.
- POPSLoader: `.research/` is 70% of the repo (21.2 MB) — `POPSLOADER-001`; root docs sprawl — `POPSLOADER-015`.
- SMS: generated docs committed ~3× (source + `docs/` + `wiki/`, ~15–20 MB) — `SMS-004`.
- PS2-Servers: docs/EDITIONS sprawl and root handoff clutter — `PS2SERVERS-039`.
All five repos received a "Docs site: softer dark-gray colour scheme" commit within ~24 h of the pin — the docs sites are being actively maintained *inside* the product repos. **Fix:** one format per demo (MP4), generated output un-committed or in a docs repo, archives on Release assets.

### X-03 / Branch and tag sprawl (LIST only, per brief — nothing deleted by this audit)
Verified counts at the pins: **623 remote branches and 313 tags across five repos.**
- RiptOPL: 273 branches, 225 of them `claude/*` agent branches, and `claude/**` pushes still trigger ps2build CI — `RIPTOPL-004`. Tags: 5.
- PS2-Servers: 159 branches (incl. 9 `backup/*` branches — backups kept as *branches*) and 118 tags, **81 of them auto-generated `main-<n>-<hash>`** — `PS2SERVERS-009`.
- Launchstation: 104 branches, 140 tags, **88 of them sequential `build-*`** — `LAUNCHSTATION-023`.
- SMS: 50 branches incl. `checkpoint-*` and `pre-*-checkpoint`, 13 tags incl. mutable `latest`/`rolling` — `SMS-023`.
- POPSLoader: 37 branches incl. `BETA-*`/`CHECKPOINT2`, 37 tags incl. `backup/*` and `checkpoint/*` tag names — `POPSLOADER-014`.
**Fix:** delete merged/stale agent branches and build/main-hash tags; keep release tags only. This is the single largest hygiene item in the whole audit and costs no code risk.

### X-04 / Tests that grep source text instead of testing behaviour
- RiptOPL: 277 test files, 266 source-text `read_text` assertions, 692 call sites (parent-verified count); full serial suite did not finish in 120 s — `RIPTOPL-005`.
- Launchstation: 213 tests / 31,353 lines, 127 source-text scrapers; CI runs 212 inside the build job (compile.yml = 812 lines) — `LAUNCHSTATION-009`.
- SMS: 59 host scripts / ~14,000 lines duplicating the C structs they "test" — `SMS-019`.
- PS2-Servers contrast: a real suite exists (1,544 tests) — and *additionally* 1,608 lines of self-tests inside the shipped server dirs duplicating it — `PS2SERVERS-015`.
**Fix:** keep the minority of tests that execute behaviour; delete the scrapers or collapse each to the one assertion that once caught a real bug. A test that fails when code is *refactored correctly* is a cost, not a guard.

### X-05 / .BAK / backup copies as a design habit
Today's HEAD commits removed the ELF .BAK from RiptOPL's updater and Launchstation's updater — and the habit survives everywhere else:
- RiptOPL: `.bak` still written **to memory cards** by the POPSTARTER/UDPFS config editor and the VMC rebuild (a permanent full-card copy) — `RIPTOPL-013`.
- POPSLoader: every settings save writes the file three times (WriteAtomic triple-copy) on a slow card — `POPSLOADER-008`.
- SMS: a `.bak-512` file is *tracked in git* despite the repo's own `*.bak` ignore rule — `SMS-007`.
- PS2-Servers: rollback kept as whole duplicate implementations (standalone UDPFS run loop kept purely as rollback — `PS2SERVERS-002`) and as `backup/*` branches (X-03).
**Fix:** in-RAM rollback where the old data is already in memory (it is, in the cited code); delete the rest. .BAK is banned by the brief and, on an 8 MB memory card, it is also a capacity bug.

### X-06 / POPSTARTER binaries duplicated within and across repos
- POPSLoader: 5 copies of POPSTARTER.ELF (838,500 B); the default-named copy is md5-identical to the **DEBUG** profile (parent-verified) — `POPSLOADER-005`; the POPStarter SMB IRX set tracked twice byte-for-byte — `POPSLOADER-004`.
- RiptOPL: six POPSTARTER variants ship in the bundle, including three DEBUG builds — `RIPTOPL-010`.
**Fix:** one canonical copy per profile, second layout produced at packaging time; and a human decision on whether "default = DEBUG" is intentional.

### X-07 / UDPFS: three copies in RiptOPL's IOP tree, three editions in PS2-Servers
- PS2-Servers: UDPFS implemented 3× (Python standalone 3,643 lines + Core subclass + Go ~2,700 lines); Core's own docstring (udpfs_server/ps2servers_core.py:98, parent-verified) admits fixes edited into the standalone copy "never execute on the shipped path" — `PS2SERVERS-001`. UDPBD — a documented subset of UDPFS — also implemented 3× — `PS2SERVERS-005`.
- RiptOPL: the UDPFS IOP core is copy-pasted into 3 directories, byte-identical (mprintf.h in 5) — `RIPTOPL-008`.
- Launchstation: a stale precompiled `udpfs_smap.irx` survives beside the source-built target — `LAUNCHSTATION-019`.
**Fix:** one implementation per side of the wire. On the server, that means retiring the standalone edition (its CLI/parser/run loop is rollback-only, X-05) and letting Go Edge be a port *of record* or not exist; on the console, one IOP source dir.

### X-08 / SMB implemented over and over, on both sides of the wire
- Launchstation: SMB1 client (iop/smbman, 7 sources) duplicating the SMB2/3 client (smb2man) — `LAUNCHSTATION-005`; *plus* a full ~60-source libsmb2 SMB **server** embedded in the launcher alongside FTP/host:/NetFS servers — `LAUNCHSTATION-006`.
- PS2-Servers: SMBv1 implemented 2× (Python 1,862 + Go 1,910 lines) with a parity test whose premise is byte-matching the two — `PS2SERVERS-004`; SMB2 signing carries **four CMAC implementations stacked as fallbacks** plus hand-rolled MD4/AES/RC4/SPNEGO — `PS2SERVERS-014`; SMB2 IPC$ is 289 lines for one RPC call — `PS2SERVERS-033`.
- RiptOPL: SMB1 + SMB2 + NFS + HTTP + NBD + UDPFS as parallel game-source stacks, each with its own launch leg (X-09); NBD embedded in every build incl. Lite — `RIPTOPL-027`; HTTP as a full extra source stack — `RIPTOPL-028`.
**Fix:** per program, one SMB dialect client (SMB2/3) and no server in a *launcher*; per server app, one SMB1 implementation (the other language's copy is the parity burden, not a feature).

### X-09 / The per-device launch leg, copy-pasted
- RiptOPL: the "prepare filename + cdvdman settings + launch" sequence is copy-pasted across 6 call sites in 5 files (`strcpy(filename, game->startup)` at bdmlaunch.cpp:904, ethsupport.cpp:1504, hddsupport.cpp:2787, mmcesupport.cpp:1556, udpfssupport.cpp:977,1134) — `RIPTOPL-018`. This one *does* meet the shared-helper bar: same logic, 6 places, sharing removes code overall.
- Launchstation: three external-launcher integrations (POPStarter, Ember, Neutrino) each carry their own game-ID/path/launch stack — `LAUNCHSTATION-026`.
**Fix:** the one justified consolidation in this audit — a single launch-prep helper per program, called by each device leg.

### X-10 / iLink / IEEE 1394 carried end-to-end everywhere for a port almost no console uses as a game source
- RiptOPL: the iLink driver is maintained **twice, already diverged** — `RIPTOPL-021`.
- SMS: iLink support end-to-end (driver, browser, playback paths) — `SMS-026`.
- POPSLoader: a dedicated `usbd.irx.ilink` embed (one of the duplicates in `POPSLOADER-002`).
**Fix:** keep i.Link in *at most one* program as the maintained copy; in the others it is a candidate for the same treatment as Launchstation's legacy network stack (X-11) — removal, or a separate build, not the default ELF. (User context, not an audit finding: i.Link on PSX is a *port-presence* argument for that machine, not for every PS2 program.)

### X-11 / Legacy parallel stacks kept for one flag / one build variant
- Launchstation: a complete PS2SDK-v1.0 DEV9/PS2IP/SMAP stack (~131 KB, incl. the 118,183 B largest embedded IRX) for the single `legacy_net_drivers` flag — `LAUNCHSTATION-003` (flag parent-verified at config.c:641,858,1018).
- SMS: the never-shipped BDM=0 build doubles storage code paths (~90 `#ifdef` sites, 16 files) and costs a full CI job — `SMS-009`; two vendored network stacks + triplicated headers — `SMS-018`; two IOP delivery systems in one ELF (legacy 266 KB hex blob + BDM IRX set) — `SMS-001`.
- RiptOPL: the edition × configuration × toolchain × device matrix is the project's largest surface — `RIPTOPL-007`; foreign-format compat layers for wOPL configs/favourites kept permanently — `RIPTOPL-020`.
**Fix:** a legacy variant, if truly needed, as a separate build artifact — never as resident code in the default ELF.

### X-12 / Unsafe string handling is pervasive in every C codebase (one finding per repo, counts are the point)
- Launchstation: 863 grep hits for strcpy/strcat/sprintf incl. a `%n` chain in config save (config.c:545-712) — `LAUNCHSTATION-015`.
- SMS: 176 strcpy / 62 strcat / 87 sprintf sites, on playlist/path/skin input — `SMS-014`; MOV counts trusted for malloc — `SMS-015`.
- RiptOPL: unguarded `strcpy` of SMB credentials into fixed cdvdman fields (ethsupport.cpp:1192-1194, 1444-1446, parent-verified — the adjacent Neutrino path *does* check) — `RIPTOPL-016`; sprintf into 32/64-byte buffers in OSD history — `RIPTOPL-017`; unchecked malloc in sysDeleteFolder — `RIPTOPL-015`.
- POPSLoader: sprintf into malloc(16) via an int-truncated pointer — `POPSLOADER-020`; 512-entry MC table on the EE stack — `POPSLOADER-017`; unchecked getcwd — `POPSLOADER-021`.
- PS2-Servers (the server side of the same wire): no connection caps on SMB1/SMB2/HTTP while NFS caps at 32 — `PS2SERVERS-022`; **no single-writer exclusion in any UDPFS edition** (still open; the 2026-11-05 finding, re-verified at this pin — two peers can interleave writes into the same file) — `PS2SERVERS-013`; UDPFS allocates thread+queue+64 handles per *unauthenticated* datagram — `PS2SERVERS-021`; default posture guest/writable/open on a broadcast-discoverable server — `PS2SERVERS-023`; SMBv1 can stop Windows' own LanmanServer via PowerShell to take port 445 — `PS2SERVERS-024`.
**Fix:** bounded copies using each codebase's existing idiom, at the cited sites only — not a sweep, not a new string library. PS2SERVERS-013 is the one justified *addition* in the audit: the concrete bug is interleaved-write corruption, and the fix (refuse a conflicting open, as the Go Edge build already does with EBUSY) is the smallest change that closes it.

### X-13 / Config/settings implemented more than once per program
- Launchstation: classic CNF (config.c) and the dashboard store (dash_store.c) run in parallel — `LAUNCHSTATION-024`.
- PS2-Servers: at least **nine** CLI/config parsers across servers/languages/formats — `PS2SERVERS-017`; six separate path-containment implementations — `PS2SERVERS-018`; Edge WebUI keeps its own config store/schema/supervisor (~2,050 lines) — `PS2SERVERS-028`; portable-mode detection writes a probe file on *every* config access — `PS2SERVERS-032`.
- SMS: config-save / mc-icon code duplicated inside SMS_Config.c, plus a permanent "TEMP" save-diagnostic with duplicated save paths — `SMS-011`, `SMS-012`.
- POPSLoader: settings saved via the triple-write in X-05 — `POPSLOADER-008`.
**Fix:** one settings store and one parser per program; the second implementation is deleted, not wrapped.

### X-14 / Byte-identical files and agent/meta clutter inside the trees
- RiptOPL: `AGENTS.md` ≡ `CLAUDE.md` (the same file twice) — `RIPTOPL-023`; a 324 KB bgm.ogg kept "only as a reference", plus a second different copy in the ship bundle — `RIPTOPL-024`; 20 identical empty SDK stub headers for host tests — `RIPTOPL-031`; tracked prebuilt debug IRX — `RIPTOPL-032`.
- Launchstation: md5-verified duplicate files incl. twin ioplib.c copies in mmceman/mx4sio_bd — `LAUNCHSTATION-021`; 16 res/icons/*.png unused by the icon system — `LAUNCHSTATION-022`; dead bgm.ogg (462,185 B, parent-verified) + boot.adp (144 KB) — `LAUNCHSTATION-013`.
- POPSLoader: IRX/ELF duplicates (X-06); a 1.47 MB unreferenced source tarball inside `iop/embed/` — `POPSLOADER-006`; UI images shipped loose *and* embedded — `POPSLOADER-007`.
- SMS: plain `.irx` tracked beside the `.irx.xz` the build uses (323 KB) — `SMS-003`; a handoff folder whose README says "delete before merge", merged, with mutated crash-test media — `SMS-008`; a 44 KB Windows binary with no source and no reference — `SMS-031`.
- PS2-Servers: banner tracked twice byte-identical + 3.1 MB Go testdata binaries — `PS2SERVERS-016`; agent/handoff clutter in repo root and docs — `PS2SERVERS-039`.
**Fix:** delete; where a file is a packaging *input*, generate the second copy at packaging time (the workflows already assemble packages).

### X-15 / Watcher/publisher workflow sprawl
- RiptOPL: 12 workflows, 2,220 lines, six of them scheduled watchers/publishers (ember-watch, neutrino-watch, orbit-neutrino-watch, ps2build-sdk-watch, docs-sync, wiki-publish…) — `RIPTOPL-009`.
- Launchstation: a download-counter workflow running 8× a day — `LAUNCHSTATION-027`.
- SMS: 3 of 6 workflows rebuild/republish docs or media on every master push — `SMS-024`.
- POPSLoader: 10 workflows / 2,062 lines incl. a **one-shot retraction workflow that has done its job** and an AI-comment-bot workflow (`opencode.yml`) — `POPSLOADER-012`, `POPSLOADER-013`.
- PS2-Servers: two near-duplicate release workflows (~1,095 lines) running the same pipeline — `PS2SERVERS-010`.
**Fix:** watchers that only *report* belong in one scheduled job outside the product repos; one-shot workflows get deleted when they fire.

### X-16 / Second products living inside first products
- PS2-Servers: RetroAchievements = 52,963 lines of vendored C + 5,201 lines of Python + **two runtimes** (bundled xeRAbora vs an `--owned-runtime` preview) + two modes, all flagged experimental/untested-on-console — `PS2SERVERS-003`; plus a direct-link network-administration product (1,927 lines + ~600 lines of GUI state machine) — `PS2SERVERS-025`; two SQLite library catalogues and **three** library UIs — `PS2SERVERS-026`; three separate HTTP servers — `PS2SERVERS-027`; Discord presence / achievement sounds / art fetching / OBS export — `PS2SERVERS-029`.
- Launchstation: a native Google Drive subsystem (HTTP+TLS+OAuth+QR, Mbed TLS, CA roots) in a file launcher, with a duplicate PC-side relay — `LAUNCHSTATION-004`, `LAUNCHSTATION-031`; an exploit installer + KELF signer + ~148 KB payloads in the everyday launcher — `LAUNCHSTATION-007`.
- RiptOPL: both glyph sets + ~130 PNGs embedded in every ELF — `RIPTOPL-011`; FatFs unicode tables for **all** code pages compiled into the IOP for one fixed CP869 — `RIPTOPL-012`; mbedTLS vendored whole and globbed whole (`library/*.c`) into two editions — `RIPTOPL-006`.
**Fix:** second products move to their own repos/builds. The PS2 programs keep the *client* they need; the TLS/QR/Drive and RA stacks are the clearest ELF-size wins available anywhere in this audit.

---

## Top 25 findings (benefit first, risk considered)

| # | ID | Finding | Headline benefit |
|---|---|---|---|
| 1 | PS2SERVERS-001 | UDPFS implemented 3×; fixes land in a copy that never executes | ~6,300 lines of duplicate protocol code deletable |
| 2 | RIPTOPL-001 | docs/assets 53.7 MB, tours stored ×4 as GIF+MP4 | ~40 MB of repo |
| 3 | POPSLOADER-001 | .research/ is 70% of the repo (21.2 MB) | ~15–21 MB of repo |
| 4 | SMS-004 | Generated docs committed ~3× | ~15–20 MB of repo |
| 5 | LAUNCHSTATION-008 | docs-site 17.4 MB, demos as GIF+MP4 | ≥7.7 MB duplicated media |
| 6 | PS2SERVERS-003 | RetroAchievements is a second product (58k lines, 2 runtimes) | largest single removal in any repo |
| 7 | LAUNCHSTATION-002 | 3 font families × 3 sizes = 585,728 B rodata | −194,560 B for the bold face alone |
| 8 | LAUNCHSTATION-001 | 9 languages compiled into every ELF | ~305 KB ELF |
| 9 | SMS-002 | Dead s_iop_image.h, referenced only from comments | 373,784 B / 3,820 lines, pure delete |
| 10 | SMS-001 | Two IOP delivery systems in one ELF | ~100–200 KB ELF (est.), ~10k lines |
| 11 | RIPTOPL-006 | mbedTLS vendored + globbed whole into 2 editions | whole unused cipher/hash families per edition |
| 12 | LAUNCHSTATION-004 | Google Drive subsystem + TLS + QR in every ELF | subsystem-scale ELF/RAM removal |
| 13 | LAUNCHSTATION-003 | Legacy v1.0 network stack for one config flag | ~131 KB embedded IRX + parallel stack |
| 14 | POPSLOADER-002 | Byte-identical IRX embedded 2–3× into the ELF | ~131,508 B embedded payload, S/Low |
| 15 | RIPTOPL-002 | ship/Example = second committed copy of the ship tree | 137 files / ~5.9 MB |
| 16 | RIPTOPL-003 | 1,251-line Makefile that cannot build the program | one build definition, honestly |
| 17 | PS2SERVERS-004 | SMBv1 implemented 2× with a byte-parity test | 1,862 or 1,910 lines + the parity burden |
| 18 | PS2SERVERS-005 | UDPBD implemented 3× though UDPFS contains it | two implementations of a subset protocol |
| 19 | SMS-013 | Fixed 2.5 MB player ring buffers | up to ~2.5 MB EE RAM (content-dependent) |
| 20 | LAUNCHSTATION-017 | Self-update holds a whole second ELF in RAM | ~one ELF of RAM during update, on 32 MB |
| 21 | POPSLOADER-003 | All languages inline in system.lua, parsed every boot | ~200 KB source, boot parse + RAM for 6 unused languages |
| 22 | RIPTOPL-011 | ~130 PNGs + both glyph sets embedded in every ELF | per-ELF asset payload |
| 23 | PS2SERVERS-013 | **Bug:** no single-writer exclusion in any UDPFS edition | interleaved-write corruption, fix already exists in Edge (EBUSY) |
| 24 | RIPTOPL-016 | **Bug:** SMB credentials strcpy'd unchecked into fixed fields | config-file-triggerable overflow on the console |
| 25 | SMS-015 | **Bug:** MOV container trusts file counts for malloc size | hostile-file allocation/overflow in the player |

## Quick wins (Low risk + S effort — do these first, in any order)

- `POPSLOADER-006` — delete the unreferenced 1,466,084 B tarball in iop/embed/.
- `POPSLOADER-002` — alias the byte-identical IRX embeds (~131,508 B, md5-proven).
- `SMS-002` — delete s_iop_image.h (only commented references; parent-verified).
- `SMS-005` — delete the diverged `lng/` copies (the tested/shipped copy is docs/translation/).
- `SMS-007` — untrack jellyfish.jpg.bak-512 (25,390 B; parent-verified on disk).
- `LAUNCHSTATION-013` — delete dead bgm.ogg (462,185 B) + boot.adp (143,984 B).
- `LAUNCHSTATION-019` — delete the stale precompiled udpfs_smap.irx.
- `LAUNCHSTATION-020` — delete unused IOPRP.IMG + XSYSTEM2.XLF payloads.
- `PS2SERVERS-007` — delete the dead `_append_log` in gui.py (shadowed by the main.py shim).
- `PS2SERVERS-002` — retire the standalone UDPFS CLI/parser/run loop kept as rollback (~200 lines).
- `RIPTOPL-023` — delete one of AGENTS.md/CLAUDE.md, keep a one-line pointer.
- `POPSLOADER-012` — delete the spent one-shot retraction workflow.
- `POPSLOADER-025` — delete the leftover upstream TODO block in fntsys.cpp.
- Branch/tag sweep (X-03) — no code risk at all; 623 branches / 313 tags is the cheapest credibility win in the audit.
- `PS2SERVERS-040` / Launchstation cloud secret — secret-like values exist at PS2-Servers/smb2_server/smb2_server.py:44 (example credential literal in a docstring) and as a CI-baked value via Launchstation/scripts/gen_cloud_client.py. **Locations only; no values are printed in any audit file.**

## Suggested order of work

1. **Quick wins above** (an afternoon; all deletes, all verified).
2. **Branch/tag sweep** (X-03) — before any code work, so CI stops building agent branches (RiptOPL's `claude/**` trigger makes this a real compute cost, not just tidiness).
3. **Repo-composition moves** — docs/archives/research out of the product repos (RIPTOPL-001/002, POPSLOADER-001, SMS-004, LAUNCHSTATION-008). Big, boring, zero hardware risk.
4. **Bugs before bloat, where hardware is the judge** — PS2SERVERS-013 (single-writer), RIPTOPL-016/015/017, SMS-014/015/016, POPSLOADER-020/017/021, LAUNCHSTATION-015/016. Each needs a real-hardware or at least emulator-rig check after the fix; none is proven by a build.
5. **ELF diets, one subsystem at a time, hardware-verified each step** — languages (X-01), fonts (LAUNCHSTATION-002), legacy stack (LAUNCHSTATION-003), cloud/RA second products (X-16), SMS dual IOP (SMS-001/002/003/006). Order within a repo: biggest resident bytes first.
6. **Protocol consolidation on the server** — UDPFS to one edition (PS2SERVERS-001/002/005), SMBv1 to one implementation (PS2SERVERS-004), release workflows to one (PS2SERVERS-010), parsers/containment to one each (PS2SERVERS-017/018).
7. **Test-corpus reckoning** (X-04) — last, because it touches CI everywhere; do it once the code it scrapes has stopped moving.

## Test / build evidence (results only)

- RiptOPL: `test_selfupdate_host.py` PASS (52 checks). Full `tools/run_tests.sh` did **not** finish in 120 s (stopped, no failure seen) — reported as not-finished, not a pass.
- Launchstation: host tests browser_sort PASS, navigation_wraparound PASS (centre scrolling + wraparound confirmed present on master — not flagged).
- SMS: `test_language_packs.py` PASS, `test_rolling_release.py` PASS.
- POPSLoader: `tools/test_disc_layout.py` **not run** (missing `lupa` in this VM) — reported as not-run.
- PS2-Servers: Python unittest discovery — 1,544 tests in 108.6 s: **3 failures, 71 errors, 78 skipped**. Root cause established as environmental: this sandbox blocks UDP `sendto` (PermissionError), failing all live-socket tests (all 3 failures are test_status_client). **Not repo defects.** Go tests **not run** — no Go toolchain in the VM.
- **No PS2 build was run for any repo** (no PS2SDK/ps2build toolchain in this VM). Every ELF/IRX byte figure in this audit is computed from measured file/array sizes and labelled an estimate in the per-repo files. Nothing here is hardware-verified; per the user's standing rule, a build is not proof anyway — items in steps 4–5 above need real hardware before they are called done.

## What is NOT finished (exactly, per the brief)

- **Category 6 (bugs/security) is partial in every PS2 repo:** EE/UI surfaces were swept repo-wide, but IOP module internals (Launchstation FTP/SMB parsers, POPSLoader ds34/pademu/ps2atad, RiptOPL ee_core/modules beyond sampled ranges, SMS vendored IOP sources) were inventoried/grep-swept/sampled, **not line-audited**. A round 2 should line-read the IOP network parsers first.
- **Category 5 (performance) is structural only:** cited items rest on self-evident code (busy-waits, per-frame plasma, opendir-per-entry probes, 30 s blocking polls, triple card writes). Nothing was profiled; no PS2 build or hardware timing exists in this pass.
- **Category 2, cross-repo, is complete at the pattern level (X-01…X-16)** but a function-level diff of the shared updaters / network-init / config parsers across RiptOPL↔Launchstation (e.g. Launchstation's usmb2/smb2auth taken from RiptOPL, per ps2.yaml:249) has not been done — that is the highest-value round-2 item after the IOP parsers.
- **PS2-Servers Category 4 (Edge binary size/RAM) unfinished** (no Go build possible here); Category 6 live wire interop untested (no hardware/UDP in sandbox); per-opcode SMB2/NFS handler audit not done.
- **POPSLoader:** tools/host_harness.py (2,759 lines) and .research/build_site.py (2,377 lines) not audited for Categories 1/3; system.lua/ui.lua read in targeted sections, not end-to-end.
- **RiptOPL:** most of src/ grep-swept and sampled, not read end-to-end (2380 files); vendored mbedTLS/lwIP internals not line-read.
- Per-repo "Files not read and why" lists are in each Sable-<REPO>.md footer and are part of the deliverable, not fine print.

## Files in this deliverable

- Sable-SUMMARY.md (this file)
- Sable-RiptOPL.md — 36 findings
- Sable-Launchstation.md — 32 findings
- Sable-POPSLoader.md — 25 findings
- Sable-Simple-Media-System.md — 35 findings
- Sable-PS2-Servers.md — 40 findings
- PINS.md — pins, branch/tag counts, extension inventories
- PROGRESS.md — live status log (kept so another agent can resume round 2 from exactly here)

---

# ROUND 2 ADDENDUM (2026-11-14)

- **Round-2 pins** (live heads moved in 4 of 5 repos overnight; clones updated in place, still read-only; full table in PINS-ROUND2.md): RiptOPL `2e347d5ac885` rebuild/main, Launchstation `9fb0598a79f0` master, POPSLoader `29272cddbf01` (unchanged), SMS `e65ced39a27e`, PS2-Servers `c5f021c4d386`.
- **New findings: 100** — RiptOPL 15 (037–051), Launchstation 20 (033–052), POPSLoader 22 (026–047), SMS 14 (036–049), PS2-Servers 15 (041–055), cross-repo 14 (X-17…X-30). **Running total: 268 findings.**
- **Formal corrections to pass 1 (the audit auditing itself):**
  - RIPTOPL-008 reframed: the three `udpfs_core.c` were already 2-line `#include` shims into `udpfs_shared` at the pass-1 pin (verified via `git show` at `677812185ac5`); only the headers are triplicated (→ RIPTOPL-048).
  - SMS-014 narrowed: EE unsafe-string population is 238 call lines (7 real-risk / 48 bounded-fragile / 183 safe) — pass-1 counts were whole-repo approximations. SMS-028 narrowed likewise.
  - SMS-017 corrected by X-section evidence: two alloc *sites*, mutually exclusive; the simultaneous cost is SMS's stream buffers, not the copy buffer.
  - Pass-1 "four config parsers" claim corrected: there are **ten** (cross-repo file, Topic 3).
- **Revalidation verdicts at the new heads:** LAUNCHSTATION-017 **STILL TRUE, changed form** (#384 deleted the device/staging path; RAM-only update is now the only path — and its in-place successor created LAUNCHSTATION-034). RIPTOPL-003/004/005/013/016/021/034 STILL TRUE (003 worse: Makefile 1,260 lines); LAUNCHSTATION-004/008/009/028/030 STAND. RiptOPL delta mechanisms (#417 filemgr rename, #419 IGR, #420 SMB1-VMC) read fresh and are **clean** — recorded as an honest negative, not findings.
- **New Top-tier findings this round (parent spot-checked):**
  1. **X-18** — Launchstation writes starter `title.cfg` as `title = %s` / `boot = %s` (dash_apps.c:178-187); RiptOPL's classifier (src/core/config.cpp:155-163) keeps it LEGACY, its splitter keeps the trailing space in the key, appsupport requires both keys → the app silently never appears in RiptOPL. Fix: two template lines in Launchstation. *(Parent-verified both sides.)*
  2. **RIPTOPL-037** — NBNS `decode_name` (modules/network/nbns/nbns.c:110-122) loops on a packet-supplied length byte into `decoded_name[17]` on the stack (:172) — LAN-triggerable IOP stack overflow. *(Parent-verified.)*
  3. **PS2SERVERS-042** — a third, fake SMB2 implementation inside the SMB1 file (smbv1_server/smbserver_opl.py:508-640): CREATE returns SUCCESS with a hard-coded FileId and opens nothing, READ returns zeros, WRITE discards data and reports success, SESSION_SETUP grants guest bypassing the SMB1 logon gate. Executed-proven. Delete ~130 lines.
  4. **PS2SERVERS-043** — SMB2 read-only handle can delete files via SET_INFO disposition + CLOSE (executed against a temp share); CREATE DELETE_ON_CLOSE shares the hole. The same function's EOF branch already has the correct check.
  5. **LAUNCHSTATION-034** — `overwrite_elf` (self_update.c:220-247) truncates the only ELF copy in place: no staging, no readback; its own error text admits the ELF "may be damaged". Fix restores stage-verify-rename *without* .BAK retention (justification in the finding). *(Parent-verified.)*
  6. **SMS-037** — 37,312 padded bytes of `g_DataBuffer` dead in the shipped build, exact constants: SMB blob 19,641 B has no consumer in any config; UMS/USBD load only in the BDM=0 arm while Makefile:3 defaults BDM=1. *(Parent-verified constants.)*
  7. **PS2SERVERS-044** — SMB1 truncated-params packet escapes the connection thread's exception catch and drops the session (executed, 37-byte packet). NT_CREATE was fixed; its neighbours weren't.
  8. **POPSLOADER-028** — a "(TEST)" HDD write-probe runs on every production Settings save (ui.lua:4622), mount-RW-probing partitions and writing a tmp file.
- **Evidence upgrades this round:** PS2-Servers Edge is now **measured** (Go 1.27.4, user-space install, sha256-verified): release build **7,622,780 B** vs default 11,371,165 B; product code is only ~250 KB of symbols — the WebUI's net/http/http2/tls entourage (~686 KB symbols + 55,307 B embedded assets) is the size story (→ PS2SERVERS-041: build-tag the WebUI; CI's own comment already names the remedy). POPSLoader gates now run: `test_disc_layout.py` PASS (30), `host_harness.py` 62/62 PASS. NFSv4 handler table: 18/18 PASS — recorded as the in-repo exemplar. SMB2 Python: 16/19 registered, FLUSH + the -043 sites fail. SMB1: 12/16 PASS.
- **Files added this round:** Sable-RiptOPL-ROUND2.md, Sable-Launchstation-ROUND2.md, Sable-POPSLoader-ROUND2.md, Sable-Simple-Media-System-ROUND2.md, Sable-PS2-Servers-ROUND2.md, Sable-CROSSREPO-ROUND2.md (+ round2-sections/ evidence, 793 lines), PINS-ROUND2.md.
- **What is STILL not finished (round-3 scope):** per-opcode wire-validation tables for UDPFS and UDPBD (both languages) — the largest remaining gap; Go Edge handler tables (suite blocked by sandbox UDP); vendored codec internals in SMS (Vorbis codebook allocations are the largest unexamined Cat-6 surface — upstream code); smbd (vendored libsmb2, ~60 sources) inventory-only; BDMAssault tarball internals (151 entries); RiptOPL ee_core beyond delta hunks + the largest EE src/ files sampled not end-to-end; Launchstation EE remainders (mc_* cluster outside cited ranges); Category 5 remains structural everywhere — no PS2 build exists in this VM (no PS2SDK) and no hardware timing is possible; **nothing in either round is hardware-verified.**

---

# ROUND 3 ADDENDUM (2026-11-14)

- **Pins:** round-2 pins held for all repos (verified at start and end of every round-3 workstream; POPSLoader unchanged since pass 1).
- **New findings: 64** — RiptOPL 14 (052–065), Launchstation 25 (053–077), POPSLoader 5 (048–052), SMS 3 (050–052), PS2-Servers 7 (056–062), cross-repo 10 (X-31…X-40). **Running total: 332 findings**, plus 9 formal revisions across rounds 2–3.
- **Round-3 revisions:** REV-006 **changes a pass-1 fix** — the BDMAssault tarball is a documented source pin and the only in-repo source for its binaries; extract-or-archive, don't plain-delete. REV-016 narrows pass 1's "16 one-shot scripts" (11 are CI standing gates; true residue 5 scripts/547 lines). LAUNCHSTATION-051 narrowed+strengthened; -052 and -047 censuses corrected upward (4th and 6th copies found).
- **The UDPFS question is now closed at source level.** Wire layouts agree bit-for-bit across both C clients and all three PS2-Servers editions (X-section §1.2, source-level claim — live interop untestable in this sandbox). Per-opcode tables complete for UDPFS/UDPBD/SMB1/SMB2/NFS. The divergences are validation posture: **X-31** RiptOPL's UDPRDMA receive path copies a wire-sized header (≤60 B) toward an 8-byte app buffer with no check (`udpfs_shared/src/udprdma.c:192-193`, parent-verified) while SMS's fork of the same file clamps and drains; **PS2SERVERS-056/057/058** Python BWRITE/UDPBD writes are never range- or completion-checked (executed: images grown past EOF with WRITE_DONE 0) while Go's `inRange` model sits in-repo; **X-34** identical packets yield different outcomes per server language on five points.
- **New top-tier this round:** LAUNCHSTATION-053 smbd pread/pwrite truncate `uint64_t off` to `(int)` — a write at 4 GiB wraps to offset 0 (parent-verified at smbd.c:150-159; the report's cited lines drift ~15 from the mechanism, substance exact); POPSLOADER-048 pademu DS4 path zeroes 50 B and sends 79 B — uninitialised IOP stack to the controller (parent-verified both copies); RIPTOPL-052 ~370 lines of unreachable partition-format machinery below an unconditional -EACCES refusal (parent-verified); SMS-052 the round-2-praised WAV clamp inverts at format size exactly 17 → malloc(0) + ~4 GiB unsigned read (parent-verified); LAUNCHSTATION-056 smbd-adjacent FileTimeToDate computes wrong dates for 80/240 sampled timestamps (host-replicated) while two sibling modules carry the correct algorithm.
- **Coverage state after round 3:** RiptOPL ee_core complete; Launchstation IOP protocol files (smb2man/smb_fio/nfsman/unfs4) complete; POPSLoader Lua + tooling complete with gates green; SMS EE classification complete, containers at allocation+ASF/MPEG-PS logic level; PS2-Servers all protocol tables complete. Vendored code is now inventoried everywhere (SMS codecs + IOP trees pristine upstream; Launchstation's libsmb2 is *fetched*, not vendored — pinned a52c1571 with 2 characterised patches).
- **Still open (round-4 scope):** RiptOPL EE src/ remainder (22,632 lines in size order) + named modules (ds34bt, ps2ips bounds commentary, smap ×3…); Launchstation libsmb2 itself (fetch + settle three INFERRED link claims), vmcman internals (main.c 4,398), mmce_fs bodies; POPSLoader's 11 CI-wired research scripts (~1,508 lines); SMS_JPEG decode walk + AVI/MOV logic; PS2-Servers launcher/compressed-iso internals + Go session/compression. Category 5 remains structural; no PS2 build or hardware verification exists for any round.

---

# ROUND 4 ADDENDUM (2026-11-14)

- **Pins:** all five live heads re-checked — **nothing moved**; round-4 work is at the round-2/3 pins throughout.
- **New findings: 122** — RiptOPL 79 (066–144), Launchstation 19 (078–096), POPSLoader 7 (053–059), SMS 4 (053–056), PS2-Servers 5 (063–067), cross-repo 8 (X-41…X-48). **Running total: 454 findings, 15 revisions.**
- **POPSLoader is EXHAUSTED at source level** (round-4 verdict, argued from a complete coverage table): every line of shipped Lua, EE/IOP C, client libs, tooling, research tooling, workflows and Makefiles read across rounds 1–4; all host gates green at the pin. Remainder is non-source: generated bin2c dump, tarball upstream contents (REV-006 disposition), prose, binaries, hardware behaviour. A further round is productive only after a REV-006 extraction or a pin move.
- **Round-4 revisions — the audit withdrawing its own findings:** LAUNCHSTATION-065 **REFUTED and withdrawn** (libsmb2's receive cap + decoder bounds make the feared cast unreachable; fetched at pin a52c1571 and read); -064 downgraded to latent hardening (full calloc census); -072 split — two files are empty translation units (deletable), but **aes_reference.c is the server's only AES and must NOT be deleted** (round 3's "duplicate" call was wrong; the 36-line aes.c dispatches to it). REV-016b: the CI-wired research set is 12 files, not 11.
- **New top-tier:** RIPTOPL-066 — the POPSLOADER-048 memset defect **verbatim in both of RiptOPL's ds34bt copies** (79 B buffer, 50 B memset, 79 B send; parent-verified at ds34bt.c:1208,1243,1263) → the bug is a family-level copy-drift disease, censused in round 5. RIPTOPL-067 ps2ips setsockopt: EE-supplied optlen memcpy'd into a 128 B stack buffer unchecked (parent-verified). LAUNCHSTATION-079/080/081 — vmcman crafted-card cluster: unchecked superblock geometry used as divisors/indices, FAT chains indexing ifc_list[32] unbounded, and strcpy-then-terminate in dread2 (parent-verified at ps2mc_fio.c:283). PS2SERVERS-063 — a 32-byte crafted CSO declaring a 256 MiB block allocates 256 MiB on read(1) (executed; mechanism parent-verified at cso.py:71 — the 16 MiB cap exists three times in-repo, not on the serving path). SMS-053 — the 1024-px safety gate is one-sided: unsigned file dimensions wrap negative in int32 fields and pass (parent-verified all three legs). X-41 — ps2build SDK machinery hand-copied ×2 (~1,370 lines; only diff in the installer is the User-Agent). X-45 — POPSLoader's release workflow is hard-coded to "1.4.4" (parent-verified). X-46 — the docs-palette fan-out cost 15 PRs / ~35 commits across all five repos; SMS carries its stylesheet twice, byte-identical.
- **Coverage after round 4:** RiptOPL ee_core/src fully read; EE src/ read through the 1,280-line tier (40,307 lines this round); Launchstation libsmb2 settled at the pin (client halves inventory-only); SMS containers + JPEG + MOV closed (JPEG is the repo's best-validated parser — cleared); PS2-Servers protocol + launcher + compressed-iso closed with 11 executed claim-groups.
- **Round-5 scope:** RiptOPL EE below-tier (guigame 2,617 → down) toward an exhaustion verdict; Launchstation mcdev/EE-Mc* (-085 question) + glue; SMS GUI/rendering/backends remainder; PS2-Servers Go internals remainder; cross-repo ds34 defect census across all copies in all repos + mcman geometry-validation comparison. Category 5 remains structural; nothing is PS2-build- or hardware-verified in any round.

---

# ROUND 5 ADDENDUM (2026-11-14) — verdict round

- **Pins:** all five live heads re-verified **unmoved** for the fourth consecutive round.
- **New findings: 266** — RiptOPL 136 (145–280), Launchstation 89 (097–185), SMS 36 (057–092), PS2-Servers 2 (068–069), cross-repo 3 (X-49…X-51).
- **TOTALS, RECONCILED FROM THE NUMBERED FILES (this supersedes every running total quoted in chat):** the finding numbers are contiguous per repo — RiptOPL 001–280, Launchstation 001–185, POPSLoader 001–059, SMS 001–092, PS2-Servers 001–069, cross X-01…X-51 — **736 numbered items**, of which X-01…X-16 are pass-1 cross-references (each defect also carries a per-repo number) and the rest are standalone findings; minus 1 withdrawn (LAUNCHSTATION-065) = **735 standing**. Earlier chat narration carried three arithmetic slips in per-repo cumulative figures (Launchstation "121/210", POPSLoader "66", SMS "59 after round 4" — correct: 96/185, 59, 56); the numbered files themselves were never affected. The master index (Sable-MASTER-INDEX.md) is generated from the files and is the counting authority from here on.
- **Exhaustion verdicts — 4 of 5 repos CLOSED at source level in this environment:** POPSLoader (round 4), PS2-Servers, Launchstation, RiptOPL (round 5). Each verdict names its residue: not-unread-source classes are tests/prose/binaries/vendored-by-framing/assembly; un-auditable-here classes are the smbd link test (no toolchain), live UDP/CHD/UCI/Windows paths (PS2-Servers), RiptOPL's 3,854 lines of assembly + 59,927-line test corpus + headers-as-corpus. **SMS is the one open repo:** 2,074 named EE lines + SMS_DSP.c kernels remain — round 6 is scoped to exactly that.
- **Round-5 headlines:** X-49 — the ds34 census: 10 copies, memset defect 4 affected/1 correct, battery-index 8 affected/2 correct, **no copy correct on both**, both fixes exist in-family in different lineages; complete repair = 12 one-line transcriptions; the census caught Launchstation's BT copy (LAUNCHSTATION-136), which no per-repo round had line-audited. X-50 — Launchstation holds both the family's worst (IOP vmcman) and best (EE mc_card_view.c) card parsers; the gap is a placement failure across its own EE/IOP boundary. RIPTOPL-145/146 — menu-side SMB1 receive trusts wire length/DataOffset/DataLength into fixed buffers (parent-verified at smb.c:~257-262); the in-game stack already rejects these. LAUNCHSTATION-119 — GET_XPARAM_DB_SIZE() ≡ 1: the 292-entry Deckard database is searched over one entry (parent-verified at xparam.h:36); -118 settles the `unit & 9` mask as a latent live defect and -085 as proven waste (~33,984 B IOP statics). SMS-057 — palette rotate wraps at 17, not at 0 → g_Palette[-1] by ordinary menu use (parent-verified); SMS-060 — the LZMA2 size guard decompresses into address 0 on its own failure path (parent-verified at SMS_EE.c:946-965). PS2SERVERS-069 — UCI boolean vocabulary split: dashboard loads read_only 'on' as false and the next Save silently strips the protection.
- **Standing limits unchanged:** no PS2 build, no hardware result, no live UDP interop in any round; Category 5 structural throughout.

---

# ROUND 6 ADDENDUM + CONSOLIDATION STATE (2026-11-14)

- **Round 6 (SMS final sweep): 10 new findings (SMS-093…102) + 2 location-completing revisions** (R6-REV-1 completes SMS-057's sink list; R6-REV-2 adds SMS-068's twelfth site). Headlines: SMS-093 history loader — the HIST_SIZE cap exists only on the write side; load loops are unbounded and allocate file-controlled sizes through the tree's only list helper that never NULL-checks its calloc (parent-verified at SMS_History.c:20,141). SMS-094 — `DSP_MDCTInit`'s error branch `if ( !DSP_iFFTInit(...) < 0 )` is dead by operator precedence and has never executed (parent-verified at SMS_DSP.c:972); SMS-095 its unchecked memalign neighbour.
- **SMS verdict: EXHAUSTED at source level in this environment.** With round 6, **all five repos carry exhaustion verdicts** at their pins, each with its residue named in its own report and in the master index §1.2.
- **FINAL TOTALS (master index is the counting authority): 746 numbered items** — RiptOPL 280, Launchstation 185, SMS 102, PS2-Servers 69, POPSLoader 59, cross X-01…X-51 — statuses: 706 STANDING, 23 REVISED, 16 CROSS-REF (X-01…X-16), 1 WITHDRAWN (LAUNCHSTATION-065) → **745 standing**. Quick-win set (standing + S effort + Low risk): 498. Cat-6 top tier: 32 items, listed in the index §3(b) from the addenda's own headline lists.
- **Deliverable:** `Sable-MASTER-INDEX.md` — every numbered item with title/category/effort/risk/confidence/status, the action view, the 26-entry revisions ledger, pins, and all five verdicts. Generator scripts (`extract_index.py`, `build_index.py`, `index-scratch.tsv`) are kept beside it; regeneration after any future round is a two-command rerun.
- **What "exhausted" means here, once more, plainly:** every line of first-party text source in scope was read at the stated pins across rounds 1–6. It does NOT mean: PS2-built (no PS2SDK in this VM), hardware-verified (none), link-tested (the smbd test cannot run here), or extended to the classes the brief framed out (vendored codec/stack internals, assembly as a corpus, test suites line-by-line, binaries). Productive continuations are exactly: a pin move, a scope extension into those named classes, or a PS2 build/hardware rig. On the current pins and scope, further rounds would be re-reading.
- **Read-only held across all six rounds:** every clone verified git-clean at every round's end; no edits, commits, pushes, PRs, issues, branches or workflows were made in any audited repo; secret-like values were reported by location only, never printed.

---

# ROUND 7 ADDENDUM (2026-11-14) — scope extension

- **Trigger:** the user's "You're not done." Round 7 audited exactly the classes the round 4–6 verdicts had named as residue: assembly, headers-as-corpus, test corpora, vendored/tarball contents, codec internals, docs prose, generated artefacts.
- **Pins:** all five live heads re-verified **unmoved** (sixth consecutive check).
- **New findings: 167** — RiptOPL 15 (281–295), Launchstation 14 (186–199), POPSLoader 37 (060–096), SMS 55 (103–157), PS2-Servers 44 (070–113), cross-repo 2 (X-52, X-53). **Running total: 913 numbered items** (per-repo ranges contiguous: RiptOPL 001–295, Launchstation 001–199, POPSLoader 001–096, SMS 001–157, PS2-Servers 001–113, X-01…X-53); +2 revisions (R7-REV-006 narrows REV-006 to the bdm_assault half — the shipped usbhdfsd.irx is an MX4SIO driver with no source in the repo; R7-REV-011 corrects POPSLOADER-011's rationale via -066).
- **The extension was justified by yield:** POPSLOADER-071 — tarball USB CSW validation defeated by construction (receive buffer pre-filled with the expected signature/tag/success; parent-verified in the extracted bytes); SMS-103 — LFN EntrySeq unchecked into a 128-byte name buffer on a crafted USB stick (parent-verified at ums_fat.c:421), with SMS-104…108 a crafted-media overflow family across DTS/MPEG-4/Vorbis; LAUNCHSTATION-186 — libsmb2's IOP randomness is a 15-bit LCG feeding NTLM challenges and SMB3 nonces whose call-site comment demands unpredictability (parent-verified at compat.c:515 / ntlmssp.c:1004); LAUNCHSTATION-187 — a CI-wired test fails deterministically at the pin (reproduced); PS2SERVERS-070 — shipped archives tell users "read-only by default" while the binary defaults writable (parent-verified at edge-build.yml:387 vs main.go:150,301,359), inside a 44-finding test-vacuity harvest (PS2SERVERS-071…113); RIPTOPL-281 — GSHandler REGIMM mask 0x3F into a 32-entry jump table (parent-verified at gsm_engine.S:1062-1063); X-52/X-53 — generated artefacts are byte-exact today (7 groups regenerated and compared) but almost nothing would notice drift, and Launchstation's font TTF inputs are tracked nowhere.
- **Honest negatives, recorded:** RiptOPL headers — 714 macros censused, zero defects, no ARRAY_SIZE-family macro exists there; Launchstation macros — zero siblings of -119; xparam table sequence-identical to RiptOPL's in-repo reference at all 286 positions; PS2-Servers suites fail only on this sandbox's blocked UDP; no PS2-Servers test encodes any round 1–5 protocol bug as correct; cross-repo generated-artefact drift — zero confirmed.
- **Index state:** the master index extraction reproduced 878 of 913 rows automatically; the 35-row gap is fully diagnosed — two round-7 files use variant finding formats (RiptOPL-ROUND7's index-table + Title-block format, 15 rows; POPSLoader-ROUND7's tarball section T-number mapping for 077…096, 20 rows) that the extractor's heading parser does not match. A repair pass on the extractor (reports untouched) is closing the gap; the per-file counts above rest on the agents' verified contiguous numbering, and the index will be re-verified against them.
- **Residues after round 7 (each report carries its own):** Launchstation docs prose — the largest untouched class anywhere; SMS constant-table regions + AC3 imdct + IOP non-parsing internals + elided SIMD ranges + SMS docs; RiptOPL test corpus line-read (bounded, not closed, in round 7). PS2-Servers and POPSLoader residues are now purely un-executable-here / binary / hardware classes. Round 8 is scoped to the three remaining read-shaped residues.

---

# CORRECTION TO THE ROUND 7 ADDENDUM (2026-11-14, same day)

The round-7 addendum's POPSLoader count was wrong, and the error was in the deliverable, not the arithmetic: the POPSLoader round-7 coordinator claimed 37 findings (POPSLOADER-060…096), but only 17 were ever written into Sable-POPSLoader-ROUND7.md (060…076). The tarball section's T07…T26 (to have been 077…096) **were counted but never written** — lost at the same truncation that cut POPSLOADER-076's body mid-finding (the report's line 178 is the literal marker "...[truncated 21461 chars]", parent-verified). An exhaustive search (report, section files, /tmp working file — which holds only T01–T06 — all workspace .md, agent records) found no trace of the 20 missing findings. The index-repair pass caught this precisely because it refused to invent rows.

**Corrected delivered totals: 893 numbered items with written bodies** (RiptOPL 295, Launchstation 199, POPSLoader 76, SMS 157, PS2-Servers 113, X-01…X-53; statuses 852 STANDING / 24 REVISED / 16 CROSS-REF / 1 WITHDRAWN → 892 not withdrawn). The round-7 new-finding count is 147 delivered, not 167 claimed. A completion pass is re-deriving the tarball section from the extracted tarball at /tmp/bdma7/ — completing -076's body and filing whatever the evidence supports as POPSLOADER-077 upward (the count will follow the evidence, not the earlier claim) — after which the index regenerates and the totals are restated from the files. The parent relayed the coordinator's "37" to the user without verifying the count against the deliverable; the mechanisms spot-checked (071 in particular) were and are real, but the count was not, and the correction is recorded here and in the index §1.3/§5.

---

# ROUND 8 ADDENDUM + TARBALL COMPLETION (2026-11-14)

## Tarball completion (closes the Round 7 correction)

The completion pass re-derived the BDMAssault tarball section end-to-end from /tmp/bdma7/. POPSLOADER-076's body is completed from source (scsi_connect discards scsi_warmup's result at scsi.c:279-280 in both generations, diff-verified; a failed device is published with zero/stale geometry — downstream, GPT's entriesPerSector becomes 0 and the BDM mount thread divides by zero). **31 new findings were filed, POPSLOADER-077…107** — more than the 26 originally claimed, because the full pass (usb_mass/scsi remainder, bdm + part drivers, libbdm cache/defrag, fs_driver/diskio/ffsystem glue, full USBD host stack; all 21 component↔merged pairs re-diffed: substitutions only, no local deltas) supported more, and nothing was padded or suppressed to match the earlier claim. Headlines: **-077** DevCtl STOP_UNIT/STOP_ALL bodies literally swapped (fs_driver.c:781-790, parent-verified); **-078** IsoTD halted-flush clears the wrong LUT slot; **-079** failed hub connect leaves a dangling privDataField then double-frees; **-080** part_read/part_write never clamp to the partition's sectorCount; **-081** bd_cache marks blocks valid on failed reads. The final tarball-section total is 37 findings (071…107) — the number round 7 claimed, reached this time by written bodies. Report header, section header, residue and totals lines in Sable-POPSLoader-ROUND7.md corrected to match, with an in-section completion note recording that T07…T26 as originally conceived are unrecoverable and were re-derived, not restored.

**POPSLoader cumulative: 107** (rounds 1–4: 59; round 7 as completed: 48).

## Round 8 (scoped to the three remaining read-shaped residues)

- **Launchstation +24 (200–223)** — docs claims-vs-code: 109 prose files / 11,439 lines read in full; 209 claim groups: 167 MATCH / 33 contradicted (deduped to 24 findings) / ~18 unverifiable-from-source (listed, not filed). Headline **-200**: the shipped example config's `Misc = MISC/` double-slashes on load (config.c:973 unconditional append) and its own FileBrowser shortcut fails the exact dispatch compare (main_actions.c:732), compounding each save/load. Docs prose class CLOSED.
- **SMS +21 (158–178)** — 313 constant tables script-counted (VLC bounds clean family-wide; Parity[256] exhaustively verified); **-161** DTS scale_factor_quant6[63]=0 + quant7[125..127]=0 (parent-verified literal zeros terminating strictly-increasing runs; largest scale factors decode as silence; replacement values INFERRED, spec-only); **-160** AAC Huffman bound arrays wrong in both directions (interlocks with SMS-123's fix ordering); **-158** SMSTCPIP do_connect discards tcp_connect's return → netconn_connect deadlock on ERR_MEM; **-159** get_socket indexes the 15-entry table with an unchecked fd in IRX exports; **-162** USBD OHCI init memsets through an unchecked AllocSysMemory. Tasks closed: tables, AC3 imdct (fixed-size verified line-by-line), IOP internals (brief line estimates corrected on record: 4,503 not ~10,100; hcd.c 498 not ~2,830), SIMD arithmetic (2,815 lines, zero findings), all four not-re-derived items settled consistent (PackAddMB offsets now derived exactly), docs (48 claims: 41/1/6).
- **RiptOPL +48 (296–343)** — .github/scripts corpus LINE-CLOSED: 302 tracked files / 63,264 lines read in full (round 7: 24; round 8: 278; sole unread item is an untracked .pyc); +1 formal extension of RIPTOPL-291 (10 instances) and 1 narrowing revision attached to -301. Headline **-296**: the APA raw-namespace scan globs `*.[ch]`, never sees the tree's 115 .cpp files, and unscanned hdd0: spellings already exist (parent-verified autolaunch.cpp:91); **-298** a test encodes RIPTOPL-160's missing GPT extent validation as correct; **-302** a membership assertion that can never fail (executed); **-304…-307** suites testing private re-implementations of production logic; the -291 extension's worst instance: a JPG-decoder suite gated on dependencies no workflow installs — plausibly never runs in CI.

**Counts discipline:** every round-8 count above was verified by the parent against the delivered files' numbered headings before being recorded here (Launchstation 24 unique IDs; SMS 21; RiptOPL 44 in 300–343 + 4 in 296–299 = 48 contiguous; POPSLoader ROUND7 file: 060–079 all present + 077–107 = 31 unique new).

**Restated delivered totals: 1,017 numbered items** (RiptOPL 343, Launchstation 223, POPSLoader 107, SMS 178, PS2-Servers 113, X-01…X-53). Status split to be restated by the regenerated master index (the +31/+93 change the standing/revised mix; the index is the authority once regenerated).

**Round 9 (launched 2026-11-14 on the user's "line for line supreme ultra max" directive):** RiptOPL headers as a corpus (344+), modules/ full line-read (400+), third_party in two passes (500+/600+, vendored lens), SMS last named source (179+: USBD dispatch + hub.c remainder + two not-promoted items settled), cross-repo shipped-binary/IRX verification (X-54+). Launchstation and PS2-Servers have no round-9 reading scope left at their pins.

---

# ROUND 9 ADDENDUM (2026-11-14) — "line for line supreme ultra max"

Scope set by the user with a usage screenshot (Power plan 22% used, 385M weekly tokens left, 6B additional untouched): full line-reads of every corpus previously mechanism-scanned or excluded, plus the binary class. Six workstreams, **165 new findings**, every count parent-verified against the delivered files' headings before being recorded here.

- **RiptOPL headers +24 (344–367)** — 260 files / 16,029 lines outside modules/third_party line-closed. **-344**: CNFGetKey writes the terminating NUL only on the whitespace path; a ≥64-char BOOT2 token leaves the caller's exact-64 stack buffer unterminated and GetStartupExecName scans past it (parent-verified ps2cnf.cpp:54-67). Six unguarded headers incl. the EE↔loader contract header modules.h (-345). On the record: rounds 7/8's header totals (35,590–35,808 lines) do not reproduce at this pin under any measured extension set; this round's measured ledger is authoritative.
- **RiptOPL modules/ +119 (400–499, 512–530)** — all 493 files / 128,148 lines line-read, unread-as-source zero; 9 candidates dropped as duplicates of existing findings (mapping in file). **-401**: SMB negotiate domain name reaches PrimaryDomainServerName[64] via getStringField's inbytes==0 raw strcpy — pre-auth server-controlled overflow (parent-verified smbman-ra/smb.c:336-347,404; the cdvdman copy clamps — divergence). **-400** FindFirstNext2 unchecked server offsets; **-402** ZSO uses LZ4_decompress_fast on user images; **-403** lwip_accept NULL-netconn deref; **-404** GPT fallback trusts raw partition_count; **-412** ARP can never expire (LWIP_ARP defined nowhere); **-430** the STOP_UNIT/STOP_ALL swap also lives in RiptOPL's own bdm fs_driver (cf. POPSLOADER-077); **-431** SMB1 FileTimeToDate wrong on ~half of dates (executed: 198/396); **-436** USB READ CAPACITY missing +1 (last sector unreachable). The 19-finding numbering overflow was allocated 512–530 by a finishing pass with a full old→new map in the file's COUNT section.
- **RiptOPL third_party +14 (500–511, 600–601)** — vendored lens held: mbedTLS byte-identical to official 3.6.7 (zero diff, 276 files, executed), ps2sdk-socket byte-identical to ps2sdk @ac92a9f6, PSUManager core byte-identical to its pinned upstream — pristine defects recorded as unnumbered observations only. Findings are integration-level: **-501** 55 config-empty TUs compiled per full-config mbedTLS build (75 in slim; preprocessor census); **-502** the vendor test never hashes a vendored byte — the byte-for-byte claim is unenforced; **-500** korium assets test orphaned by all workflows; **-503** orbit README understates load-bearing replacements (1 vs 2); **-600** two Sectigo roots (1,996 B) embedded into RA builds with no update channel (ELF retention INFERRED); **-601** PSUManager's vendored CMake+tests dead in this build (delete 155 lines).
- **SMS +4 (179–182)** — last named source closed (USBD driver.c/interface.c full; hub.c full, 7 candidates dissolved). Both round-8 not-promoted items settled by promotion: **-179** err_to_errno maps every error to EIO — signed err_t compared against unsigned sizeof makes the 11-entry table unreachable (parent-verified sockets.c:89-91 + err.h:39); **-182** tcp_next_iss fully predictable (seed 6510). **-180** USBD callback-thread false-success (third of the family); **-181** three exported USBD stubs return USB_RC_OK doing nothing. SMS-161's missing DTS values: named precisely, sources are spec/reference tables only, explicitly not interpolated.
- **Cross/binary +4 (X-54…X-57)** — real MIPS tooling ran (user-space binutils-mipsel 2.42): **POPSLOADER-069 upgraded to disassembly-verified** (usbhdfsd.irx entry computes the "MX4SIO: MX4SIO v1.2" string address and printfs it first; sio2man imports, zero USB); **X-55** shipped root POPSTARTER.ELF is byte-identical to the DEBUG variant in both repos (cmp matrix, ≤2-byte deltas in one dword); **X-54** SMS ships 18 plain .irx duplicates (286,561 B) of their .xz payloads with no consumer; **X-56** RiptOPL drvtif-ingame.irx ≡ drvtif.irx since introduction; **X-57** BDMAssault family = 45 files/9 binaries, RiptOPL PROVENANCE hashes verify 9/9, but the .udpfs pair is recorded nowhere and POPSLoader keeps no provenance record. Full 206-artefact inventory (10,857,571 B) in the report §5.

**Restated delivered totals: 1,182 numbered items** (RiptOPL 500, Launchstation 223, POPSLoader 107, SMS 182, PS2-Servers 113, X-01…X-57). Status split and quick-win count to be restated by the regenerated master index (extraction reconciles or reports the gap; the index remains the counting authority).

**Residue after round 9, honestly stated:** at the round-2 pins, every first-party source corpus in all five repos has now been line-read (RiptOPL incl. headers/modules/third_party/test corpus; Launchstation incl. docs; SMS incl. tables/SIMD/IOP/docs; POPSLoader incl. tarball contents; PS2-Servers complete since round 5), documentation claims-checked, and shipped binaries inventoried with structure/strings verification plus disassembly of the contested artefact. What remains is not unread text: (1) behavioural/disassembly audit of the other 205 binaries (structure-level only); (2) PS2 build results (no PS2SDK in this VM); (3) real-hardware behaviour — nothing in 1,182 findings is hardware-verified; (4) live network interop (sandbox blocks UDP); (5) spec-only values (SMS-161) and external-contract questions recorded inside findings (RIPTOPL-459/468/469, Launchstation's do_dns_getserver + ps2smb.h caveat, the smbd link test). Further rounds at these pins would be re-reading; productive continuations are a pin move, a PS2 build/hardware rig, or a behavioural binary audit.

---

# VERIFICATION PHASE (2026-11-14) — adversarial re-verification, census, execution re-runs; reconciliation folded into the index

After round 9, the audit's own claims were put through the same treatment the audit gives the code: every Category 6 finding was adversarially re-derived from source at the round-2 pins by fresh readers briefed to refute, not confirm; a consistency census swept all 1,182 findings for duplicates, contradictions and orphans; and every execution-based claim that this sandbox can re-run was re-executed from scratch. Five deliverables: `Sable-VERIFY-RiptOPL-CAT6.md`, `Sable-VERIFY-SMS-CAT6.md`, `Sable-VERIFY-OTHERS-CAT6.md`, `Sable-VERIFY-CONSISTENCY.md`, `Sable-VERIFY-EXECUTION.md`. This addendum records the verdicts and the reconciliation; the master index has been regenerated and remains the counting authority.

**Cat-6 re-derivation — 239 findings: 165 VERIFIED / 45 VERIFIED-DRIFT / 26 WEAKENED / 3 REFUTED.** VERIFIED-DRIFT means the mechanism holds and one or more citations were corrected; the corrected citations live in the VERIFY files, which are now the citation-correction record (the original reports are unchanged). WEAKENED means the defect survives only under a narrowed condition — 23 of the 26 are now REVISED in the index, each with a §4 ledger entry quoting the narrowed condition; the other three (RIPTOPL-405, -408, -468) were also duplicates and are retired as CROSS-REF below, with their narrowings recorded in their §4 entries; the execution qualification (PS2SERVERS-071) is likewise REVISED. **Consistency census: 16 duplicate pairs (9 full, 7 partial), 4 contradictions (C-1…C-4), 0 orphans** in-corpus. **Execution re-runs: 13 CONFIRMED (5 to the exact filed numbers), 0 BROKEN, 3 BLOCKED** — all three blocks are environment, not evidence (the sandbox blocks UDP `sendto`; mbedtls dev headers and Python `cryptography` are absent in this VM).

**Three findings are WITHDRAWN (REFUTED):**
- **RIPTOPL-513** — defect absent: the HDPro function's `lba` parameter is 32-bit (`hdpro_atad.c:678`; `atad.h:55`), so the cited LCYL/HCYL composition is correct and the prescribed fix is an identity transformation.
- **RIPTOPL-443** — the claimed double-close trigger is defeated by the sole caller's mount-state guard (`device-smb.c:165` checks `smb_mount_state == 1`, `:168` sets −1; `DeviceDeinit` delegates to the same guarded `DeviceUnmount`); the u16/sentinel non-idempotence is latent-only.
- **SMS-015** — its own proposed fix already exists at the pin: the `_tbl_fits` guard (`SMS_ContainerMOV.c:143-146`) runs before every cited malloc, with atom sizes bounded by the parent chain rooted at the real file size. This also resolves census contradiction C-2 (SMS-045's boundedness assertion stands).
A withdrawal note is appended under each finding's heading in its report file, so no reader acts on them.

**SMS-123 reopens.** Its in-text withdrawal rationale ("declared sizes are maximum valid indices") is falsified by SMS-160's verified counts (declared = actual + 1 for codebooks 1/2/4/6/10; declared = actual − 1 for codebook 11). The rationale is withdrawn, SMS-123 is REVISED, and any fix must pair the check-reorder with SMS-160's corrected bounds (census C-3; a reorder-only fix still admits 1–2 past-end entries, and a `>=`-on-declared-count fix would falsely reject codebook 11's valid offset 373). The check-after-use defect itself is verified and stands.

**Duplicates — the pattern, admitted plainly.** 8 of the 9 full duplicates are round-9 re-filings. The round-9 briefs deduplicated by skimming prior *headings*, but the earlier mechanisms live in finding *bodies*, not headings — so the dedupe failed systematically in exactly the round that filed the most. The later filing in each full pair is retired as CROSS-REF to the canonical earlier finding: RIPTOPL-344→158, -468→093, -454→045, -411→086, -455→208, -444→085, -405→149, -416→169, -501→006; two partial pairs merge the same way (RIPTOPL-408→163, RIPTOPL-445→040) and two cross-references are regularised (X-17→LAUNCHSTATION-041, X-23→PS2SERVERS-014); three further partials are annotation-only (census D-12, D-14, D-16). RIPTOPL-468 additionally carried a false claim about RIPTOPL-093 (census C-1): -093 files the REV_3 gate expression at both smap copies, not "the REV_1 gate" — corrected in the §4 ledger. C-4 is dispositioned inside D-9: RIPTOPL-006's "tens of KB of ELF size" benefit estimate is superseded by RIPTOPL-501's measurement (no ELF effect; the win is build time and archive bulk).

**Six new findings**, filed by the verification passes themselves and collected in `Sable-VERIFICATION-NEW-FINDINGS.md`: **RIPTOPL-602** (`hddFormat` reads a cache entry's sector after freeing it — a second instance of the RIPTOPL-467 pattern, in the XOSD build variant); **SMS-183** (SMSTCPIP `lwip_getpeername`/`lwip_getsockname` ignore `netconn_peer`/`netconn_addr`'s return — a guarded error becomes a successful garbage result, and SMS-170's fix alone does not save `lwip_getsockname`); **SMS-184** (USBD `hcdInit` never checks the HCD IRQ thread's creation); **POPSLOADER-108** (GPT partition `sectorCount` one sector short — `last_lba` is inclusive); **PS2SERVERS-114** (the fake SMB2's TREE_CONNECT and CLOSE always raise `struct.error` and kill the connection thread, on well-formed requests); **PS2SERVERS-115** (the fake SMB2's header packer/parser is 66 bytes, not 64). Renumbering record: the SMS verification pass filed its candidates as SMS-230/SMS-231; they are renumbered **SMS-230 → SMS-183** and **SMS-231 → SMS-184** here and in the new-findings file.

**Execution qualifications.** C-1: RIPTOPL-302's "82–84 targets" figure does not reproduce (actual 73 korium/incebtion, 76 ra/ra_incebtion); the mechanism is confirmed and count-independent — no status change. C-2: PS2SERVERS-071 is REVISED — the filed wrong-sector-oracle defect stands, but its "guard removed → payload at offset 0" hypothetical is backstopped by a second clamp (`server.go:498-500`).

**Category-label note.** `Sable-POPSLoader-ROUND7.md`'s tarball section labels its findings "Category: 2 (correctness/safety)" for mechanisms that are Category 6 in the audit scheme — which is why §3(b)'s first-number extension lists only one POPSLoader row (POPSLOADER-066). The mechanisms were verified regardless (VERIFY-OTHERS verified the full tarball set).

**Restated delivered totals (regenerated master index, extraction's figures): 1,188 numbered items** — RiptOPL 501, Launchstation 223, POPSLoader 108, SMS 184, PS2-Servers 115, X-01…X-57. **Statuses: 1,104 STANDING / 51 REVISED / 29 CROSS-REF / 4 WITHDRAWN → 1,184 not withdrawn. Quick wins: 849.** The reconciliation changed exactly 41 statuses (25 STANDING→REVISED, 13 STANDING→CROSS-REF, 3 STANDING→WITHDRAWN) and added exactly the 6 new findings; the §2 diff against the pre-verification index shows no other row touched, and the pre-existing §3(b) top-tier block is byte-identical.

**What verification did not change:** the residue statement. Verification re-checked claims at the same pins; it did not extend coverage — no PS2 build (no PS2SDK in this VM), nothing hardware-verified, live UDP interop still sandbox-blocked, and the other 205 shipped binaries remain structure-verified rather than behaviourally audited.

---

# FULL VERIFICATION (2026-11-14) — every remaining finding adversarially re-derived; reconciliation #2 folded into the index

The verification phase covered Category 6. The user then directed that **all** of the audit's findings be put through the same treatment ("all of them"). The full-verification phase adversarially re-derived, from source at the same round-2 pins, every STANDING/REVISED finding the first phase had not covered — fresh readers briefed to refute, not confirm, with execution wherever this sandbox allows it. Six deliverables: `Sable-VERIFY2-RIPTOPL.md`, `Sable-VERIFY2-LAUNCHSTATION.md`, `Sable-VERIFY2-POPSLOADER.md`, `Sable-VERIFY2-SMS.md`, `Sable-VERIFY2-PS2SERVERS.md`, `Sable-VERIFY2-CROSS.md`. This addendum records the verdicts and the second reconciliation; the master index has been regenerated again and remains the counting authority.

**Full verification — 939 verdict rows: 751 VERIFIED / 122 VERIFIED-DRIFT / 51 WEAKENED / 14 REFUTED / 1 BLOCKED-ENV.**

| Repo | Rows | VERIFIED | VERIFIED-DRIFT | WEAKENED | REFUTED | BLOCKED-ENV |
|---|---|---|---|---|---|---|
| RiptOPL | 401 | 358 | 30 | 11 | 2 | 0 |
| Launchstation | 208 | 159 | 29 | 17 | 3 | 0 |
| POPSLoader | 68 | 52 | 10 | 6 | 0 | 0 |
| SMS | 108 | 80 | 17 | 8 | 3 | 0 |
| PS2-Servers | 103 | 75 | 17 | 5 | 5 | 1 |
| Cross-repo | 51 | 27 | 19 | 4 | 1 | 0 |
| **Total** | **939** | **751** | **122** | **51** | **14** | **1** |

(POPSLoader's 52 VERIFIED include POPSLOADER-016/-033, verified in their already-revised narrowed form. PS2-Servers' 75 VERIFIED are 71 full-scope verdicts plus 4 verified aspects of PS2SERVERS-071; its fifth aspect — the mutation run — is the 1 BLOCKED-ENV, environment-blocked exactly as in phase 1, and its REVISED status is unchanged.)

**Combined two-phase totals: 1,178 verdict rows.** Phase 1 (Category 6): 239 rows — 165 VERIFIED / 45 VERIFIED-DRIFT / 26 WEAKENED / 3 REFUTED. Phase 2 (everything else): 939 rows — 751 / 122 / 51 / 14 / 1 blocked. Every STANDING/REVISED finding in the corpus has now been adversarially re-derived at least once at the round-2 pins. VERIFIED-DRIFT across both phases (167 findings) means the mechanism holds and one or more citations were corrected; the corrected citations live in the VERIFY and VERIFY2 files, which are the citation-correction records — the original reports are unchanged, except for the WITHDRAWN notes appended under the refuted findings' headings.

**Fourteen findings are WITHDRAWN (REFUTED):**
- **RIPTOPL-051** — `size` is `u32`, so `size <= 0` at mcemu.c:845,896 is a live `size == 0` exit that fires when `size -= csize` consumes the remainder; the guard is functional, not dead.
- **RIPTOPL-348** — a live caller exists: `.github/scripts/test_ra_ps1.py:137` generates the `raVcdBootName` assertions into a compiled harness the suite runs with `check=True`; the suite passes at the pin.
- **LAUNCHSTATION-100** — `usmb2_readdir` sits inside `#ifdef USMB2_FEATURE_OPENDIR` (usmb2.c:743-820), a macro no build file defines, with zero callers; the live directory path (smb2man.c) does clamp.
- **LAUNCHSTATION-127** — `q_escape`/`json_escape` fail (−1) rather than truncate and all three call sites check those returns; worst cases ≈1,109 < query[1280], ≈3,913 < path[4352], ≈974 < body[1024], ≈1,018 < body[1280] — truncation is arithmetically unreachable.
- **LAUNCHSTATION-214** — `shouldHideHddAtaDevices()` exists (main_startup.c:746-756) and is consumed (filer.c, dash_devices.c); README.md:181 is substantively correct.
- **X-57** — POPSLoader's `docs/third_party/okeanos_udpfs/PROVENANCE.json:12,17` records both .udpfs files by name with hashes; the headline is false as filed. Its surviving residue is filed as X-59.
- **SMS-013** — the 2 MB video-ring allocation (SMS_Player.c:1741) already sits inside the video-stream branch (`m_Type == SMS_CodecTypeVideo`, :1716); the proposed fix is already the code.
- **SMS-089** — the JPEG preflight walk returns at SOF0 (SMS_Artwork.c:64-68) or SOS (:60) and never reaches entropy data, where RST/TEM markers only exist; DRI is length-bearing and walked correctly.
- **SMS-123** — see the full history below.
- **PS2SERVERS-104, -105, -109, -110, -111** — **FABRICATED CITATIONS.** These five are the round-7 Cat-2 test-census sub-block (PS2SERVERS-104…111), and their citations do not exist at the pin: -104 cites `network_test.go`, `helpers_test.go` and `udpfs_probe_test.go` (none exist; the string `"UDPFS1.0 ready"` occurs 0 times, not three; a shared `startServerAt` bootstrap already exists); -105 cites four absent test files and a `_handler`/`_negotiate` helper that exists nowhere in tests/; -109 cites a `Supervisor`/`start_owned`/`stop_owned` API that grep finds 0 times in the named file, which already shares `start()`/`ready()` helpers; -110 cites a `_comp_for_ext` function that exists nowhere — both "copies" call the single production `_format_for_extension`; -111 names two tests that do not exist, over spans that hold two different hash-mismatch tests. The sub-block's other members (-106, -107, -108, -112, -113) were re-derived and stand (with -106 narrowed); the fabrication is confined to these five, and it is named here as what it is: the round-7 census pass invented file and function names for five of its findings. All five are withdrawn, with the words FABRICATED CITATIONS in their index §4 entries and in the notes appended under their headings.

A withdrawal note is appended under each finding's heading in its report file, so no reader acts on them.

**SMS-123 — the full three-step history, closed.** (1) At filing (round 7), an in-text script count withdrew the off-by-one limb on the rationale "declared sizes are maximum valid indices", leaving only the check-after-use defect. (2) Verification phase 1 (census C-3) falsified that rationale with SMS-160's verified counts (declared = actual + 1 for codebooks 1/2/4/6/10; declared = actual − 1 for codebook 11), withdrew the rationale, and **reopened** the finding as REVISED — the previous addendum's "SMS-123 reopens" paragraph records that step and is superseded by this one. (3) Full verification then settled the reachability question itself: two independent script derivations prove the first-stage Huffman segments tile each second-stage table exactly, so the maximum reachable offset equals the last valid index on all seven codebooks (declared/actual/max-reachable: cb1 114/113/112, cb2 86/85/84, cb4 185/184/183, cb6 126/125/124, cb8 83/83/82, cb10 210/209/208, cb11 373/374/373; excess past end 0 everywhere). No reachable out-of-bounds read exists; the check-after-use ordering is a latent dead guard. **SMS-123 is WITHDRAWN**, with the correct rationale this time. One piece of the reopened finding survives as guidance: the **SMS-160 bounds-pairing** — if the check-reorder is ever applied as defence-in-depth, it must use SMS-160's corrected bounds, because a reorder on the declared bounds would use wrong bounds and a `>=`-on-declared check would falsely reject codebook 11's valid offset 373.

**Fifty-one findings are REVISED (WEAKENED)** — the defect survives only under the narrowed condition quoted in each §4 ledger entry (VERIFY2-N1…N51). The load-bearing narrowings: **POPSLOADER-041's mechanism is REPLACED** — the endpoint walks are count-bounded (`while (epCount--)`), so a zero bLength stalls but terminates; the real hang is `epCount = interface->bNumEndpoints − 1` underflowing to −1 when `bNumEndpoints == 0` (ds34bt.c:117, ds34usb.c:132 DS3 branch), and the fix should add an `epCount < 0` / `bNumEndpoints == 0` guard. **LAUNCHSTATION-185's originally proposed fix should NOT be applied** — its loop-condition half (`i1 + 1 < argc`) would read one argv slot past the last complete pair; only the argc == 3 fall-through survives. **LAUNCHSTATION-072** (already REVISED in round 4) narrows further: only 2 of its 7 proposed deletions are proven (quic.c, smbdirect.c); aes_reference.c is the server's only AES and must stay; sync.c and the three smb2-data files are UNVERIFIABLE-HERE pending a `--gc-sections` link test. **X-54's** deletion fix stands, narrowed: the plain .irx files are regeneration inputs to compress_irx.py, not unreferenced. **PS2SERVERS-093's** bare return stands but its filed CI consequence is refuted — no Windows job runs the module. **X-07** moves from CROSS-REF to REVISED: RiptOPL's per-edition UDPFS cores are 122–125 B `#include` shims, not copies; only the header set is triplicated.

**Twelve new findings**, filed by the full-verification passes themselves and collected in `Sable-VERIFY2-NEW-FINDINGS.md`: **RIPTOPL-603** (smb_open's full-size strncpy count leaves `fh->name` unterminated — the count-equals-size sibling of RIPTOPL-040's dopen site); **RIPTOPL-604** (mmce_fs SET_GAMEID devctl case dereferences `arg` unchecked — a fifth case beside RIPTOPL-057's four); **RIPTOPL-605** (tools/assets.py comment asserts the opposite of the RA anchor table it annotates); **SMS-185** (TocEntryCopy writes the string terminator at the disc-supplied filename length, past its 129-byte field); **SMS-186** (AVI `_Load_idx1` publishes an unchecked `SMS_Realloc` result); **SMS-187** (`SMS_ListPushBack(...)->m_Param` unchecked dereferences at 14 further sites beyond SMS-068's filed list); **SMS-188** (`_sb_string_width` iterates one element past the string end into the unchecked glyph-width helper); **PS2SERVERS-116** (the HTTP server's unconditional top-level `from launcher import session_stats` at http_server.py:47 — a copy outside the tree dies on `--help`); **PS2SERVERS-117** (the achievements-engine CI step's fixed module list omits `tests.test_ra_credentials`); **PS2SERVERS-118** (the blanket `# noqa: F401` at test_smb2_libsmb2_compat.py:26 hides the one genuinely dead import, PS2SERVERS-112's `Client`); **X-58** (RiptOPL's PC-tool CRC-32 copies retain the signed-byte negative-index read the EE copy fixed); **X-59** (RiptOPL's BDMAssault PROVENANCE.md omits the .udpfs pair it ships — the surviving residue of X-57).

**Restated delivered totals (regenerated master index, extraction's figures): 1,200 numbered items** — RiptOPL 504, Launchstation 223, POPSLoader 108, SMS 188, PS2-Servers 118, X-01…X-59. **Statuses: 1,054 STANDING / 100 REVISED / 28 CROSS-REF / 18 WITHDRAWN → 1,182 not withdrawn. Quick wins: 810.** Reconciliation #2 changed exactly 64 statuses (13 STANDING→WITHDRAWN, SMS-123 REVISED→WITHDRAWN, 49 STANDING→REVISED, X-07 CROSS-REF→REVISED; LAUNCHSTATION-072's revision text narrowed in place) and added exactly the 12 new findings.

**What full verification did not change:** the residue statement, again. Both verification phases re-checked claims at the same pins; neither extended coverage — no PS2 build (no PS2SDK in this VM), nothing hardware-verified, live UDP interop still sandbox-blocked, the other shipped binaries still structure-verified rather than behaviourally audited, and PS2SERVERS-071's mutation aspect remains environment-blocked in this VM. LAUNCHSTATION-072's four UNVERIFIABLE-HERE files join that residue: their deletion case rests on a `--gc-sections` link test that cannot run here.
