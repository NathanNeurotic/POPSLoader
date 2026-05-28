# POPSLoader Regression Matrix

Last updated: 2026-05-28
BETA-10-5 release tag: `9a0ebe2`, hardware-confirmed clean 2026-05-28 (Nuno).
Current `BETA-12-PLAY` development tip: `81c886e` (Merge PR #473 hotfix). Post-release PR work is CI-verified but `Unknown (verify on hardware)` unless explicitly recorded below.

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
- currently unimplemented menu options (`HDD (exFAT)`, `SMB (v1)`, `ILINK`),
- release package validation gates,
- repository automation workflows that are not runtime/hardware gates.

This file is the authoritative detailed run ledger for CI and hardware outcomes. The other root docs should summarize the active state and point here for chronology.

## Automated CI Gates

These gates are defined by `.github/workflows/compilation.yml`. The separate `.github/workflows/opencode.yml` workflow only runs comment-triggered AI assistance and is not a build, package, runtime, or hardware validation gate.

| ID | Area | Source | Pass Criteria |
|---|---|---|---|
| CI-01 | Build | `.github/workflows/compilation.yml` | `make clean elfloader all` succeeds |
| CI-02 | Boot script syntax/newline | workflow step `Validate etc/boot.lua` | `etc/boot.lua` exists, ends with newline, parses with `luac`/`lua` when available |
| CI-03 | Release package assembly | workflow packaging step | ZIP includes expected tree rooted at `PS1_POPSLOADER/` + `POPS/` |
| CI-04 | Release manifest exactness | workflow python verifier | exact expected file set; no extra/missing files |
| CI-05 | Legacy payload rejection | workflow python verifier | no `POPS/*.tm2` entries present |
| CI-06 | Packaged build identity | workflow packaging step | ZIP includes `PS1_POPSLOADER/BUILD_INFO.txt` so hardware can confirm the exact GitHub-built artifact |
| CI-07 | Embedded runtime identity | workflow step `Verify embedded build identity` | built `enceladus.elf` contains expected embedded Lua markers and the generated embedded-loader blob was regenerated |
| CI-08 | Optional default cover asset | `.github/workflows/compilation.yml` without `bin/POPSLDR/IMG/default.png` | build succeeds, omits `asset_default_png`, and runtime `IMG.default` falls back to embedded `MISSING.png` |

## Manual Runtime Matrix

### Settings and persistence
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| S-01 | Defaults with missing settings file | Remove `mc0:/POPSTARTER/.pldrs` | Start app and open Settings | Defaults load without crash |
| S-02 | Staged edits are not immediate writes | Change settings rows but do not leave Settings | Hard-exit app | Prior persisted values remain |
| S-03 | Commit on exit | Change profile/paths/BDMA and confirm or leave | Reopen Settings | Values persist and reload |
| S-04 | Save failure feedback | Make `mc0:/POPSTARTER` unavailable | Leave Settings with changes | User sees explicit save/apply error notification |
| S-05 | BDMA mode restore from marker | Prepare `.pldr_bdma_mode` marker | Boot and open Settings | Selected BDMA mode reflects effective marker state |
| S-06 | Back prompts when staged settings exist | Open Settings from a non-main scene and change profile/path/video/hide-text state | Press `O Back` | A "Save Settings" modal appears with `X Save / O Cancel / Triangle Don't Save`. Triangle (Don't Save) returns to the originating scene without saving and reopening Settings shows prior runtime/persisted values. O (Cancel) stays on Settings. X (Save) commits and exits to the originating scene. With no staged changes, Back returns immediately with no prompt. |
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
| D-07A | ILINK option status | any setup | Select `ILINK` | UI shows `Not Implemented Yet` |
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
| U-12 | Notification interrupt behavior | Trigger two or more notifications before the first fades out | Observe the on-screen notification | The newest notification appears immediately and older pending notifications do not backlog |

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
| 2026-05-20 | Unknown (not reported) | Latest `BETA-12-PLAY` artifact; HDD-resident `POPSTARTER.ELF` resolved as `pfs3:/POPS/POPSTARTER.ELF`; app dir shown as `hdd0:+OPL:pfs:/APPS/PS1_POPSLOADER/`; HDD title `SLUS_007.42.Rampage 2 - Uni.VCD` | D-10 | FAIL: launcher popup returned with `POPSTARTER HDD pre-exec gate failed: Cannot resolve HDD partition context`; source also showed the popup route/gate fields were argument-shifted before the 2026-05-20 follow-up |
| 2026-05-20 | Unknown (not reported) | Later readable-diagnostic artifact; configured/effective POPSTARTER path `hdd0:__common:pfs:/POPS/POPSTARTER.ELF`; resolved POP path `pfs3:/POPS/POPSTARTER.ELF`; exec path `pfs:/POPS/POPSTARTER.ELF`; HDD title `SLUS_007.42.Rampage 2 - Uni.VCD` | D-10 | FAIL: launcher popup returned with `POPSTARTER HDD pre-exec gate failed: POPSTARTER is not accessible using exec path`; source showed the gate was probing generic `pfs:/...` instead of a real slot-mounted path |
| 2026-05-20 | Unknown (not reported) | Latest-artifact regression after D-10 gate follow-up; USB boot with USB sidecar/cwd `POPSTARTER.ELF`; HDD title selected from the HDD page | D-15 | FAIL: black screen; source follow-up restores legacy `System.loadELF(path, reboot_iop, selector)` one-argument selector behavior so no extra Lua argument can reach normal POPSTARTER launches |
| 2026-05-20 | Unknown (not reported) | Follow-up non-HDD POPSTARTER test; explicit `mass:/POPS/POPSTARTER.ELF` launches, while default/cwd sidecar `POPSTARTER.ELF` stops before launch | L-08/D-15 guard | FAIL: `Cant find POPSTARTER ELF`; source follow-up expands default sidecar lookup to live current directory plus boot/app directories without changing the selector handoff |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with SIFLOADFILE sentinel | D-10 | PASS: target-side SifInitRpc(0) & SifLoadFileInit() succeeded (GREEN->YELLOW->WHITE->RED/MAGENTA loop) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with FILEXIOINIT sentinel | D-10 | PASS: target-side fileXioInit() succeeded (GREEN->CYAN->YELLOW->WHITE->RED->BLUE->MAGENTA/GREEN loop) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with TARGET-IOPRESET sentinel | D-10 | FAIL: post-reset target-side SifInitRpc(0) hung (froze on TEAL) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with TARGET-IOPRESET-EXITRPC sentinel | D-10 | FAIL: post-reset target-side SifInitRpc(0) hung (froze on TEAL) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with MINIMAL TARGET-IOPRESET sentinel | D-10 | FAIL: post-reset target-side SifInitRpc(0) hung (froze on TEAL) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with MINIMAL TARGET-IOPRESET-EXITRPC sentinel | D-10 | FAIL: post-reset target-side SifInitRpc(0) hung (froze on TEAL) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with POST-RESET INITCMD SPLIT sentinel | D-10 | FAIL: post-reset SifInitRpc(0) hung (froze on BLUE) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with POSTINITCMD RPCMODE1 sentinel | D-10 | FAIL: post-reset SifInitRpc(1) hung (froze on BLUE) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with MANUAL RPCINIT HANDSHAKE sentinel | D-10 | FAIL: manual post-reset RPCINIT handshake timed out (froze on PURPLE/MAGENTA loop) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with MANUAL RPCINIT HANDSHAKE RETRY sentinel | D-10 | FAIL: manual post-reset RPCINIT handshake retry timed out (froze on PURPLE/MAGENTA loop) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic pre-exec POPSLOADER; HDD POPSTARTER replaced with MANUAL RPCINIT HANDSHAKE UDNL RESET sentinel | D-10 | FAIL: manual post-reset RPCINIT handshake timed out (froze on PURPLE/MAGENTA loop) |
| 2026-05-22 | USB Control | USB-launched POPSLOADER.ELF + USB sidecar/CWD POPSTARTER.ELF; launching HDD or USB games | D-10 / Control | PASS: Works (IOP reset and SIF RPC initialization succeed) |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic B0 POPSLOADER (direct fileXio load only); HDD POPSTARTER | D-10 | FAIL: black screen |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic B3 POPSLOADER (direct fileXio load + target PFS unmount); HDD POPSTARTER | D-10 | FAIL: black screen |
| 2026-05-22 | D-10 Hardware | HDD Boot; diagnostic B2 POPSLOADER (standard SifLoadElf + dynamic PFS unmount); HDD POPSTARTER | D-10 | PASS: Real POPSTARTER booted and worked successfully |
| 2026-05-22 | D-10 Hardware | HDD Boot; Production POPSLOADER with B2 fix; HDD POPSTARTER | D-10 | PASS: Real POPSTARTER booted and worked successfully |
| 2026-05-22 | D-14 Hardware | HDD-backed POPSTARTER with non-HDD game; Production POPSLOADER | D-14 | PASS: Real POPSTARTER booted and worked successfully |
| 2026-05-22 | D-15 Hardware | USB Boot; USB sidecar POPSTARTER + HDD game; Production POPSLOADER | D-15 | PASS: Real POPSTARTER booted and worked successfully |
| 2026-05-22 | USB Hardware | USB Boot; USB sidecar POPSTARTER + USB game; Production POPSLOADER | USB Path | PASS: Real POPSTARTER booted and worked successfully |
| 2026-05-22 | Non-HDD Hardware | Checked non-HDD paths tested in the regression set; Production POPSLOADER | Other Paths | PASS: Checked non-HDD paths remained functional |
| 2026-05-22 | BOOT.ELF Hardware | Exit to BOOT.ELF / Triangle using System.loadELF(elf_path, 0) | L-07 / U-10 | FAIL: black screen / hangs (Candidate C SIF cleanup also failed) |
| 2026-05-22 | BOOT.ELF Hardware | Exit to BOOT.ELF / Triangle using BRAM embedded loader | L-07 / U-10 | FAIL: black screen / hangs (embedded BRAM loader diagnostic failed) |
| 2026-05-24 | D-10 Hardware | HDD Boot; Production POPSLOADER at 73e6e5d (PR #451 merged: BOOT.ELF reboot path argv0); HDD POPSTARTER | D-10 | PASS: D-10 still works -- no regression from BOOT.ELF / DKWDRV experiments |
| 2026-05-24 | BOOT.ELF Hardware | HDD Boot; System.loadELF(elf_path, reboot_iop=1, elf_path) -- the LaunchBootElf reboot-IOP path with explicit argv0 (PR #451) | U-10 | FAIL: black screen. Conclusion: standard LoadELFFromFileExecPS2RebootIOPWithPartition reboot path is the wrong target for BOOT.ELF on HDD-loaded state. PR #451 reverted on 2026-05-24. Next angle: special-case mc?:/BOOT/BOOT.ELF in the BRAM child loader so it can conditionally reset IOP under HDD-loaded state. |
| 2026-05-24 | DKWDRV Hardware | DKWDRV_PATH set to custom HDD path; Production POPSLOADER at dabfe96 (PR #452 merged: V4 :pfs:/ + reboot_iop=0 for HDD DKWDRV) | DKWDRV / D-10 paired | FAIL: black screen. Conclusion: routing HDD DKWDRV through LoadELFFromFileExecPS2 (no-reboot) with HDD keep-mask preservation also does not unblock the launch. The SifExitIopHeap/SifExitRpc/SifExitCmd teardown in the HDD-backed branch may be incompatible with DKWDRV's startup, OR the keep mask isn't actually retaining the partition slot on the way to ExecPS2. PR #452 reverted on 2026-05-24. Next angle: route HDD DKWDRV through the BRAM child loader (same path as POPSTARTER on HDD, since that passes), or copy DKWDRV.ELF to EE RAM before ExecPS2 so it has no HDD dependency at runtime. |
| 2026-05-24 | BOOT.ELF / DKWDRV | Production POPSLOADER at baed871 with PRs #451 + #452 reverted (current source returns to b725464-equivalent behavior for these two flows; PR #450 reboot_iop-dead-code-fix retained as a clean source defect repair even though it does not unblock BOOT.ELF on hardware) | U-10 / DKWDRV | Unknown (verify on hardware). Treat the rolled-back state as the next baseline. |
| 2026-05-24 | DKWDRV Hardware | DKWDRV_PATH set to custom HDD path; Production POPSLOADER with `LoadELFFromFileExecPS2RebootIOPWithPartition` updated to route HDD DKWDRV through `ExecuteHddBackedViaEmbeddedLoader` (the BRAM child-loader path POPSTARTER uses successfully on D-10). Removes the V3 `!is_dkwdrv_elf_path` exclusions; HDD DKWDRV now inherits the same B2-fix IOP-state contract as D-10. Non-HDD DKWDRV (e.g. `mc0:/PS1_DKWDRV/DKWDRV.ELF`) is unchanged: falls through to standard direct-launch + V3 argv0 synthesis. | DKWDRV | Unknown (verify on hardware). |
| 2026-05-25 | DKWDRV Hardware | Production POPSLOADER at PR #457 (commit `de6da75`): DKWDRV-HDD routed through BRAM child loader, no IOP reset. Test path: `hdd0:/__common:pfs1:/APPS/PS1_DKWDRV/DKWDRV.ELF` | DKWDRV-HDD | FAIL (Nuno): black screen. POPSTARTER-on-HDD still PASS (no regression). Conclusion: same BRAM-loader path POPSTARTER uses doesn't automatically work for DKWDRV; DKWDRV needs additional state. |
| 2026-05-25 | BOOT.ELF Hardware | Production POPSLOADER at PR #457 (commit `de6da75`): BOOT.ELF exit after HDD-boot | U-10 | FAIL (Nuno): black screen. U-10 unchanged from prior tests. |
| 2026-05-25 | DKWDRV Hardware | Production POPSLOADER at PR #458 (commit `dff091c`): added fileXio teardown to `_ps2sdk_memory_init` AND new IOP-reset branches in child loader for DKWDRV + BOOT.ELF (`is_dkwdrv_target`, `is_boot_elf_target`). Test path: `hdd0:/__common:pfs1:/APPS/PS1_DKWDRV/DKWDRV.ELF` | DKWDRV-HDD | FAIL (Nuno): black screen. POPSTARTER-on-HDD still PASS. |
| 2026-05-25 | BOOT.ELF Hardware | Production POPSLOADER at PR #458 (commit `dff091c`): BOOT.ELF exit after HDD-boot through new `is_boot_elf_target` reset branch | U-10 | FAIL (Nuno): black screen. **Worse: PR #458's `is_boot_elf_target` branch ALSO regressed V2's working USB-boot-exit-to-BOOT.ELF case** (intercepted before non-HDD branch, forced IOP reset BOOT.ELF doesn't tolerate). PR #460 reverts the regression. |
| 2026-05-25 | wLaunchELF Report | POPSLoader launched from wLaunchELF on some wLE builds (CosmicScale). PSBBN / Browser / HOSDMenu / OSDMenu launches all work. | (new) | FAIL on certain wLE builds, regardless of POPSLoader source device. PR #458 Layer A (`SifExitRpc + SifInitRpc + fileXioExit` in `_ps2sdk_memory_init` per ps2sdk #425) targets this. Hardware pending. |
| 2026-05-25 | PR #460 Source-verified | V2 mimicry: revert PR #458's `is_dkwdrv_target` and `is_boot_elf_target` child-loader branches and the reboot-variant BOOT.ELF route. Add DKWDRV special-case in `LoadELFFromFileWithPartition` mirroring V2 BOOT.ELF route (d23520a). `ui.lua OpenDKWDRV` uses `reboot_iop=0` for HDD paths. Completes the V2 contract V4 (PR #452) missed. Commit `740fa87` (BETA-12-PLAY head). | DKWDRV-HDD / L-07 | Source-verified only. Hardware pending. CI green: https://github.com/NathanNeurotic/POPSLoader/actions/runs/26416917597 |
| 2026-05-25 | PR #460/461/462 Hardware | Production POPSLOADER on BETA-12-PLAY post-merge of PR #460 + #461 (audit cleanup + doc refresh) + #462 (idle-work bundle). | D-10 / DKWDRV-HDD / DKWDRV-MC / BOOT.ELF-from-USB-boot | D-10 PASS (Nuno), DKWDRV-MC PASS (Nuno), BOOT.ELF-from-USB-boot PASS (Nuno -- V2 working route restored by reverting PR #458's regression), DKWDRV-from-HDD FAIL (Nuno, still black-screen). V2 mimicry was necessary but not sufficient for DKWDRV-HDD. |
| 2026-05-26 | PR #463 DIAG | Diagnostic-only artifact at `claude/diag-u10` with `LOADER_ENABLE_DEBUG_COLORS=1` + `POPSLOADER_DIAG_U10` stage paints in `LoadELFFromFile{WithPartition,ExecPS2RebootIOPWithPartition}`. Side branch, NOT merged. | U-10 / DKWDRV-HDD / Settings sidecar | (a) U-10 BOOT.ELF-from-HDD-boot: **last color YELLOW** (Nuno). YELLOW = post-SifLoadElf, pre-SifIopReset. ORANGE (post-reset) never paints. **SifIopReset itself hangs.** Matches H5 in `docs/U10_INVESTIGATION.md`: stale `pfs1:` mount blocks the reset. (b) DKWDRV-HDD: no colors visible -- non-reboot variant runs through to ExecPS2-to-child-loader too fast for GS BGCOLOUR to be visible against POPSLoader's still-rendering menu. Diagnostic limitation, not a code bug. (c) Settings save on HDD FAIL: error toast shows `pfs:/APPS/PS1_POPSLOADER/.pldrs may be read-only`. Bug: `etc/boot.lua` chdir's to slot-less `pfs:/...` (preserving whatever pfsdev came in via ARGV0) while the actual mount is at `pfs1:`. PR #464 normalizes to `pfs1:` in boot.lua. (d) HDD POPSTARTER + HDD games still PASS. |
| 2026-05-26 | PR #464 Source-verified | F4 fix from `docs/U10_INVESTIGATION.md` based on PR #463 diagnostic data: `LoadELFFromFileExecPS2RebootIOPWithPartition` now unconditionally calls `unmount_pfs_slots_for_exec(build_exec_keep_mask(resolved_path))` before `SifIopReset` (was previously gated on HDD-backed exec path, which skipped the unmount for BOOT.ELF on MC and let fileXio's pfs1: RPC server thread hang the reset). Plus `etc/boot.lua` normalizes any pfs slot prefix in BOOTPATH to `pfs1:` so Lua's cwd matches the actual mount slot. | U-10 / Settings sidecar HDD | Source-verified only. Hardware pending. |
| 2026-05-27 | PR #464 Hardware | BETA-12-PLAY at commit `153e703` (post PR #464 merge). Tested: HDD-booted POPSLoader, OSDmenu launch. | U-10 / Settings save HDD / D-10 | (a) U-10 BOOT.ELF-from-HDD-boot: **FAIL** (Nuno) -- still black-screens. F4 unconditional unmount wasn't enough alone. (b) Settings save on HDD-installed POPSLoader: **FAIL** (Nuno) -- error msg now correctly shows `pfs1:/APPS/PS1_POPSLOADER/.pldrs` (boot.lua normalization works) but the write still fails. Driver-level constraint suspected (`ps2hdd-osd.irx` r/w limitation). (c) D-10 still PASS (Nuno) -- HDD POPSLoader + POPSTARTER same dir, HDD games load OK. |
| 2026-05-27 | PR #466 Release prep | Disable HDD sidecar (HDD-backed APP_DIR -> sidecar=nil, save goes to mc0 fallback like pre-PR-#459). Document DKWDRV-on-HDD + U-10 as known-broken-accepted-for-release per Nuno's pragmatic call ("most users have other devices for DKWDRV, small percentage have HDD installs"). Close diag PR #463 and HDD r/w probe PR #465 as superseded. | (release) | Source-verified only. Pre-release regression check on D-10 / D-15 / DKWDRV-MC / BOOT.ELF-from-USB-boot before formal release. |
| 2026-05-27 | PR #466 Hardware | BETA-12-PLAY post-merge. Tested: POPSLoader on USB launched from wLaunchELF. | DKWDRV-MC / Settings save USB+MC / BOOT.ELF-from-wLE-USB | (a) DKWDRV.ELF launch OK from default MC path (Nuno). (b) Settings save on USB and MC: PASS (Nuno) -- confirms sidecar works on non-HDD devices. (c) BOOT.ELF exit when POPSLoader was launched via wLaunchELF FAILS (Nuno) -- black screen. Possibly always-broken/latent (same BOOT.ELF route as the working autoboot/OSDSYS cases per code analysis). Not previously tested explicitly. (d) MX4SIO / MMCE untested (no hardware on hand). |
| 2026-05-27 | PR #468 Release cut | Tagged `BETA-10-5` at commit `9a0ebe2`. `bin/changelog` v1.0.0-rev5 entry added; `etc/boot.lua` POPSLDR_VER bumped to v1.0.0-rev5; STATE.md known-broken list refined (wLE bullet removed since not confirmed as regression). GitHub release published at https://github.com/NathanNeurotic/POPSLoader/releases/tag/BETA-10-5 . | (release) | Source-verified release cut. |
| 2026-05-28 | BETA-10-5 Hardware | Tagged release artifact downloaded and installed. Tested HDD-installed POPSLoader. | D-10 / BOOT.ELF / Settings save / DKWDRV-MC | All four checks **PASS** (Nuno 2026-05-28 09:04 AM): (a) BOOT.ELF exit OK, (b) games from HDD load OK (D-10 confirmed), (c) settings save from HDD to MC OK (sidecar falls back to MC by design for HDD installs), (d) DKWDRV launch from default MC path OK. **Release is hardware-confirmed clean.** Known-broken items (DKWDRV-from-HDD-custom-path, U-10 BOOT.ELF-from-HDD-boot) match the documented expectations. |
| 2026-05-28 | CI capstone | PR #470 LAUNCH_ARGS game/debug consumers merged (commit `8b55072`). | LAUNCH_ARGS | Repo / CI verified (CI green on PR #470 merge run). Hardware UNKNOWN (verify on hardware). Test plan: boot with `-page=hdd -game=__.POPS|<VCD>` from wLE/HOSDMenu; boot with `-debug`; regression check with no args. |
| 2026-05-28 | Workflow capstone | `.github/workflows/rolling-release.yml` added (commit `761129a`). Publishes `POPSLOADER-rolling-release.zip` to canonical `rolling-release` tag on push to `BETA-12-PLAY` and on PR events. Last-write-wins. | (infra) | Operational. First production rolling-release built 2026-05-28T10:38Z. Subsequent PR builds overwrite as expected. |
| 2026-05-28 | CI capstone | PR #472 MX4SIO evidence-based mass: classification merged (commit `b0c0baf`), including maintainer refinement `7b587fe` ("USB or unknown mass stays USB-only") and C-layer `mx4sio_bd` → `usbmass_bd` dependency enforcement. | MX4SIO classification | Repo / CI verified. Hardware UNKNOWN (verify on hardware on an MX4SIO unit). Test plan: MX4SIO-booted unit shows "MX4SIO" boot label; MX4SIO page lists games; pure USB boots never load `mx4sio_bd`; no regression on USB / HDD / MC boots. |
| 2026-05-28 | Hardware regression | Tester reported rolling-release crashed on Enceladus boot with `[string "system.lua"]:3148: attempt to call a nil value (global 'ClassifyMassRootDriver')`. Cause: PR #472 maintainer refinement `7b587fe` reorganized mass-classification helpers, ending up with `local function ClassifyMassRootDriver` declared AFTER `ClassifyStartupMassTargets` which calls it. Lua's `local function` doesn't hoist; the closure couldn't capture it as an upvalue and fell through to globals (nil) at runtime. | (crash) | Reported by maintainer's tester 2026-05-28. Reproduced as Enceladus error screen. Lua syntax check did not catch it (source-valid; runtime-broken). |
| 2026-05-28 | CI capstone | PR #473 HOTFIX merged (commit `81c886e`). Moves `local function ClassifyMassRootDriver` declaration above `ClassifyStartupMassTargets`. Removes duplicate later declaration. Body unchanged. | (crash fix) | Repo / CI verified. Hardware UNKNOWN (verify on hardware — the next rolling-release test cycle confirms whether boot reaches the menu). |
| 2026-05-28 | Open work | PR #471 (DRAFT) `claude/curious-noether-3f2a8`: Layer C `mmceman.irx` lazy-loaded unless `boot_device_hint == "MMCE"`. Includes the PR #473 hotfix and a MMCE/MC clarification commit. | Layer C mmceman | Repo / CI verified. Hardware: pad input PASS (Nuno 2026-05-28; all his other tests worked and pad input is required for those). MMCE-specific page entry from deferred state NOT specifically tested. |
| 2026-05-28 | Reference branch | `NUNO-CHECKPOINT-5282026` pinned to PR #471 head `860ae26` as a stable reference to whatever rolling-release asset Nuno is testing. Tag floats; branch is fixed. | (infra) | Operational. |
| 2026-05-28 PM | Nuno on rolling-release | Hardware verification pass after PR #470/#472/#473 merged + PR #471 mmceman defer in artifact (commit `860ae26`). Tested: MX4SIO + USB boot/classification, BOOT.ELF exit "across the board", DKWDRV from MC regardless of booted source, USB sidecar settings save. | MX4SIO classification / USB / BOOT.ELF (incl. U-10) / DKWDRV-MC / Settings save USB | **PASS across the board (Nuno 2026-05-28 PM):** (a) MX4SIO and USB working as intended — PR #472 evidence-based classification confirmed on hardware. (b) **BOOT.ELF exit working across the board, including HDD-booted POPSLoader (U-10)** — this is unexpected because PR #470/#472/#473 don't architecturally touch the U-10 path; possible side effects of the C-layer `EnsureUsbMass`-first ordering or the boot-crash fix changing earlier-than-BOOT.ELF state are not yet investigated. **U-10 status downgraded from known-broken-accepted to PASS** in STATE/ROADMAP/TRUTHSHEET/README. (c) DKWDRV from MC works regardless of POPSLoader boot source (USB/MX4SIO/HDD all confirmed). (d) Settings save works from USB-booted POPSLoader (sidecar at APP_DIR/.pldrs). **Confirmed known-broken (no change):** DKWDRV from custom HDD path. **By-design fallback (confirmed working):** HDD-installed POPSLoader settings save to `mc0:/POPSTARTER/.pldrs` (PR #466). MMCE device access from deferred-load state NOT specifically tested but pad/everything-else PASS implies the Layer C mmceman defer didn't break general boot. |
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
    - latest recorded hardware on this line is therefore `PASS`; preserve that behavior through further `D-10` work.
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
    - current source also returns the actual embedded-loader `ExecPS2` result instead of collapsing it to `-1`, keeps legacy `System.loadELF(path, reboot_iop, selector)` on POPSTARTER's normal one-argument selector contract, now shows the actual exec path separately from the probed/opened POPSTARTER path in the launcher popup, routes partition-aware HDD launches through the explicit `System.loadELFWithPartition(path, reboot_iop, partition_context, selector)` API and mounted-`pfs0:` `SifLoadElf` in the embedded loader, normalizes stale canonical profile-path state so Profile 1/default does not silently keep another profile's HDD POPSTARTER path, and keeps the older iomanX-aware `fileXio` path only as the fallback for direct `pfs:` / `hdd:` loads with no partition-aware HDD context.
    - 2026-05-19 source audit found remaining handoff defects before new hardware retests: Lua mounted-PFS fallback can leave stale launch context, normal HDD game labels can fail fallback partition parsing, the fallback path can skip the pre-exec gate even when reconstruction failed, `System.loadELF(..., args..., partition_context)` can leak the partition context into target argv, the generic embedded-loader default-argv contract is unreachable, and the child loader still uses `snprintf`/`strncat` despite older docs claiming that risk was avoided. See `HDD_POPSTARTER_HANDOFF.md`.
    - 2026-05-19 source change applies the audit fixes except for the child-loader `snprintf`/`strncat` cleanup (which would require regenerating the embedded loader blob): bare HDD partition labels are now normalized via `NormalizeHddPartitionLabelForMount` before the mounted-PFS fallback parses them, the `RunPOPStarterGame` context table is resynced from the fallback locals before `LaunchEngine` consumes it, the HDD pre-exec gate is only skipped when the fallback actually reconstructed a path, a dedicated `System.loadELFWithPartition(path, reboot_iop, partition_context, args...)` binding in `src/luasystem.cpp` replaces the trailing-arg overload so partition_context can no longer leak into target argv, `LaunchEngine` calls the new binding when partition context is set, and `ExecuteViaEmbeddedLoader` no longer rejects `argc == 0` so the documented child-loader default-argv synthesis is reachable. POPSTARTER-specific argv0 enforcement in `ExecuteHddBackedViaEmbeddedLoader` is unchanged.
    - 2026-05-20 hardware screenshot from the latest `BETA-12-PLAY` artifact showed a narrower returned failure: the HDD POPSTARTER pre-exec gate could not resolve partition context for `pfs3:/POPS/POPSTARTER.ELF`, while the app dir was `hdd0:+OPL:pfs:/APPS/PS1_POPSLOADER/`.
    - 2026-05-20 source follow-up keeps the selector contract unchanged, fixes the argument-shifted failure popup call sites, lets Lua parse the repo's own `hdd0:PART:` partition-context form, lets the shared HDD partition recovery candidate builder accept safe bare labels such as `__.POPS`, and lets mounted-PFS fallback recover the actual POPSTARTER source partition before falling back to the selected HDD game partition.
    - a later 2026-05-20 readable-diagnostic screenshot showed the next source issue: the gate was checking the loader-facing generic `pfs:/POPS/POPSTARTER.ELF` path with `doesFileExist()` instead of checking a real mounted slot path. The source now derives a mounted probe path for the gate while preserving the generic exec path for the C loader.
    - the latest source simplification pass makes that partition-aware/gated route non-default for normal `X`: HDD-backed POPSTARTER keeps the resolved executable path, clears Lua partition context, skips the Lua gate/remount fallback, skips the embedded-loader reboot path, and uses legacy `System.loadELF(path, 0, selector)`.
    - that direct non-reboot artifact still black-screened before POPSTARTER debug screens, so the current source removes the remaining HDD-only parent pre-`ExecPS2` cleanup from `LoadELFFromFileExecPS2()` to avoid `fileXioUmount`/SIF teardown behavior that the working non-HDD POPSTARTER path does not use.
    - hardware result after the 2026-05-20 source follow-up remains `Unknown (verify on hardware)`. Verify `D-15` first to confirm non-HDD-POPSTARTER HDD-game still passes, then `D-10` `X`, then `D-10` `R2`, then `D-14`.
    - current source still exposes an `R2` alternate HDD launch for HDD-resident `POPSTARTER.ELF` that changes only the selector path to `hdd0:PART:pfs0:/GAME.ELF`; hardware result is still `Unknown (verify on hardware)`.
    - on 2026-05-22, a series of targeted target-side diagnostic sentinels were run on hardware to isolate the D-10 black screen / hang location:
      1) SIFLOADFILE sentinel: target-side SifInitRpc(0) and SifLoadFileInit() succeeded (GREEN->YELLOW->WHITE->RED/MAGENTA loop), proving the hang is later than SifLoadFileInit().
      2) FILEXIOINIT sentinel: target-side fileXioInit() succeeded (GREEN->CYAN->YELLOW->WHITE->RED->BLUE->MAGENTA/GREEN loop), proving the hang is later than fileXioInit().
      3) TARGET-IOPRESET and TARGET-IOPRESET-EXITRPC sentinels: target-side SifIopReset("", 0) and SifIopSync() returned, but the subsequent post-reset SifInitRpc(0) hung (froze on TEAL).
      4) MINIMAL TARGET-IOPRESET and MINIMAL TARGET-IOPRESET-EXITRPC sentinels: post-reset SifInitRpc(0) still hung (froze on TEAL), proving prior SifLoadFileInit() or fileXioInit() state is not the cause.
      5) POST-RESET INITCMD SPLIT and POSTINITCMD RPCMODE1 sentinels: explicit post-reset SifInitCmd() succeeded, but subsequent SifInitRpc(0) or SifInitRpc(1) still hung (froze on BLUE).
      6) Manual RPCINIT Handshake Probing sentinel (SENTINEL_TARGET_IOPRESET_RPCINIT_HANDSHAKE_POPSTARTER.ELF): manual post-reset RPCINIT handshake probe. Timed out on hardware (froze on PURPLE/MAGENTA loop), confirming IOP does not respond to the initialization command after reset.
      7) Manual RPCINIT Handshake Retry sentinel (SENTINEL_TARGET_IOPRESET_RPCINIT_RETRY_POPSTARTER.ELF): manual post-reset RPCINIT handshake attempts with named retry delays (RETRY_DELAY_1, RETRY_DELAY_2, RETRY_DELAY_3) and packet reinitialization. Hardware result: FAIL (timed out, froze on PURPLE/MAGENTA loop).
      8) Manual RPCINIT Handshake UDNL Reset sentinel (SENTINEL_TARGET_IOPRESET_UDNL_RPCINIT_POPSTARTER.ELF): tests whether the blank target-side IOP reset argument is the poisonous variable by calling SifIopReset("rom0:UDNL rom0:EELOADCNF", 0). Hardware result: FAIL (timed out, froze on PURPLE/MAGENTA loop).
         - *Interpretation*: Blank reset argument is ruled out as the sole poisonous variable. SifIopReset/Sync/InitCmd and sceSifSendCmd all return, but SIF_SREG_RPCINIT is never signaled.
         - *Boundary Correction*: The failure is tied to the HDD-backed POPSTARTER source / HDD-backed loader-origin state, not the selected game device/listing.
           - **Known-good**: USB POPSLOADER.ELF + USB sidecar/CWD POPSTARTER.ELF works, including when selecting HDD games.
           - **Known-bad**: HDD POPSLOADER.ELF + HDD sidecar/CWD POPSTARTER.ELF fails. HDD POPSTARTER.ELF fails regardless of selected game device/listing.
           - **Diagnostic Boundary**: The next investigation should isolate differences immediately before ExecPS2 when loading the target ELF from HDD versus USB sidecar/CWD (file-open/mount state, CWD/source device state, argv/environment, and leftover IOP module state).
      9) USB Control Test: USB-launched POPSLOADER.ELF + USB sidecar/CWD POPSTARTER.ELF works, including when selecting HDD games. Hardware result: PASS.
         - *Interpretation*: The post-reset SIF RPC handshake succeeds when POPSTARTER is executed from USB, even if the game was selected from the HDD listing. This proves the HDD game-selection environment itself is not the poison. The failure follows the HDD-backed POPSTARTER / HDD-backed launch-origin state.
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
    - user reported a 2026-05-20 latest-artifact regression where USB boot with USB sidecar/cwd `POPSTARTER.ELF` plus an HDD title black-screened.
    - current source follow-up restores legacy `System.loadELF(path, reboot_iop, selector)` one-argument behavior for normal/non-HDD POPSTARTER launches while leaving partition-aware HDD POPSTARTER launches on `System.loadELFWithPartition(...)`; hardware result is `Unknown (verify on hardware)`.
    - user then reported explicit `mass:/POPS/POPSTARTER.ELF` launches, while default/cwd sidecar resolution can stop at `Cant find POPSTARTER ELF`; current source now adds live-CWD sidecar lookup and safer boot/app fallback candidates. Hardware result is `Unknown (verify on hardware)`.
  - `U-10`: one artifact was reported good before a later regression experiment.
    - repo history shows the BOOT.ELF modal later changed from its older non-reboot direct `System.loadELF(elf_path, 0, elf_path)` path to a reboot-I/O path with launch-CWD setup.
    - a later 2026-03-29 hardware report said BOOT.ELF still behaved incorrectly once HDD runtime had been initialized on that restored non-reboot source.
    - current working inference is that `U-10` may share the same underlying handoff/state-poisoning boundary as `D-10`, but that remains unproven and must be validated separately on hardware.
    - 2026-05-22 hardware testing of the System.loadELF(elf_path, 0) candidate (and Candidate C cleanup) failed with a black screen. U-10 remains FAILED/known-broken.
    - 2026-05-22 hardware testing of the BRAM-loader exact-path diagnostic (ExecuteViaEmbeddedLoader) also failed with a black screen.
- All other manual hardware items remain `Unknown (verify on hardware)` unless run logs are added above.
