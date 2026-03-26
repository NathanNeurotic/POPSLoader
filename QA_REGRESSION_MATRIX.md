# POPSLoader Regression Matrix

Last updated: 2026-03-26
Target branch: `BETA-8-5`

## Scope
This matrix tracks current behavior across:
- settings load/save/apply transaction flow,
- settings return/discard behavior and persisted UI preferences,
- launch path validation and error feedback,
- USB/MMCE/MX4SIO/HDD page behavior,
- on-screen keyboard/path editor behavior and long-running busy overlays,
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
| S-06 | Back discards staged settings | Open Settings from a non-main scene and change profile/path/video/hide-text state | Press `O Back` | Returns to the originating scene without saving; reopening Settings shows prior runtime/persisted values |
| S-07 | Video standard persistence | Set Video Standard to `PAL` or `NTSC` and save | Reboot/relaunch and reopen Settings | Selected video standard reloads from settings and runtime video mode matches the saved value |
| S-08 | Hide-text persistence | Open Settings, press `Select`, then save | Reboot/relaunch and reopen Settings | Hidden/shown UI state reloads from settings and matches the last saved toggle state |

### Launch and path handling
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| L-01 | Missing POPStarter path | Configure nonexistent POPStarter path | Launch game | UI shows `Cant find POPSTARTER ELF` message |
| L-02 | Missing DKWDRV path | Configure nonexistent DKWDRV path | Launch Disc option | UI shows `Cant find DKWDRV ELF` message |
| L-03 | `mc?:/` POPStarter alias (`mc0`) | Place POPStarter only on `mc0:/` and configure `mc?:/` | Launch game | Path resolves to `mc0:/` and launch proceeds |
| L-04 | `mc?:/` POPStarter alias (`mc1`) | Place POPStarter only on `mc1:/` and configure `mc?:/` | Launch game | Path resolves to `mc1:/` and launch proceeds |
| L-05 | `mc?:/` DKWDRV alias | Place DKWDRV only on `mc1:/` and configure `mc?:/` | Launch Disc option | Path resolves to `mc1:/` and launch proceeds |
| L-06 | Invalid alias targets | Configure `mc?:/` path with file on neither card | Launch game/Disc option | Launch is blocked with explicit missing-file notification |
| L-07 | BOOT.ELF exit fallback | Put `BOOT.ELF` on `mc0:/BOOT/` only, then `mc1:/BOOT/` only | Open Exit modal and choose `BOOT.ELF` | `mc0:/BOOT/BOOT.ELF` is preferred and `mc1:/BOOT/BOOT.ELF` is used as fallback |

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
| D-10 | HDD POPSTARTER on HDD | POPSLoader and/or configured `POPSTARTER_PATH` points to HDD, including HDD sidecar/cwd resolution | Launch HDD title | POPSTARTER resolves from sidecar or configured HDD path without blocking launch or hanging on a black screen |
| D-11 | HDD common art path | `hdd0:__common/POPS/ART/<title>.png` present | Browse HDD title list | cover art appears and launch still succeeds |

### UI behavior
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| U-01 | Hide auxiliary text toggle | Main menu or game list scene | Press Select twice | Toggle shows/hides supported auxiliary text and reports state notification |
| U-02 | Hide toggle on non-hide scenes | Settings or Credits scene | Press Select | Settings updates the saved hide-text toggle without hiding the settings UI; Credits does not apply hide mode unexpectedly |
| U-03 | Cover sidecar load | Put `<game>.png` beside selected `.VCD` | Highlight game | Cover preview appears |
| U-04 | Cover sidecar missing | Remove sidecar PNG | Move selection repeatedly | No notification spam; UI remains responsive |
| U-05 | Exit to OSDSYS | Boot POPSLoader on target hardware, including a run where `HDD (PFS)` was opened first | Open Exit modal and choose `OSDSYS` | Returns to the PS2 browser without black screen, including after the HDD page initialized tracked mounts |
| U-06 | PAL video asset aspect | Set Video Standard to `PAL` in Settings | Browse main menu, settings, and splash/UI assets | Bundled UI assets retain expected proportions without PAL squish |
| U-07 | Path editor cursor and press feedback | Open POPStarter or DKWDRV path editor | Move cursor with `L1`/`R1`, toggle case, insert/delete characters, confirm/cancel | Cursor moves within the string, lowercase letter keys render uppercase when case is enabled, and the selected key flashes when pressed |
| U-08 | Save progress overlay | Change any setting and save | Observe the save/apply sequence | A visible progress popup/overlay stays on-screen until the save/apply flow completes or fails, without looking stalled at a single coarse stage for the whole operation |
| U-09 | Device-load progress overlay | Use a slow or large MMCE/MX4SIO/HDD/USB library | Open the device page and wait for list generation | A visible progress popup/overlay stays on-screen during scanning/list generation and advances through the scan instead of only jumping between coarse stage markers |

## Run Log Template
| Date | Console | Storage Setup | IDs Run | Result |
|---|---|---|---|---|
| YYYY-MM-DD | SCPH-xxxxx | USB/MMCE/MX4SIO/HDD details | e.g. S-01,S-02,D-02 | PASS/FAIL + notes |

## Current Verification Status
- CI gates: verified by workflow definition (execution status depends on CI runs).
- Manual hardware matrix: `Unknown (verify on hardware)` unless run logs are added above.
