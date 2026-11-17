# RiptOPL vendor continuation findings

Snapshot 679d3d8626dd09a913e7081101418e337234fe7c. In progress; exact reviewed ranges in ript_vendor-progress.json.

### RIPTOPL-400 / Delete the retired socket compatibility implementation / Categories 1, 7

- **Location(s):** `RiptOPL/third_party/ps2sdk-socket/socket.c:1-471`; `RiptOPL/third_party/ps2sdk-socket/fdman.h:1-38`; retirement evidence `RiptOPL/third_party/ps2sdk-socket/UPSTREAM:4-9`; obsolete instructions `RiptOPL/third_party/ps2sdk-socket/README.md:5-7`; active build `RiptOPL/tools/build_edition.py:125-127,253-257`. All cited source/header contents read.
- **Problem:** The native SDK migration retired the fallback socket archive, but the repository still contains its entire 509-line implementation/header and instructions claiming that archive is compiled. The only current build reference copies provenance files, and repository source/build searches found no consumer of these implementation files.
- **Fix:** Delete `socket.c` and `fdman.h`; remove or correct the stale README claims. Keep accurate provenance/notices where still needed.
- **Justification:** Pure deletion of a documented retired implementation; no replacement dependency, fallback, abstraction or logging.
- **Benefit:** **Measured source reduction: 509 lines / 11,061 bytes** for the two implementation files. No runtime/ELF reduction is claimed because they are already absent from the build graph.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for retirement/build/source evidence; absence of external manual consumers is INFERRED.

### RIPTOPL-401 / Stop retaining and compiling Mbed TLS modules disabled by both shipped configurations / Categories 1, 7

- **Location(s):** active wildcard `RiptOPL/tools/build_edition.py:109-118,132-141`; exact configs `RiptOPL/third_party/mbedtls/riptopl_mbedtls_config.h:13-83`, `RiptOPL/third_party/mbedtls/riptopl_mbedtls_slim_config.h:15-70`; representative disabled modules read completely: `RiptOPL/third_party/mbedtls/library/entropy_poll.c:1-233`, `RiptOPL/third_party/mbedtls/library/padlock.c:1-157`, `RiptOPL/third_party/mbedtls/library/timing.c:1-152`, `RiptOPL/third_party/mbedtls/library/mps_trace.c:1-112`, `RiptOPL/third_party/mbedtls/library/ecp_curves_new.c:1-9`. Complete measured candidate list and per-configuration symbol evidence: `ript_vendor-build-closure.json` (machine compilation/dependency evidence, not a claim that every candidate's inactive body has already been semantically read).
- **Problem:** Both edition paths compile all 109 vendored C files although 55 define no symbols under either configuration. This includes unused TLS servers, file-backed storage, alternate ciphers, diagnostic/version helpers and architecture accelerators; these files add source/compile work while providing no shipped functionality.
- **Fix:** Remove the 55 always-disabled C files identified in the saved build-closure list, retaining the same active configuration and all headers still required by retained code. Remove the vendor test's obsolete requirement that unused `error.c` must exist and update the vendored-subset inventory. A still smaller build-only step is to replace the wildcard with the measured active source list; do not rewrite the TLS implementation.
- **Justification:** Deletes inactive complete modules and their compilation; no new dependency, crypto policy, compatibility fallback, wrapper or logging. Removing headers requires its own include-closure check because active code can include an inactive module's declarations.
- **Benefit:** **Measured source candidate reduction: 36,695 lines / 1,213,775 bytes across 55 C files**, and 55 fewer translation units per TLS build. In a host link of the existing `tests/ratls/host_main.c` plus actual `ratls.c`, omitting all empty objects produced byte-identical `.text`, `.rodata` and `.data` sections under both configurations (RA retains 54 nonempty objects; slim 34). No PS2 ELF/RAM or elapsed build-time saving is claimed; disabled files already contribute no runtime code.
- **Effort:** M. **Risk:** Med (vendored-subset and host-test maintenance). **Confidence:** READ for configs/build evidence, measured host compilation/link comparison; target build-time improvement INFERRED.

### RIPTOPL-402 / Delete the orphan Mbed TLS build recipes / Categories 1, 7

- **Location(s):** `RiptOPL/third_party/mbedtls/include/CMakeLists.txt:1-22`; `RiptOPL/third_party/mbedtls/library/CMakeLists.txt:1-379`; `RiptOPL/third_party/mbedtls/library/Makefile:1-410`; actual build `RiptOPL/tools/build_edition.py:109-118,132-141`; vendor inventory `RiptOPL/third_party/mbedtls/README.md:13-17`. All three recipes read completely, including inactive/platform branches and comments.
- **Problem:** The vendored subset keeps three unused upstream build recipes even though RiptOPL builds the C files directly through ps2build and the existing host test uses direct compiler calls. These recipes name omitted upstream generators/framework/3rdparty files (for example `Makefile:189` includes an absent `../3rdparty/Makefile.inc`), so they also advertise an unusable alternate build entry point.
- **Fix:** Delete these three unused recipes from the vendored subset and state its one actual build entry point in the existing README.
- **Justification:** Pure deletion; retain the source files and generated artifacts actually needed by ps2build/direct host tests. No additional build system or compatibility branch.
- **Benefit:** **Measured: 811 lines / 24,259 bytes** removed across the three recipes; no ELF/RAM or active-build-time saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for current build paths and missing inputs; absence of untracked external callers INFERRED.

### RIPTOPL-403 / Delete the unused experimental MPS reader / Categories 1, 3, 8

- **Location(s):** `RiptOPL/third_party/mbedtls/library/mps_reader.c:1-538`; `RiptOPL/third_party/mbedtls/library/mps_reader.h:1-366`; `RiptOPL/third_party/mbedtls/library/mps_common.h:1-181`; `RiptOPL/third_party/mbedtls/library/mps_error.h:1-89`; `RiptOPL/third_party/mbedtls/library/mps_trace.h:1-154`. All five files read completely. Experimental status is stated at `mps_error.h:16-24`; compilation trigger is `mps_reader.c:10`.
- **Problem:** Enabling TLS 1.3 compiles this separate fragment/accumulator state machine, but no shipped TLS or RiptOPL source calls its public functions or includes its reader API. Its own TODO describes MPS as an experimental component inaccessible from the public API; the actual TLS implementation uses its existing record/message code.
- **Fix:** Delete the unused MPS reader and its unreferenced headers. Remove `mps_trace.c` as already covered by RIPTOPL-401; do not add another fragment abstraction to integrate this unfinished subsystem.
- **Justification:** Pure deletion of a caller-free experimental subsystem and its tracing/configuration helpers. Existing TLS 1.3 behavior remains in the active TLS implementation.
- **Benefit:** **Measured: 1,328 additional lines / 52,392 bytes** across the five files, excluding the 112-line trace C file already counted in RIPTOPL-401. Static-archive linking normally leaves the unreferenced reader object out, so no PS2 ELF/RAM saving is claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for source status and repository caller/include search; external untracked users INFERRED absent.

### RIPTOPL-404 / Delete the unwired PSUManager verification path / Categories 1, 7, 8

- **Location(s):** `RiptOPL/third_party/PSUManager/src/core/CMakeLists.txt:1-13`; `RiptOPL/third_party/PSUManager/src/core/PsuArchive.cpp:1-200`, `RiptOPL/third_party/PSUManager/src/core/PsuArchive.h:1-54`, `RiptOPL/third_party/PSUManager/src/core/PsuDate.cpp:1-87`, `RiptOPL/third_party/PSUManager/src/core/PsuDate.h:1-19`, `RiptOPL/third_party/PSUManager/src/core/PsuFormat.h:1-57`; `RiptOPL/third_party/PSUManager/src/core/tests/PsuArchiveTests.cpp:1-142`; `RiptOPL/.github/scripts/verify_psu_with_psumanager.cpp:1-80`; actual production PSU writer/validator `RiptOPL/.github/scripts/package_release_app.py:150-210,261-265`. All cited C/C++/build files read completely; producer/validator ranges read directly.
- **Problem:** The preserved C++ core is referenced only by an independent verifier executable and its own uninvoked CMake test, and the verifier has no current caller in tracked code, tools or workflows. Release packaging writes and validates PSU records directly in Python, so the extra library, writer/extractor/date APIs and verifier currently provide no executed check despite documentation saying CI uses them.
- **Fix:** Delete the unused C++ verifier and the unused vendored core/tests; correct the existing documentation to describe the Python packaging/verification actually performed. Preserve accurate historical project credits.
- **Justification:** Removes an unwired feature and unused vendored library instead of adding a new build/dependency/invocation solely to keep it alive. The active Python PSU checks already remain in the actual package path.
- **Benefit:** **Measured: 652 source/build/test lines / 21,692 bytes** across eight files, plus any obsolete explanatory text chosen for removal. No console ELF/RAM saving is claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for all local source/build references and current packaging path; absence of external manual verifier users INFERRED.

### RIPTOPL-405 / Remove the unused legacy HKDF API from the RA configuration / Categories 1, 3

- **Location(s):** `RiptOPL/third_party/mbedtls/riptopl_mbedtls_config.h:40-56`; `RiptOPL/third_party/mbedtls/library/hkdf.c:1-161`; `RiptOPL/third_party/mbedtls/include/mbedtls/hkdf.h:1-124`. Both implementation and API documentation read completely.
- **Problem:** RA enables the separate legacy `MBEDTLS_HKDF_C` module, but its TLS/PSA configuration uses PSA's key-derivation implementation and no shipped source references the legacy `mbedtls_hkdf*` API. The module is compiled and retained in the vendor tree without a consumer; the saved object-dependency closure independently confirms `hkdf.c` is unreachable from production `ratls.c` and updater SHA-256 roots.
- **Fix:** Remove the unused `MBEDTLS_HKDF_C` define and the legacy HKDF source/header from this vendored subset. Keep the PSA HKDF support used by TLS 1.3.
- **Justification:** Deletes a duplicate unused API implementation; no replacement KDF, new dependency or wrapper.
- **Benefit:** **Measured source candidate: 285 lines / 9,171 bytes**, plus one configuration line and one fewer compiled RA object. Static-archive linking already excludes this object, so console ELF/RAM saving is not claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for configuration/reference evidence and measured host object closure; untracked external users INFERRED absent.

### RIPTOPL-406 / Preserve a negative base sign during in-place modular exponentiation / Category 6

- **Location(s):** `RiptOPL/third_party/mbedtls/library/bignum.c:1676-1724`; API contract `RiptOPL/third_party/mbedtls/include/mbedtls/bignum.h:883-915`. Both entire files read, including inactive branches/comments.
- **Problem:** The API permits the destination to alias the base, but the implementation sets `X->s = 1` and later checks `A->s` to decide whether to correct an odd power of a negative base. When `X == A`, that assignment has already destroyed the sign: the source trace for base −2, exponent 3, modulus 5 yields 3 instead of 2.
- **Fix:** Save the original base sign before modifying the destination and use that saved value for the final correction.
- **Justification:** One local scalar is needed to preserve information that the existing implementation overwrites; no dependency, fallback or abstraction.
- **Benefit:** **INFERRED correctness benefit:** makes the documented in-place API agree with the non-aliased operation for negative bases and odd exponents. No negative-base trigger in RiptOPL's current TLS/updater call graph has been established, and no console security impact or performance saving is claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for the alias contract and overwritten-sign control flow; example is a source/mathematical trace, not an executed regression test.
