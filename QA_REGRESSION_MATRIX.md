# POPSLoader Regression Matrix

Last updated: 2026-03-20
Audit baseline: `BETA-9-RECOVERY`

## Scope
This matrix tracks current behavior across:
- CI build/package contract,
- settings load/save/apply transaction flow,
- video standard persistence,
- launch path validation and error feedback,
- USB/MMCE/MX4SIO/HDD page behavior,
- `mc?:/` alias path resolution,
- cover preview behavior,
- currently unimplemented menu options (`HDD (exFAT)`, `SMB (v1)`).

## Automated CI Gates
| ID | Area | Source | Pass Criteria |
|---|---|---|---|
| CI-01 | Build info generation | `.github/workflows/compilation.yml` step `Generate build info` | `bin/POPSLDR/BUILD_INFO.txt` is written with commit hash and UTC timestamp before compile |
| CI-02 | Boot script syntax/newline | workflow step `Validate etc/boot.lua` | `etc/boot.lua` exists, ends with newline, parses with `luac` or `lua` when available |
| CI-03 | Build | workflow step `Compile project` | `make clean elfloader all` succeeds |
| CI-04 | Release package assembly | workflow step `Create release package` | ZIP includes the expected tree rooted at `PS1_POPSLOADER/` and `POPS/` |
| CI-05 | Release manifest exactness | workflow python verifier | exact expected file set; no extra or missing files |
| CI-06 | Legacy payload rejection | workflow python verifier | no `POPS/*.tm2` entries are present |

Notes:
- CI currently generates `bin/POPSLDR/BUILD_INFO.txt`, but the release ZIP assembled by the workflow does not copy that file into `POPSLOADER.zip`.

## Manual Runtime Matrix

### Settings and persistence
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| S-01 | Defaults with missing settings file | Remove `mc0:/POPSTARTER/.pldrs` | Start app and open Settings | Defaults load without crash |
| S-02 | Staged edits are not immediate writes | Change settings rows but do not leave Settings | Hard-exit app | Prior persisted values remain |
| S-03 | Commit on exit | Change profile, POPStarter path, DKWDRV path, BDMA mode, or video standard and leave Settings | Reopen Settings | Values persist and reload |
| S-04 | Save failure feedback | Make `mc0:/POPSTARTER` unavailable | Leave Settings with changes | User sees explicit save/apply error notification |
| S-05 | BDMA mode restore from marker | Prepare `.pldr_bdma_mode` marker | Boot and open Settings | Selected BDMA mode reflects effective marker state |
| S-06 | Video standard persistence | Change NTSC/PAL in Settings and save | Reopen Settings and continue using UI | Selected video standard persists and runtime display mode matches the selection |

### Launch and path handling
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| L-01 | Missing POPStarter path | Configure nonexistent POPStarter path | Launch game | UI shows `Cant find POPSTARTER ELF` message |
| L-02 | Missing DKWDRV path | Configure nonexistent DKWDRV path | Launch Disc option | UI shows `Cant find DKWDRV ELF` message |
| L-03 | `mc?:/` POPStarter alias (`mc0`) | Place POPStarter only on `mc0:/` and configure `mc?:/` | Launch game | Path resolves to `mc0:/` and launch proceeds |
| L-04 | `mc?:/` POPStarter alias (`mc1`) | Place POPStarter only on `mc1:/` and configure `mc?:/` | Launch game | Path resolves to `mc1:/` and launch proceeds |
| L-05 | `mc?:/` DKWDRV alias | Place DKWDRV only on `mc1:/` and configure `mc?:/` | Launch Disc option | Path resolves to `mc1:/` and launch proceeds |
| L-06 | Invalid alias targets | Configure `mc?:/` path with file on neither card | Launch game or Disc option | Launch is blocked with explicit missing-file notification |
| L-07 | HDD sidecar POPStarter resolution | Boot POPSLoader from HDD with adjacent `POPSTARTER.ELF` and leave default relative path selected | Launch HDD title | POPStarter resolves from the local sidecar without requiring a memory-card fallback |

### Device pages and backend behavior
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| D-01 | USB backend unavailable | No USB mass backend mounted | Open USB page | UI shows `No USB backend found` |
| D-02 | MX4SIO present | Insert MX4SIO media | Open MX4SIO page | Device is detected with bounded retry behavior; list loads or shows a clear no-game state |
| D-03 | MX4SIO absent | No MX4SIO media | Open MX4SIO page | UI shows `No MX4SIO device found` |
| D-04 | MMCE absent | No MMCE card | Open MMCE page | UI shows MMCE-not-found notification |
| D-05 | HDD PFS unavailable | No usable HDD | Open HDD (PFS) | Explicit HDD status or partition error notification is shown |
| D-06 | HDD exFAT option status | Any setup | Select `HDD (exFAT)` | UI shows `Not Implemented Yet` |
| D-07 | SMB option status | Any setup | Select `SMB (v1)` | UI shows `Not Implemented Yet` |
| D-08 | HDD POPS partition scan | `__.POPS`, `__.POPS0`, and one higher `__.POPSN` are present | Open HDD (PFS) | Titles from all present POPS partitions list in partition order |
| D-09 | HDD duplicate title names | Same VCD filename exists in two POPS partitions | Launch each entry from HDD (PFS) | Each entry launches from its own source partition |
| D-10 | HDD dependency checks (optional code path) | Enable `PLDR.CHECK_POPSTARTER_FILES`, then make `hdd0:__common` missing or remove required POPS files | Open HDD (PFS) | UI reports missing partition or missing `POPS.ELF`/`IOPRP252.IMG` dependencies |
| D-11 | HDD common art path | `hdd0:__common/POPS/ART/<title>.png` exists | Browse HDD title list | Cover art appears and launch still succeeds |

### UI behavior
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| U-01 | Hide auxiliary text toggle | Main menu or supported game-list scene | Press Select once | Toggle shows or hides supported auxiliary text and reports the new state |
| U-02 | Hide toggle exclusions | Settings or Credits scene | Press Select | No unintended text hiding occurs in excluded scenes |
| U-03 | Cover preview toggle | Game-list scene with at least one title | Press Square | Cover preview toggles between enabled and disabled states |
| U-04 | Cover sidecar load | Put `<game>.png` beside selected `.VCD` on USB, MMCE, or MX4SIO | Highlight game and pause briefly | Cover preview appears |
| U-05 | Cover sidecar missing | Remove the sidecar PNG | Move selection repeatedly | No notification spam; UI remains responsive |
| U-06 | Optional build stamp | Place `BUILD_INFO.txt` or `POPSLDR/BUILD_INFO.txt` beside the app with valid two-line content | Open Credits | Credits scene shows `build <hash> <timestamp>` |

Notes:
- Device-lock helpers exist in UI state, but current menu flow does not use them to block device switching. No pass/fail case is tracked for lock enforcement until that behavior exists.

## Run Log Template
| Date | Console | Storage Setup | IDs Run | Result |
|---|---|---|---|---|
| YYYY-MM-DD | SCPH-xxxxx | USB/MMCE/MX4SIO/HDD details | e.g. S-01,S-06,D-02 | PASS/FAIL + notes |

## Current Verification Status
- CI gates: verified by workflow definition; execution status depends on GitHub Actions runs.
- Manual hardware matrix: `Unknown (verify on hardware)` unless run logs are added above.
