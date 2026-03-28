# POPSLoader Regression Matrix

Last updated: 2026-03-27
Target branch: `BETA-10-play`

## Scope
This matrix tracks current behavior across:
- settings load/save/apply transaction flow,
- persisted UI preferences (`video`, `hide-text`, `keyboard layout`),
- launch path validation and error feedback,
- startup backend auto-init,
- USB/MMCE/MX4SIO/HDD page behavior,
- removed runtime device-lock behavior,
- on-screen keyboard behavior,
- busy/progress overlays,
- cover art behavior,
- exit handoff behavior,
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
| S-05 | BDMA mode restore from marker | Prepare `.pldr_bdma_mode` marker | Boot and open Settings | Selected BDMA mode reflects effective marker state |
| S-06 | Back discards staged settings | Open Settings from a non-main scene and change profile/path/video/hide-text state | Press `O Back` | Returns to the originating scene without saving; reopening Settings shows prior runtime/persisted values |
| S-07 | Video standard persistence | Set Video Standard to `PAL` or `NTSC` and save | Reboot/relaunch and reopen Settings | Selected video standard reloads from settings and runtime video mode matches the saved value |
| S-08 | Hide-text persistence | Open Settings, press `Select`, then save | Reboot/relaunch and reopen Settings | Hidden/shown UI state reloads from settings and matches the last saved toggle state |
| S-09 | Keyboard layout persistence | Set keyboard layout to `ABC`, `QWERTY`, or `DVORAK` and save | Reboot/relaunch and reopen the path editor | Selected keyboard layout reloads from settings and the keyboard opens in that layout |

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
| L-08 | Default/Profile 1 local POPSTARTER path | Start from a settings file that may contain an older absolute local POPSTARTER path, then select default/Profile 1 with local sidecar/cwd `POPSTARTER.ELF` present | Cold boot and launch a game | Launch does not stop at `Cant find POPSTARTER ELF`; the current local sidecar/cwd POPSTARTER path wins over the stale equivalent override |

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
| D-10 | HDD POPSTARTER on HDD | POPSLoader and/or configured `POPSTARTER_PATH` points to HDD, including HDD sidecar/CWD resolution | Launch HDD title | POPSTARTER resolves from sidecar or configured HDD path without blocking launch or hanging on a black screen |
| D-11 | HDD common art path | `hdd0:__common/POPS/ART/<title>.png` present | Browse HDD title list | cover art appears and launch still succeeds |
| D-12 | Startup backend auto-init | Boot from USB/MX4SIO/MMCE/HDD, or save a `POPSTARTER_PATH` / `DKWDRV_PATH` / profile on one of those devices | Cold boot app and launch without first opening that device page | Required backend drivers initialize automatically from boot/configured paths |
| D-13 | No runtime device lock gating | Enter one backend page first, then move to another backend page in the same session | Open the second backend page | UI does not block the scene transition with a restart-required device-lock gate |
| D-14 | HDD-backed POPSTARTER with non-HDD game | Configure `POPSTARTER_PATH` or Profile 2 to an HDD-resident `POPSTARTER.ELF` | Launch a USB, MMCE, or MX4SIO title | POPSTARTER launches without hanging on a black screen even though the executable itself is on HDD |
| D-15 | HDD game with non-HDD sidecar POPSTARTER | Boot from USB/MMCE/MX4SIO or another non-HDD device with sidecar/cwd `POPSTARTER.ELF` on that same device | Launch an HDD title | HDD title still launches without a black screen when POPSTARTER itself remains off-HDD |
| D-16 | USB first-entry backend discovery | Cold boot without first opening the USB page | Open USB once | USB backend is found on the first entry without backing out and re-entering |

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
| U-08 | Save progress overlay | Change any setting and save | Observe the save/apply sequence | A visible progress popup/overlay stays on-screen until the save/apply flow completes or fails |
| U-09 | Device-load progress overlay | Use a slow or large MMCE/MX4SIO/HDD/USB library | Open the device page and wait for list generation | A visible progress popup/overlay stays on-screen during scanning/list generation and advances through the scan instead of only jumping between coarse stage markers |
| U-10 | BOOT.ELF after HDD page init | Open `HDD (PFS)` first so dependency checks and partition scans run | Return to main menu and launch `BOOT.ELF` from Exit | `BOOT.ELF` handoff succeeds without freezing or black-screening after HDD page access |
| U-11 | Boot-device label | Boot from USB, MX4SIO, MMCE, and HDD | Reach the main menu | Main menu boot label reflects the detected boot device/backend family |

## Run Log Template
| Date | Console | Storage Setup | IDs Run | Result |
|---|---|---|---|---|
| 2026-03-27 | Unknown (not reported) | Booted from USB; USB `POPSTARTER.ELF` via default/Profile 1/cwd/sidecar; launch stopped before handoff | L-08 | FAIL: `Cant find POPSTARTER ELF` |
| 2026-03-27 | Unknown (not reported) | Same USB sidecar/cwd/Profile 1 repro after rollback to checkpoint resolver behavior | L-08 | PASS |
| 2026-03-27 | Unknown (not reported) | Booted from HDD; startup auto-init did not bring up the HDD driver stack before manual HDD page entry | D-12 | FAIL |
| 2026-03-27 | Unknown (not reported) | Cold boot; first USB page entry said no backend; backing out and re-entering then worked | D-16 | FAIL |
| 2026-03-27 | Unknown (not reported) | Booted from HDD; POPSTARTER via default/Profile 1/cwd/sidecar on HDD; game device HDD | D-10 | FAIL: black screen |
| 2026-03-27 | Unknown (not reported) | Boot source not reported; Profile 2 `POPSTARTER.ELF` on HDD; game device USB | D-14 | FAIL: black screen |
| 2026-03-27 | Unknown (not reported) | Booted from non-HDD device; HDD game; sidecar/cwd `POPSTARTER.ELF` on boot device; EE-side HDD direct-load attempt | D-15 | FAIL: black screen (reported regression) |
| YYYY-MM-DD | SCPH-xxxxx | USB/MMCE/MX4SIO/HDD details | e.g. S-01,S-02,D-02 | PASS/FAIL + notes |

## Current Verification Status
- CI gates: repository-verified by workflow definition.
- Reported hardware outcomes:
  - `L-08`: reported FAIL on 2026-03-27 when booted from USB with USB sidecar/cwd/Profile 1; launch stopped at `Cant find POPSTARTER ELF`.
    - comparison against `BETA-10-play-CHECKPOINT2` showed the checkpoint branch worked without the later unverified common-path resolver/settings changes.
    - current source was rolled back to the checkpoint branch's shared resolver behavior for this path.
    - user later confirmed the rolled-back source passed the same hardware repro.
  - `U-05`: reported PASS.
  - `D-12`: a 2026-03-27 hardware report said booting from HDD did not auto-init the HDD driver stack.
    - current source now routes HDD startup targets through `PLDR.LoadHDDModules()` instead of only `EnsureHddRuntimeReadyForExec()`.
    - corrected-source hardware result is still `Unknown (verify on hardware)`.
  - `D-16`: a 2026-03-27 hardware report said the first USB page entry reported no backend, but backing out and re-entering then worked.
    - current source now adds a bounded wait between failed USB root probes in `BuildUsbIdentityDeferred()`.
    - MX4SIO discovery code was not changed by this correction.
    - corrected-source hardware result is still `Unknown (verify on hardware)`.
  - `D-10`: reported FAIL when booted from HDD and launching an HDD title with HDD `POPSTARTER.ELF` sidecar/CWD.
    - 2026-03-27 re-test of the current source still failed with boot source HDD, POPSTARTER on HDD via default/Profile 1/cwd/sidecar, and game device HDD.
    - the later EE-side direct-load workaround was reverted after it did not fix this and coincided with a broader regression report.
    - current source still exposes an `R2` alternate HDD launch for HDD-resident `POPSTARTER.ELF` that changes only the selector path to `hdd0:PART:pfs0:/GAME.ELF`; hardware result is still `Unknown (verify on hardware)`.
  - `D-14`: reported FAIL on 2026-03-27 when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD.
    - this broadened the remaining issue from “HDD game launch” to “HDD-backed POPSTARTER exec path”.
  - `D-15`: reported FAIL on 2026-03-27 when booting from a non-HDD device and launching an HDD title with sidecar/cwd `POPSTARTER.ELF` on that boot device.
    - the user identified this as a regression on the EE-side HDD direct-load attempt.
    - that direct-load workaround has now been reverted; reverted-source hardware result is still `Unknown (verify on hardware)`.
  - `U-10`: one artifact was reported good before a later regression experiment; current source has been restored away from that experiment and must be re-tested.
- All other manual hardware items remain `Unknown (verify on hardware)` unless run logs are added above.
