# POPSLoader Regression Matrix

Last updated: 2026-03-28
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
| CI-06 | Packaged build identity | workflow packaging step | ZIP includes `PS1_POPSLOADER/BUILD_INFO.txt` so hardware can confirm the exact GitHub-built artifact |
| CI-07 | Embedded runtime identity | workflow step `Verify embedded build identity` | built `enceladus.elf` contains expected embedded Lua markers and the generated embedded-loader blob was regenerated |

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
| 2026-03-28 | Unknown (not reported) | Same HDD-boot auto-init repro on corrected source | D-12 | PASS |
| 2026-03-28 | Unknown (not reported) | Booted from HDD; default/Profile 1 sidecar POPSTARTER on HDD; entered USB page before HDD page on the boot-time split source | D-12 | FAIL: HDD POPSTARTER could not be found until HDD page entry |
| 2026-03-28 | Unknown (not reported) | Same HDD-backed startup/Profile POPSTARTER repro on raw-`APP_DIR` fallback source | D-12 | FAIL: still required HDD page entry |
| 2026-03-28 | Unknown (not reported) | Same HDD-backed startup/Profile POPSTARTER repro after startup warm-path and on-demand path-access follow-ups | D-12 | FAIL: still required HDD page entry |
| 2026-03-28 | Unknown (not reported) | Same HDD-backed startup/Profile POPSTARTER repro on exact-boot-mount/source-context source | D-12 | PASS |
| 2026-03-27 | Unknown (not reported) | Cold boot; first USB page entry said no backend; backing out and re-entering then worked | D-16 | FAIL |
| 2026-03-28 | Unknown (not reported) | Cold boot; first USB page entry on corrected source | D-16 | PASS |
| 2026-03-27 | Unknown (not reported) | Booted from HDD; POPSTARTER via default/Profile 1/cwd/sidecar on HDD; game device HDD | D-10 | FAIL: black screen |
| 2026-03-27 | Unknown (not reported) | Boot source not reported; Profile 2 `POPSTARTER.ELF` on HDD; game device USB | D-14 | FAIL: black screen |
| 2026-03-27 | Unknown (not reported) | Booted from non-HDD device; HDD game; sidecar/cwd `POPSTARTER.ELF` on boot device; EE-side HDD direct-load attempt | D-15 | FAIL: black screen (reported regression) |
| 2026-03-27 | Unknown (not reported) | HDD game with non-HDD `POPSTARTER.ELF` on the broader stripped-handoff source | D-15 | FAIL: black screen |
| 2026-03-28 | Unknown (not reported) | HDD game with non-HDD `POPSTARTER.ELF` on broader experimental source before current rollback | D-15 | FAIL: black screen |
| 2026-03-28 | Unknown (not reported) | USB boot; USB sidecar/cwd `POPSTARTER.ELF`; HDD game on the rolled-back current source | D-15 | FAIL: black screen |
| 2026-03-28 | Unknown (not reported) | USB boot; USB Profile 1 sidecar/cwd `POPSTARTER.ELF`; HDD game on the narrowed current source | D-15 | PASS |
| 2026-03-28 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on narrowed Lua-side source with cleared post-load PFS keep mask | D-10 | FAIL: black screen (no visible change) |
| 2026-03-28 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on loader-side no-auto-exec-slot-preserve source | D-10 | FAIL: black screen on both `X` and `R2` |
| 2026-03-28 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on forced-`reboot_iop = 1` source | D-10 | FAIL: black screen on both `X` and `R2` |
| 2026-03-28 | Unknown (not reported) | Non-HDD game with HDD-backed `POPSTARTER.ELF` on forced-`reboot_iop = 1` source | D-14 | FAIL: `X` black screen, `R2` no response |
| 2026-03-28 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source | D-10 | FAIL: `X` black screen |
| 2026-03-28 | Unknown (not reported) | Non-HDD game with HDD-backed `POPSTARTER.ELF` on direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source | D-14 | FAIL: `X` black screen |
| 2026-03-28 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on mounted-`pfs0:` embedded-loader source | D-10 | FAIL: `X` black screen |
| 2026-03-28 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on exact-boot-mount/source-context source | D-10 | FAIL: black screen |
| 2026-03-28 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on partition-aware reboot-contract source | D-10 | FAIL: no black screen, but launcher regained control through generic timeout failure path |
| 2026-03-29 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on prior partition-aware source with real returned-rc popup | D-10 | FAIL: launcher regained control with `rc=-1 (returned after 22618 ms)` |
| 2026-03-29 | Unknown (not reported) | HDD boot; HDD sidecar/cwd `POPSTARTER.ELF`; HDD game on later GitHub artifact from the broader partition-aware/current-source line | D-10 | FAIL: black screen |
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
    - user later confirmed the earlier corrected source passed on hardware.
    - a later boot-time report showed startup HDD init was also scanning partitions and building the HDD games list, which can make HDD boot appear hung on large libraries.
    - current source now keeps startup HDD init limited to runtime readiness only; the HDD page still scans partitions and builds the games list on page entry.
    - later 2026-03-28 reports on that narrowed boot-time split source still said HDD-backed startup/Profile POPSTARTER could not be found after entering the USB page before the HDD page.
    - the raw boot `APP_DIR` fallback alone did not restore that case.
    - current source now also pre-resolves any HDD-backed startup/configured exec paths immediately after `PLDR.LoadHDDModules()` so HDD POPSTARTER/Profile paths are mounted and recorded without reintroducing HDD page work at boot.
    - current source also routes on-demand HDD path mounts through `PLDR.LoadHDDModules()` instead of only the lower-level `EnsureHddRuntimeReadyForExec()` gate, so later POPSTARTER/Profile resolution from USB or other pages uses the same runtime init path as HDD page entry.
    - current source also fixes the startup warm-path classification for Profile 1/default relative `POPSTARTER.ELF`, which had previously been skipped because only explicit `hdd:` / `pfs:` paths were being marked for HDD warm-up.
    - because `etc/boot.lua` establishes HDD boot on a dedicated `pfs1:` mount before `system.lua` runs, current source now also carries that exact boot partition/slot metadata into `system.lua`, seeds the HDD mount tracker from it, and rebuilds HDD sidecar/partition context from mounted `pfs1:` candidates instead of relying only on later rediscovery.
    - user later confirmed on 2026-03-28 that the exact-boot-mount/source-context source restored the USB-before-HDD-page startup/Profile repro on hardware.
    - updated-source hardware result is still `Unknown (verify on hardware)`.
  - `D-16`: a 2026-03-27 hardware report said the first USB page entry reported no backend, but backing out and re-entering then worked.
    - current source now adds a bounded wait between failed USB root probes in `BuildUsbIdentityDeferred()`.
    - MX4SIO discovery code was not changed by this correction.
    - user later confirmed the corrected source passed on hardware.
  - `D-10`: reported FAIL when booted from HDD and launching an HDD title with HDD `POPSTARTER.ELF` sidecar/CWD.
    - 2026-03-27 re-test of the current source still failed with boot source HDD, POPSTARTER on HDD via default/Profile 1/cwd/sidecar, and game device HDD.
    - the later EE-side direct-load workaround was reverted after it did not fix this and coincided with a broader regression report.
    - later 2026-03-27 Memory Card staging, stripped-handoff, CWD/selector, and HDD-init-state experiments did not fix this.
    - user later confirmed on 2026-03-28 that the narrowed source restored `D-15`, so the remaining blocker is again isolated to HDD-backed `POPSTARTER.ELF`.
    - a later 2026-03-28 re-test still black-screened on that narrowed Lua-side source with no visible positive change.
    - a later 2026-03-28 re-test on the loader-side no-auto-exec-slot-preserve source still black-screened on both `X` and `R2`.
    - a later 2026-03-28 re-test on the forced-`reboot_iop = 1` source still black-screened on both `X` and `R2`.
    - a later 2026-03-28 re-test on the direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source still black-screened on `X`.
    - follow-up repo inspection then found `BuildDirectHddExecPathFromMounted()` had been omitting the colon after `pfsN`, so that earlier direct-path experiment was not a clean control.
    - a later 2026-03-28 re-test on the mounted-`pfs0:` embedded-loader source still black-screened on `X`.
    - follow-up repo comparison showed that earlier source-context work had still been incomplete because Lua had usually already normalized HDD POPSTARTER to mounted `pfs1:` / `pfs3:` paths before the reboot loader saw it.
    - a later 2026-03-28 re-test on that exact-boot-mount/source-context source still black-screened on `X`.
    - current source now replaces the earlier ad hoc HDD source-context reboot handoff with an explicit partition-aware contract across `bin/POPSLDR/system.lua`, `src/luasystem.cpp`, `src/elf_loader/src/elf.c`, and `src/elf_loader/src/loader/src/loader.c`.
    - on that contract, the parent passes exact HDD partition context separately from the mounted load path, normalizes the partition-aware exec filename to generic `pfs:/...`, remounts `pfs0:` from that partition while reusing the mounted relpath Lua already resolved, routes HDD partition-aware launches through cold external-launch prep so the old tracked `pfsN:` mount is not preserved into exec, and aligns the child loader closer to the reference loaders by removing the post-reset MC module reload and exiting SIF command state before the final target `ExecPS2`.
    - a 2026-03-29 hardware result on the prior partition-aware source no longer black-screened, but the launcher regained control with `rc=-1 (returned after 22618 ms)`.
    - a later 2026-03-29 GitHub artifact re-test on that broader partition-aware/current-source line black-screened again, so the returned-rc boundary is not yet stable enough to treat as the new steady state.
    - current source now restores more of the original parent-side embedded-loader jump contract in `src/elf_loader/src/elf.c`: BRAM wipe plus `SifInitRpc`/`SifLoadFileInit`/`SifLoadFileExit` before the copy, and `SifExitIopHeap`/`SifExitRpc`/`SifExitCmd` before the final `ExecPS2`.
    - current source also keeps the safer embedded-loader fix that avoids `printf`/`snprintf` in that environment, returns the actual embedded-loader `ExecPS2` result instead of collapsing it to `-1`, fixes `System.loadELF(path, reboot_iop, args...)` so it forwards all extra args instead of dropping everything after the first one, now shows the actual exec path separately from the probed/opened POPSTARTER path in the launcher popup, restores the older iomanX-aware `fileXio` ELF load path inside the embedded loader for `pfs:` / `hdd:` targets instead of relying only on `SifLoadElf` there, and keeps that `fileXio` success path on the older direct `ExecPS2` handoff instead of the later reset / teardown path.
    - current source still exposes an `R2` alternate HDD launch for HDD-resident `POPSTARTER.ELF` that changes only the selector path to `hdd0:PART:pfs0:/GAME.ELF`; hardware result is still `Unknown (verify on hardware)`.
  - `D-14`: reported FAIL on 2026-03-27 when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD.
    - this broadened the remaining issue from “HDD game launch” to “HDD-backed POPSTARTER exec path”.
    - the user later clarified that the other same-day 2026-03-28 success result referred to `D-15`, not this case.
    - a later 2026-03-28 re-test on the forced-`reboot_iop = 1` source still black-screened on `X`; `R2` produced no response in that non-HDD-game repro.
    - a later 2026-03-28 re-test on the direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source still black-screened on `X`.
    - current source now uses the same partition-aware HDD reboot contract as `D-10`, rather than the earlier ad hoc source-context handoff or whichever mounted `pfsN:` path Lua happened to resolve first; hardware result is still `Unknown (verify on hardware)`.
  - `D-15`: reported FAIL on 2026-03-27 when booting from a non-HDD device and launching an HDD title with sidecar/cwd `POPSTARTER.ELF` on that boot device.
    - the user identified this as a regression on the EE-side HDD direct-load attempt.
    - a later 2026-03-27 broader stripped-handoff source also failed, a 2026-03-28 experimental source still black-screened, and the 2026-03-28 rolled-back current source still black-screened with USB boot plus USB sidecar/cwd `POPSTARTER.ELF`.
    - current source now removes Lua-side HDD game pre-mount/CWD preservation from this path and leaves only the normal selector handoff unless `POPSTARTER.ELF` itself is HDD/PFS-backed.
    - user later confirmed on 2026-03-28 that USB boot + USB Profile 1 sidecar/cwd `POPSTARTER.ELF` + HDD game passes on the corrected source.
  - `U-10`: one artifact was reported good before a later regression experiment.
    - repo history shows the BOOT.ELF modal later changed from its older non-reboot direct `System.loadELF(elf_path, 0, elf_path)` path to a reboot-I/O path with launch-CWD setup.
    - a later 2026-03-29 hardware report said BOOT.ELF still behaved incorrectly once HDD runtime had been initialized on that restored non-reboot source.
    - current source now keeps the no-launch-CWD rollback, re-enables `reboot_iop = 1` for BOOT.ELF only when HDD runtime has already been loaded, and uses a BOOT.ELF-specific cold external-launch prep that clears the exec keep mask and unmounts tracked HDD slots instead of preserving boot PFS state.
- All other manual hardware items remain `Unknown (verify on hardware)` unless run logs are added above.
