# Verification Batch E — RE-SERV-088…100 + Go Baseline (PS2-Servers)

- **Pin confirmation:** `git -C ~/workspace/audit-clones-2026-11-13/PS2-Servers rev-parse HEAD` = `c5f021c4d38698860f56b03498adc261dbb8d8dd` — matches the mandated pin exactly.
- **Method:** clone read-only; all runs in a fresh `/tmp` copy (`/tmp/edge-test-E`) of `native/ps2servers-edge`, Go 1.27.4 (`~/workspace/tools/go1.27.4/bin`). Mutations for RE-SERV-089/090/091 were applied only in the /tmp copy and restored from backups afterwards.
- **Repo house rule noted:** the clone's `AGENTS.md` (GitHub attribution policy) was read; it imposes no constraint on this read-only verification and no GitHub content was produced.

---

### BASELINE-GO — VERIFIED

- **Citations:** Baseline text (Redo-PS2Servers.md lines 14–97): build/vet clean; 246 top-level = 145 pass / 99 fail / 2 skip; 298 incl. subtests = 177/119/2; per-package top-level failures smb 4, udpbd 10, udpfs 84, webui 1; 89 outputs containing `sendto: operation not permitted`, 22 containing `i/o timeout`; 250 `func Test` definitions, 5 behind `//go:build cgo && chd`; packages ok 6 / FAIL 4 / no-test-files 3; skips = `TestEntryRefusesNamesWindowsWouldReinterpret`, `TestSharedHandshakeFixtures`.
- **Execution (mine, reproduced exactly):**
  - `go build ./...` exit 0, no output. `go vet ./...` exit 0, no output. `go test -json ./...` exit 1.
  - **My counts are identical in every particular:** 246 top-level results = **145 pass / 99 fail / 2 skip**; 298 incl. subtests = **177 pass / 119 fail / 2 skip**; per-package top-level failures **udpfs 84, udpbd 10, smb 4, webui 1**; packages ok 6 (`cmd/ps2servers-edge`, `compression`, `filesystem`, `memory`, `protocol`, `sessionstats`), FAIL 4 (`smb`, `udpbd`, `udpfs`, `webui`), no test files 3 (`logging`, `session`, `statuslistener`); the 2 skips are exactly the two named tests.
  - **Failure classification — every one of the 99 traced by me:** global output occurrences `sendto: operation not permitted` = **89**, `i/o timeout` = **22** (exact match to the claimed message counts). At top-level-test granularity: 70 failing tests carry `operation not permitted` in their own output, 21 carry `i/o timeout`; the remaining 8 resolve as follows — 7 (`TestBlockWriteOnAFileHandleSurvivesALoaderHandoff`, `TestReplacementLoaderCanRewriteAFileTheOldOneHadOpen`, `TestReplacementLoaderCanDeleteAFileTheOldOneHadOpen`, `TestBackgroundDiscoveryPreservesActiveStream`, `TestSendPacketsFallbackAndMetrics`, `TestBatchedTransferDoesNotPublishQueuedPacketsBeforeFlush`, `TestARefusedWriteTakesNoChunksAfterAnUnfinishedOne`) fail only in subtests whose output is `write udp4 …: sendto: operation not permitted` (one subtest of `TestSendPacketsFallbackAndMetrics` instead times out on read), and the 8th, webui `TestStatusIdentifiesTheServiceByFlags` (`webui_test.go:447`), is the one-step-removed case the baseline describes: I confirmed the fake server replies via `conn.WriteToUDP` (webui_test.go:440) and the code under test queries over UDP (`queryAllStatus`, service.go:276), so with `sendto` blocked no reply can arrive. **Genuine (non-environmental) failures found by me: 0.**
  - **Source reconciliation:** my grep counts **250** `func Test` definitions. The 5 gated behind `//go:build cgo && chd` are exactly 4 in `internal/compression/chd_enabled_test.go` + 1 in `internal/udpfs/chd_operations_test.go` (headers read directly). Note the complementary file `chd_disabled_test.go` (`//go:build !cgo || !chd`, 1 test) *is* compiled by default, which is consistent with the baseline arithmetic: 250 − 5 gated = 245 compiled + the `FuzzParseDataPacket` seed-corpus run = 246 top-level results. CI context also confirmed: `edge.yml` test job runs `go test -race ./... -count=2`, `go vet`, gofmt gate, and the CHD step `CGO_ENABLED=1 go test -tags chd ./internal/compression ./internal/udpfs` — so the 5 gated tests do run in CI.
- **Caveat (shared with the baseline, not a drift):** an early parse of my JSON while the run was still writing gave a truncated 219-result picture; the completed file (1,357 lines) gives the full counts above. The baseline's own warning stands and is corroborated: UDP wire behaviour is *unverified* in this sandbox, not verified good.

---

### RE-SERV-088 — VERIFIED

- **Citations:** `internal/smb/integration_test.go:65-69` (`tryTrans2`), `internal/smb/limits_test.go:63-93` (`TestSearchesAreBounded`) — both exist exactly as cited.
- **Mechanism:** Re-derived. `tryTrans2` body is `p, d := cl.trans2(sub, tParams); return p, d, nil` — error hard-wired to `nil`. Inner `trans2` (integration_test.go:156) checks `h.Status != StatusSuccess` and Fatalfs. Grep: `tryTrans2` has exactly two callers, `limits_test.go:84` and `:89`, both checking the unreachable `err != nil`. The test loops `MaxSearches*8` FIND_FIRST2 (`MaxSearches = 16`, wire.go:138, so 128 requests) and afterwards asserts only that the server still answers; production eviction is `evictOldest(…, MaxSearches, …)` at handlers.go:729, which is silent — a non-evicting implementation passes identically. The bound is genuinely unasserted.
- **Execution:** `TestSearchesAreBounded` **passed** in my full run (TCP/in-process, unaffected by the UDP block) — consistent with the finding: it passes while asserting nothing about the bound.
- **Fix:** Sound and LESS-NOT-MORE compliant: deleting `tryTrans2` removes dead scaffolding (the inner Fatal already fails the test); the proposed FIND_NEXT2-on-evicted-ID assertion is a real behavioural bound check using existing protocol surface, no production addition required (the alternative same-package count inspection is also test-only).

### RE-SERV-089 — VERIFIED

- **Citations:** `internal/webui/webui_test.go:638-669` (`TestServerPortFallback`); production `internal/webui/webui.go:237-257` — both exist as cited; schema doc at `internal/webui/schema.go:169` confirmed verbatim ("0 uses 8082 with fallback to an OS-assigned port"), `DefaultPort = 8082` (webui.go:20).
- **Mechanism:** The test constructs `Port: 0`, sleeps 100 ms, cancels, asserts only `Serve` returned nil. It never occupies 8082, never reads the bound address, never asserts a port. The fallback branch cannot be entered and a wrong-port bind cannot fail it.
- **Execution (mutation reproduced by me):** in the /tmp copy I replaced the default-port attempt at webui.go:245 with a direct bind to `"0"` (deleting the 8082 attempt entirely); `go test ./internal/webui/ -run TestServerPortFallback -count=1` still **passed** (`ok … 0.189s`). Unmutated test also passed in my full baseline run. File restored after.
- **Fix:** Sound, test-only, small: occupy 8082 first and assert reachability on a different port, plus assert 8082 in the unoccupied case. No production change; LESS-NOT-MORE compliant.

### RE-SERV-090 — VERIFIED

- **Citations:** `internal/udpfs/blockdev_test.go:256-276` (`TestCompressionCacheDefaultsAndDisables`); behaviour at `internal/udpfs/blockdev.go:398-402` — both exist as cited.
- **Mechanism:** The test only asserts `New` stored `cfg.CompressionCache` verbatim (0→0, 8→8) and never opens an image. The actual defaulting is in `openImage`: `cache := s.cfg.CompressionCache; if cache == 0 { cache = compression.DefaultCacheBlocks }` — a function the test never calls. No disable path/value is exercised (the only "disable" in production is the separate `NoCompression` flag, untouched here).
- **Execution (mutation reproduced by me):** in the /tmp copy I changed the substitution to `cache = 1`; `go test ./internal/udpfs/ -run 'TestCompressionCacheDefaultsAndDisables|TestNoCompressionStopsAdvertisingContainersAsIso' -count=1` still **passed** (`ok … 0.027s`). Unmutated test also passed in my full run. File restored after.
- **Fix:** Sound: drive `openImage` (same package, directly callable) with cache 0 and assert the opened image's limit — test-only, no new production surface. Renaming/dropping "Disables" is pure deletion of a false claim.

### RE-SERV-091 — VERIFIED

- **Citations:** `internal/compression/chd_cuebin_test.go:119-126`; production `internal/compression/chd_cuebin.go:378-388` — both exist as cited.
- **Mechanism:** The test asserts exactly two rejections (invalid UTF-8 `0xff…bin`; 252×`x` + `.bin` = 256 bytes) and no acceptance. Production `safeCueName` additionally rejects `"`, `\`, control chars `< 0x20` and `0x7f` (chd_cuebin.go, loop after the UTF-8/length check) — none tested. A reject-everything stub therefore passes, as claimed. The name quibble is also accurate: the overlong case is ASCII, not a UTF-8 case.
- **Execution (mutation reproduced by me):** in the /tmp copy I stubbed `safeCueName` to `return false` unconditionally; `go test ./internal/compression/ -run TestSafeCueNameRejectsInvalidAndOverlongUTF8 -count=1` still **passed** (`ok … 0.010s`). File restored after.
- **Fix:** Sound and minimal: add positive cases (ordinary name, 255-byte boundary, valid non-ASCII) and one case per rejection rule. Pure test additions to an existing test, each justified by an existing production rule.

### RE-SERV-092 — VERIFIED

- **Citations:** `internal/filesystem/root_test.go:216-235`; CI at `.github/workflows/edge.yml:37` — both exist as cited.
- **Mechanism:** The test opens with `if runtime.GOOS != "windows" { t.Skip("Windows path normalisation") }`. I checked **all** workflows, not just edge.yml: the only workflow that runs this Go module's tests is `edge.yml`, whose jobs are all `ubuntu-latest` (lines 37, 191, 239; `edge-build.yml:23` also ubuntu and builds without testing). Windows runners exist elsewhere (`ci.yml`, `release*.yml`) but run Python unittest suites / packaging, never `go test` for `native/ps2servers-edge` — so the finding's precise wording ("every CI job that runs this module's tests is Linux") holds. The guarded behaviour (trailing dot/space reinterpretation, `"..."` → parent/root, expecting `ErrEscape`) is security-relevant and gets zero automated execution.
- **Execution:** The test was one of exactly 2 skips in my reproduced baseline run.
- **Fix:** Sound; the preferred half (extract a platform-independent predicate, test it anywhere) is less code than a Windows CI job and LESS-NOT-MORE compliant. The Windows-runner alternative is heavier and the finding itself ranks it second.

### RE-SERV-093 — VERIFIED

- **Citations:** `internal/smb/wire_test.go:157-179`, `:211-220`; `internal/smb/limits_test.go:157-171`; constants `wire.go:84` (`DefaultPort = 1111`), `wire.go:105,118` (`MaxMessage = 128<<10`, `MaxConnections = 16`), `server.go:120` (`idleTimeout = 5 * time.Minute`) — all exist exactly as cited (I read each test body and each constant).
- **Mechanism:** Re-derived per test: (1) `TestDefaultPortIsUnprivileged` asserts only `DefaultPort >= 1024`, binds nothing. (2) `TestMaxMessageClearsTheLargestRealFrame` asserts only arithmetic: `MaxMessage > 65594` and `MaxMessage*MaxConnections <= 4<<20`; sends nothing. (3) `TestConnectionSlotsAreNotHeldByIdleSockets` asserts only `0 < idleTimeout <= 30m` and its own comment concedes it "asserts the mechanism exists rather than waiting for it"; opens no connection (the real deadline is set at server.go:569, unexercised). No behavioural regression in bind/dispatch/accept paths can fail any of the three.
- **Execution:** All three **passed** in my full run — consistent with constant pins passing while the constants are in range.
- **Fix:** Mostly sound. Renaming to `…Constant…` is pure honesty at zero cost. The behavioural additions are justified for port-bind and large-frame round-trip; the idle-socket case is the expensive half — `idleTimeout` is a production `const`, so observing a drop requires making it test-configurable (a small production change). That half should be scoped as such, not presented as test-only; it does not defeat the finding.

### RE-SERV-094 — VERIFIED

- **Citations:** `internal/udpfs/write_test.go:143-148` — exists exactly: `func result(payload []byte) int32 { if len(payload) < 8 { return 0 }; return int32(binary.LittleEndian.Uint32(payload[4:8])) }`, and 0 is the protocol success value.
- **Mechanism:** Grep confirms `result(` is used across the package's test files (I found it in 13 `*_test.go` files including all nine the finding names: write, blockdev, blockonly, fileid_bwrite, handoff_write, pathops, rediscovery, compression_operations, chd_operations). Any truncated (<8-byte) reply therefore reads as success for every `result(...) == 0` expectation. The claimed exception checks out: `pathOp` (pathops_test.go:28-35) does `if len(reply) < 8 || … != ResultReply { Fatalf }` before calling `result` — most callers do not.
- **Execution:** Helper and call sites read directly; the masking is a code-read certainty (no run can distinguish it in the UDP-blocked sandbox, where these wire tests fail at send anyway — in my run the udpfs wire tests fail on `sendto`, before any `result` decoding).
- **Fix:** Sound and minimal: thread `t` (every caller already has one, directly or via the test client's `c.t`) and `t.Fatalf` on short payloads, or return an impossible sentinel. Test-only change, no production code.

### RE-SERV-095 — VERIFIED

- **Citations:** `internal/udpfs/status_test.go:150-173` (`TestUnknownServiceIDIsStillIgnored`); neighbour at `:109-148` — both exist as cited.
- **Mechanism:** The test sends one DISCOVERY with `ServiceID: 0x1234` and asserts only that no reply arrives within 500 ms. No positive exchange against the same server instance, so server-side ignoring is indistinguishable from transport death, wedging, or broken discovery handling. The neighbour `TestOrdinaryDiscoveryStillWorksAlongsideStatus` does prove liveness but against a different `startServerAt` instance in a different test, exactly as claimed.
- **Execution:** In my full baseline run — with every UDP `sendto` blocked — `TestUnknownServiceIDIsStillIgnored` **passed**, while the positive-control neighbour `TestOrdinaryDiscoveryStillWorksAlongsideStatus` **failed**. That asymmetry is direct executed proof of the vacuity: the negative-only test is satisfied by a dead transport.
- **Fix:** Sound and small: positive DISCOVERY/INFORM exchange on the same server/socket first, then the unknown-ID silence assertion. (Consequence to note: after the fix this test will *fail* in UDP-blocked sandboxes like this one — that is the point of a positive control, and CI has working UDP.)

### RE-SERV-096 — VERIFIED

- **Citations:** `internal/udpfs/observability_test.go:22-40` (`synchronizedLogBuffer`) vs `internal/udpfs/session_summary_test.go:22-38` (`lockedBuffer`); copies at `internal/smb/session_summary_test.go:17-33`, `internal/udpbd/session_summary_test.go:18-34`; CSO builders at `internal/compression/image_test.go:13-33`, `sizeof_test.go:16-47`, `corrupt_index_test.go:22-40`, `internal/udpfs/compression_operations_test.go:16-36` — all exist as cited.
- **Mechanism:** I compared the bodies directly. The two udpfs types are identical in substance: `mu sync.Mutex; b bytes.Buffer` with mutex-guarded `Write`/`String` delegating to the buffer — differing only in type/receiver names and one comment. The smb and udpbd `lockedBuffer` copies are the same type again. For the container builders: all four hand-assemble the same 24-byte CISO header with the same field offsets (magic `[0:4]`, header size `[4:8]`, total size `[8:16]`, block size `[16:20]`, version/align bytes 20/21). Minor nuance I verified: `writeContainer` and `writeUDPFSContainer` are near-identical full header+index builders; `writeCorruptIndex` varies the index gap as its purpose requires; `writeBigIndexCSO` assembles the header but simulates the index by truncation rather than writing index entries. So "header hand-assembled four times" is exact; "index layout in four" is exact for three and by-simulation for the fourth. This does not change the duplication substance.
- **Execution:** Read/diff only (duplication is a source fact); all four packages compile and run in my baseline.
- **Fix:** Sound, with the finding's own prioritisation correct: the same-package udpfs dedupe (delete `synchronizedLogBuffer`, keep `lockedBuffer`) is a pure deletion and the valuable half. Cross-package copies cannot be shared without an exported test-support package — the finding concedes this is the weaker half, correctly. Parameterising one container builder per package is a net test-code reduction; `writeBigIndexCSO`'s truncation trick needs to survive as a parameter/variant, which the finding's parameter list (declared size, index gap, magic) mostly covers.

### RE-SERV-097 — VERIFIED

- **Citations:** `internal/protocol/packet_test.go:23-30` (`FuzzParseDataPacket`, 3 seed inputs: empty, 6-byte, one marshalled Data packet); `internal/udpfs/udpwrite_test.go:338-377` (`BenchmarkUDPBatch`) — both exist exactly as cited and are the only `func Fuzz` / `func Benchmark` in the module (my grep found no others).
- **Mechanism:** `go test` without `-fuzz` runs a fuzz target only over its seed corpus as a unit test, and never runs benchmarks. I grepped **all** workflows (not only edge.yml) plus looked for Makefiles: no `-fuzz`, `-bench`, `bench`, or `fuzz` invocation anywhere; `edge.yml`'s Go invocations are only the `-race -count=2` test run and the CHD-tagged run (lines 56, 82).
- **Execution:** In my `go test -json` run, `FuzzParseDataPacket` appears as an ordinary **passing** top-level test (it is the +1 in the 245+1=246 reconciliation) and there is no benchmark result of any kind — direct executed confirmation.
- **Fix:** Sound under the finding's own justification rule: either the bounded CI step (~60 s fuzz + `-benchtime=1x` smoke) — an addition, but bounded and the only way either artefact yields its intended signal — or delete the benchmark (pure LESS). Both branches are honestly presented; no production code involved.

### RE-SERV-098 — VERIFIED

- **Citations:** `internal/udpfs/blockdev_test.go:278` — exists verbatim: `var _ = session.Pending // keep the session import meaningful across refactors`.
- **Mechanism:** My grep of the file for `session.` returns exactly one hit — line 278 itself. Nothing else in the file uses the `session` package; the line exists solely to keep the import compiling, as its own comment admits.
- **Execution:** Grep result quoted above (single hit); the file compiles in my baseline build/test run with the line present.
- **Fix:** Ideal LESS-NOT-MORE: delete the line and the import. Pure deletion, zero risk beyond compilation, which the compiler itself verifies.

### RE-SERV-099 — VERIFIED

- **Citations:** `internal/udpbd/udpbd_test.go:50-65` (`TestBlockGeometryIsConsistent`); production `internal/udpbd/protocol.go:101-104` — both exist as cited: `blockSize = 1 << (shift + 2); return blockSize, rdmaMaxPayload / blockSize, SectorSize / blockSize`.
- **Mechanism:** Re-derived assertion by assertion over the test's shifts {3,5,6,7} (block sizes 32/128/256/512): (a) `size == 1<<(shift+2)` restates the first production line verbatim; (b) `perSector*size == SectorSize` holds for every shift in the set because each block size divides 512 — it is a property of the chosen inputs, not an independent expectation; (c) `perPacket*size <= rdmaMaxPayload` is identically true for any integer-division quotient `rdmaMaxPayload / size` (absent overflow, impossible at these magnitudes). No value external to the implementation appears anywhere in the test. The contrast also checks out: the neighbouring `TestBlockShiftMatchesReferenceTable` pins literal expected shifts against the reference implementation — a real external oracle in the same file. The finding's own Med/INFERRED confidence label is honest: the arithmetic identities are certain; "no external oracle" is a judgement I independently reach from the same two files.
- **Execution:** `TestBlockGeometryIsConsistent` **passed** in my full run (in-process, UDP-independent) — as it must, given (a)–(c).
- **Fix:** Sound and minimal: replace the derived assertions with a literal `(blockSize, blocksPerPacket, blocksPerSector)` table sourced from the reference geometry, mirroring the existing neighbour test. Test-only, no size growth of consequence.

### RE-SERV-100 — VERIFIED

- **Citations:** `internal/udpfs/server_test.go:15-49` (`TestClassify` at 11-21, `TestSharedHandshakeFixtures` at 23-49) — exists as cited; fixture at `conformance/fixtures/handshake_cases.json` in the clone, read directly by me.
- **Mechanism:** Both halves re-derived. (1) Duplication: the fixture's five cases — standard-zero 0/0→standard, modulo-fresh 0/1→modulo, modulo-resumed 7/8→modulo, modulo-wraparound 4095/0→modulo, nonmatching-fallback 7/0→standard — are exactly `TestClassify`'s hardcoded table `{{0,0,Standard},{0,1,Modulo},{7,8,Modulo},{4095,0,Modulo},{7,0,Standard}}`, case for case including profiles. As a Go test it adds no case; its value is only cross-implementation sharing of the file, as claimed. (2) Skip-to-pass: on `os.IsNotExist` it calls `t.Skipf`, and the path `../../../../conformance/…` escapes the Go module, so any module-only copy silently loses it with a green run.
- **Execution:** In my mandated /tmp module-only copy the test **skipped** (1 of the 2 baseline skips) while the fixture verifiably exists in the full clone — the exact evaporation the finding describes, reproduced.
- **Fix:** Sound: fail (not skip) when the fixture is missing in a full checkout, gated by an explicit standalone-copy marker, and log the executed case count. The env-marker condition is a small addition but is what keeps downstream module consumers working; the alternative (unconditional fail) would break them, so the scoped version is the right one.

---

## Tally

- **BASELINE-GO: VERIFIED** — every claimed number reproduced exactly (build/vet clean; 246 = 145/99/2; 298 = 177/119/2; per-package failures 84/10/4/1; 89 `sendto` + 22 `i/o timeout` output occurrences; 250 definitions, 5 CHD-gated; 0 genuine failures).
- **RE-SERV-088…100: 13 VERIFIED, 0 VERIFIED-DRIFT, 0 WEAKENED, 0 REFUTED, 0 BLOCKED-ENV.**
- Mutation proofs independently reproduced for 089, 090, 091 (mutated code in /tmp copy, named tests still passed, files restored). Vacuity of 095 proven from my own run (negative-only test passed under total UDP block while its positive-control neighbour failed). All other findings re-derived from direct reads/greps quoted above.

## CANDIDATES (new defects)

- **None.** No genuinely-failing test was found: all 99 failures in my run trace to the sandbox UDP `sendto` block or its downstream `i/o timeout` (classification in the BASELINE-GO block, including the 7 subtest-level and 1 webui one-step-removed cases). No test, helper, or production defect beyond RE-SERV-088…100 was identified in this batch's scope. The only nuance worth recording is inside RE-SERV-096 (documented there): `writeBigIndexCSO` simulates its index by file truncation rather than writing index entries, so "index layout hand-assembled four times" is exact for three builders and by-simulation for the fourth — a wording nuance, not a new defect and not a defeat of the finding.
