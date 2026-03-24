# POPSLoader Regression Matrix

Last updated: 2026-03-24
Target branch: `BETA-9-RECOVERY-BACKUP-CHECKPOINT-PROFILES-PLAY`

## Scope
This matrix tracks current behavior across:
- settings load/save/apply transaction flow,
- launch path validation and error feedback,
- USB/MMCE/MX4SIO/HDD page behavior,
- `mc?:/` alias path resolution,
- currently unimplemented menu options (`HDD (exFAT)`, `SMB (v1)`),
- release package validation gates.

## Automated CI Gates
| ID | Area | Source | Pass Criteria |
|---|---|---|---|
| CI-01 | Build | `.github/workflows/compilation.yml` | `make clean elfloader all` succeeds |
| CI-02 | Boot script syntax/newline | workflow step `Validate etc/boot.lua` | `etc/boot.lua` exists, ends with newline, parses with `luac`/`lua` when available |
| CI-03 | Release package assembly | workflow packaging step | ZIP includes expected tree rooted at `PS1_POPSLOADER/` + `POPS/` |
| CI-04 | Release manifest exactness | workflow python verifier | exact expected file set; no extra/missing files |
| CI-05 | Legacy payload rejection | workflow python verifier | no `POPS/*.tm2` entries present |

## Manual Runtime Matrix

### Settings and persistence
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| S-01 | Defaults with missing settings file | Remove `mc0:/POPSTARTER/.pldrs` | Start app and open Settings | Defaults load without crash |
| S-02 | Staged edits are not immediate writes | Change settings rows but do not leave Settings | Hard-exit app | Prior persisted values remain |
| S-03 | Commit on exit | Change profile/paths/BDMA and confirm or leave | Reopen Settings | Values persist and reload |
| S-04 | Save failure feedback | Make `mc0:/POPSTARTER` unavailable | Leave Settings with changes | User sees explicit save/apply error notification |
| S-05 | BDMA mode restore from marker | Prepare `.pldr_bdma_mode` marker | Boot and open Settings | selected BDMA mode reflects effective marker state |

### Launch and path handling
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| L-01 | Missing POPStarter path | Configure nonexistent POPStarter path | Launch game | UI shows `Cant find POPSTARTER ELF` message |
| L-02 | Missing DKWDRV path | Configure nonexistent DKWDRV path | Launch Disc option | UI shows `Cant find DKWDRV ELF` message |
| L-03 | `mc?:/` POPStarter alias (`mc0`) | Place POPStarter only on `mc0:/` and configure `mc?:/` | Launch game | Path resolves to `mc0:/` and launch proceeds |
| L-04 | `mc?:/` POPStarter alias (`mc1`) | Place POPStarter only on `mc1:/` and configure `mc?:/` | Launch game | Path resolves to `mc1:/` and launch proceeds |
| L-05 | `mc?:/` DKWDRV alias | Place DKWDRV only on `mc1:/` and configure `mc?:/` | Launch Disc option | Path resolves to `mc1:/` and launch proceeds |
| L-06 | Invalid alias targets | Configure `mc?:/` path with file on neither card | Launch game/Disc option | Launch is blocked with explicit missing-file notification |

### Device pages and backend behavior
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| D-01 | USB backend unavailable | No USB mass backend mounted | Open USB page | UI shows `No USB backend found` |
| D-02 | MX4SIO present | Insert MX4SIO media | Open MX4SIO page | Device is detected with bounded retry behavior; list loads or clear no-game state |
| D-03 | MX4SIO absent | No MX4SIO media | Open MX4SIO page | UI shows `No MX4SIO device found` |
| D-04 | MMCE absent | No MMCE card | Open MMCE page | UI shows MMCE-not-found notification |
| D-05 | HDD PFS unavailable | No usable HDD | Open HDD (PFS) | explicit HDD status/partition error notification |
| D-06 | HDD exFAT option status | any setup | Select `HDD (exFAT)` | UI shows `Not Implemented Yet` |
| D-07 | SMB option status | any setup | Select `SMB (v1)` | UI shows `Not Implemented Yet` |
| D-08 | HDD POPS partition scan | `__.POPS`, `__.POPS0`, and one higher `__.POPSN` present | Open HDD (PFS) | titles from all present POPS partitions list in stable partition order |
| D-09 | HDD duplicate title names | Same VCD filename exists in two POPS partitions | Launch each entry from HDD (PFS) | each entry launches from its own source partition |
| D-10 | HDD POPSTARTER on HDD | POPSLoader and/or configured `POPSTARTER_PATH` points to HDD | Launch HDD title | Launch reaches POPSTARTER output without black screen and without returning to POPSLoader |
| D-11 | HDD common art path | `hdd0:__common/POPS/ART/<title>.png` present | Browse HDD title list | cover art appears and launch still succeeds |

### UI behavior
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| U-01 | Hide auxiliary text toggle | Main menu or game list scene | Press Select twice | Toggle shows/hides supported auxiliary text and reports state notification |
| U-02 | Hide toggle exclusions | Settings/Credits scenes | Press Select | No unintended text hiding in excluded scenes |
| U-03 | Cover sidecar load | Put `<game>.png` beside selected `.VCD` | Highlight game | Cover preview appears |
| U-04 | Cover sidecar missing | Remove sidecar PNG | Move selection repeatedly | No notification spam; UI remains responsive |

## Run Log Template
| Date | Console | Storage Setup | IDs Run | Result |
|---|---|---|---|---|
| YYYY-MM-DD | SCPH-xxxxx | USB/MMCE/MX4SIO/HDD details | e.g. S-01,S-02,D-02 | PASS/FAIL + notes |
| 2026-03-24 | Unknown | HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: black screen still present across commits `7a32ad2`, `120fc72`, and `ea03ba2`; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `0327006` diagnostic artifact was still reported as a black screen; stage remained unobserved, which motivated the follow-up diagnostic loader revision that adds visible debug-screen stage text; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `03c1a2b` screen-backed diagnostic artifact was still reported as a black screen; this narrows the next diagnostic change to the embedded-loader `ExecPS2` boundary and loader entry before `argv` string dereference; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `2172a2f` displayed `diag return after loader copy`, `argc=3`, `partition=hdd0:+OPL:`, `path=pfs:/APPS/PS1_POPSLOADER/POPSTARTER.ELF`; embedded-loader image copy completed, so the next probe targeted `SifExitRpc` / cache cleanup; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `6c81233` displayed `diag return after loader cleanup`, `argc=3`, `partition=hdd0:+OPL:`, `path=pfs:/APPS/PS1_POPSLOADER/POPSTARTER.ELF`; cleanup completed, so the next artifact tests the embedded loader `gp` handoff; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `c3cf306` still reached a solid black screen; user reported a very fast flash before black, but the stage text was unreadable, so the next artifact tests reinitializing SIF RPC after the embedded loader's user-memory wipe; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `4d350a4` had the same flash-then-black result as `c3cf306`; the next artifact now halts immediately after the embedded loader records the `SifLoadElf()` outcome so hardware can tell whether target ELF load succeeds, fails, or never reaches that point; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `3d52065` still flashed and then black-screened even though the diagnostic loader now loops forever after recording the `SifLoadElf()` result; the next artifact halts before `SifLoadElf()` to tell whether execution is reaching that call at all; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `5699aa8` still flashed and then black-screened even though the diagnostic loader now loops forever before `SifLoadElf()`; the next artifact keeps SIF RPC alive across the partitioned embedded-loader `ExecPS2` boundary while reusing that pre-`SifLoadElf()` halt; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `9eaa040` reached a stable white `embedded loader entry` screen with valid `argc` and `argv` pointer values; the next artifact halts after argument-string copy to isolate the failure between loader entry and the old pre-`SifLoadElf()` stage; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `6bddf69` still only flashed text and then black-screened even though the diagnostic loader now halted after argument copy; the next artifact halts earlier, after copying the partition/path strings but before dereferencing the forwarded selector `argv[2]`; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `11f1dc6` still only flashed text and then black-screened even though the diagnostic loader now halted after copying the partition/path strings and building `exec0`; the next artifact halts after copying only `argv[0]` into `partition_prefix`, before dereferencing `argv[1]`; see `FAILURES.md` |
| 2026-03-24 | Unknown | HDD diagnostic build + HDD boot + HDD POPSTARTER sidecar + HDD game | D-10 | FAIL: commit `78e0ee6` still only flashed text and then black-screened even though the diagnostic loader now halted after copying only `argv[0]` into `partition_prefix`, before dereferencing `argv[1]`; this marks the current screen-backed post-entry diagnostic line as exhausted without a new durable stage beyond `embedded loader entry`; see `FAILURES.md` |

## Current Verification Status
- CI gates: verified by workflow definition (execution status depends on CI runs).
- Manual hardware matrix: `Unknown (verify on hardware)` unless run logs are added above.
- Current known hardware failure: `D-10` is failing on this branch; see `FAILURES.md`.
- Current HDD diagnostic plateau: stable `embedded loader entry` was observed at commit `9eaa040`, but later post-entry halts (`6bddf69`, `11f1dc6`, `78e0ee6`) all collapsed to flash-then-black and did not produce a new durable hardware stage.
