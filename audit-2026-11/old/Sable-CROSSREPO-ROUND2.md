# Sable Audit — ROUND 2: CROSS-REPO, function-level

- **Auditor:** Sable
- **Date:** 2026-11-14
- **Mode:** READ ONLY. All five clones verified `git status` clean at the end of this pass (0 dirty files, HEADs at the pins below). No repo file edited, nothing pushed, no PRs/issues/branches/workflows touched.
- **Relation to pass 1:** This file is the function-level pass that pass 1's SUMMARY explicitly owed ("a function-level diff of the shared updaters / network-init / config parsers across RiptOPL↔Launchstation … has not been done"). It does **not** repeat X-01…X-16. New findings start at **X-17**.
- **Rule:** LESS, NOT MORE. Consolidation is recommended only where sharing genuinely removes code overall; where the evidence shows speciation, the verdict says "keep separate" and proves it.
- **Confidence labels:** READ = the cited lines were read at the pin. INFERRED = composed from READ facts, with the composition shown in the working sections (`round2-sections/01…05`), which are part of this deliverable's evidence base.
- **Secrets:** location-only throughout. No config values, credentials, or key material are reproduced anywhere in this file or its sections.

## Round-2 pins (checked live 2026-11-14; see PINS-ROUND2.md)

| Repo | Round-2 HEAD | Delta from pass 1 |
|---|---|---|
| RiptOPL | `2e347d5ac885` (rebuild/main) | #417 self-update + filemgr rework, #419, #420 |
| Launchstation | `9fb0598a79f0` (master) | #384 self-update in-place write; docs palette ×2 |
| POPSLoader | `29272cddbf01` (master) | unchanged |
| Simple-Media-System | `e65ced39a27e` (master) | docs palette only |
| PS2-Servers | `c5f021c4d386` (main) | docs palette only |

**Headline result:** at the pattern level (pass 1) everything looked duplicated. At the function level the picture splits cleanly in two: the **small, old, vendored-origin pieces are literally byte-identical across repos** (smb2auth.c, SMB1 md4/des/auth, MX4SIO crc16 — sync them, never fork them), while the **large, first-party subsystems have speciated** (network init, file copy, config stores) to the point where a shared library would contain every existing variant plus glue — more code, not less. The real waste found at this level is almost all *intra*-repo: dead machinery kept after a redesign (Launchstation self-update), a second implementation inside one binary (smb2man IOP, Launchstation EE), and checklists each repo re-derived incompletely (file copy). Plus one genuine cross-repo **bug**: a file one program writes that another program silently cannot read (X-18).

---

## Topic 1 — SELF-UPDATE (RiptOPL vs Launchstation)

Full evidence: `round2-sections/01-selfupdate.md`.

### Comparison table

| Axis | RiptOPL | Launchstation |
|---|---|---|
| Updater-exclusive size (READ, wc) | **603 lines** — src/ui/selfupdate.cpp:1-424 + src/platform/selfupdate.c:1-140 + include/selfupdate.h:1-39 | **1,151 lines** — src/self_update.c:1-434 + src/update_psu.c:1-364 + src/dash_tools.c:715-1037 (323) + include/self_update.h:1-30 |
| Downloaded unit | Bare ELF asset, per-edition tag (src/ui/selfupdate.cpp:54-72,277-278) | Whole `.psu` package (ELF + sidecars), tag `latest` (include/self_update.h:11; src/self_update.c:14) |
| Manifest / digest source | SHA256SUMS.txt fetched first (src/ui/selfupdate.cpp:231-242) | GitHub API release JSON, asset `digest` field (src/dash_tools.c:897-905,966-977) |
| "Newer?" proof | Integer build revision parsed from sums-file archive names vs local revision; offer iff strictly greater (src/platform/selfupdate.c:55-103; src/ui/selfupdate.cpp:240) | Second API call, commit **ancestry**: ahead = update, **diverged = blocked outright** (src/dash_tools.c:814-887,986-1015) |
| Hash verification | SHA-256 (mbedTLS) streamed during download, memcmp before any write (src/ui/selfupdate.cpp:186,205,283-300) | SHA-256 (mbedTLS) inside HTTP layer, memcmp in src/self_update.c:296-303 |
| Signature verification | **None** | **None** (digest travels the same cert-verified HTTPS channel as the file, in both) |
| ELF validation | 6-condition 20-byte test on the **first bytes, before RAM allocation** (src/platform/selfupdate.c:135-140; src/ui/selfupdate.cpp:170-191) | **Byte-identical-logic** 6-condition test, after download+hash, on ELF located inside PSU (src/self_update.c:210-215,306-317) |
| Journaling / backup / retries | None / none / none (header states it, src/ui/selfupdate.cpp:1-13) | None / stale legacy `.BAK` deleted pre-install only (src/self_update.c:261,279-288) / none |
| Redirect policy | ≤3 hops, **allowlist of 3 GitHub hosts enforced per hop** (src/platform/selfupdate.c:105-126) | ≤5 hops, **any HTTPS host** (cert still verified); host check applies only to bearer-token media (src/cloud_http.c:982,1000-1006,1083-1110) |
| RAM behaviour | Whole ELF in RAM, malloc at Content-Length, cap 8 MiB (src/ui/selfupdate.cpp:95,184-207) | Whole **PSU package** in RAM + a 4 MiB reserve probe malloc that must succeed, cap 16 MiB (src/self_update.c:15-19,176-193) |
| Free-space pre-check | **None in code**; orphan comment at src/ui/selfupdate.cpp:250-251 describes a cluster check no code performs | Explicit: free + old ELF ≥ new ELF + 32 KiB, or refuse (src/self_update.c:343-350) |
| Write | fileXioOpen WRONLY\|CREAT\|TRUNC, 16 KiB chunks, steps 1/2/3 (src/ui/selfupdate.cpp:303-347) | genOpen WRONLY\|CREAT\|TRUNC, 16 KiB chunks, steps 1/2/3 (src/self_update.c:216-243) |
| Boot devices | mc + mass only (src/ui/selfupdate.cpp:128-142) | 8 prefixes: mc, mass, usb, mmce, mx4sio, ilink, ata, hdd (src/self_update.c:22-51) |
| CA trust | Roots embedded in the binary (include/ratls.h:78-82) | External `WLE-UPDATE-CA.PEM` file must exist on device; update itself can install it from the package (src/dash_tools.c:794-812; src/self_update.c:319-341) |
| Extras | Session reinstall memory (src/ui/selfupdate.cpp:102,342) | Sidecar install (CA/BGM if missing, never overwrite), SAS folder-timestamp preserve/restore (src/self_update.c:319-341,396-433) |
| Auto-restart | None | None |

### Same flow or different?

**The same flow, hand-ported — and RiptOPL's source says so:** *"Overwrite the booted ELF with the verified bytes, as Launchstation does"* (`src/ui/selfupdate.cpp:303-305`, READ, parent-verified). Shared spine: metadata first → digest from the metadata channel → whole payload in RAM → hash-compare → identical ELF header test → TRUNC-in-place 16 KiB-chunk overwrite with the same 1/2/3 step numbering → no staging, no backup, no journal, no signature, no restart. A mid-write failure can brick the on-device ELF in both, and both tell the user so.

The divergence is **scope, not approach** — except two genuine design disagreements: the version proof (ancestry vs integer revision) and the redirect policy (any-HTTPS vs 3-host allowlist).

### Revalidation duty discharged: LAUNCHSTATION-017

**STILL TRUE, reframed.** #384 killed the staging-file/rename/.BAK dance (its tests now assert that machinery's absence, tests/test_self_update.py:29), but RAM-only is now the *only* path by deliberate, documented design (src/self_update.c:184-185), the 16 MiB cap + 4 MiB reserve probe survive (src/self_update.c:15-19,176-193), and what is held grew in kind: the whole PSU package, of which only the ELF slice is written out. The pass-1 fix ("use the card path that already exists") is **no longer available as described**: the file-based path (update_psu.c:183-211,335-353; cloud_http.c:1279-1287, self-described "Historical") has **no production caller at this head** — only host tests call it. It is dead code wearing a fallback's clothes (→ X-17).

### Verdict — Topic 1

One flow's **shape** already serves both and is the template for any future sibling. A shared **library** is NOT a win: the true common core is ~100 lines per repo (ELF test 6, hex glue ~35, overwrite loop ~30-45, redirect follow ~40), while each HTTPS stack is welded to a different host (RiptOPL's ratls also serves RetroAchievements and refuses while a UDP transport owns the NIC; Launchstation's cloud_http also serves Google Drive). Delete instead: Launchstation's dead file-based update machinery (~90-100 lines, X-17); RiptOPL's orphan comment (or implement the 8-line check, copying Launchstation's shape). Hash machinery is **not** duplicated inside either repo — both use mbedTLS SHA-256; only ~35 lines of hex glue is written twice across the repos.

---

## Topic 2 — NETWORK INIT (RiptOPL vs Launchstation vs SMS)

Full evidence: `round2-sections/02-netinit.md`.

### The correction this topic makes to the pass-1 framing

**RiptOPL contains BOTH stack families.** Its *menu* stack is NETMAN+lwIP (Launchstation-modern's sibling); its *in-game* ee_core stack is SMSTCPIP (SMS's sibling). Load order is **stack-determined, not repo-determined**:

| Stack family | Load order | Who |
|---|---|---|
| NETMAN / SDK lwIP | DEV9 → NETMAN → SMAP → PS2IP (address applied after, or as PS2IP arg) | RiptOPL menu (src/sources/netsupport.cpp:192-219); Launchstation modern (src/init.c:656-677) |
| SMSTCPIP / v1.0 (no NETMAN) | DEV9 → **PS2IP first → SMAP second, SMAP takes the address (+link mode)** | Launchstation legacy (src/init.c:639-653); SMS (src/SMS_IOP.c:576-580); RiptOPL in-game (ee_core/src/iopmgr.c:262-267) |
| UDPFS ministack | DEV9-init → udpfs_smap → udpfs_ministack("ip=…") → udpfs_ioman | All three repos, three independent implementations, same shape/order/argument |

So the bring-up sequence is written **5 times** for the IP stacks (RiptOPL ×2, Launchstation ×2, SMS ×1) plus **3 more times** for the UDPFS shape. And everything *after* the loads exists in exactly one repo: RiptOPL's post-load policy layer (link wait, link-mode retries, DHCP, DNS, non-reset teardown — src/sources/netsupport.cpp:110-147,255-305,404-495, ~200 lines) has **no counterpart at all** in Launchstation or SMS. Their init is instead *ownership* policy (Launchstation: DEV9-variant reset; SMS: s_NetOwner + boot power-down), which RiptOPL expresses as refcounting + interlocks. DEV9 ownership is architecturally incompatible across the three: refcounted shared resource vs variant-owned-with-reset vs pre-resident blob driven by ioctl (SMS loads DEV9 at *boot*, powers it **down** at boot if no AUTO flag needs it, src/SMS_IOP.c:1457,1663-1672, and starts networking with a `DEV9CTLINIT` ioctl on the resident driver).

### Constants table — the same hardware steps, speciated budgets (all READ)

| Same step | RiptOPL | Launchstation | SMS |
|---|---|---|---|
| Link-up wait | **30 × 1000 ms = 30 s cap** (netsupport.cpp:82,88) — used for link *and* DHCP | **None — the wait was never written** | **None** |
| Link-mode apply retries | **3** (netsupport.cpp:117-127); mode also attempted once *pre-load* to avoid double-init (:208-209) | Never sets a mode (0 hits in src/) | Mode is a 4th SMAP load argument, single shot (SMS_IOP.c:549-574) |
| DEV9 power-off attempts (identical `DDIOC_OFF` devctl) | **100**, busy-spin (src/platform/system.cpp:264-285) | **100 at power-off (src/init.c:2585-2612) but 20 pre-reset (src/init.c:577-592)** — the same repo disagrees with itself 5× | **1**, single shot (src/SMS_IOP.c:1197; boot :1669) |
| DHCP | End-to-end: flag, setconfig, BOUND wait in the same 30 s poll (netsupport.cpp:482-495) | No DHCP code at EE level (precompiled IRX internals not read — not claimed) | **Compiled out**: `LWIP_DHCP 0` (iop/SMSTCPIP/include/lwip/opt.h:227-228) |
| Address-ready poll | 40 × 250 ms = 10 s, in the *updater* (selfupdate.cpp:228-232) and SNTP path (nettime.cpp:150-154) | None | None |
| Teardown | Non-reset deinit exists; **no DHCP release** (no repo has one — grep 0 hits ×3) | IOP reset is the teardown | IOP reset is the teardown; SMS_IOPNetSwitch's header openly says it mirrors Launchstation's switchNetworkStack (SMS_IOP.c:1760-1775) |
| UDPFS discovery probe | stat() poll every 100 ms to a caller timeout (udpfssupport.cpp:168-186) | No probe — module residency is the answer (init.c:1015-1056) | 2 EE tries × IOP discovery 5000 ms split over 4 retries ≈ **10 s window** (SMS_IOP.c:995-1005; iop/SMSUdpfs/…/udpfs_core.c:297; udprdma.c:534-543) |
| IOP-reset sync | `while (!SifIopSync()) ;` — unbounded | Unbounded | Unbounded — **the one constant all three share: ∞** |
| IPCONFIG.DAT defaults | 192.168.**1**.10 (src/app/opl.cpp:1511-1534) | 192.168.**0**.10 (src/main.c:42-44) | 192.168.**0**.10 (src/SMS_Locale.c:33-35) — identical to Launchstation's, different subnet from RiptOPL's |

Also: Launchstation's `ps2ip_init()` is **quarantined to the dashboard path** (sole occurrence src/init.c:2908) — its SMB/FTP stacks run with no EE socket bind at all; its dashboard DNS is **synthesised** (gateway → 1.1.1.1 → 8.8.8.8, src/init.c:2850-2875). SMS has a **dead declaration**: `SMS_StartNetwork` at include/SMS.h:308, defined nowhere (grep, READ); the real entry is SMS_IOPStartNet.

### Verdict — Topic 2

**Keep separate. No shared network-init library.** Proof: (1) load order flips by stack family and the address travels by a different mechanism in each sequence, so a shared lib needs a per-family branch at nearly every step — it would contain all five sequences plus glue; (2) the policy layers don't overlap (post-load policy exists only in RiptOPL; ownership policy only in the other two); (3) DEV9 ownership cannot be unified without redesigning storage stacks that also ride DEV9; (4) unifying any constant (100 vs 20/100 vs 1; 30 s vs absent) is a **hardware behaviour change disguised as deduplication**, unverifiable without real hardware. The honest LESS moves are intra-repo (→ X-24): align Launchstation's pre-reset DDIOC_OFF budget to its own documented 100, and delete SMS's dead declaration. The already-shared artifact is the **IPCONFIG.DAT format** — keep it as a contract, not code (its three parsers are Topic 3's problem, → X-25). If the pass-1 stack deletions happen (LAUNCHSTATION-003, SMS-018), the sequence count drops 8 → 6 with zero new code — strictly better than any abstraction.

---

## Topic 3 — CONFIG PARSING (all four PS2 repos)

Full evidence: `round2-sections/03-config.md`.

### Premise corrections (READ)

1. **There are not 4 parsers. There are 10** (P1-P10 in the section): RiptOPL has a legacy parser + a libconfig twin + an sscanf IPCONFIG reader; Launchstation has **three** line parsers plus a positional IPCONFIG reader; POPSLoader's C side has **none** (Lua only).
2. **SMS's main config is not text at all.** `SMS_LoadConfig` (src/SMS_Config.c:595-802) is a binary struct dump gated on `m_Version == 14` and **exactly 892 bytes** (include/SMS_Config.h:59-61 states the constraint). Version mismatch or a short read discards the *entire* config — no per-key salvage is possible — and in exchange it is immune to every text-parser bug class below. SMS's only text parser is the **positional, keyless** `SMS.smb` list (6 lines/record, 8 in the new format).

### Divergence table (condensed; full table in section §3)

| Axis | RiptOPL legacy | RiptOPL libconfig | LS get_CNF_string | LS dashKvParse | LS smbConfigParse | SMS positional | POPSLoader Lua |
|---|---|---|---|---|---|---|---|
| Location | config.cpp:167-195,1115-1182 | config.cpp:794-895 | config.c:111-160 | dash_store.c:65-103 | smb_cnf.c:345-438 | SMS_Config.c:314-379 | system.lua:6222-~6760 |
| Line without `=` | log + skip | group hdr or drop | **ABORTS THE WHOLE FILE** (config.c:139-140) | skip | skip | blank line = a field, **shifts the record** | key absent |
| Key trim | leading only — **trailing space stays in the key** (:180-193) | both | name grammar stops at space | both (dashTrim) | both (trim) | n/a | **none** |
| Caps (key/value) | 48/256, **silent truncate** | key ≥48 **rejected**, value truncated | none in parser; dest fields 64-1025, mostly unbounded strcpy | none in parser; dest 256 | 32/32/256, **reject with reason string** | fields, silent truncate + drain | none in parser; SMB sanitizer cap 255 |
| Escapes/quotes | none | **both directions** (write :1020-1040, read :855-884) — verified consistent | none | none | none | none | none |
| Unknown keys on save | **kept, written back** | kept | dropped | dropped | ignored "for later versions" | n/a | **permanently deleted** |
| Duplicate keys | last wins | last wins | last wins | last wins; lists append, no dedup | last wins; dup share-name rejected | records kept | **FIRST wins** |
| Comment | `#` (+`//`,`/*` in classify) | same | **any first char < 'A'** — incl. digit-led lines | `# ; [ //` + BOM skip | `# ;` + BOM skip | none exists | none exists |
| Whole-file cap | 4096 B streamed buffer | same | 128 KiB | 64/256/16 KiB per file | none in parser | fixed 896 B read | none (Ember sub-reader: 8192 B) |

**The same credential, five ceilings (READ, sizes only):** an SMB password field is 255 usable chars in RiptOPL's generic value, 31 in Launchstation CNF SMB fields (`[32]`, guarded at config.c:1050-1053), 31 in Launchstation share blocks (`SMB_CRED_LEN 32`), 63 in SMS's list (`[64]`), 255 in POPSLoader's sidecar — five parsers, no agreed size (→ X-26).

**IPCONFIG.DAT — one file, three parsers, three contracts:** RiptOPL-legacy demands exactly 12 integers via `sscanf` or sets nothing (config.cpp:731-774); Launchstation NUL-splits every space/CR/LF and validates nothing (main_startup.c:53-141, 48-byte buffer); POPSLoader's Lua demands exactly 3 whitespace tokens on line 1 (system.lua:8194-8202). A file with a trailing comment or a 4th token parses in Launchstation and fails whole in the other two (INFERRED from the three READ grammars).

**Escape/quote roundtrip check (explicitly requested): NO writer-only or reader-only mismatch exists in any repo** — RiptOPL libconfig escapes both ways, every other parser is none/none, and POPSLoader's sanitizer newline-strips values its writer emits raw. The asymmetry that does exist is a *format-latch* risk inside RiptOPL (config.cpp:1140-1148): a legacy file whose first meaningful line happens to satisfy all three libconfig tests (space before `=`, trailing `;`, legal identifier) is re-read — and re-written — in the other dialect.

### Duplicated functions, named, with diff evidence

- **`dashTrim` vs `trim` — same repo, verbatim copy.** Launchstation/src/dash_store.c:53-63 vs Launchstation/src/smb_cnf.c:60-70: diff of the 11-line extractions differs in **exactly one line — the signature**; the other 10 lines are byte-identical. `dashTrim` is a non-static export in the same link; the copy exists because smb_cnf.c was kept host-testable standalone.
- **`get_CNF_string` vs `dashKvParse` — same repo, divergent re-implementation.** config.c:111-160 vs dash_store.c:65-103: same job, opposite malformed-line policy — and the divergence is *documented intent* (include/dash_internal.h:657-660: *"Unlike get_CNF_string it skips malformed lines instead of stopping"*). The lenient parser was written because the strict one's abort was unacceptable — and the strict one was left in charge of the main CNF and SYSTEM.CNF.
- **Cross-repo: no function body is a near-copy.** Duplication across repos is at the *format* level (IPCONFIG.DAT, title.cfg, per-game keys), not the code level. The one true shared *format* — `title.cfg` — is where the worst bug lives (X-18).

### Verdict — Topic 3

- **Launchstation internal: CONSOLIDATE 4 → 2 line parsers.** Keep `dashKvParse` as the single line parser (it already serves settings, lists, library, themes, cloud, title.cfg), keep `smbConfigParse` as a validator/record layer on top of it (reject-with-reason + URL-closes-record are real added value), retire `get_CNF_string` — or minimally flip its missing-`=` path to skip-and-continue, a one-branch change with dashKvParse as the existence proof. Keep `getIpConfig` separate (different format). Delete one of the two identical trim copies.
- **RiptOPL ↔ Launchstation: KEEP SEPARATE parsers; FIX THE SHARED FORMAT.** Their main configs are not shared files; their stores are structurally different (generic ordered list vs fixed SETTING struct). What is shared — `title.cfg` — needs a format rule, not shared code (X-18).
- **POPSLoader internal: consolidate the idiom, not the parsers.** ~25 hand-unrolled two-pattern `string.match` extractions (system.lua:6408-6460) + the same idiom in SmbParse + the Ember block = one missing `matchKey` helper, ~27 extraction sites → 1. The .DAT parsers are genuinely different grammars and stay.
- **SMS ↔ everyone: KEEP SEPARATE, proof §2.3 of the section.** Binary config cannot converge with text parsers without breaking every existing SMS.cfg — the version-14 gate *is* the migration wall. Nothing to consolidate that isn't a breaking format change.
- **Net if taken:** 10 parsers → 7, zero format changes except Launchstation's title.cfg template spacing — the single change that fixes the round's worst bug.

---

## Topic 4 — FILE COPY / MOVE (all four PS2 repos)

Full evidence: `round2-sections/04-filecopy.md`.

### Buffer sizes — every implementation, cited (the mandatory row)

| Implementation | Buffer | Location |
|---|---|---|
| RiptOPL filemgr | **65,536 B** — one heap buffer shared by the whole tree | `FM_BUF (64*1024)`, src/core/filemgr.cpp:46,440 |
| RiptOPL vcd staging | **16,384 B** — smallest in the topic | `VCD_COPY_CHUNK (16*1024)`, src/sources/vcdsupport.cpp:1081 |
| RiptOPL vmcsaves (adjacent, PSU pack) | 65,536 B chunks, but **whole files staged in RAM** | src/core/vmcsaves.cpp:150,163,478,829 |
| Launchstation copy() | **131,072 / 262,144 / 393,216 / 524,288 / 1,048,576 B by device pair**; default 1 MB; **×2 buffers at 1 MB**; fileXio IOP buffer widened 16 KB → 131,072 B for the paste | src/filer_copy.c:32,90-117,1427-1429; src/init.c:1282-1297 |
| POPSLoader C rename | **`BUFSIZ`, on the stack** (value not defined anywhere in the repo; INFERRED newlib 1024 B) | src/luasystem.cpp:828,839 |
| POPSLoader Lua | **32,768 B** chunks — the same literal in 4 sibling functions | bin/POPSLDR/system.lua:5359,5273,5439,5484 |
| SMS CopyTree/CopyFile | **393,216 B** (`4096*96`); two alloc *sites*, mutually exclusive per copy — **plus 2 × 393,216 B source stream buffers**, ≈**1.125 MB live per copy** | src/SMS_CopyTree.c:31,211,314; src/SMS_FileContext.c:603-625,1875 |

Copy-buffer sizes span **64×** (16 KiB → 1 MiB, 2 MiB double-buffered) across the family. Only Launchstation documents a per-device rationale (filer_copy.c:85-89). SMS's 384 KiB has no stated rationale anywhere, and its stream-buffer multiplication is invisible from the copy file itself. No throughput measurement exists in any repo to justify any of these numbers (no hardware was run in this audit; none is claimed).

### Behaviour comparison (condensed; full table in section §5)

| Dimension | RiptOPL filemgr | RiptOPL vcd | Launchstation | POPS C rename | POPS Lua | SMS |
|---|---|---|---|---|---|---|
| Partial-write handling | retry loop | retry loop | fail (size pre-measured) | fail | fail (exact count demanded) | fail via post-hoc fioSync |
| Partial file on error | **deleted** (+ partial tree) | **deleted** | file **deleted**; **folder tree left** | **left** (dest already truncated) | **deleted** (.tmp pattern) | **left, all paths** |
| Post-copy verify | **dest size re-read** | none (close checked) | none except udpfs: size re-read | none (close unchecked) | counted bytes vs expected; no re-read | per-chunk count only |
| Close checked | **no** | **yes** | yes (but FC-BUG-1) | **no** | result ignored | result ignored |
| Same-device move | **rename** | n/a | full copy + manifest re-stat, then delete | copy+delete (it *is* the rename) | promotion = C rename | no move exists |
| Depth cap | 16 | flat | 16, **~900 KB listing held per level** (filer_copy.c:744-745) | flat | flat | **none found**; tree pre-scanned into RAM |
| Progress / cancel | per-chunk %, throttled; **no cancel** | none | **best**: worker-thread chunks, speed/ETA, pad cancel, UI animates | none | none — UI freezes (INFERRED) | GUI_Progress + pad cancel |
| Timestamps | none | none | **full MC/VMC/ChStat matrix** | none | none | none |
| Overwrite policy | **never** (O_EXCL) | overwrite | delete-then-create | truncates dest | tmp + .bak promotion | overwrite |

### Volume

Six independent read/write loops across four repos. Narrow count (loop functions only): **≈779 lines**. Full copy subsystems (loops + recursion + move/delete glue + buffer policy + verify): **≈1,796 lines** — RiptOPL 203, Launchstation 1,180 (one function, `copy()`, is 967 lines carrying four modes), SMS 246, POPSLoader 167.

### Verdict — Topic 4

**No cross-repo copy library** — four different I/O stacks (POSIX+fileXio / gen*+fileXio+mcserv / Lua-over-POSIX / fio*+FileContext) and three different destination universes. The transferable asset is a **checklist**, and the diff shows each repo holding a different subset of it: delete-the-partial (RiptOPL, POPS-Lua — missing in SMS, half-missing in Launchstation folders and POPS-C), size re-read (RiptOPL filemgr; Launchstation udpfs-only), close check (Launchstation, RiptOPL-vcd), source-unchanged-before-delete (Launchstation only), timestamps (Launchstation only), free-space gate (SMS tree; RiptOPL partial). Intra-repo wins only: Launchstation's folder/file attribute ladder is written twice inside `copy()` (~60-80 lines deletable, X-22 list); POPSLoader's Lua chunk loop is written three times (~50 lines); RiptOPL's two loops should stay separate but each should gain the other's check (FC-BUG-5). SMS needs correctness fixes, not consolidation (X-21). RiptOPL's filemgr states the rule the others keep re-learning, in one comment: *a cut-short copy is never left looking whole.*

---

## Topic 5 — MD5/SHA, CRC, base64, JSON (all five repos)

Full evidence: `round2-sections/05-crypto.md`. Classification: FP = first-party hand-rolled; VEND-IN = vendored code in a first-party path; VEND = vendored library; STD = stdlib.

### Who rolls their own — the table

| Algorithm | RiptOPL | Launchstation | POPSLoader | SMS | PS2-Servers |
|---|---|---|---|---|---|
| MD5 | FP unified in smb2auth.c (IOP) + VEND-IN Deutsch 382 L (EE, RA builds only) + VEND usmb2 190 L (IOP) | FP smb2auth.c (**byte-identical to RiptOPL**) + VEND usmb2 (**byte-identical**) | **none** | none | STD hashlib + VEND Deutsch in rcheevos (**1-line diff from RiptOPL's EE copy**) |
| MD4 | Families A (smbman, 182 L) + B (usmb2 md4c) + C (smb2auth) + **diverged second copy of A** (smbinit, 175 L) | A + B + C | none | A (**byte-identical, third copy**) | FP Python md4() (smb2_auth.py:75-128) — justified: OpenSSL 3 removed MD4 |
| SHA-256 | FP in smb2auth.c (IOP); EE = mbedTLS library only | **FP twice**: mc_sha256.c:20-94 (EE, 94 L) + smb2auth.c (IOP, identical to RiptOPL) — **plus mbedTLS in the same EE binary** | none | none | STD hashlib / Go crypto only |
| SHA-1 | none FP (mbedTLS sha1.c on disk, **switch off** in both configs) | none FP | none | none | STD hashlib only |
| CRC32-family | **FP ×2 in one EE binary** (USBA system.cpp:465-492 + Ogg-delta bgm.cpp:359-376, same poly); USBA text **×3 in the repo** (EE + iso2opl + opl2iso tools); FatFs bit-CRC in BDM IOP | FP nibble zipCrc (mc_save_export.c:373-387 — deliberate size trade, 64 B table) | none | **3 vendored codec CRCs** (xz CRC32, Ogg CRC32, FLAC CRC-8 — different checks, codec-mandated) | none hand-rolled (zlib.crc32 STD ×1) |
| CRC16/CRC7 | MX4SIO crc16.c 27 L + CRC-7 | **byte-identical to RiptOPL** | none | — | none |
| base64 | **none FP in any repo** (suspects RA/selfupdate checked, disproven). Only mbedTLS base64.c on disk, switch off; STD on host side | none FP | none | none | STD only (Python + Go) |
| JSON | **Real bounded tokenizer**, FP: achievements.cpp:151-309 (~159 L core; UTF-8/escape-aware) | **Two FP extractors in one binary**: cloud_google.c:61-122 (escape-aware) + dash_tools.c:715-746 (weaker, no escapes) | **none** (Lua-JSON suspect disproven) | none | STD json everywhere FP; VEND jsmn.h 471 L + rcheevos in the RA vendor tree |
| AES/CMAC etc. | mbedTLS (library) | mbedTLS (external) | none | none | FP AES-128 + RC4 + KDF + **CMAC ×4 behind one dispatcher** (smb2_crypto.py:124-340, 431 L file) — re-verified at this head |

**Byte-identity proofs (md5sum/diff, READ):** smb2auth.c identical RiptOPL↔Launchstation (307 L / 9,549 B; Launchstation's own iop/smb2man/README.md:11,15 says "RiptOPL's … unchanged, byte for byte"); SMB1 md4.c/des.c identical in **three** repos; MX4SIO crc16.c identical ×2; usmb2 md5.c/md4c.c identical ×2; Deutsch MD5 differs by exactly 1 line between RiptOPL's EE tree and PS2-Servers' rcheevos vendor.

**Explicit non-findings (checked, do not re-flag):** no hand-rolled SHA-1 anywhere; no FP base64 anywhere in five repos; no zlib/libpng crc32.c in any repo; no hand-rolled XML parser anywhere; RiptOPL's mbedTLS md5.c/sha1.c/base64.c/cmac.c are **on disk only** — their `_C` switches are off in both configs, so they cost repo size, not binary size (this refines, and partly defuses, a naive reading of RIPTOPL-006); PS2-Servers and POPSLoader host code is stdlib-only for hashing.

### Verdict — Topic 5

The cross-repo state is already "one text" for every byte-identical family — the correct action is a **sync rule** (one canonical home, never fork), not consolidation work. The genuine doubles are all *inside* one binary: smb2man's 2×MD4 + 2×MD5 (X-19), Launchstation EE's library+FP SHA-256 (conditional, X-20), Launchstation's two JSON extractors (~32 L pure deletion), RiptOPL's USBA_crc32 text ×3 (repo-level). PS2-Servers' CMAC stack: keep pure-Python + one native path per shipped platform; the OpenSSL-1.1 path is the deletion candidate (X-23).

---

## NEW cross findings (X-17…, summary format)

### X-17 / Launchstation still carries the file-based update design #384 replaced, as test-only dead code
- **Category:** 1 (dead code) / 8
- **Location(s):** Launchstation/src/update_psu.c:183-211 (`selfUpdateExtractPsu`, `selfUpdateExtractPsuMem`), Launchstation/src/update_psu.c:335-353 (`selfUpdateExtractPsuSidecar`), the `PsuIn` file branch they keep alive at Launchstation/src/update_psu.c:23-68, and Launchstation/src/cloud_http.c:1279-1287 (`cloudHttpDownloadFd`, self-described "Historical self-update interface")
- **Problem:** At head `9fb0598a79f0` these entry points have no production caller (repo-wide grep, READ) — only host tests call them, and one test asserts the dead function's *presence* (tests/test_self_update.py:13-14). Meanwhile the live design is RAM-only by declaration (src/self_update.c:184-185), so the tree simultaneously documents two contradictory update architectures. This is also the loose end of LAUNCHSTATION-017 (pass 1): its suggested fix pointed at this code as a live alternative; it is not live.
- **Fix:** Delete the three file-based PSU wrappers, the `PsuIn` fd branch, and `cloudHttpDownloadFd` with its presence-asserting test lines. Keep the RAM entry points and the extract cores they use. (If a low-RAM fallback is ever wanted, that is a new decision — keeping dead code is not a fallback.)
- **Benefit:** ~90-100 lines removed (est. from READ line ranges); one update architecture left to reason about.
- **Effort:** S. **Risk:** Low (no production caller, grep-verified). **Confidence:** High (READ).

### X-18 / Launchstation writes a `title.cfg` dialect RiptOPL silently cannot read — app never appears (WORST new bug)
- **Category:** 6 (bug) / 2 (cross-repo format duplication)
- **Location(s):** Writer: Launchstation/src/dash_apps.c:178-187 (`"title = %s\r\n"`, `"boot = %s\r\n"` — spaces, no `;`). Reader chain: RiptOPL/src/core/config.cpp:155-163 (classifier: spaced line is libconfig **only if** it also ends in `;` — otherwise the file latches LEGACY, :1140-1148), RiptOPL/src/core/config.cpp:180-193 (legacy `splitAssignment` copies the key verbatim — key becomes `"title "` with trailing space; parent-verified at this head, including RiptOPL's own comment at config.cpp:~150 admitting `"title = Foo" -> stays LEGACY`), RiptOPL/src/core/config.cpp:257-264 (`ConfigSet::find` is exact-match, so `"title "` ≠ `"title"`), RiptOPL/src/sources/appsupport.cpp:735 + include/appsupport.h:15-16,19 (app requires **both** `title` and `boot`)
- **Problem:** A user who creates an app entry in Launchstation's UI gets a starter title.cfg that RiptOPL's app scan silently skips — no error in either program, the app simply never appears in RiptOPL. One-directional (Launchstation's own readers trim both sides and are unaffected; POPSLoader's shipped title.cfg uses the unspaced form and parses everywhere). Corollary (INFERRED): if RiptOPL later re-saves that folder's config it appends a correct unspaced line while keeping the spaced originals, leaving both dialects in one file.
- **Fix:** Launchstation's starter template emits the unspaced `key=value` form — the only dialect all three readers accept. One template, two lines (dash_apps.c:180-181 region). No parser change, no new code. (Hardening RiptOPL's legacy splitter to trim the key is the alternative; it touches the parser every legacy file depends on, so it is the *bigger* change.)
- **Benefit:** a silent cross-program data-loss-of-visibility bug closed; the family's one shared format gets one canonical written form.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ — every link in the chain line-cited and parent spot-verified).

### X-19 / One IOP module links two MD4s and two MD5s (RiptOPL and Launchstation, same module both times)
- **Category:** 2 (duplication) / 4 (size — IOP RAM is the scarcest in the system)
- **Location(s):** RiptOPL/modules/network/smb2man/usmb2/md4c.c (240 L), md5.c (190 L), hmac-md5.c (99 L) **and** RiptOPL/modules/iopcore/cdvdman/smb2auth.c:31-121 (FP MD4+MD5 blocks, used for signing at modules/network/smb2man/smb2man.c:49,156-205); Launchstation/iop/smb2man/usmb2/{md4c,md5,hmac-md5} **and** Launchstation/iop/smb2man/smb2auth.c:31-121 — both repos, byte-identical files on both sides of the double
- **Problem:** The menu-side smb2man IOP module compiles usmb2's RSA-family MD4/MD5 (used by usmb2/ntlm.c) and the first-party smb2auth MD4/MD5 (used for signing) — 2× MD4 and 2× MD5 inside one ~2 MB-IOP-RAM binary, in both repos identically. (Files and both call-site sets READ; final link INFERRED — smb2man has no in-tree Makefile, its IOP build is external to that directory.)
- **Fix:** Route one consumer through the other implementation and delete the unused files: drop usmb2's md5.c/md4c.c/hmac-md5.c and call smb2auth from ntlm.c, or vice-versa — never both. Do it once, in the canonical copy, and sync (the files are byte-identical across repos today; a one-repo fix creates the fork).
- **Benefit:** 529 lines of vendored crypto deleted per repo (READ sizes), one MD4 and one MD5 left in the module.
- **Effort:** M. **Risk:** Med (NTLM/signing paths must be exercised — SMB2 auth against a real server; not verifiable in this VM). **Confidence:** High for the duplication (READ); Med for link membership (INFERRED, stated).

### X-20 / Launchstation EE links mbedTLS SHA-256 and a hand-rolled SHA-256 in the same binary
- **Category:** 2 / 4
- **Location(s):** Launchstation/src/mc_sha256.c:20-94 (FP, 94 L) + include/mc_sha256.h:13-22, called from src/mc_card_view.c:412-489, src/mc_save_export.c:81-88, src/mmce_save_versions.c:82-87,141-156,303-332; mbedTLS SHA-256 called from src/cloud_http.c:25,142,842-1267 and src/cloud_google.c:18,1230-1262 — and **src/mc_save_export.c uses both** (:11-12,53-78 mbedTLS; :81-88 FP)
- **Problem:** Two SHA-256 implementations in one EE program. NOT a pure deletion candidate: mc_sha256.c's header documents a real reason — it is "linked in builds without the cloud TLS stack and runs on the host in tests."
- **Fix:** Conditional: if/when the non-cloud build variant is dropped, delete mc_sha256.c (118 lines total) and route its three callers to mbedTLS. Until then, keep it and add no third caller class. Do not delete today on this evidence alone.
- **Benefit:** 118 lines + one implementation, *when* the variant goes.
- **Effort:** S (when applicable). **Risk:** Med (build-variant dependent). **Confidence:** High (READ).

### X-21 / File-copy failure handling: SMS leaves truncated copies indistinguishable from complete ones, in every path
- **Category:** 6 (bug) / 5
- **Location(s):** Simple-Media-System/src/SMS_CopyTree.c:298-387 (no fioRemove anywhere in the function, READ); read-error ≡ EOF at :338-340; cancel code 2 matches no message branch in SMS_CopyTree at :219-238 (silent); write errors reported as "not enough space" via the `==3` branch; single-file caller ignores the return at src/SMS_GUIFileCtxMenu.c:102. Counter-model in the same audit: RiptOPL/src/core/filemgr.cpp:359-370 (delete partial + size re-read)
- **Problem:** A mid-stream device error returns *success* with a short file; a cancelled tree copy shows no message; a failed copy stays on the HDD looking whole. Four small defects, one root: the destination is never treated as untrusted until proven complete. POPSLoader's C rename has the same disease in miniature (truncates dest on open, leaves partials, unchecked close, then deletes the source — src/luasystem.cpp:826-877; its own Lua layer documents the failure mode and builds a .bak dance around it at system.lua:5229-5259), and Launchstation has it in exactly two places (close-failure path filer_copy.c:1628-1717 never removes `out`; folder failure :1193-1196 leaves the partial tree).
- **Fix:** Per repo, the smallest local change, no shared code: SMS — delete destination on any non-success exit, distinguish read-error from EOF, surface the result at the single-file caller. POPSLoader C — unlink-on-failure + checked close + size compare (~10 lines, modelled on RiptOPL/src/sources/vcdsupport.cpp:1171-1176), after which part of the Lua scaffolding is redundant. Launchstation — one genRemove on the close-failure exit; folder rollback needs created-file tracking (its file branch deliberately replaces existing files, so RiptOPL's blind tree-delete does not transfer).
- **Benefit:** the "truncated file looks complete" failure class closed in three repos.
- **Effort:** S per repo. **Risk:** Low-Med. **Confidence:** High (READ).

### X-22 / Intra-binary duplicate machinery found at function level (three small pure deletions)
- **Category:** 2
- **Location(s):** (a) Launchstation JSON extractor ×2 in one EE binary: src/cloud_google.c:61-122 (escape-aware `json_string`) vs src/dash_tools.c:715-746 (`releaseJsonString`, no escape handling) — fold the second onto the first, **delete ~32 lines**. (b) Launchstation copy() attribute ladder written twice: src/filer_copy.c:1225-1275 (folder) ≈ :1639-1690 (file), same device ladder and skip lists — one helper, **delete ~60-80 lines (INFERRED est.)**. (c) POPSLoader Lua 32,768-byte chunk loop written three times: bin/POPSLDR/system.lua:5261-5509 (`WriteAtomic`/`WriteBytesDirectBounded`/`WriteBytesAtomicBounded`) — one parameterised writer, **delete ~50 lines (INFERRED est.)**
- **Problem:** Each pair/triple is same-binary, same-author-surface duplication that drifts independently — (a) already has: one copy handles escapes, the other doesn't.
- **Fix:** Delete the weaker copy in each case; keep the stronger as the only one. No new abstraction beyond the surviving function.
- **Benefit:** ~140-160 lines total (est.), three drift surfaces removed.
- **Effort:** S each. **Risk:** Low. **Confidence:** High for existence (READ); Med for line estimates (INFERRED).

### X-23 / PS2-Servers CMAC: four implementations behind one dispatcher, re-verified at Round-2 head
- **Category:** 3 (overengineering — fallback stack)
- **Location(s):** PS2-Servers/smb2_server/smb2_crypto.py:124-129 (dispatcher `aes_cmac`) → pure-Python :132-161, bcrypt/CNG :192-234, OpenSSL 3 EVP_MAC :260-305, OpenSSL 1 `CMAC_*` :306-340 — inside a 431-line file that also hand-rolls AES-128 (:73-114), RC4 (:361-385) and SP800-108 KDF (:341-357). (Pass 1's PS2SERVERS-014 count of four CMACs re-verified READ at `c5f021c4d386`.)
- **Problem:** Four backends for one 16-byte MAC, selected by availability — the fallback-stack pattern the brief bans unless justified. The first three each have a plausible platform story (pure fallback, Windows, modern OpenSSL); the OpenSSL-1.1 path serves a library generation that is EOL.
- **Fix:** Delete the OpenSSL-1 path (34 lines) on any OpenSSL-3-only target; keep pure + one native per platform actually shipped. No new code.
- **Benefit:** 34 lines + one test surface.
- **Effort:** S. **Risk:** Low (INFERRED applicability — depends on shipped targets). **Confidence:** High for the count (READ); Med for the deletion's applicability.

### X-24 / Network-init constants have speciated — including inside one repo
- **Category:** 3 / 5
- **Location(s):** DEV9 power-off retries for the identical devctl: RiptOPL/src/platform/system.cpp:264-285 = **100**; Launchstation/src/init.c:2585-2612 = **100** but Launchstation/src/init.c:577-592 = **20** (pre-reset); Simple-Media-System/src/SMS_IOP.c:1197 = **1**. Link wait: RiptOPL/src/sources/netsupport.cpp:82,88 = 30 s; absent in the other two. SMS dead declaration: Simple-Media-System/include/SMS.h:308 (`SMS_StartNetwork`, defined nowhere)
- **Problem:** The 100/20 split inside Launchstation is the finding: its own power-off path documents 100 as the considered policy (init.c:2598-2604 even cites RiptOPL), so the pre-reset 20 is an outlier with no stated reason. Cross-repo values (100 vs 1) are NOT flagged as wrong — they are the proof (Topic 2 verdict) that these sequences were never shared and must not be "unified" blind.
- **Fix:** Intra-repo only: align Launchstation's pre-reset budget to 100 (or document why 20); delete SMS's dead declaration. Nothing cross-repo.
- **Benefit:** one unexplained 5× inconsistency removed; one dead declaration removed.
- **Effort:** S. **Risk:** Low for the declaration; Med for the constant (hardware behaviour — the change is *toward* the repo's own documented policy). **Confidence:** High (READ).

### X-25 / Config-parser consolidation that actually pays: Launchstation 4 → 2, POPSLoader ~27 sites → 1 helper
- **Category:** 2 / 3
- **Location(s):** Launchstation/src/config.c:111-160 (`get_CNF_string`) vs Launchstation/src/dash_store.c:65-103 (`dashKvParse`) vs Launchstation/src/smb_cnf.c:345-438 (`smbConfigParse`); identical trim at dash_store.c:53-63 ≡ smb_cnf.c:60-70 (diff = 1 line, the signature). POPSLoader/bin/POPSLDR/system.lua:5877-5889,6408-6460 (~27 hand-unrolled extraction sites)
- **Problem:** Launchstation maintains three line parsers for files in the same directory, with opposite malformed-line policies — and the *main* config uses the aborting one (X-26). POPSLoader unrolls the same two-pattern match ~27 times because the helper was never written.
- **Fix:** As Topic 3 verdict: dashKvParse becomes the only line parser, smbConfigParse stays as its validator layer, get_CNF_string retired, one trim deleted. POPSLoader gains one `matchKey` helper — justified under the brief's rule: same logic at 27 sites, sharing removes code overall (~25 call-site blocks collapse).
- **Benefit:** one parser + one trim function deleted in Launchstation; ~25 extraction blocks collapse in POPSLoader.
- **Effort:** M (Launchstation — loadConfig is on the boot path), S (POPSLoader). **Risk:** Med (Launchstation boot path; the lenient parser already runs in production for sibling files), Low (POPSLoader). **Confidence:** High (READ, diff-verified).

### X-26 / One malformed line silently amputates Launchstation's main CNF — and the next save makes it permanent
- **Category:** 6 (bug)
- **Location(s):** Launchstation/src/config.c:139-140 (`if (*tp != '=') return false;`), callers looping on its return at src/config.c:950 (loadConfig, LAUNCHELF.CNF) and src/main_startup.c:180 (readSystemCnf, SYSTEM.CNF); writer src/config.c:533-718 (enumerates in-memory state). Aggravating grammar detail: a name is `*tp >= 'A'` or digit (config.c:131-132), so a dotted or dashed key ends the name early and hits the same abort; and any line whose first char is < 'A' — including a digit-led line — is treated as a comment (:124-129)
- **Problem:** A hand-edited CNF with a dotted key, a space inside a key, or one stray word line loses **every setting below that line, silently, on every boot** — and the next save rewrites the file from the truncated in-memory state, making the loss permanent (last clause INFERRED from the READ writer). The same repo's dashboard parser was written specifically to not do this (include/dash_internal.h:657-660) and the main config doesn't use it.
- **Fix:** The one-branch change from X-25: missing-`=` skips the line and continues (or route loadConfig through dashKvParse). No new machinery — the correct behaviour already exists in the same binary.
- **Benefit:** a silent, self-perpetuating settings-loss bug closed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

### X-27 / POPSLoader config semantics invert the family on both axes (first-wins + save-deletes-unknowns)
- **Category:** 6 / 3
- **Location(s):** First-wins: bin/POPSLDR/system.lua:5877-5889,6408-6460 (`string.match` returns the first match). Save-deletes-unknowns: writer bin/POPSLDR/system.lua:5891-5941 (`EncodeSettings` rewrites only known keys, full-file). Family contrast: last-wins in RiptOPL config.cpp:363-387, Launchstation config.c/dash_store.c/smb_cnf.c; unknowns preserved on save only in RiptOPL (config.cpp:1590-1598)
- **Problem:** In a hand-merged `.pldrs`, the *stale* duplicate of a key governs (every C parser in the family would take the corrected later one), and the first save after such a load permanently deletes the correction and every unknown/hand-added key — silently, in the opposite direction from RiptOPL on both axes.
- **Fix:** Document the semantics at the loader, at minimum; the real fix is last-match extraction (match from the end, or iterate matches and keep the last) — a local change inside the X-25 helper, a few lines. Preserving unknown keys requires the writer to carry unparsed lines — that is *more* machinery; only adopt it if hand-edited .pldrs files are a real use case (INFERRED judgement).
- **Benefit:** hand-edited configs behave the same way in POPSLoader as everywhere else in the family.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; the save-deletes-correction consequence is INFERRED from first-match + full-rewrite, both READ).

### X-28 / RiptOPL carries the same CRC-32 text three times, and two CRC-32-family functions in one EE binary
- **Category:** 2
- **Location(s):** src/platform/system.cpp:465-492 (`USBA_crc32`, poly 0x04C11DB7 non-reflected) copied at tools/pc/iso2opl/src/iso2opl.c:48-70 and tools/pc/opl2iso/src/opl2iso.c:43-65; second family member in the same EE binary at src/core/bgm.cpp:359-376 (`oggCrcDelta`, same polynomial, delta-only contract)
- **Problem:** Three texts of one function (EE + two PC tools) drift independently; the EE pair share a polynomial but not a table/init contract, so they cannot be merged into one function — only the table could be shared.
- **Fix:** One shared source for USBA_crc32 across EE + both tools (delete 2 copies, ~46 lines). Leave bgm's delta variant alone — different contract, merging it would be the abstraction the brief bans.
- **Benefit:** ~46 lines, two drift surfaces.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

### X-29 / SMS's positional SMB list has no resync — one blank line shifts every record
- **Category:** 6
- **Location(s):** Simple-Media-System/src/SMS_Config.c:314-379 (six unconditional File_GetString calls per record, :333-348; 6-vs-8 decided by one EOF check) + src/SMS_FileContext.c:2176-2211 (over-long field: silent truncate **and drain**, :2201-2204, so the truncated value is what gets written back)
- **Problem:** The format has no keys, no comments, no blank-line skipping: one extra line desynchronises every following record, and there is nothing in the data to recover framing from. Mitigated only by SMS normally being the file's sole writer.
- **Fix:** None proposed under LESS-NOT-MORE: any fix (keys, markers, checksums) is a format change with a migration cost larger than the defect, for a file with one writer. Recorded so the limitation is a decision, not a surprise. **Delete nothing; add nothing.**
- **Benefit:** n/a (honesty finding). **Effort:** —. **Risk:** —. **Confidence:** High (READ).

### X-30 / Self-update trust/policy divergences that should be decisions, not accidents
- **Category:** 6 / 3
- **Location(s):** Redirect allowlist: present in RiptOPL/src/platform/selfupdate.c:105-126 (3 GitHub hosts, ~20 lines), absent on Launchstation's updater path (src/cloud_http.c:1000-1006 — host check only for bearer-token media; :1083-1110 accepts any https:// Location). Free-space pre-check: present in Launchstation/src/self_update.c:343-350 (8 lines), absent in RiptOPL, whose file carries a comment describing the check as if it existed (src/ui/selfupdate.cpp:250-251). Version-proof: integer revision (RiptOPL) vs commit-ancestry with diverged-refusal (Launchstation/src/dash_tools.c:814-887)
- **Problem:** Two sibling updaters, ported from each other in the same period, disagree on three safety properties — and in each case one side has the stronger property at trivial cost while the other side's code/comments imply it thinks it has it too (RiptOPL's orphan comment is the clearest case).
- **Fix:** Decide once, apply to both shapes: adopt the allowlist in Launchstation's updater path (copy the ~20-line check), adopt the free-space check in RiptOPL (copy Launchstation's 8 lines) **or** delete RiptOPL's orphan comment — but not neither. Ancestry-vs-revision is a genuine product difference (Launchstation's `latest` is a moving tag; RiptOPL's editions are pinned channels) — keep both, documented as deliberate.
- **Benefit:** the two updaters' safety stories match their documentation.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

---

## Per-topic verdicts, one line each

1. **Self-update:** Same flow, hand-ported, 603 vs 1,151 lines — the 2× is Launchstation updating *more things* (package, sidecars, timestamp, ancestry), not worse; share the **shape**, never a library; delete Launchstation's dead file-based machinery (X-17). LAUNCHSTATION-017: **still true, reframed** (RAM-only is now the only, documented path).
2. **Network init:** **Keep separate** — load order is stack-family-determined, RiptOPL alone has post-load policy, DEV9 ownership is incompatible, and the constants (100 vs 20/100 vs 1) have speciated; a shared lib would be all five sequences plus glue.
3. **Config parsing:** 10 parsers, not 4; consolidate **inside** Launchstation (4→2) and POPSLoader's extraction idiom (X-25), fix the one shared format (`title.cfg`, X-18), keep everything else separate — SMS's config isn't even text.
4. **File copy:** ~1,796 subsystem lines across 6 loops is **not** itself the waste (four I/O stacks genuinely differ); the waste is the incompletely-shared failure checklist — SMS/POPS-C/Launchstation each miss a delete-the-partial or verify step that a sibling states in one line (X-21).
5. **Crypto/parsing:** Cross-repo state is already one-text for every shared algorithm (byte-identical, md5-verified) — impose a **sync rule**, not consolidation; the real doubles are intra-binary (smb2man 2×MD4/2×MD5, X-19; Launchstation SHA-256, X-20; its JSON extractor, X-22); base64 and SHA-1 are non-findings — nobody hand-rolls them.

## What could not be compared, and why

- **Launchstation's precompiled PS2IP IRX internals** (any DHCP/link behaviour inside the blobs): binary, no in-tree source — EE-level absence is READ; blob behaviour is not claimed.
- **Final link membership of the smb2man IOP module** (X-19): files + both call-site sets are READ, but smb2man has no in-tree Makefile (IOP build external to the directory) — link is INFERRED and labelled as such in the finding.
- **POPSLoader's `BUFSIZ` numeric value:** not defined anywhere in the repo (PS2SDK/newlib header); INFERRED 1024, labelled wherever used.
- **Throughput justification for any copy-buffer or retry constant:** no PS2 build or hardware run exists in this environment; every size/constant claim is as-written in source, and no claim in this file asserts a number is *wrong* on hardware — only that it is undocumented, inconsistent, or duplicated.
- **PS2-Servers GUI/startup paths at function level for Topics 1-4:** out of the assigned scope (it is the server side; Topics 1-4 are console-program comparisons). It is fully covered in Topic 5, where it belongs (stdlib hashing, FP MD4/CMAC/AES in the SMB2 server).

## Files in this round's deliverable

- Sable-CROSSREPO-ROUND2.md (this file) — synthesis, tables, verdicts, X-17…X-30
- round2-sections/01-selfupdate.md — Topic 1 full evidence (159 lines)
- round2-sections/02-netinit.md — Topic 2 full evidence (104 lines)
- round2-sections/03-config.md — Topic 3 full evidence (209 lines)
- round2-sections/04-filecopy.md — Topic 4 full evidence (183 lines)
- round2-sections/05-crypto.md — Topic 5 full evidence (138 lines)
- PINS-ROUND2.md — round-2 pins and delta duties
