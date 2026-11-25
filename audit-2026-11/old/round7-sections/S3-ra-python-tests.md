# S3 — RetroAchievements-family Python tests (`tests/`) — Round 7, LESS-NOT-MORE

- Repo: `NathanNeurotic/PS2-Servers`, clone `~/workspace/audit-clones-2026-11-13/PS2-Servers`, pin `c5f021c` (READ: `git rev-parse --short HEAD` = `c5f021c`; `git status` clean before and after).
- Scope: test-suite defects only. Shipped code was read only where a test's meaning depends on it (flagged below); PS2SERVERS-001…069 stand and are not re-audited here.
- Method: every line of all 24 assigned files read (4,410 lines total, `wc -l` sum; 243 `def test_` methods). CI behaviour read statically from `.github/workflows/ci.yml`. READ = line seen in this pass; INFERRED = consequence drawn from those lines.
- Provisional IDs are S3-01… — not PS2SERVERS numbers.

## CI map (READ, `.github/workflows/ci.yml`) — needed by several findings

| Job | Lines | What runs |
|---|---|---|
| `achievements-engine` | ci.yml:13, :37-39 | Builds the native engine (`build/build_achievements.py`), then runs exactly 5 modules: `test_retroachievements test_game_library test_achievement_viewer test_achievement_loader test_discord_presence`. |
| `python-checks` | ci.yml:54, :97 | Full discovery (`unittest discover -s tests -t .`) on ubuntu-latest, **without** building the native engine and **without** building libchdr first. Later, after discovery: libchdr smoke build (ci.yml:144) plus an explicit step (ci.yml:148-151) asserting `LIBCHDR_AVAILABLE` and re-running the two named real-CHD tests in `test_ra_compressed_hash` and one in `test_disc_identity`. |
| `windows-storage` | ci.yml:50,52 | Unrelated modules only. |

Consequences: in `python-checks`, every engine-gated and libchdr-gated test below *skips*; coverage for them exists only in the jobs/steps named above. Whether a skip can turn a whole job green depends on whether the gated class carries the family's own hard-fail pattern (compiler-gated classes do — see Checked-and-sound §2; the engine-gated class does not — S3-01).

---

## (1) Per-file ledger

Lines / tests = `wc -l` / `grep -c "def test_"`. Verdict one line each; details in §2/§3.

| File | Lines | Tests | Ledger verdict |
|---|---|---|---|
| tests/test_retroachievements.py | 492 | 25 | Wire/Caduceus tests real (mock socket, exact wire strings). Native class wholly gated at :254 — **S3-01**. Polling `except …: pass` loops are deadline-bounded with `self.fail` after (sound, §3). |
| tests/test_ra_owned_service.py | 501 | 20 | Strongest file: real loopback UDP, real evaluator in second class. Client scaffolding duplicated verbatim across its two classes — **S3-06**; native `setUpClass` duplicated with evaluator — **S3-05**. |
| tests/test_ra_evaluator.py | 399 | 23 | Real pinned rcheevos via compiled library; compiler guard hard-fails on Linux CI (:27-29, sound). `setUpClass` boilerplate — **S3-05**. No vacuous test found. |
| tests/test_ra_supervisor.py | 320 | 13 | Mock-heavy by design (unit isolation; real-service coverage lives in owned_service — §3). One helper swallows all exceptions — **S3-04**. |
| tests/test_ra_account_worker.py | 300 | 18 | Real spawn/reaping, generation-safe commits; `tearDown` asserts no leaked children. Sound. |
| tests/test_ra_protocol.py | 245 | 21 | Pure parser/assembly vectors, no mocks at all; truncation loop asserts every prefix via `subTest`+`assertRaises`. Sound; its `packet()` is the family's shared fixture (imported by 4 other files). |
| tests/test_ra_session_client.py | 224 | 10 | Real client against fake `Opener` transports; signatures/payload fields asserted exactly. `Opener` redefined 7× — **S3-07**. |
| tests/test_ra_compressed_hash.py | 216 | 9 | CSO/CHD-hash tests mostly real. Two ZSO tests mock the availability flag they claim to test without — **S3-02**. Two real-CHD tests skip on `ImportError` but are re-run under a hard assert in CI (§3). |
| tests/test_ra_account.py | 77 | 4 | Real `AccountClient`/`Transport` against fake openers; pacing/backoff/sanitisation asserted. `Opener` redefined 4× — **S3-07**. |
| tests/test_ra_credentials.py | 88 | 7 | Real platform store round-trip. One test is a bare `return` on Windows — reported as pass, executes nothing — **S3-03**. Symlink skip at :70-71 is a proper `skipTest` (sound). |
| tests/test_ra_dependency.py | 63 | 3 | First two tests contain no `assert*` at all: oracle is `subprocess.run(..., check=True)` exit status (sound, §3). Compiler guard copy-pasted 3× in 63 lines — part of **S3-05**. |
| tests/test_ra_notifications.py | 129 | 7 | Pure tracker/poller logic, deterministic `now=` injection, exact event lists asserted. Sound. |
| tests/test_ra_overview.py | 107 | 8 | Pure `view_model` mapping + bounded-payload checks; fetch tests mock only transport. Sound. |
| tests/test_ra_receiver.py | 121 | 9 | Deterministic receiver with injected clock; ownership/lease/budget cases all assert replies/values. Sound. |
| tests/test_ra_resolver_process.py | 168 | 7 | Real spawn, stuck/crash/oversized/partial-write children; `tearDown` asserts no leaked children. POSIX-only test properly `skipIf` at :93. Sound. |
| tests/test_ra_session.py | 95 | 7 | Pure `SessionTracker` state machine with explicit timestamps. Sound. |
| tests/test_ra_sets.py | 124 | 9 | Real `qualify_set`/`RASetClient`; its `responses()` is a shared fixture (imported by evaluator, owned_service, dependency). `Opener` redefined 4× — **S3-07**. |
| tests/test_ra_sounds.py | 107 | 6 | Real WAV files on disk; symlink skip at :51-52 is a proper `skipTest(str(error))`. Sound. |
| tests/test_ra_submissions.py | 63 | 3 | Bounded-queue consumer with fake workers; call lists and offer booleans asserted. Sound (small but complete). |
| tests/test_ra_watchlist.py | 82 | 5 | Real binary layout vectors; `watch_file()` is a shared fixture (imported by 4 other files). Sound. |
| tests/test_ra_web.py | 151 | 9 | Real HTTP server on loopback, real SSE/logout/403 paths. Sound. |
| tests/test_achievement_loader.py | 48 | 3 | `fetch`/`LOADERS` mocked, checksum/provenance logic real and asserted on files written. Sound — mocking the network is the subject boundary, not the subject. |
| tests/test_achievement_viewer.py | 86 | 5 | Real viewer proxying to a real local HTTP stub; routing/403/503 asserted, upstream request log asserted empty where required. `log_message(...): pass` at :27 is log silencing, not a swallowed assertion. Sound. |
| tests/test_discord_presence.py | 204 | 12 | Activity/privacy logic real; IPC transport mocked except the Windows-only real named-pipe test, properly `skipUnless(os.name=="nt")` at :157 and run by the `achievements-engine` job's module list (ci.yml:39). Sound. |

No file in the section imports deleted/renamed code (READ: every `launcher.*` / `tests.*` import in the 24 files was grep-checked against the tree — `launcher/ra_*.py`, `launcher/achievements.py` incl. `engine_path` :22, `available_account_port` :69, `claim_service` :50, `bootstrap_owner` :80, `launcher/servers.py:_achievements_argv` :689, `launcher/achievement_viewer.Viewer`, `launcher/achievement_loader.blob_id/export_loader` all exist at the pin). No top-level helper/fixture in any of the 24 files is defined-but-never-used (AST/reference census; `packet`, `watch_file`, `responses`, `fixture`, `make_indexed` are additionally imported cross-file, e.g. `tests/test_disc_identity.py` and `tests/test_orbit_reference_wire.py` — outside this section, noted only as usage evidence).

---

## (2) Candidate findings

### S3-01 / Native-engine test class can skip wholesale and still report green — no CI hard-fail unlike its sibling classes
- Category: Vacuous-in-CI (silent skip)
- Locations: tests/test_retroachievements.py:254 (`@unittest.skipUnless(engine_path().is_file(), "build the native achievement engine first")` on `NativeEngineTests`, 5 tests: :255, :316, :387, :403, :418); .github/workflows/ci.yml:37-39, :97
- Problem: READ — the whole class is gated on the engine binary existing. In `python-checks` (full discovery, ci.yml:97) it always skips, by design, because `achievements-engine` builds the engine and runs this module (ci.yml:37-39). But unlike the compiler-gated classes in the same family — tests/test_ra_evaluator.py:27-29, tests/test_ra_owned_service.py (EvaluatedOwnedServiceTests.setUpClass, :192ff), tests/test_ra_dependency.py:17-19 — this class has **no** `GITHUB_ACTIONS`+Linux hard-fail. INFERRED: if `engine_path()` ever points at the wrong location (rename/move of the built artefact) while `build_achievements.py` still exits 0, the achievements-engine job runs 5 modules in which every native test skips and the job is green with zero native coverage — the exact failure mode the sibling guards were written to prevent.
- Fix: Add the family's existing guard shape inside `NativeEngineTests.setUpClass`: on `GITHUB_ACTIONS=true` + Linux, `self.fail(...)` instead of skipping when `engine_path()` is not a file. ~4 lines, no new mechanism.
- Benefit: A path/build regression cannot silently delete the only native-engine smoke coverage.
- Effort: S
- Risk: Low — local runs without an engine still skip; only CI-on-Linux changes.
- Confidence: High on the guard asymmetry (READ); Medium on likelihood (requires an `engine_path()`/artefact drift that the build step itself doesn't catch).

### S3-02 / "Without LZ4" ZSO tests mock `LZ4_AVAILABLE=True` — the no-LZ4 claim is never tested, and no LZ4-compressed ZSO block is ever hashed
- Category: Mocked-away subject / misleading test
- Locations: tests/test_ra_compressed_hash.py:95-106 (`test_ziso_uncompressed_blocks_match_iso_hash_without_lz4`), :108-117 (`test_zso_opl_layout_matches_iso_hash`), esp. `mock.patch.object(zso, "LZ4_AVAILABLE", True)` at :105 and :116; fixture `make_indexed` at :53-75; context READ in shipped code (not re-audited): udpfs_server/compressed_iso/zso.py:53-54
- Problem: READ — (a) The test named *without_lz4* and commented "A ZISO with raw index blocks needs no decompressor. Source-only CI may not have the lz4 dependency packaged in production builds" (:98-100) forces the availability flag to `True` before asserting the hash. The wrapper's constructor refuses to open *any* ZSO/ZISO file when the flag is false (zso.py:53-54, `raise ImportError` before header parsing, irrespective of whether blocks are raw), so the behaviour a no-LZ4 user actually gets — refusal, not a hash — is the one behaviour this test cannot observe. The patch doesn't simulate absence; it simulates presence. (b) `make_indexed` only ever LZ4-compresses nothing: `compress_it` is true only for `CISO` magic (:66), so every ZSO/ZISO block in both tests is stored raw (high bit set) and the LZ4 decompression path is exercised by zero tests in this file. (c) The 6-line `sys.path` insertion + import block is copy-pasted verbatim at :100-105 and :111-116.
- Fix: LESS-style: rename/split honestly — keep one raw-block test but assert it under the *real* flag and drop both `LZ4_AVAILABLE` patches (CI installs `lz4`, ci.yml python-checks deps, so the flag is genuinely true there); if raw-without-LZ4 support is intended, that is a shipped-code decision for the parent, and the test should then assert it *without* the patch and fail until supported. Delete the duplicated import block by importing `zso` once at module top.
- Benefit: Removes a test whose name asserts the opposite of what it verifies; stops a future reader trusting raw-ZSO works in LZ4-less production builds.
- Effort: S (test-only part)
- Risk: Low
- Confidence: High — all elements READ at the lines cited, including the constructor gate.

### S3-03 / POSIX-permissions test `return`s on Windows: counted as a pass while executing zero assertions
- Category: Vacuous test (invisible skip)
- Locations: tests/test_ra_credentials.py:76-78
- Problem: READ — `test_posix_insecure_permissions_are_rejected` begins `if os.name == "nt": return`. On Windows (the `achievements-engine`/`windows-storage` runners are Windows, and local Windows dev) unittest records this as *ok*, not *skipped* — unlike the same file's proper `skipTest` at :70-71 and this family's proper decorators elsewhere (e.g. test_retroachievements.py:55, test_discord_presence.py:157). The comment's justification (DPAPI exercised by the round-trip test) is reasonable; the reporting is not: pass counts overstate coverage on exactly the platform where the branch runs.
- Fix: Replace the bare `return` with `self.skipTest("POSIX file-mode policy")` (or `@unittest.skipIf(os.name == "nt", ...)` on the method). One line.
- Benefit: Skips become visible in CI summaries instead of phantom passes.
- Effort: S
- Risk: None
- Confidence: High (READ).

### S3-04 / Supervisor state-HTTP probe swallows every exception, so its only failure signal is an unexplained empty box
- Category: Swallowed failure in test helper (`except → pass`)
- Locations: tests/test_ra_supervisor.py:287-297 (`check_port_and_alive`, `except Exception: pass` at :296-297); assertions that depend on it at :316-322
- Problem: READ — this is the family's only bare `except Exception: pass` outside deadline-bounded socket polling loops. The helper is passed to real `run_owned_runtime` as the owner-alive callback; every HTTP fetch/parse failure (wrong port file, server not up, malformed JSON) is discarded, and the test later fails only as `assertTrue(port_box)` with no cause, URL, or last error — on a flaky run there is nothing to diagnose from. It is not vacuous (the outer assertions at :316-322 do catch total failure), so this is a diagnosability defect, not a false pass.
- Fix: Record the last exception (`errors.append(repr(error))`) and include it in the final assertion message / `self.fail(...)`. ~3 lines, no new helper.
- Benefit: The one genuinely integration-flavoured supervisor test fails with its cause attached.
- Effort: S
- Risk: Low
- Confidence: High on the swallow (READ); the test's pass/fail correctness itself is sound.

### S3-05 / Native-library build + CDLL-unload boilerplate duplicated across three files; compiler guard pasted five times
- Category: Duplication (shared fixture missing)
- Locations: tests/test_ra_evaluator.py:24-51 (`EvaluatorTests.setUpClass`, 28 lines); tests/test_ra_owned_service.py:192-227 (`EvaluatedOwnedServiceTests.setUpClass`, same body plus one extra CDLL patcher for `ra_sets`); compiler guard at tests/test_ra_evaluator.py:25-29, tests/test_ra_owned_service.py:198-204, tests/test_ra_dependency.py:16-19, :26-29, :36-39 (three near-identical 5-line copies inside one 63-line file)
- Problem: READ — the build-the-pinned-library / track-every-`CDLL` / `FreeLibrary`|`dlclose`-on-cleanup sequence is written out twice, and the "no compiler → fail on Linux CI, skip locally" guard five times. The two `setUpClass` bodies already differ in exactly one respect (owned_service patches a second module), which is how duplicated fixtures drift: a fix to the unload discipline (the comment at evaluator :33-35 explains a real Windows DLL-retention hazard) must be made in two places or the hazard returns in one class.
- Fix: One shared helper module under `tests/` (the family already shares fixtures this way — `packet`, `watch_file`, `responses`): e.g. `build_native_library(testcase_cls, patch_modules=(...))` returning the library path and registering the unload cleanup; dependency's three guards become one call each. Net ≈ −35 lines.
- Benefit: Single place owns the compiler guard and the DLL-unload discipline.
- Effort: S–M
- Risk: Low — pure test scaffolding; both classes must keep building into separate temp dirs (parameter, not shared state).
- Confidence: High (side-by-side READ).

### S3-06 / Loopback client scaffolding (`start`/`request`/`ready` + socket setUp/tearDown) duplicated verbatim within test_ra_owned_service.py
- Category: Duplication
- Locations: tests/test_ra_owned_service.py:14-45 (`OwnedServiceTests`) vs :228-262 (`EvaluatedOwnedServiceTests`) — `start` :29-33 ≡ :245-249 (differing only in `library=self.library`), `request` :35-37 ≡ :251-253, `ready` :39-45 ≡ :255-261 (character-identical), plus near-identical socket `setUp`/`tearDown` blocks
- Problem: READ — ~30 lines exist twice in one file. Any change to the polling discipline (timeout, WAIT handling) made in one class silently leaves the other class testing with the old discipline.
- Fix: Extract a small mixin/base class in the same file holding `setUp`/`tearDown`/`request`/`ready` and a `start()` that passes `library=getattr(self, "library", None)`. Net ≈ −25 lines, no new file.
- Benefit: One polling implementation for both the plain and evaluated services.
- Effort: S
- Risk: Low
- Confidence: High (verbatim READ).

### S3-07 / Fake `Opener` transport class redefined 15 times across three files
- Category: Duplication
- Locations: tests/test_ra_account.py:16, :34, :48, :71 (4×); tests/test_ra_sets.py:71, :91, :102, :115 (4×); tests/test_ra_session_client.py:67, :99, :134, :149, :170, :185, :208 (7×)
- Problem: READ — fifteen local `class Opener: def open(self, request, timeout): …` definitions, each 5-9 lines, differing only in the canned body / exception / request-recording list. ~90 lines of near-identical scaffolding obscure the per-test payloads that are the actual test data, and a transport-contract change (e.g. opener must also expose a status attribute pattern) has to be hunted through 15 copies. This is the same pattern the family already solved for `packet`/`watch_file`/`responses` by importing one definition.
- Fix: One shared `fake_opener(bodies_or_error, requests=None)` factory in an existing shared test module (or a new `tests/ra_fake_transport.py`), returning an opener object; each call site shrinks to one line plus its payload. Net ≈ −60 lines.
- Benefit: Payloads stand out; one place defines the opener contract all three clients are tested against.
- Effort: M (15 call sites, mechanical)
- Risk: Low — must preserve the two variants that raise (`AssertionError` "should not be contacted" in sets/session_client cancellation tests, `OSError` with reflected-secret text in sets) as factory options, not defaults.
- Confidence: High (census READ).

---

## (3) Checked-and-sound (weak-but-real, or suspicious-looking but verified)

1. **Real-CHD skips are backed by a hard CI gate.** tests/test_ra_compressed_hash.py:123-124 and :150-151 `skipTest` on `ImportError` look like S3-01, but ci.yml:144-151 builds libchdr after discovery, asserts `LIBCHDR_AVAILABLE`, and re-runs exactly those two test IDs by name. A missing decoder fails that step. Sound. (Residual, not a finding: local/non-CI runs still skip silently — accepted pattern in this repo.)
2. **Compiler-gated classes hard-fail where it matters.** tests/test_ra_evaluator.py:27-29, tests/test_ra_owned_service.py EvaluatedOwnedServiceTests.setUpClass, tests/test_ra_dependency.py:17-19/:27-29/:37-39: on `GITHUB_ACTIONS=true` + Linux, missing compiler is an `AssertionError`/`fail`, not a skip. This is the correct pattern — and the contrast that makes S3-01 a finding.
3. **Assertion-free dependency tests have a real oracle.** tests/test_ra_dependency.py:15-23 and :25-33 contain no `assert*`; failure is `subprocess.run(..., check=True)` raising on the conformance scripts' non-zero exit. The third test (:35-63) does assert byte-exact watchlist hex per case. Sound.
4. **`except …: pass` polling loops in native tests are bounded and fail loudly.** tests/test_retroachievements.py:280-281 and :461 swallow only `socket.timeout`/`ConnectionResetError` inside loops that call `self.fail(...)` on deadline or process exit. Sound. Similarly tests/test_achievement_viewer.py:27 `log_message: pass` is HTTP log silencing.
5. **Platform skips elsewhere are proper, visible skips.** tests/test_retroachievements.py:55 (`skipUnless nt`), :386/:402 (`skipIf nt`), tests/test_ra_credentials.py:70-71, tests/test_ra_sounds.py:51-52, tests/test_ra_resolver_process.py:93, tests/test_discord_presence.py:157 — all `skipTest`/decorators with reasons, none unexplained or permanent. The discord named-pipe test is in the achievements-engine module list (ci.yml:39), so it does run on Windows CI.
6. **Supervisor mocking does not mock away the subject.** tests/test_ra_supervisor.py replaces `OwnedService`/`AccountWorker`/`CredentialStore` with mocks, but its subject is `run_owned_runtime`'s orchestration (call order, cancellation, logout revocation), and the real service is covered over real loopback UDP in tests/test_ra_owned_service.py (both classes) and the real evaluator in tests/test_ra_evaluator.py. Isolation, not vacuity. Likewise tests/test_achievement_loader.py mocks only network `fetch`, and tests/test_ra_overview.py mocks only HTTP transport.
7. **No zero-assertion test methods.** AST census over all 243 tests: every test contains `assert*`/`fail`/`assertRaises`, except the two `check=True`-oracle tests in item 3 and the platform branch in S3-03. Assertions inside loops were spot-checked: protocol truncation (every prefix, `subTest`), watchlist invalid tables, receiver telemetry budgets — all loops are over fixed collections and the assertions execute unconditionally per iteration; post-loop assertions guard the polling loops in owned_service/notifications.
8. **No tests of deleted/renamed code; no dead helpers.** All imports resolve at the pin (see §1 note); every module-level helper is referenced, and `packet`/`watch_file`/`responses`/`fixture`/`make_indexed` are shared cross-file — the family's existing fixture pattern that S3-05/S3-07 ask to extend, not invent.
9. **Duplicate hash assertion is a cache check, not filler.** tests/test_ra_compressed_hash.py:91-92 calls `hash_image` twice with the same expectation — second call exercises the cached path. Sound.
10. **Early return with an assertion is sound.** tests/test_retroachievements.py:79-85: if the port bind fails (TIME_WAIT), the test asserts `available_account_port() != 18196` *before* returning; both branches assert. Not S3-03's pattern.

---

*Totals: 24 files, 4,410 lines read, 243 test methods. Candidates: 7 (S3-01…S3-07). Clone left unmodified (`git status` clean on exit).*
