# FULL-VERIFICATION — Cross-repo findings X-32 … X-48 (worker: verify2-cross-C)

- **Date:** 2026-11-14 · **Stance:** adversarial — each finding had to survive a refutation attempt.
- **Clones (read-only), HEADs verified before work:** RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`, SMS `e65ced39a27e`, PS2-Servers `c5f021c4d386` — all five matched the stated pins, working trees clean.
- **Verdict tally:** VERIFIED 14 · VERIFIED-DRIFT 2 (X-37, X-46) · WEAKENED 1 (X-45) · REFUTED 0.

---

## X-32 — Two C UDPRDMA/UDPFS forks, disjoint hardening (D2–D4)
**Verdict: VERIFIED**
- D2: SMS `udpfs_core.c` zero-initialises the result struct (`= {0}` with explanatory comment) and clamps `if (result.result > ret) return ret;`; RiptOPL's `_recv_with_result` returns `result.result` unclamped. Both read in full.
- D3: RiptOPL `udprdma.c` has the duplicate-packet branch (`(rx_seq_nr_expected - seq) & 0xFFF) < 2048` → cumulative ACK `EF_RX_WINDOW`, with resend-storm comment); SMS's corresponding branch is NACK-only (`rx_nack_sent` → `EF_RX_NACK`). D4: RiptOPL BREAD treats `ret <= 0` as failure and `memset`-zero-fills a short tail; SMS fails only on `ret < 0`, counts EOF-0 as a full chunk and leaves the tail stale. File sizes confirm the fork pair (core 791 vs 825 lines; udprdma 738 vs 804).

## X-33 — Three server editions, three limit sets; Python honours none of the header's
**Verdict: VERIFIED**
- C contract read at `udpfs_packet.h:56-60`: path 256, `UDPFS_MAX_READ` 64 KiB, `UDPFS_MAX_SECTOR_READ` 128. Python: `_handle_open:1789` / `_handle_getstat:2294` decode path by split-on-NUL with no length check anywhere (`grep "len(path"` = no caps); transfer cap executed in Python — module imported from the clone: `DEFAULT_MAX_TRANSFER_BYTES = 8388608` (8 MiB), `_clamp_max_transfer(1) = 262144` (256 KiB floor), and byte-cap-only sector arithmetic `8388608 // 512 = 16384` sectors, matching the claim. Go: `maxPathBytes = 1024` (`server.go:24`), `transferDivisor = 16`, `minTransferCap = 256<<10` (`budget.go:46,51`). Errno split confirmed: Python answers EINVAL for over-cap READ/WRITE/BREAD/BWRITE; Go answers EINVAL for READ (`operations.go:508`) but EFBIG for WRITE/BWRITE (`operations.go:569,627`; `blockdev.go:247,282`).

## X-34 — Identical packets, different outcomes per server language
**Verdict: VERIFIED**
- All five points re-read on both sides. Handle 0: Python seeds `handles[BLOCK_DEVICE_HANDLE=0] = server.bd_fh` (`:3213`) and READ/LSEEK/WRITE go through that shared `fh.obj` position; Go handle-0 has no Reader outside BREAD/BWRITE → EBADF (`operations.go` handle lookup). Range: Go `inRange` (`blockdev.go:87`, enforced `:193,250`); Python BREAD has no range check and BWRITE reaches `os.pwrite`/seek+write past EOF, extending the image (`_complete_bwrite` writes `data[:expected_size]`, then `_send_write_done(addr, 0)` — truncation + WRITE_DONE 0 exactly as claimed; Go `completeBlockWrite` requires `len(buf) == expected` else EINVAL, WRITE_DONE = count). Short WRITE_REQ/BWRITE_REQ: Python `_send_ack` only (`:2037` region, `:2555`); Go answers EINVAL (`operations.go:552`). Disorder: Python drops the chunk and keeps the buffer armed; Go `ResetWrite()` + WRITE_DONE EIO (`operations.go` chunk-order branch). Scope note: Go's own comment concedes *file-handle* BWRITE may extend a file — the finding is scoped to the block image, where it holds.

## X-35 — SMS config save never change-gated, fires as a side effect
**Verdict: VERIFIED**
- `SMS_SaveConfig` (`SMS_Config.c:878-1101`) scanned in full: no dirty flag, no memcmp/equality gate. Callers confirmed by grep: unconditional `SMS_IOP.c:1786` ("Persist BEFORE anything is torn down" before every network switch), gate-position calls at `SMS_GUIFileCtxMenu.c:212,235,309,334` before copy-to-MC, plus the explicit menu save at `SMS_GUIMenuSMS.c:1007`. Both halves of the finding hold.

## X-36 — SMS carries two unbuilt UDPFS front-ends, 267 lines
**Verdict: VERIFIED**
- `udpfs_bd.c` = 132 lines, `udpfs_fhi.c` = 135 lines (267 total, exact). `tools/build_udpfs.sh` builds only `make -C udpfs clean all UDPFS_IOMAN=1`; top-level `Makefile:53` embeds only `udpfs_ioman_irx.o`. Whole-repo grep over build files (`*.sh`, `Makefile*`, `*.yml`, `*.mk`, `*.py`, `*.bat`, `*.ps1`) finds bd/fhi references only in the variant arms of `iop/SMSUdpfs/udpfs/Makefile` itself — nothing ever selects them.

## X-37 — DiscHeader bytes 2–3: "reserved, must be 0" vs live port
**Verdict: VERIFIED-DRIFT**
- Core claim verified: C header (`udprdma_packet.h`) declares `reserved; /* Reserved (must be 0) */`; Python names the field `port` (`udpfs_server.py:493-505`) and standalone `_send_inform:2656` writes `self.dsock.getsockname()[1]` there. Executed: importing the clone's server module, `DiscHeader(service_id=0xF5F5, port=0xF5F6).pack()` = `f5f5f6f5` — bytes 2–3 carry the port, round-trip intact. Both C clients ignore the field and take `s->port = ntohs(disc_pkt->udp.port_src)` (RiptOPL `udprdma.c`, SMS `udprdma.c`, same lines read). Core Python sends `port=0` in both its INFORMs (`ps2servers_core.py` canonical + compatibility), as claimed.
- **Correction:** the finding's "Go canonical INFORM sends port 0" is wrong at the pin. Go's *standard* INFORM (`negotiation.go:195`, `sendStandardInform`) writes the **real data port** — `DiscoveryHeader{ServiceID: …, Port: uint16(data.Port)}` (`packet.go:87-95` puts it at bytes 2–3); only Go's *compatibility* INFORM (`negotiation.go:211`) writes 0. Go therefore joins Python standalone on the "field is a live port" side, which strengthens the finding's central claim while falsifying that one sub-detail.

## X-38 — Go Edge zeroes timestamps and attrs in UDPFS replies
**Verdict: VERIFIED**
- Go `sendOpen` (36-byte buffer), `sendDRead` (48 B) and `sendGetStat` (48 B) in `operations.go` allocate zeroed buffers and fill only result/mode/size (plus name length) — attr and all time fields stay zero; `session.DirEntry` even carries a `ModTime` that `sendDRead` never serialises. Python's `_send_open_reply:3045`, `_send_dread_reply:3109`, `_send_getstat_reply:3142` pack real `attr` + ctime/atime/mtime values. Layouts agree, content diverges, exactly as claimed.

## X-39 — POPSLoader triple-write atomicity for a disposable cache vs single write for its twin
**Verdict: VERIFIED**
- `PLDR.SaveGameListCache` (`system.lua:9880`) writes via `WriteAtomic` → `PromoteTmpToDest` (`:5234`): tmp write, `System.rename` dest→`.bak` (copy+delete per its own comment), rename tmp→dest, delete `.bak` — three content writes. `PLDR.HDD.CreateCache` (`:9944`) writes the same `PLDRGC1` format directly (`openFile(FCREATE)` + one `writeFile` + close, self-deleting on short write, `:9977-9987` region). The write-cost inversion is real.

## X-40 — Launchstation rewrites DASHAPPS.CNF on every launch; RiptOPL's equivalent writes nothing
**Verdict: VERIFIED**
- `dashStorePushRecent` (`dash_store.c:843-861`): `listFind` result is used only as the shift start; there is no `idx == 0` early return, and `dashStoreSaveLists()` is called unconditionally — relaunching the already-most-recent app rewrites the lists with identical content. RiptOPL contrast confirmed: `ConfigSet::setStr` (`config.cpp`) sets `modified_` only when the value actually differs, so an untouched per-launch save writes nothing.

## X-41 — ps2build machinery hand-copied in two repos, identical pins
**Verdict: VERIFIED**
- Byte-level re-diff, changed-line counts (`diff | grep -c '^[<>]'`) reproduce the finding **exactly**: installer `tools/ps2build_sdk.sh` vs `scripts/ps2build_sdk.sh` — 459 vs 459 lines, **4** changed lines, the only code difference the User-Agent at `:70-71`; watcher 452 vs 452 lines, **10** changed lines; watcher tests 596 vs 567 lines, **87** changed lines; bump workflow 279 vs 245 lines, **144** changed lines. Pin files: every shared value identical (`PS2BUILD_SDK_TAG=sdk-v2026.11.10-1a473e7c`, `SUMS_SHA256=02f4e5b8…`, identical component string, LLVM `v2026.11.05`); RiptOPL's file adds only its ogg/vorbis extras block, as claimed.

## X-42 — `actions/checkout` at six generations, three inside POPSLoader
**Verdict: VERIFIED**
- Full re-grep of all workflows reproduces every per-repo count exactly: RiptOPL SHA `d23441a4…` (# v6.1.0) ×20 + `@v6` ×5; PS2-Servers SHA `3d3c42e5…` (# v7.0.1) ×19 uniform; SMS `@v7` ×7 + that SHA ×1; POPSLoader `@v4` ×5 + `@v5` ×10 + `@v6` ×1; Launchstation `@v4` ×6 + SHA `11d5960a…` (# v4) ×1. Six version generations in play family-wide: v4, v5, v6, v6.1.0, v7, v7.0.1.

## X-43 — ps2dev image pinned three ways; POPSLoader's a mutable tag
**Verdict: VERIFIED**
- Re-grepped verbatim: SMS `ps2dev/ps2dev:v1.0@sha256:da02eb0870af…` (`compilation.yml:27,134,174`; `smbman.yml:31`); POPSLoader bare `ps2dev/ps2dev:v2.0.0` (`compilation.yml:68`, `experimental-release.yml:59`, `rolling-release.yml:63`); RiptOPL digest-only `ghcr.io/ps2dev/ps2dev@sha256:8fba50ecc222…` with no version in the reference (`flavours.yml:365`). Three postures, exactly as claimed.

## X-44 — Only RiptOPL CI enforces formatting
**Verdict: VERIFIED**
- `grep -rl clang-format` over all five repos' workflows returns exactly one file: RiptOPL `check-format.yml` (37 lines, DoozyX action @v0.18.2, clangFormatVersion 12, `**.c/.h` paths). Root `.clang-format` md5s reproduce the finding exactly: RiptOPL `403df320…`, Launchstation `9b913e25…`, SMS `2cc422f8…` — three different configs, two of them never run by any workflow. POPSLoader has neither config nor gate (file absent).

## X-45 — Release machinery ×3 (PS2-Servers prune / POPSLoader hard-coded 1.4.4 / SMS rolling race)
**Verdict: WEAKENED**
- **Survives, fully verified:** (1) PS2-Servers `release-on-main.yml` auto-tags `main-<run>-<sha7>` (two sites) and prunes dev releases to the newest `KEEP: '5'`, selecting by the exact-shape regex `^main-[0-9]+-[0-9a-f]{7}$` with a `v`-prefix refusal — hand-made tags cannot be selected. (2) POPSLoader `official-release.yml` hard-codes 1.4.4 in the workflow `name:` (line 1), the concurrency group `popsloader-1.4.4-release` (line 17) and the verify greps `POPSLDR_VER = "v1.4.4"` / `Version=1.4.4` (lines 47-49), plus a `RELEASE_1.4.4.md` existence test — ≥4 literal sites, as claimed.
- **Falls in part:** the SMS half. The in-tree comment exists at the cited place (`compilation.yml` ~:269) and two workflows do write the same `rolling` release — but at the pin the destructive race the finding calls "documented in-tree and unfixed" has already been mitigated in-tree: the comment itself is the record of the fix (delete/recreate replaced by create-if-missing + in-place clobber upload, "leaves other workflows' assets alone"), the player workflow owns release creation and the tag, both workflows carry per-asset-family concurrency groups (`sms-player-…-rolling`; `sms-converter-rolling-<os>`, `queue: max`), and the converter waits/retries for release creation instead of racing it. What remains is deliberate co-writing of disjoint assets on one release, not a timing-decided survivor. The finding's prescribed SMS fix ("give rolling a single writer") is therefore largely obsolete; the other two thirds stand untouched.

## X-46 — Docs-palette fan-out: ~35 commits / 15 PRs, design in 5–6 copies
**Verdict: VERIFIED-DRIFT**
- In-repo copies verified exactly: Launchstation `docs-site/static/assets/style.css` 1,900 lines; SMS pair 1,891 lines each and **byte-identical** (md5 `17bb5910b70428fba496445aaa7f3ec2` both); PS2-Servers `docs/assets/style.css` 1,715 lines. Git history verified on the clones (`git log --all`): all 15 PR numbers match the finding exactly (#410/#421/#422, #381/#385/#386, #641/#644/#645, #67/#69/#70, #314/#317/#318), waves 2 and 3 merged at 07:48 and 08:18–08:19 PST in all five repos; landing branches confirmed — RiptOPL wave-3 is an ancestor of `origin/gh-pages` and NOT of `rebuild/main` (`merge-base --is-ancestor`), POPSLoader's is contained only in `origin/dev`. Palette-sequence commits in the 2026-11-13/14 window count 34 by subject grep (6/6/6/10/6 per repo, SMS highest because of its doubled pair + extra unify commits), consistent with "≈35".
- **Correction:** wave 1 did not merge at 05:56–05:57 in all five repos — PS2-Servers' wave-1 commit `5179b4b` (#314) is timestamped **2026-11-13 09:04 PST** (its branch commit `df83613` at 16:55 UTC), roughly three hours after the other four repos' 05:56–05:57 wave-1 merges. The 15-PR / five-repo fan-out itself is unaffected.

## X-47 — SMSTCPIP: two diverged forks, RiptOPL hardened / SMS pristine
**Verdict: VERIFIED**
- Full re-diff reproduces the finding's numbers **exactly**: RiptOPL tree 11,072 lines of `.c`, SMS 9,642; 19 shared `.c` basenames, **19 of 19 differ** (md5 census), with diff counts pbuf.c 826, api_lib.c 1,066, etharp.c 969, mem.c 523, ip.c 431 — all exact. RiptOPL's hardening guard exists as claimed (six `test_smstcpip_*.py` host tests in `.github/scripts/`). One sub-claim is **UNVERIFIABLE-HERE**: "SMS's copy is pristine upstream" is SMS round 3's verdict; no upstream SMSTCPIP copy exists in these clones to re-derive it against. The verdict rests on the divergence itself, which is fully proven; nothing in the SMS tree contradicts a pristine snapshot.

## X-48 — Wiki publishing implemented four times
**Verdict: VERIFIED**
- Enumerated at the pin: Launchstation `sync-wiki.yml` (72 lines, `.wiki.git` clone at :43), POPSLoader `wiki-sync.yml` (93 lines, clone at :58), SMS `wiki.yml` (72 lines, clone at :54) **plus** its scripted `docs-site/sync_wiki.py`, and RiptOPL `wiki-publish.yml` (125 lines) driving the tested program `.github/scripts/wiki_sync.py` with `test_wiki_sync.py` present. Three hand-rolled YAML copies + one tested program (SMS carrying both a YAML copy and a script) — count and kinds as claimed.

---

## Unnumbered new-defect candidates

None beyond the drift corrections recorded above. Two observations already inside existing findings, noted only so they are not lost: (a) X-37's Go standard INFORM writing the real data port (negotiation.go:195) means a future C client that trusts the field against a *Core-Python* server (which sends 0) breaks — the asymmetry now runs in both directions; (b) X-45's SMS prescription is partially obsolete at the pin — anyone actioning X-45 should scope the remaining work to POPSLoader's version literals and treat the SMS item as already mitigated.
