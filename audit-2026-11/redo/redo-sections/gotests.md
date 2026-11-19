# PS2-Servers — Go test suite audit (blind redo)

Scope: every `*_test.go` under `native/ps2servers-edge/` in the clone
`~/workspace/audit-clones-2026-11-13/PS2-Servers` @ `c5f021c4d38698860f56b03498adc261dbb8d8dd`:
42 files, 9,564 lines (counted by `wc -l`). Work was done on a copy at
`/tmp/edge-test`; the clone was never edited (`git status --porcelain` clean at the end).

## Baseline

Commands (Go 1.27.4 from `~/workspace/tools/go1.27.4/bin`, run in `/tmp/edge-test`):

```
cp -r native/ps2servers-edge /tmp/edge-test
go build ./...        # exit 0, no output
go vet ./...          # exit 0, no output
go test ./...         # exit 1
go test -json ./...   # exit 1, used for the counts below
```

Package results from `go test ./...` (13 packages):

- **ok (6):** `cmd/ps2servers-edge`, `internal/compression`, `internal/filesystem`,
  `internal/memory`, `internal/protocol`, `internal/sessionstats`
- **FAIL (4):** `internal/smb`, `internal/udpbd`, `internal/udpfs`, `internal/webui`
- **no test files (3):** `internal/logging`, `internal/session`, `internal/statuslistener`

Test-result counts from `go test -json ./...`:

- 298 test results including subtests: **177 pass, 119 fail, 2 skip**.
- 246 top-level results: **145 pass, 99 fail, 2 skip**.
- Reconciliation with the source: 250 `func Test…` definitions exist (grep count).
  5 of them sit behind `//go:build cgo && chd` and are not compiled by a default
  `go test` (4 in `internal/compression/chd_enabled_test.go`, 1 in
  `internal/udpfs/chd_operations_test.go`); 245 compiled tests + the
  `FuzzParseDataPacket` seed-corpus run = the 246 top-level results.
  `BenchmarkUDPBatch` is not run by `go test` at all (see GOTEST-10).

### UDP-blocked accounting — every failure traced

The sandbox blocks UDP `sendto`. Failure messages across the run: 89 contain
`sendto: operation not permitted` and 22 contain `i/o timeout` (the downstream
symptom of a request or reply that could not be sent). Per package, top-level failures:

- `internal/smb` — 4: the four `TestSMB…Status…` tests in `status_test.go`; each dies in
  `askStatus` with `no status reply from the SMB server: read udp4 …: i/o timeout`
  (the status query/reply is UDP; the SMB TCP tests in the same package all pass).
- `internal/udpbd` — 10: 9 in `udpbd_test.go` + `TestSessionSummaryCountsAConsole`,
  all `read udp4 …: i/o timeout` on the first exchange.
- `internal/udpfs` — 84: the wire-driven tests; the overwhelming majority report
  `write udp4 …: sendto: operation not permitted` at the first client send, the rest
  report the resulting read timeout (status queries, `TestSendPackets…` receive loops).
- `internal/webui` — 1: `TestStatusIdentifiesTheServiceByFlags`
  (`webui_test.go:447: udpfs answered and set its flag, but was reported as not running`).
  Traced: the test's fake server replies with `conn.WriteToUDP` and the code under test
  (`queryAllStatus`) queries over UDP, so with `sendto` blocked no reply can arrive and
  the service is reported not running. Same environmental cause, one step removed.

**Genuine (non-environmental) failures identified: 0.** Every failing test's error
chain terminates in a blocked UDP send or the timeout it causes. The honest converse
also holds: in this environment the UDP wire behaviour is *unverified*, not verified
good — 145 passes include the TCP (SMB) and in-process tests, which are genuine, plus
one pass that is vacuous precisely because UDP is blocked (GOTEST-08).

Skips (2):

- `TestEntryRefusesNamesWindowsWouldReinterpret` (filesystem) — skips by design on
  non-Windows; see GOTEST-05 for why it therefore never runs in CI either.
- `TestSharedHandshakeFixtures` (udpfs) — skipped here only because the mandated
  module-only `/tmp` copy leaves its fixture path (`../../../../conformance/fixtures/
  handshake_cases.json`, relative to the package) outside the copy. The fixture exists
  in a full checkout (verified: `conformance/fixtures/handshake_cases.json` in the
  clone) and the test runs in CI. See GOTEST-13 for the residual fragility.

CI context (read from `.github/workflows/edge.yml`, the workflow that gates this
module): the test job runs `go test -race ./... -count=2`, `go vet ./...` and a
`gofmt -l` gate on `ubuntu-latest`, and a separate step installs `libchdr-dev` and
runs `CGO_ENABLED=1 go test -tags chd ./internal/compression ./internal/udpfs` — so
the 5 CHD-gated tests **do** run in CI and are not orphans. No workflow contains a
`-bench` or `-fuzz` step (grep over `.github/workflows/*.yml`: no hits).

## Findings

### GOTEST-01 — `tryTrans2` can never return an error, and `TestSearchesAreBounded` never asserts the bound
- **Category:** 7
- **Locations:** `internal/smb/integration_test.go:65-69`, `internal/smb/limits_test.go:63-93`
- **Problem:** The helper is documented as "trans2 without the t.Fatal, for tests that drive it in a loop", but its body is `p, d := cl.trans2(sub, tParams); return p, d, nil` — the error return is hard-wired to `nil`, and the inner `trans2` already `t.Fatalf`s on a non-success status (`integration_test.go`, `trans2`: `cl.t.Fatalf("trans2 %#x status %#x", …)`). Both callers — the only two uses, at `limits_test.go:84` and `:89` — check `err != nil`, a branch that is unreachable. Worse, the test's stated claim is unasserted: `TestSearchesAreBounded` issues `MaxSearches*8` FIND_FIRST2 requests and then only checks the server still answers. FIND_FIRST2 succeeds whether or not old searches are evicted (eviction is silent, `handlers.go` `evictOldest(…, MaxSearches, …)`), so an implementation that held all 128 listings and grew without bound passes this test exactly as a bounded one does — the heap growth the comment describes (~80 MiB per 2,000 searches) is never measured or inspected. Proof: read of both functions; grep shows `tryTrans2` has no other callers.
- **Fix:** Delete `tryTrans2` and call `trans2` directly (its Fatal already provides the failure the error checks pretend to add); add a real bound assertion to the test — e.g. after the loop, verify via a FIND_NEXT2 on an early search ID that the oldest search was evicted, or expose/inspect the per-connection search count from the same package.
- **Benefit:** A regression that removes search eviction (a 32 MB-board killer, per the test's own comment) currently passes CI; after the fix it would fail.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOTEST-02 — `TestServerPortFallback` never exercises the fallback or any port
- **Category:** 7
- **Locations:** `internal/webui/webui_test.go:638-669`; production behaviour at `internal/webui/webui.go:237-257`
- **Problem:** Production `Serve` with `Port == 0` first tries `DefaultPort` (8082) and only on failure falls back to an OS-assigned port. The test constructs `Port: 0`, starts `Serve`, sleeps 100 ms, cancels, and asserts only that `Serve` returned nil. It never occupies 8082, never reads the bound address, and never asserts which port was bound — so the fallback branch is never entered and a wrong-port bind also passes. Proof (EXECUTED, in the /tmp copy): the production line was mutated to bind `"0"` directly, deleting the default-port attempt entirely; `go test ./internal/webui/ -run TestServerPortFallback` still **passed**.
- **Fix:** Occupy 8082 with a listener first, then assert `Serve` succeeds and the server is reachable on a different, OS-assigned port; also assert the unoccupied case binds 8082.
- **Benefit:** The schema documents "0 uses 8082 with fallback to an OS-assigned port" (`internal/webui/schema.go:169`); today that documented behaviour has no working test despite a test named for it.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### GOTEST-03 — `TestCompressionCacheDefaultsAndDisables` tests struct storage, not defaulting or disabling
- **Category:** 7
- **Locations:** `internal/udpfs/blockdev_test.go:256-276`; the behaviour it names lives at `internal/udpfs/blockdev.go:398-402`
- **Problem:** The test builds servers with `CompressionCache: 0` and `CompressionCache: 8` and asserts `New` stored the value verbatim in `cfg`. It never opens an image. The actual defaulting — `openImage` substituting `compression.DefaultCacheBlocks` when the configured value is 0 — is in a different function the test never calls, and no "disable" value or path is exercised at all. Proof (EXECUTED, in the /tmp copy): the substitution was mutated to `cache = 1`; `TestCompressionCacheDefaultsAndDisables` (and its neighbour `TestNoCompressionStopsAdvertisingContainersAsIso`) still **passed**.
- **Fix:** Drive `openImage` (or an OPEN of a `.cso` through a running server) with cache 0 and assert the opened image's cache limit is `compression.DefaultCacheBlocks`; drop "Disables" from the name or add the case that actually disables.
- **Benefit:** The 0-means-default convention is exactly the kind of silent change that doubles or quarters memory use on a 32 MB board; it is currently unguarded.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### GOTEST-04 — `TestSafeCueNameRejectsInvalidAndOverlongUTF8` has no positive control; a reject-everything stub passes
- **Category:** 7
- **Locations:** `internal/compression/chd_cuebin_test.go:119-126`; production rules at `internal/compression/chd_cuebin.go:378-388`
- **Problem:** The test asserts only two rejections (invalid UTF-8, a 256-byte name). It never asserts that any valid name is accepted, so the function can regress to "reject everything" — breaking every legitimate CUE/BIN pair — and the test stays green. Proof (EXECUTED, in the /tmp copy): `safeCueName` was stubbed to `return false` unconditionally; the test still **passed**. The same gap leaves three of the production rejection rules untested: embedded `"`, `\`, and control characters (`chd_cuebin.go:382-386`). (The test name is also slightly off: the overlong case is 252 ASCII `x`s + `.bin`, not a UTF-8 case.)
- **Fix:** Add positive cases (an ordinary `disc.bin`, a 255-byte name, a non-ASCII-but-valid name) and one case per rejection rule.
- **Benefit:** Converts a one-sided test into one that can fail in both directions; the positive side is the side users hit.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### GOTEST-05 — Windows-only filesystem test can never run in CI
- **Category:** 7
- **Locations:** `internal/filesystem/root_test.go:216-235`; CI at `.github/workflows/edge.yml:37` (test job `runs-on: ubuntu-latest`; the other Edge jobs are also `ubuntu-latest` and `edge-build.yml` builds but does not test)
- **Problem:** `TestEntryRefusesNamesWindowsWouldReinterpret` begins `if runtime.GOOS != "windows" { t.Skip("Windows path normalisation") }`. Every CI job that runs this module's tests is Linux, so the test is skipped on every CI run and on every non-Windows developer machine — it was one of the only 2 skips in the baseline run. The behaviour it guards (Windows stripping trailing dots/spaces so the OS acts on a different entry than the one checked — `"..."` resolving to the parent/root) is security-relevant path handling that currently has zero executed coverage anywhere automated. This is a feature-detection skip where the feature platform is never present in CI.
- **Fix:** Extract the name-rejection check into a platform-independent predicate and test it directly on any OS (keeping a thin Windows integration case), or add a Windows runner for the filesystem package alone.
- **Benefit:** A named, security-motivated check stops being dead coverage; the fix is less code than a new CI platform.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ|EXECUTED — skip observed in the baseline run)

### GOTEST-06 — Three "behaviour" tests assert only that constants lie in a range
- **Category:** 7
- **Locations:** `internal/smb/wire_test.go:157-179` (`TestMaxMessageClearsTheLargestRealFrame`), `internal/smb/wire_test.go:211-220` (`TestDefaultPortIsUnprivileged`), `internal/smb/limits_test.go:157-171` (`TestConnectionSlotsAreNotHeldByIdleSockets`); constants at `internal/smb/wire.go:84` (`DefaultPort = 1111`), `internal/smb/wire.go:105,118` (`MaxMessage`, `MaxConnections`), `internal/smb/server.go:120` (`idleTimeout = 5 * time.Minute`)
- **Problem:** None of the three performs the behaviour in its name. `TestDefaultPortIsUnprivileged` never binds a socket — it asserts `DefaultPort >= 1024`. `TestMaxMessageClearsTheLargestRealFrame` never sends a message — it asserts arithmetic over `MaxMessage` and `MaxConnections`. `TestConnectionSlotsAreNotHeldByIdleSockets` never opens a connection — it asserts `0 < idleTimeout <= 30m`, and its own comment concedes it "asserts the mechanism exists rather than waiting for it". These tests can only fail if someone edits a constant past the bound; no behavioural regression (bind path ignoring `DefaultPort`, dispatcher rejecting a largest-frame message, accept loop never setting a read deadline) can fail them. They are pins on values, presented as tests of mechanisms.
- **Fix:** Keep the constant pins if wanted, but rename them as such (e.g. `TestDefaultPortConstantIsUnprivileged`) and add one behavioural case each: bind with the default port config, round-trip a near-`MaxMessage` frame, and open a silent connection against a server with a test-shortened idle timeout and observe it being dropped.
- **Benefit:** Test names stop claiming coverage that does not exist — the failure mode that lets a reader (or a future audit) mark these areas "tested".
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

### GOTEST-07 — UDPFS test helper `result()` reports a truncated reply as success (0)
- **Category:** 6
- **Locations:** `internal/udpfs/write_test.go:143-148`
- **Problem:** `result(payload)` is the shared reply decoder for the whole `udpfs` test package (used across `write_test.go`, `blockdev_test.go`, `blockonly_test.go`, `fileid_bwrite_test.go`, `handoff_write_test.go`, `pathops_test.go`, `rediscovery_test.go`, `compression_operations_test.go`, `chd_operations_test.go`). For any payload shorter than 8 bytes it returns `0` — which is the protocol's success value. A server regression that truncates a reply therefore satisfies every `result(...) == 0` expectation and every `result(...) <= 0`-style check in the package instead of failing the test; only expectations of a specific negative errno or a positive byte count would notice, and several success-path assertions would then read unrelated bytes or panic on slicing, misreporting the cause. (One caller, `pathOp` in `pathops_test.go`, does length-check before calling `result`; most do not.)
- **Fix:** Make the helper take `t` and `t.Fatalf` on a short payload (it is test-only code; every caller already has a `*testing.T` in scope via the client), or return a sentinel that no expectation accepts.
- **Benefit:** Removes a package-wide mask over exactly the class of bug (short/malformed replies) these wire tests exist to catch.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOTEST-08 — `TestUnknownServiceIDIsStillIgnored` is negative-only and passes with the transport completely dead
- **Category:** 7
- **Locations:** `internal/udpfs/status_test.go:150-173`
- **Problem:** The test sends one DISCOVERY with an unknown service ID and asserts no reply arrives within 500 ms. It performs no positive exchange against the same server instance, so "correctly ignored" is indistinguishable from "request never arrived", "server wedged", or "discovery handling broken for all packets". Proof (EXECUTED): in the baseline run, with every UDP `sendto` in the sandbox blocked (`operation not permitted`), this test **passed** — its assertion was satisfied by a transport on which the server could not have replied to anything. Contrast the neighbouring `TestOrdinaryDiscoveryStillWorksAlongsideStatus` (`status_test.go:109-148`), which does prove liveness, but against a different server instance in a different test.
- **Fix:** On the same server and socket, first complete an ordinary DISCOVERY/INFORM exchange (positive control), then send the unknown-service-ID query and assert silence.
- **Benefit:** The anti-reflector guarantee this test pins becomes a statement about the server, not about the network.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### GOTEST-09 — Duplicated test scaffolding: the same mutex log buffer twice in one package, and CSO fixture builders re-implemented four times
- **Category:** 2
- **Locations:** `internal/udpfs/observability_test.go:22-40` (`synchronizedLogBuffer`) vs `internal/udpfs/session_summary_test.go:22-38` (`lockedBuffer`); further copies at `internal/smb/session_summary_test.go:17-33` and `internal/udpbd/session_summary_test.go:18-34`. CSO/CISO header builders: `internal/compression/image_test.go:13-33` (`writeContainer`), `internal/compression/sizeof_test.go:16-47` (`writeBigIndexCSO`), `internal/compression/corrupt_index_test.go:22-40` (`writeCorruptIndex`), `internal/udpfs/compression_operations_test.go:16-36` (`writeUDPFSContainer`)
- **Problem:** Within the single `udpfs` test package, two differently-named types implement byte-identical mutex-guarded `bytes.Buffer` log capture (`Write`/`String`); the same type is then copied into two more packages. Separately, the 24-byte CISO header + index layout is hand-assembled in at least four test helpers across two packages, each with its own field offsets — a format change (or an offset mistake in one copy) has to be found and fixed four times, and the copies can silently diverge so different tests exercise slightly different containers.
- **Fix:** Keep one log-buffer type per package (delete `synchronizedLogBuffer` in favour of the existing `lockedBuffer` in `udpfs`); promote one container-builder helper per package with parameters for the fields the corrupt/sizeof cases vary (declared size, index gap, magic), instead of four open-coded copies.
- **Benefit:** Less test code to keep correct; one place to fix when the container layout or log-capture needs change. (Cross-package copies of `lockedBuffer` are the weaker half — Go test packages cannot share helpers without an exported test-support package — and are worth less than the same-package duplicate.)
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

### GOTEST-10 — The fuzz target and the benchmark are never run as fuzzing or benchmarking anywhere
- **Category:** 7
- **Locations:** `internal/protocol/packet_test.go:23-30` (`FuzzParseDataPacket`), `internal/udpfs/udpwrite_test.go:338-377` (`BenchmarkUDPBatch`); CI: `.github/workflows/edge.yml:50-82`
- **Problem:** `go test` executes `FuzzParseDataPacket` only against its 3 seed inputs, as an ordinary unit test; no workflow runs `go test -fuzz` for any duration, and no workflow runs `-bench`, so `BenchmarkUDPBatch` — the only performance regression check for the UDP batch path — has never executed in CI. Proof: grep for `bench`/`fuzz` over `.github/workflows/*.yml` returns no hits; the baseline `go test -json` run contains no benchmark result. Both artefacts look like coverage (a fuzz target for the packet parser that faces untrusted datagrams; a benchmark for the hot send path) while functioning, in automation, as one small table test and as dead code respectively.
- **Fix:** Add a short bounded CI step (e.g. `-fuzztime=60s` for `internal/protocol` on a schedule or in the Edge workflow, and `-bench=. -benchtime=1x` as a compile/smoke gate for the benchmark), or delete the benchmark if nobody intends to read its numbers.
- **Justification:** (only if fix ADDS) The added CI time is bounded (~1 minute) and is the only way either artefact produces the signal it exists for; the alternative half of the fix — deletion — adds nothing.
- **Benefit:** The parser that faces malformed network input actually gets fuzzed; the batch benchmark either runs or stops implying a perf gate exists.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ|EXECUTED — grep over workflows; baseline run contents)

### GOTEST-11 — Dead keep-alive line for an unused import in `blockdev_test.go`
- **Category:** 1
- **Locations:** `internal/udpfs/blockdev_test.go:278`
- **Problem:** `var _ = session.Pending // keep the session import meaningful across refactors` exists solely to keep the `session` import compiling; nothing else in the file uses the package (grep of the file shows no other `session.` reference). It is dead code whose comment announces that the import, not any test need, is what is being preserved.
- **Fix:** Remove the line and the import.
- **Benefit:** One less misleading artefact for a reader tracing which session behaviour this file tests (none).
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOTEST-12 — `TestBlockGeometryIsConsistent` asserts identities guaranteed by the implementation's own formulas
- **Category:** 7
- **Locations:** `internal/udpbd/udpbd_test.go:50-65`; production at `internal/udpbd/protocol.go:101-104`
- **Problem:** Production `blockGeometry` is one expression set: `blockSize = 1 << (shift+2); return blockSize, rdmaMaxPayload / blockSize, SectorSize / blockSize`. The test asserts (a) `size == 1<<(shift+2)` — a restatement of the first line; (b) `perSector * size == SectorSize` for shifts {3,5,6,7} — true for exactly the shifts whose block sizes (32/128/256/512) divide 512, which are the only shifts ever passed; and (c) `perPacket * size <= rdmaMaxPayload` — identically true for any integer-division quotient. Unlike its neighbour `TestBlockShiftMatchesReferenceTable`, which pins values from the hardware-validated Python server (a real external oracle), this test has no oracle outside the code it tests: it can catch a formula edit, but it cannot catch the implementation and the expectation being wrong together, and two of its three assertions cannot fail for any values the function can produce.
- **Fix:** Replace the derived assertions with a literal table of expected `(blockSize, blocksPerPacket, blocksPerSector)` per shift, taken from the reference implementation's geometry, as the block-shift test already does.
- **Benefit:** The geometry that decides RDMA packetisation gets an external pin instead of a self-consistency check.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ|INFERRED — the integer-division identity is arithmetic; the "no external oracle" judgement is inferred from the two files)

### GOTEST-13 — `TestSharedHandshakeFixtures` duplicates the hardcoded cases and degrades to a silent skip
- **Category:** 7
- **Locations:** `internal/udpfs/server_test.go:15-49`
- **Problem:** Two weaknesses compound. (1) Duplication: the fixture file it loads (`conformance/fixtures/handshake_cases.json`: standard-zero 0/0, modulo-fresh 0/1, modulo-resumed 7/8, modulo-wraparound 4095/0, nonmatching-fallback 7/0) contains exactly the five cases already hardcoded in `TestClassify` in the same file ({0,0},{0,1},{7,8},{4095,0},{7,0}) — as a Go test it adds no case the hardcoded test lacks; its value is purely cross-implementation sharing of the file. (2) Skip-to-pass: when the file is absent it calls `t.Skipf` and the run is green — and the path (`../../../../conformance/…`) points outside the Go module, so any module-only copy, vendored checkout, or downstream consumer of the module silently loses the test, as happened in this audit's mandated /tmp copy (it was 1 of the 2 baseline skips). Nothing in CI distinguishes "ran with 5 cases" from "skipped".
- **Fix:** Keep the fixture as the cross-language artefact, but make the Go test fail — not skip — when the file is missing in a full checkout (e.g. skip only when an explicit env marker says the module was copied standalone), and log the number of cases executed so a zero-case run is visible.
- **Benefit:** The shared-conformance claim stays honest in exactly the environments (copies, vendoring) where it currently evaporates silently.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ|EXECUTED — skip observed in the baseline; fixture contents compared line by line with the hardcoded table)

## Checked and cleared (suspicions that did not survive verification)

- **CHD-gated tests are orphans** — false. `edge.yml:76-82` installs `libchdr-dev` and runs the `chd`-tagged tests for both affected packages; the testdata (`test.iso`, `test_cd.chd`, `test_dvd.chd`) exists under `internal/compression/testdata/`.
- **`TestStatusEncodingIsFaithfulEvenWhereItIsLossy`** (`internal/smb/wire_test.go`) pins a lossy status encoding — deliberately, and the pin is justified in its own comment: byte-for-byte parity with the reference server matters more than losslessness, and every status in use has the dropped bits clear. Not counted as encoding wrong behaviour.
- **Allocation assertions in `internal/compression/sizeof_test.go`** (runtime `MemStats` deltas) are coarse but have generous margins (a tenth of the index; 8× separation) and passed deterministically in both baseline runs; not counted as tautological or flaky on this evidence.
- **`FuzzParseDataPacket` discarding its results** is the standard crash-oracle fuzz shape, not a vacuity; its problem is only that CI never fuzzes (GOTEST-10).
- **SMB `TestOpenHandlesAreBounded` / `TestTreesAreBounded`** look similar to GOTEST-01 but do assert their bound indirectly and soundly: if reclamation stopped, the repeated opens/connects would start failing within the loop. Only the searches case lacks such a failure signal.

## Files read

All 42 in-scope test files, in full:

- `cmd/ps2servers-edge/main_test.go`
- `internal/compression/cache_budget_test.go`, `chd_cuebin_test.go`, `chd_disabled_test.go`, `chd_enabled_test.go`, `chd_test.go`, `corrupt_index_test.go`, `image_test.go`, `lz4_test.go`, `sizeof_test.go`
- `internal/filesystem/root_test.go`
- `internal/memory/budget_test.go`
- `internal/protocol/packet_test.go`
- `internal/sessionstats/sessionstats_test.go`
- `internal/smb/integration_test.go`, `limits_test.go`, `session_summary_test.go`, `status_test.go`, `wire_test.go`, `write_semantics_test.go`
- `internal/udpbd/session_summary_test.go`, `udpbd_test.go`
- `internal/udpfs/blockdev_test.go`, `blockonly_test.go`, `chd_operations_test.go`, `compression_operations_test.go`, `errno_test.go`, `fileid_bwrite_test.go`, `handoff_write_test.go`, `integration_test.go`, `negotiation_seq0_test.go`, `observability_test.go`, `pathops_test.go`, `rediscovery_test.go`, `server_test.go`, `session_summary_test.go`, `status_test.go`, `transfer_test.go`, `udpwrite_test.go`, `write_test.go`
- `internal/webui/schema_test.go`, `webui_test.go`

Supporting (non-test) files read or grepped only to verify cited symbols/behaviour exist:
`.github/workflows/edge.yml`, `conformance/fixtures/handshake_cases.json`,
`internal/compression/chd_cuebin.go` (`safeCueName`), `internal/smb/wire.go` and
`server.go` (constants), `internal/smb/handlers.go` (`evictOldest`/`MaxSearches` use),
`internal/udpbd/protocol.go` (`blockGeometry`), `internal/udpfs/blockdev.go`
(`openImage` cache defaulting), `internal/webui/webui.go` (port fallback) and
`schema.go` (documented port behaviour).

## Files not read (in scope)

None. Every `*_test.go` file in scope was read in full. Binary fixtures under
`internal/compression/testdata/` (`test.iso`, `test_cd.chd`, `test_dvd.chd`) were
listed but not read — they are data, not test code. Production files other than the
spot-checks listed above were not read; this section's scope was the test suite.
