# Sable Audit — VERIFICATION PASS: fresh re-execution of execution-based claims

- **Date:** 2026-11-14. **Method:** every claim below was re-run fresh in disposable copies under `/tmp/verify/` (clones never written; all five clones verified at the round-2 pins and `git status` clean at start and finish: RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`, SMS `e65ced39a27e`, PS2-Servers `c5f021c4d386`).
- **Toolchain:** Python 3.12.3; Go 1.27.4 at `~/workspace/tools/go1.27.4/bin`.
- **Verdicts:** CONFIRMED = the claim reproduces as filed. BROKEN = it no longer reproduces (evidence given). BLOCKED = this environment prevents the run (blocker named). **No claim came back BROKEN.** Two claims carry numeric/mechanism qualifications, recorded inline and collected at the end as unnumbered candidates — no new finding numbers are issued by this pass.

---

## 1. PS2-Servers (pin c5f021c4d386)

### 1(a) Full host suites vs the round-7 execution table

**Go — `go test ./...` in `native/ps2servers-edge` — CONFIRMED, exactly.**
- Result: 6 of 10 packages pass (cmd/ps2servers-edge, compression, filesystem, memory, protocol, sessionstats); 4 fail (smb, udpbd, udpfs, webui) with **exactly 99 failing tests** — the same packages and the same count round 7 reported.
- Cause audit: 111 log lines carry `operation not permitted` / `sendto` / `i/o timeout`. The one failure whose message lacks a network keyword, `TestStatusIdentifiesTheServiceByFlags` (webui_test.go:447, "udpfs answered and set its flag, but was reported as not running"), was read: it binds a real UDP loopback socket, runs a responder goroutine, and probes it via `queryAllStatus` — with `sendto` blocked the query never arrives, so the service reports not-running. It is a UDP socket test. **All 99 failures are UDP-environment failures; zero non-network failures.**

**Python — `python3 -m unittest discover -s tests -t .` — CONFIRMED, exactly.**
- Result: **Ran 1544 tests in 156.599s — FAILED (failures=3, errors=71, skipped=78)**. Round 7 claimed 1,544 tests with 3–4 failures / 71–72 errors / 78 skipped across two runs; this run lands inside every range, on the low edge.
- Cause audit of all 74 non-skip outcomes: **70 × `PermissionError: [Errno 1] Operation not permitted`** (blocked UDP `sendto`). The remaining 4 are all in `tests/test_status_client.py` and are no-reply assertions, exactly as round 7 described ("queries that never arrive, e.g. tests/test_status_client.py:167"):
  - `test_records_per_target_and_marks_silence_unknown` — **line 167**, the very line round 7 cited: `KeyError: 'state'` because the status reply never arrived.
  - `test_hex_string_port_is_parsed` (:123) and `test_reads_a_real_reply_over_the_wire` (:92) — `AssertionError: unexpectedly None` (no reply over the wire).
  - `test_silence_is_none_not_an_exception` — assertion message is literally "the query never arrived".
- **No non-environment failure observed.** Skips (78) are the documented platform/optional-dependency gates, as filed.

**Server selftests — CONFIRMED.** `udpfs_server/pathguard_selftest.py` → "ALL UDPFS PATH-GUARD TESTS PASSED"; `udpfs_server/compression_selftest.py` → "ALL UDPFS COMPRESSION TESTS PASSED"; `udpbd_server/selftest.py` aborts at its first `c.sendto(...)` with `PermissionError: [Errno 1] Operation not permitted` — environment-blocked, as round 7 recorded.

### 1(b) Test-vacuity findings PS2SERVERS-071…075

**PS2SERVERS-075 (mid-file `unittest.main()` orphans 28 tests) — CONFIRMED, to the exact numbers.**
- Guards re-read at the pin: `tests/test_smb2_server.py:617`, `tests/test_smb2_paths.py:203`, both mid-file.
- Executed: `python3 tests/test_smb2_server.py` → **Ran 33 tests, OK**; by module import → **56**. `python3 tests/test_smb2_paths.py` → **Ran 14 tests, OK**; by import → **19**. 23 + 5 = 28 orphaned, direct runs report green — precisely the filed figures.

**PS2SERVERS-074 ("without LZ4" tests patch `LZ4_AVAILABLE` to True) — CONFIRMED, with executed proof of the unobserved behaviour.**
- Source re-read at the pin: `tests/test_ra_compressed_hash.py` — `test_ziso_uncompressed_blocks_match_iso_hash_without_lz4` and `test_zso_opl_layout_matches_iso_hash` both wrap their assertion in `mock.patch.object(zso, "LZ4_AVAILABLE", True)`; the gate is at `udpfs_server/compressed_iso/zso.py:53-54` (`if not LZ4_AVAILABLE: raise ImportError` before header parsing).
- Executed: both named tests pass (patched, real flag here is True because `lz4` is installed in this sandbox). With `LZ4_AVAILABLE` forced to False, constructing the wrapper on a raw-block ZISO fixture raises `ImportError: LZ4 library not available` before any parsing — the refusal behaviour the "without_lz4" test never observes. Reproduces as filed.

**PS2SERVERS-072 (fake log manager makes -068 unobservable) — CONFIRMED (fresh greps + reads).**
- `internal/webui/webui_test.go:551`: `func (m *fakeManager) ServiceLogs(int) ([]string, error) { return m.logs, m.err }` — the `lines` argument is discarded by construction, as filed.
- Fresh grep over every `*_test.go` in the Edge tree: **zero** occurrences of `openwrtManager`, `systemdManager`, `clampLogLines`, or `logread`. The real `openwrtManager.ServiceLogs` (service.go:173-177) still ignores its `lines` parameter. No test can observe -068. Reproduces as filed.

**PS2SERVERS-073 (the only UCI boolean test tests the unused helper) — CONFIRMED (fresh greps + reads).**
- `TestUCIBoolMatchesOpenWrtTrueValues` (webui_test.go:707-718) exercises only the `uciBool` helper (accepts 1/true/on/yes/enabled).
- Fresh grep: `uciBool` is used exactly **once** in `config_uci.go` (:89, `UDPBatch`). The three `read_only` keys — `main.read_only`, `smb.read_only`, `udpbd.read_only` (config_uci.go:81, 125, 149 region) — still use the narrow `val == "1" || val == "true"`, so `read_only 'on'` loads as false (the -069 defect) and no test touches UCI Load/Save: fresh grep over `*_test.go` for `uciBackend`/UCI Load/Save → **zero**. Reproduces as filed.

**PS2SERVERS-071 (RDMA test verifies sectors 600–601; the hazard is at the current/zero offset) — CONFIRMED at source level; mutation execution BLOCKED here; one mechanism qualification (unnumbered candidate C-2 below).**
- Test re-read at the pin (`internal/udpbd/udpbd_test.go:348-365`): sends an unsolicited WRITE_RDMA of 0xCD bytes with no preceding CMD_WRITE, then compares only `img[600*SectorSize : 602*SectorSize]` (via `readSectors(t, c, 6, 600, 2)`). Sector 0 is never read; the whole image is never compared. The sibling `TestTruncatedWriteRDMAIsIgnored` initiates at sector 400 and reads sector 400 — as filed.
- Guard re-read (`internal/udpbd/server.go`, `handleWriteRDMA`): the drop is `if st.left <= 0 || !peerMatch` on the snapshot `st := s.write`; with no handshake `s.write` is the zero `writeState` (offset 0, left 0 — struct at :105-110). The filed core claim — the test observes 600–601 while the named hazard writes at the current/zero offset — is exact.
- Mutation execution (remove the guard in the copy, watch the test stay green) is **BLOCKED in this sandbox**: the test itself cannot run here — `go test -run TestUnsolicitedWriteRDMAIsIgnored` fails in 9.43s with `read udp4 127.0.0.1:…: i/o timeout` at the read-back (udpbd_test.go:361), because loopback UDP `sendto` is blocked. The vacuity is therefore source-verified, not mutation-verified, in this pass.
- Qualification (see C-2): a second clamp exists below the guard (`if int64(size) > st.left { size = int(st.left) }`, server.go:498-500). With no handshake (left=0) it would reduce a guard-less write to zero bytes, so the finding's "guard removed → payload written at offset 0" hypothetical overstates that one mutation path; the peer-mismatch half of the guard (attacker RDMA during a live handshake) still writes at the live offset, equally unobserved by the test. The filed defect — the oracle reads the wrong sectors — stands either way.

### 1(c) PS2SERVERS-070 (archives claim "read-only by default"; binary defaults writable) — CONFIRMED, including from the built artefact.

- Workflow side re-read: `.github/workflows/edge-build.yml:387-390` generates WHICH-DEVICE.txt with `printf '  Access         : read-only by default. Pass\n'`, `'                   --read-only=false to allow the console to\n'`, `'                   write (saves). …'`.
- Source side re-read: `native/ps2servers-edge/cmd/ps2servers-edge/main.go:150, 301, 359` — all three subcommands declare `fs.Bool("read-only", envBool("RO", false), …)`; default **false**.
- Artefact side, executed: built the release the workflow's way (`CGO_ENABLED=0 go build -trimpath -buildvcs=true -ldflags="-s -w -buildid= -X main.version=verify" -o … ./cmd/ps2servers-edge`, per edge-build.yml:264-281). The binary is **7,622,780 bytes — byte-size identical to the round-2 recorded Edge release build**. Its own `--help` for `udpfs`, `udpbd`, and `smb` each list `-read-only` with **no `(default true)` annotation** (Go's flag package prints the default only when non-zero) and help text "omit to allow the console to write saves" (udpfs). The shipped binary's help and the shipped archive's WHICH-DEVICE.txt state opposite defaults. Reproduces as filed.

---

## 2. Launchstation (pin 9fb0598a79f0)

### LAUNCHSTATION-187 (`test_copy_psu_listing.py` fails deterministically, SIGABRT) — CONFIRMED, first-hand, 3/3 fresh runs.

- Run exactly as CI wires it (compile.yml:71): `python3 tests/test_copy_psu_listing.py`.
- Every run dies at the same place: the generated C harness aborts — `test: test_copy_psu_listing.py:557: main: Assertion '!message[0]&&!nclipFiles&&!exists("mc0:/SAVEDIR")&&udpfs_read_opens==2&&!strcmp(udpfs_last_read,"udpfs:/SAVEDIR.psu")' failed`, and Python reports `CalledProcessError: Command '[…/test]' died with <Signals.SIGABRT: 6>`; script exit 1. This is the clean Cut→PSU-backup Move to a UDPFS destination (the scenario built at :556-557), as filed.
- Implicated product stage re-read at the pin: `src/filer_copy.c:245` `filerCopyDiagStage("Deleting confirmed move entries")`, and :249-250 returns `-EIO` when `moveEntryMatches(entry, &stat, 1)` fails on re-stat — the filed mechanism. (Round 7's instrumented message, "Deleting confirmed move entries (-5)", is consistent with the failing `!message[0]` conjunct; this pass did not re-instrument.)
- Combined with round 7's 5/5, the failure is now 8/8 across two independent passes.

### Other CI-wired host suites — fresh sweep of all 211 tests listed in compile.yml

- **205 PASS as run.** The 6 failures classify as:
  - `test_copy_psu_listing.py` — LAUNCHSTATION-187 itself (above).
  - `test_mc_card_view.py`, `test_mc_card_write.py`, `test_mmce_save_versions.py` — failed in the sweep with `OSError: [Errno 28] No space left on device` (/tmp here is a 512 MB shared tmpfs). Re-run individually with `TMPDIR` on the large disk: **all three PASS** ("PS2 card viewer … OK"; "Card writer … OK" in 1m41s; "PASS: per-save .psu versions …"). Environment artefacts, not product failures.
  - `test_dash_card_tool.py` — **BLOCKED (environment)**: its harness compiles with `-lmbedcrypto` and `#include <mbedtls/aes.h>`; this sandbox has an mbedcrypto runtime library but no mbedtls development headers (reproduced with the test's own gcc line: compilation terminated at `mbedtls/aes.h`). CI runners provide them.
  - `test_mc_save_export.py` — **BLOCKED (environment)**: `ModuleNotFoundError: No module named 'cryptography'` in this sandbox.
- No round made per-test pass claims for these suites beyond -187, so nothing here contradicts a filed claim; the sweep's value is the negative: at the pin, no *other* CI-wired Launchstation suite fails for a product reason in this environment.

---

## 3. RiptOPL (pin 2e347d5ac885)

### RIPTOPL-302 (`test_release_editions.py:28` membership assertion can never fail) — CONFIRMED by execution; one numeric qualification (candidate C-1).

- Lines re-read: test_release_editions.py:20 builds `targets = {t["name"]: t for t in config["targets"]}`; :27 asserts `"ps2sdk_socket_compat" not in loader["libs"]` (a real check); :28 asserts the same literal `not in targets` — a dict-key membership test over target **names**.
- Executed `build_edition.definition()` for **all four editions** (korium, ra, incebtion, ra_incebtion): no target is named `ps2sdk_socket_compat` in any edition (so :28 passes trivially in all four), and no target's `libs` contains it either (so :27 also currently passes). The suite itself runs green: `test_release_editions.py` → Ran 2 tests, OK. The vacuity reproduces exactly as filed: :28 can only fail if a target is one day *named* `ps2sdk_socket_compat`.
- Qualification: the finding's "82–84 targets per edition" figure does **not** reproduce — `definition()` with the test's own call shape returns **73 targets (korium, incebtion) / 76 (ra, ra_incebtion)**. The mechanism is count-independent; the number in the finding appears to come from a different counting basis. See C-1.

### RIPTOPL-298 (GPT test asserts partitions wholly outside the 64-sector device mount successfully) — CONFIRMED by execution.

- `python3 .github/scripts/test_bdm_partitions.py` → exit 0, final line "bdm partitions: all cases passed".
- The run's own output shows the beyond-device entries being connected: `start=0x0000000100000010 end=0x0000000100000019` and `start=0x0000000000000bb8 end=0x0000000000000bc1` (3000–3009) on the 64-sector simulated device.
- Assertions re-read at test_bdm_partitions.py:238-253: `assert(part_connect_gpt(&raw) == 0 && nconnected == 1 && connected[0]->sectorOffset == 0x100000010ull)` and the 3000–3009 twin, with the rationalising comment at :249 verbatim: "Only the entry sectors are read at mount, so partitions may lie beyond the simulated disk." The suite certifies RIPTOPL-160's missing extent validation as expected behaviour, as filed.

### RIPTOPL-291 extension, strongest instance (JPG decoder suite in `test_ripps2_art_port.py` gated on dependencies no workflow installs) — CONFIRMED end-to-end, mechanism demonstrated live.

- Gating code re-read at test_ripps2_art_port.py:128-137: the entire JPG-decoder block runs only if a `g++ -fsyntax-only` probe of `#include <jpeglib.h>` succeeds **and** `from PIL import Image` succeeds; otherwise it prints `skip JPG decode: host has no libjpeg headers or Pillow` and continues to a green exit.
- Workflow census (fresh grep over `.github/workflows/`): **no workflow installs libjpeg headers or Pillow.** Pip installs are `-r requirements.txt` (flavours.yml:25, rolling-release.yml, rolling-llvm.yml) and `requirements.txt` contains exactly one line — `PyYAML==6.0.3`; the only apt install in any workflow is `p7zip-full`. The finding's "flavours installs PyYAML only; ps2build installs nothing" holds in substance (now via requirements.txt).
- Live demonstration in this sandbox (Pillow 10.2.0 present, `/usr/include/jpeglib.h` absent): `python3 test_ripps2_art_port.py` prints the three `ok …` lines, then `skip JPG decode: host has no libjpeg headers or Pillow`, and **exits 0** — the decoder half (baseline/progressive/grayscale decode, size-box shrink, non-JPG refusal, abort handling) unexecuted in a green run. On a stock CI runner lacking both dependencies the same skip fires. Reproduces as filed.

### RIPTOPL-431 (SMB1 `FileTimeToDate` executed proof) — NOT RE-EXECUTED, per scope.

- The proof is modules-side C (`modules/network/smbman*/…` EE/IOP code); there is no host harness for it in this VM and no PS2 toolchain. Recorded as **source-only** — this pass neither confirms nor breaks it; its status remains exactly what round 9 filed (executed by the round-9 agent's own host compilation at filing time, not re-run here).

---

## Unnumbered candidates surfaced by this pass (no new finding numbers issued)

- **C-1 — RIPTOPL-302's target-count figure does not reproduce.** The finding states "82–84 targets per edition (executed)"; fresh execution of `build_edition.definition()` for all four editions at the pin returns 73/76/73/76 targets. The defect (dict-name membership at test_release_editions.py:28) is confirmed and count-independent, but the finding's executed-evidence sentence should be corrected to the reproduced figures or its counting basis stated.
- **C-2 — PS2SERVERS-071's offset-0 hypothetical is backstopped by a second clamp.** `internal/udpbd/server.go:498-500` clamps the RDMA write size to `st.left`; with no handshake (left=0) a guard-less unsolicited RDMA would write zero bytes, so "guard removed → payload written at offset 0" requires also defeating the clamp (or the peerMatch-half failure, which writes at the *live* handshake offset). The finding's filed defect — the test compares sectors 600–601 and never sector 0 or the whole image — is confirmed; only its rationale sentence overstates one mutation path. (Mutation execution itself is environment-blocked here: the test needs loopback UDP.)

## Blocked items (environment), consolidated

| Item | Blocker |
|---|---|
| PS2SERVERS-071 mutation run (and the -071 test itself) | Sandbox blocks UDP `sendto`, loopback included — test fails at read-back with i/o timeout |
| Launchstation `test_dash_card_tool.py` | No mbedtls development headers in this sandbox (`mbedtls/aes.h` absent) |
| Launchstation `test_mc_save_export.py` | Python `cryptography` module not installed in this sandbox |
| RIPTOPL-431 re-execution | Modules-side C; no host harness / PS2 toolchain in this VM (source-only by scope) |

## Scoreboard

| Claim | Verdict |
|---|---|
| PS2-Servers Go suite (6/10 pkgs; 99 fails, all UDP) | CONFIRMED (exact) |
| PS2-Servers Python suite (1,544; 3F/71E/78S, all UDP) | CONFIRMED (exact) |
| PS2-Servers selftests (2 pass, udpbd blocked) | CONFIRMED |
| PS2SERVERS-070 (read-only default misstatement) | CONFIRMED (source + built artefact) |
| PS2SERVERS-071 (wrong-sector RDMA oracle) | CONFIRMED (source); mutation BLOCKED; rationale qualified (C-2) |
| PS2SERVERS-072 (fake log manager) | CONFIRMED |
| PS2SERVERS-073 (UCI helper-only test) | CONFIRMED |
| PS2SERVERS-074 (without_lz4 patches flag on) | CONFIRMED (executed) |
| PS2SERVERS-075 (28 orphaned tests) | CONFIRMED (exact numbers) |
| LAUNCHSTATION-187 (CI test SIGABRT at pin) | CONFIRMED (3/3 fresh runs) |
| Launchstation other CI suites (211) | 205 pass; 3 pass on re-run (tmpfs space); 2 BLOCKED (env deps); no other product failure |
| RIPTOPL-302 (vacuous membership assertion) | CONFIRMED (executed); count figure qualified (C-1) |
| RIPTOPL-298 (GPT test blesses beyond-device mounts) | CONFIRMED (executed) |
| RIPTOPL-291 ext. (JPG suite dependency gating) | CONFIRMED (grep + live skip-to-green run) |
| RIPTOPL-431 (FileTimeToDate proof) | NOT RE-EXECUTED (source-only, per scope) |

**Totals: 13 claims CONFIRMED (5 of them to the exact filed numbers), 0 BROKEN, 3 BLOCKED items (all environment), 2 unnumbered qualification candidates (C-1, C-2).** Clones left at pins, git-clean; all work was done in `/tmp/verify/` copies.
