Last updated: 2026-05-28 (post-BETA-10-5; PR #470 LAUNCH_ARGS, PR #472 MX4SIO classification, PR #473 hotfix merged)

# DECISIONS

## Decision Log Format
Each entry records:
- Date (`YYYY-MM-DD`)
- Decision
- Rationale
- Implications
- Evidence

## Decision Log

### 2026-05-28 PM — U-10 Unexpectedly Resolved; Known-Broken List Reduced to DKWDRV-HDD-Custom
- Decision: Mark U-10 (BOOT.ELF from HDD-booted POPSLoader) as PASS in STATE.md, README.md, ROADMAP.md, TRUTHSHEET.md, and `QA_REGRESSION_MATRIX.md`. Remove the known-broken-accepted entry for U-10. Preserve `docs/U10_INVESTIGATION.md` and `claude/diag-u10` branch in case of regression.
- Rationale: Nuno's 2026-05-28 PM hardware test on the rolling-release artifact built post-PR-#470/#472/#473 reports BOOT.ELF exit working "across the board" including HDD-booted POPSLoader. None of those PRs architecturally touch the U-10 path; the cause is not obvious. Candidate explanations: (a) C-layer `EnsureUsbMass`-first ordering in PR #472 incidentally cleans IOP state; (b) earlier "U-10 fails" reports were partially obscured by the now-fixed PR #473 boot crash; (c) test environment shifted. None of these is conclusive without further investigation.
- Implications: The only confirmed-broken edge case in BETA-10-5 + post-release work is **DKWDRV from custom HDD path** (re-confirmed broken by Nuno same session). HDD-install settings save to MC fallback is by design (PR #466), not a bug. The previously-noted wLE → USB POPSLoader → BOOT.ELF latent failure is covered by the "across the board" PASS.
- Implications (continued): Since the root cause of the resolution is not understood, treat U-10 as conditionally PASS. Any future change touching IOP teardown, mass-backend ordering, or BOOT.ELF launch routes should retest U-10 explicitly.
- Evidence: `QA_REGRESSION_MATRIX.md` row "2026-05-28 PM | Nuno on rolling-release". Maintainer report 2026-05-28 PM: "Everything is working except saving settings, and hdd custom path dkwdrv."

### 2026-05-28 PM — PR #470, #472, #473 Hardware-Verified
- Decision: Promote PR #470 (LAUNCH_ARGS consumers), PR #472 (MX4SIO evidence-based classification), and PR #473 (forward-reference hotfix) from `Unknown (verify on hardware)` to PASS in STATE.md and TRUTHSHEET.md.
- Rationale: Nuno's 2026-05-28 PM hardware test on the rolling-release artifact (commit `860ae26` from PR #471 branch, includes all merged BETA-12-PLAY changes plus Layer C mmceman defer) confirms: MX4SIO and USB working as intended, BOOT.ELF exit working across the board, DKWDRV from MC working regardless of POPSLoader boot source, USB sidecar settings save working. No boot crash.
- Implications: The post-release backbone is now hardware-validated. PR #471 (Layer C mmceman defer, currently DRAFT) is indirectly hardware-PASS for general boot + pad input; MMCE-specific device access from deferred-load state is the one untested case. Recommend an explicit MMCE test before promoting PR #471 from DRAFT.
- Evidence: `QA_REGRESSION_MATRIX.md` row "2026-05-28 PM | Nuno on rolling-release".

### 2026-05-28 — Layer C `mmceman` Lazy Load (PR #471, DRAFT)
- Decision: `mmceman.irx` is eagerly loaded at boot only when `boot_device_hint == "MMCE"`; for USB / MC / MX4SIO / HDD boots (all HDD root variants — `hdd*`, `pfs*`, `ata*`, `apa*`) the IRX is deferred and loaded on demand via `System.ensureMmceman` from `PLDR.EnsureMmceReadyOnce`.
- Rationale: MMCE third-party adapters (`mmce0:/`, `mmce1:/`) are a small subset of installs; loading the IRX eagerly for all boot types wastes ~50-100ms. MC (`mc0:/`, `mc1:/`, standard PS2 memory cards) is a distinct device handled by `mcman`/`mcserv` which are always loaded — MMCE and MC are not the same device.
- Implications: PR #471 is DRAFT. Hardware test must verify pad input survives on USB / HDD / MC boots (no IRX load order regression) and that MMCE-page entry from a deferred state correctly lazy-loads.
- Evidence: `src/main.cpp` line 446+, `src/luasystem.cpp` `EnsureMmceman`/`MarkMmcemanLoaded`, `bin/POPSLDR/system.lua` `PLDR.EnsureMmceReadyOnce`. PR #471, branch `claude/curious-noether-3f2a8`.

### 2026-05-28 — Lua Forward-Reference Hotfix (PR #473)
- Decision: Move `local function ClassifyMassRootDriver` declaration above `ClassifyStartupMassTargets`. Remove the duplicate later declaration.
- Rationale: Lua's `local function f()` is sugar for `local f; f = function()...end`; the local doesn't exist in scope until its declaration line. A caller declared above can't capture it as an upvalue and falls through to a global lookup (nil) at call time. Hardware regression 2026-05-28: rolling-release crashed on Enceladus boot with `attempt to call a nil value (global 'ClassifyMassRootDriver')`. Source-valid; runtime-broken; Lua syntax check did not catch it.
- Implications: Body unchanged. No behavior change other than the crash going away.
- Evidence: `bin/POPSLDR/system.lua` post-PR #473 has `ClassifyMassRootDriver` at line 3135, `ClassifyStartupMassTargets` at line 3146. PR #473 (`claude/hotfix-classify-mass-root-driver`), merged 2026-05-28T17:20Z.

### 2026-05-28 — MX4SIO Evidence-Based Mass: Classification (PR #472 + refinement `7b587fe`)
- Decision: At boot, `mass:/`-prefixed devices are classified by the ioctl driver name returned by `System.getMassMountDriver`. `sdc`/`mx4` → MX4SIO; any other non-empty driver → USB; empty ioctl → fall through to legacy markers, then USB default. `mx4sio_bd.irx` is only loaded on explicit MX4SIO evidence: `mx4sio:/` prefix, `sdc`/`mx4` ioctl driver, or `.boot_mx4sio` marker. `AutoInitStartupBackends` loads only `usbmass_bd` before the first classification pass; `mx4sio_bd` loads conditionally on the second pass when an ambiguous mass slot remains (`mass_probe_needed`).
- Rationale: Per maintainer 2026-05-28: "If ioctl/devctl is ANYTHING OTHER THAN `sdc` or `mx4`, and it's a mass device, then it is USB; if a mass device is `sdc`/`mx4` on ioctl/devctl, then it must be MX4SIO." "MX4SIO should only init on startup if it came from `mx4sio:/` or `mass` with `sdc` devctl." Mass mounting is volatile — the same path (`mass:/`, `massN:/`, `mx4sio:/`, `usb:/`) can be either backend depending on hotplug + IRX load order, and the ioctl driver name is the only authoritative classifier.
- Implications: USB boots never load `mx4sio_bd`. MX4SIO boots load `mx4sio_bd` conditionally after the ambiguity is detected. The `.boot_mx4sio`/`.boot_usb` markers remain as legacy fallback for extreme hardware quirks where ioctl never returns a driver.
- Evidence: `bin/POPSLDR/system.lua` `classify_mass_boot`, `AutoInitStartupBackends`, `ClassifyStartupMassTargets`. Maintainer refinement commit `7b587fe`. PR #472 merged 2026-05-28T11:22Z.

### 2026-05-28 — `mx4sio_bd` Depends on `usbmass_bd` (Enforced at C Layer)
- Decision: `lua_mx4sio_init` in `src/luasystem.cpp` calls `EnsureUsbMass()` before loading `mx4sio_bd.irx`. The order is unviolatable from Lua.
- Rationale: Per maintainer 2026-05-28: "mx4sio will need the usb drivers to activate before it with it. USB will never need MX4SIO drivers." Multiple Lua call sites previously could load `mx4sio_bd` without first ensuring `usbmass_bd` was up; enforcing the order at the lowest level removes a class of bugs.
- Implications: Pure USB boots still never load `mx4sio_bd` (per the evidence-based classification rule above). When `mx4sio_bd` does load, `EnsureUsbMass()` is a cheap idempotent call (gated by `usbmass_irx_loaded`).
- Evidence: `src/luasystem.cpp` `lua_mx4sio_init`. PR #472 commit `357e3b8`.

### 2026-05-28 — `PLDR.LAUNCH_ARGS.game` and `-debug` Consumers Wired (PR #470)
- Decision: Add `PLDR.AutoLaunchFromLaunchArgs()` — when both `-page=<kind>` and `-game=<selector>` are set, auto-launch via `RunPOPStarterGame` after `AutoInitStartupBackends`. Supports HDD (`PARTITION|relpath`), USB (`FILE.VCD` relative to `mass:/POPS`), MX4SIO, MMCE. Add `PLDR.SurfaceLaunchArgsDebug()` — when `-debug` is set, queue a boot-context toast showing kind, boot_path, sidecar_path, settings, and parsed launch args.
- Rationale: PR #458 / PR #462 shipped the LAUNCH_ARGS infrastructure (parser + carousel auto-nav) but the `game` and `debug` values were parsed without consumers. This PR completes the loop so NHDDL-style shortcuts (e.g. wLaunchELF entries launching POPSLoader with a specific HDD game) work end-to-end.
- Implications: On launch failure, `AutoLaunchFromLaunchArgs` falls through to the main menu with an error toast — default behavior unchanged when no `-game=` is passed. `-debug` is a low-cost runtime diagnostic that doesn't require rebuilding with `DPRINTF` enabled.
- Evidence: `bin/POPSLDR/system.lua` near line 5087+. PR #470 merged 2026-05-28T10:12Z.

### 2026-05-28 — Rolling Release Workflow Operational
- Decision: `.github/workflows/rolling-release.yml` publishes a `POPSLOADER-rolling-release.zip` asset to the canonical `rolling-release` GitHub Release on every push to `BETA-12-PLAY` and on every pull-request event (`opened`, `synchronize`, `reopened`, `ready_for_review`). The tag floats; testers grab the latest asset URL.
- Rationale: Testers (Nuno, CosmicScale) consume builds from a single stable URL. Manual artifact hosting is fragile. Last-write-wins semantics are acceptable because tester traffic is coordinated.
- Implications: PR builds AND BETA-12-PLAY push builds both overwrite the same asset. Multiple in-flight PRs can churn the asset; the maintainer must coordinate which PR's build is current when sending a tester to the URL. Per-PR per-tag releases were considered and rejected in favor of the single-URL workflow.
- Evidence: `.github/workflows/rolling-release.yml` (added commit `761129a`). Rolling Release URL: https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/POPSLOADER-rolling-release.zip.

### 2026-05-28 — BETA-10-5 Hardware Confirmation (Nuno)
- Decision: BETA-10-5 release artifact at commit `9a0ebe2` is hardware-confirmed clean.
- Rationale: 2026-05-28 09:04 AM hardware test by Nuno verified: (a) BOOT.ELF exit OK, (b) HDD games load OK (D-10), (c) settings save from HDD-installed POPSLoader to MC works (sidecar fallback by design), (d) DKWDRV launch from default MC path OK. Known-broken items match documented expectations (DKWDRV-from-HDD-custom-path, U-10 BOOT.ELF-from-HDD-boot).
- Implications: D-10, D-14, D-15, DKWDRV-MC, BOOT.ELF (USB-booted), and HDD-install-settings-to-MC are now preservation contracts. Any future work must not regress these.
- Evidence: `QA_REGRESSION_MATRIX.md` row dated 2026-05-28.

### 2026-05-27 — BETA-10-5 Release Cut (`v1.0.0-rev5`, commit `9a0ebe2`)
- Decision: Tag the stable backbone of post-March work as `BETA-10-5` (`v1.0.0-rev5`). Publish GitHub release at https://github.com/NathanNeurotic/POPSLoader/releases/tag/BETA-10-5.
- Rationale: D-10/D-14/D-15 hardware-passing (B2 fix), DKWDRV-MC hardware-passing, BOOT.ELF (USB-booted) working via V2 route, per-device settings sidecar working for USB/MC/MMCE. The remaining items (DKWDRV-HDD-custom, U-10 BOOT.ELF-from-HDD-boot) had been investigated repeatedly without a stable fix; pragmatically accept them with workarounds rather than block the release.
- Implications: `bin/changelog` v1.0.0-rev5 entry; `etc/boot.lua` POPSLDR_VER bumped; STATE.md known-broken list refined.
- Evidence: PR #468 merged 2026-05-27. Tag `BETA-10-5` at `9a0ebe2`.

### 2026-05-27 — HDD Sidecar Disabled; Known-Broken Edge Cases Accepted (PR #466)
- Decision: HDD-installed POPSLoader saves settings to `mc0:/POPSTARTER/.pldrs` rather than `pfs1:/<install dir>/.pldrs`. `ResolveBootContext` returns `sidecar_path = nil` for any HDD-rooted APP_DIR (`pfs%d*`, `hdd%d*`, `ata%d*`, `apa%d*`). Document DKWDRV-from-HDD-custom-path and U-10 BOOT.ELF-from-HDD-boot as known-broken accepted for the release.
- Rationale: PR #459 had added `pfs1:` write support assuming `etc/boot.lua`'s RW mount worked; Nuno's 2026-05-27 hardware test on PR #464 confirmed that `pfs1:/.../.pldrs` writes still fail with "may be read-only" despite the boot.lua path normalization. The bundled `ps2hdd-osd.irx` driver has read-write limitations we can't reliably work around without an IRX swap that risks regressing D-10. Per Nuno + maintainer 2026-05-27: "rollout dkwdrv; vast majority of users will have other devices for DKWDRV, small percentage have HDD installs". Shift from chasing edge-case bugs to shipping the stable backbone.
- Implications: HDD-installed POPSLoader is back to pre-PR-#459 settings-save behavior (no regression vs. legacy). Non-HDD installs (USB / MX4SIO / MMCE / MC) keep per-device sidecar. In-flight diag PR #463 and HDD r/w probe PR #465 closed as superseded; branches preserved.
- Evidence: `bin/POPSLDR/system.lua` `ResolveBootContext` (lines 1764+), PR #466 merged 2026-05-27.

### 2026-05-25 — NHDDL-Style Launch Argument Parsing (PR #458)
- Decision: `main.cpp parseLaunchArgs()` recognizes `-page=<kind>`, `-mode=<kind>` (NHDDL alias), `-game=<selector>`, `-debug`. `System.getLaunchArgs()` exposes parsed values to Lua. `PLDR.LAUNCH_ARGS = {page, page_raw, game, debug}` is normalized at module load.
- Rationale: CosmicScale requested `-mode=ata` for NHDDL parity. Generalizing to `-page=`/`-game=` lets users wire wLaunchELF entries directly to a specific device page or game. Page-only consumer (carousel auto-nav) landed in PR #462; game and debug consumers landed in PR #470.
- Implications: Default behavior unchanged when no flags are passed.
- Evidence: `src/main.cpp` `parseLaunchArgs`, `src/luasystem.cpp` `lua_getLaunchArgs`, `bin/POPSLDR/system.lua` LAUNCH_ARGS parser. PR #458, #462, #470.

### 2026-05-25 — Unified `ResolveBootContext` Resolver (PR #458)
- Decision: A single canonical Lua resolver `ResolveBootContext()` combines the C-side argv[0] classification hint (`detectBootDeviceHintFromArgv0` / `System.getBootDeviceHint`), Lua-side prefix matching (`mass`/`mmce`/`mx4sio`/`pfs`/`hdd`/`smb`/`host`/`usb`/`ata`/`apa`), and the mx4sio `mass:/` driver-identity refinement. `DetectBootDevice`, `PLDR.GetBootContext`, `PLDR.GetBootKind`, and the settings sidecar path all consume this one resolver.
- Rationale: Previously three near-duplicate detection paths drifted out of sync. Unification eliminates a class of "boot detection says X but settings think Y" bugs.
- Implications: Future device-detection changes happen in one place. New ps2sdk device-kind prefixes (`usb`, `ata`, `apa`) added without breaking the legacy `mass`/`mmce`/`mx4sio`/`pfs`/`hdd`/`smb`/`host` detection.
- Evidence: `bin/POPSLDR/system.lua` lines 1694+, `src/main.cpp` `detectBootDeviceHintFromArgv0`, `src/luasystem.cpp` `lua_getBootDeviceHint`. PR #458.

### 2026-05-25 — Per-Device Settings Sidecar with First-Run Migration (PR #459, PR #462)
- Decision: Settings persist at `PLDR.SETTINGS_PATH`, resolved at load time by `LoadSettingsNonFatal`. Sidecar at `APP_DIR_LOCAL/.pldrs` is preferred; legacy `mc0:/POPSTARTER/.pldrs` is fallback. First-run migration: when settings load from MC but a sidecar path is computable, pin `PLDR.SETTINGS_PATH` to the sidecar so the next save migrates. HDD-rooted APP_DIRs are excluded per the PR #466 decision above.
- Rationale: Old design hardcoded `mc0:/POPSTARTER/.pldrs` regardless of where POPSLoader was installed. Users with USB / MX4SIO / MMCE installs got their settings written back to the boot card unconditionally.
- Implications: USB / MX4SIO / MMCE installs keep their own settings without ever touching `mc0:/POPSTARTER`. HDD installs fall back to MC by design.
- Evidence: `bin/POPSLDR/system.lua` `LoadSettingsNonFatal` (migration via `migrate_to_sidecar`), `SaveSettingsAtomic`, `ResolveBootContext` (sidecar path computation). PR #459, #462.

### 2026-05-22 — Minimal B2 Dynamic PFS Unmount Production Fix
- Decision: Apply the B2 dynamic PFS unmount fix to the child loader pre-ExecPS2 sequence for HDD-backed POPSTARTER paths, bypassing the child loader's post-load IOP reset and re-initialization.
- Rationale: Target-side diagnostic sentinel testing proved that resetting the IOP post-load in the HDD-backed loader environment causes subsequent RPC/SIF handshake initialization (SifInitRpc) to hang due to the target partition remaining mounted. Dynamically unmounting only the exact target PFS mount prefix (e.g., `pfs0:`) resolved the hang and restored the handshake without needing a loader-side reset.
- Implications: HDD-backed POPSTARTER launches proceed with the standard SifLoadElf path but with PFS slot cleanup before ExecPS2. Non-HDD paths remain completely unaffected.
- Evidence: `src/elf_loader/src/loader/src/loader.c`, B2 diagnostic variant (`artifacts/local-d10/20260522-122000-popsloader-hdd-preexec-unmount-target-pfs/POPSLOADER.ELF`).

### 2026-03-06 — Lua runtime is embedded-only at boot
- Decision: boot and required runtime Lua modules are loaded from embedded blobs, not loose filesystem Lua files.
- Rationale: deterministic startup and fewer layout-dependent failures.
- Implications: editing runtime Lua requires rebuilding the ELF.
- Evidence: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.

### 2026-03-06 — Settings persist as a transaction on Settings/Profile exit
- Decision: settings edits are staged in UI draft state and committed on confirm/leave.
- Rationale: avoid repeated writes while navigating and keep save/apply failure handling explicit.
- Implications: runtime/UI state sync must still happen if save/apply fails.
- Evidence: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.

### 2026-03-26 — USB vs MX4SIO identity is authoritative by mount driver
- Decision: mounted mass roots are classified by driver identity, not by path spelling.
- Rationale: real hardware can expose both USB and MX4SIO through `mass*:/`.
- Implications: startup auto-init, boot-device labeling, and page list building must continue to use mount-driver queries.
- Evidence: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`.

### 2026-03-26 — Runtime device locks are no longer enforced
- Decision: the old per-session device lock system is no longer an active runtime constraint.
- Rationale: device access should not be blocked by stale lock state.
- Implications: docs must not claim that switching devices requires restart; future changes must not silently reintroduce that gate.
- Evidence: `bin/POPSLDR/ui.lua` (`canEnterDevice`, `setDeviceLock`).

### 2026-03-26 — Startup backend initialization is path-driven
- Decision: startup backend auto-init considers boot paths and configured executable/profile paths, not just the page the user opens first.
- Rationale: a configured POPSTARTER/DKWDRV/profile path can require backend drivers before any device page is visited.
- Implications: startup docs and validation must cover boot source plus configured paths, and HDD startup targets must run the full HDD module-load path rather than only low-level exec initialization.
- Evidence: `bin/POPSLDR/system.lua` (`CollectStartupBackendTargets`, `AutoInitStartupBackends`).

### 2026-03-26 — PAL UI uses the same 640x448 raster layout as NTSC-authored UI assets
- Decision: PAL mode keeps the UI raster at `640x448` instead of stretching the authored layout vertically.
- Rationale: reduce PAL squish on menus and authored UI assets.
- Implications: final on-TV proportions still require hardware confirmation.
- Evidence: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.

### 2026-03-26 — Release ZIP contract is strict and PATCH_5-based
- Decision: CI package includes exact `PS1_POPSLOADER/*` launcher files plus `POPS/PATCH_5.BIN`, now including `PS1_POPSLOADER/BUILD_INFO.txt`, and rejects legacy `POPS/*.tm2` payloads.
- Rationale: prevent release drift and ambiguous installation instructions.
- Implications: docs and workflow validation must stay synchronized, and GitHub-built hardware candidates now carry a visible build stamp while CI also checks for expected embedded runtime markers before packaging.
- Evidence: `.github/workflows/compilation.yml`.

### 2026-03-29 — `QA_REGRESSION_MATRIX.md` is the detailed run ledger
- Decision: keep per-artifact hardware/CI chronology in `QA_REGRESSION_MATRIX.md`, while `README.md`, `STATE.md`, and `ROADMAP.md` summarize the stable current state and constraints.
- Rationale: repeated experiment history had started drifting across the root docs and obscuring the actual current handoff state.
- Implications: root docs should point to the matrix for detailed chronology instead of carrying their own competing mini-ledgers.
- Evidence: repository documentation audit on 2026-03-29.

### 2026-05-13 — Separate build/package CI from comment-triggered AI automation
- Decision: treat `.github/workflows/compilation.yml` as the build/package validation source of truth, and document `.github/workflows/opencode.yml` separately as comment-triggered repository automation.
- Rationale: the opencode workflow can affect repository collaboration but does not build artifacts, enforce the release ZIP contract, or prove runtime/hardware behavior.
- Implications: source-truth audits should include both workflow files, while CI/package claims should continue to cite only the compilation workflow unless the automation contract changes.
- Evidence: `.github/workflows/compilation.yml`, `.github/workflows/opencode.yml`.

### 2026-05-19 — Default cover image is optional at compile time
- Decision: `bin/POPSLDR/IMG/default.png` is optional. CI/artifact builds without it omit `asset_default_png` and fall back to the required `MISSING.png` asset for `IMG.default`.
- Rationale: default cover art should only be embedded when the PNG is present in the checkout used by GitHub Actions.
- Implications: `MISSING.png` remains required; `default.png` can be removed without breaking artifact builds.
- Evidence: `Makefile`, `src/embed_assets.cpp`, `bin/POPSLDR/images.lua`, `bin/POPSLDR/ui.lua`.

## Archived Investigations

> The investigations below were active during the March–May 2026 development cycle and are now **largely resolved** by the BETA-10-5 release. They are preserved verbatim for historical context and to document the diagnostic chain that produced the B2 fix at commit `4ae6679` (D-10) and the V2 BOOT.ELF route at commit `d23520a` (L-07). For the current state, see `STATE.md`, `TRUTHSHEET.md` Current Hardware Status Markers, and `QA_REGRESSION_MATRIX.md`.


- HDD startup auto-init on HDD boot/configured paths:
  - a 2026-03-27 hardware report said booting from HDD did not auto-init the HDD driver stack.
  - current code had detected HDD startup targets correctly but only called `EnsureHddRuntimeReadyForExec()`, which stops at low-level `HDD.Initialize()`.
  - current source now routes HDD startup targets through `PLDR.LoadHDDModules()` so startup uses the same HDD status/partition/cache initialization path as the HDD page.
  - a later boot-time report showed that using the full HDD page path at startup also caused large HDD libraries to spend boot time scanning partitions and building the games list.
  - current source therefore keeps startup HDD auto-init limited to runtime readiness only; partition scanning and game-list building remain page-entry work.
  - optional HDD cache writing now reuses the page-built game list instead of rebuilding one during startup.
  - later 2026-03-28 hardware reports on that narrowed boot-time split source still said HDD-backed startup/Profile POPSTARTER could disappear after entering the USB page before the HDD page.
  - the raw boot `APP_DIR` fallback alone did not restore that case.
  - current source therefore also pre-resolves any HDD-backed startup/configured exec paths immediately after `PLDR.LoadHDDModules()` so HDD POPSTARTER/Profile paths are mounted and recorded without reintroducing HDD page work at boot.
  - current source also routes on-demand HDD path mounts through `PLDR.LoadHDDModules()` instead of only the lower-level `EnsureHddRuntimeReadyForExec()` gate, so later POPSTARTER/Profile resolution from USB or other pages uses the same runtime init path as HDD page entry.
  - repo inspection also showed the startup HDD warm-path list had been skipping Profile 1/default relative `POPSTARTER.ELF` because it only recorded explicit `hdd:` / `pfs:` paths, so current source now includes that default-relative case when boot source is HDD.
  - repo inspection of `etc/boot.lua` also showed HDD boot is established on a dedicated `pfs1:` mount before `system.lua` runs, so current source now carries that exact boot partition/slot metadata into `system.lua`, seeds the HDD mount tracker from it, and rebuilds HDD sidecar/partition context from mounted `pfs1:` candidates instead of assuming low-level HDD readiness alone preserves the boot-side path contract.
  - user later confirmed on 2026-03-28 that the exact-boot-mount/source-context source restored the USB-before-HDD-page startup/Profile repro on hardware, so the remaining blocker is no longer startup/Profile lookup.
- USB first-entry backend discovery:
  - a 2026-03-27 hardware report said the first USB page entry reported no backend, but backing out and re-entering then worked.
  - current code already had bounded retry loops for USB root discovery, but all retries happened back-to-back with no yield for the backend to become visible.
  - current source now adds a bounded wait only in `BuildUsbIdentityDeferred()`, leaving MX4SIO discovery logic unchanged.
  - user later confirmed the corrected source on hardware.
- HDD `POPSTARTER.ELF` when launcher/sidecar/CWD is on HDD:
  - current reported hardware result is still a black-screen hang.
  - path/mount/CWD mitigations plus the HDD-backed non-reboot `ExecPS2` cleanup are present in current code.
  - a 2026-03-27 hardware re-test of the current source still black-screened with boot source HDD, default/Profile 1/cwd/sidecar `POPSTARTER.ELF` on HDD, and game device HDD.
  - a second 2026-03-27 hardware report also black-screened while launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD, so the remaining failure is now treated as the HDD-backed POPSTARTER exec path itself rather than only HDD game routing.
  - a later 2026-03-27 hardware report also said booting from another device and launching an HDD title with sidecar `POPSTARTER.ELF` on that boot device black-screened, and the user identified it as a regression.
  - the EE-side HDD direct-load workaround in `src/elf_loader/src/elf.c` has therefore been reverted; it did not fix `D-10` and is no longer supported by hardware evidence.
  - later 2026-03-27 Memory Card staging, stripped-handoff, CWD/selector, and HDD-init-state experiments in `bin/POPSLDR/system.lua` did not fix `D-10` / `D-14` and coincided with repeated `D-15` failures.
  - user later confirmed on 2026-03-28 that USB boot + USB sidecar/cwd `POPSTARTER.ELF` + HDD game passes on the narrowed source, so the remaining blocker is again isolated to HDD-backed `POPSTARTER.ELF`.
  - a later 2026-03-28 re-test still black-screened on that narrowed Lua-side source with no visible positive change, so the next shared preservation step tested was the loader's automatic post-load exec-slot keep in `src/elf_loader/src/elf.c`.
  - that loader-side no-auto-exec-slot-preserve source still left non-HDD POPSTARTER HDD-game launches on the restored selector-only handoff, while `R2` could still request the explicit `hdd0:PART:pfs0:/GAME.ELF` selector.
  - a later 2026-03-28 re-test on that loader-side source still black-screened for `D-10` on both `X` and `R2`, and the user clarified the other same-day success result was another `D-15` run rather than `D-14`.
  - a later 2026-03-28 re-test on that forced-`reboot_iop = 1` source still black-screened for `D-10` and `D-14`, so reboot mode alone did not separate the remaining failure.
  - a later 2026-03-28 re-test on that direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source still black-screened for both `D-10` and `D-14`, so exec-path form alone did not separate the remaining failure.
  - follow-up repo inspection then found `BuildDirectHddExecPathFromMounted()` had been generating malformed direct aliases without the colon after `pfsN`, so that earlier direct-path experiment was not a clean control.
  - inspection of `wLaunchELF` and `PlayStation2-Basic-BootLoader-Extended` showed the common HDD ELF pattern is to mount the target partition explicitly and feed `SifLoadElf` a mounted `pfs0:/...` path rather than a direct `hdd0:` path.
  - a later 2026-03-28 re-test on that mounted-`pfs0:` embedded-loader source still black-screened for `D-10`.
  - broader comparison then showed current HEAD had drifted away from this repo's own March 24 partitioned-loader diagnostics by reintroducing `SifExitRpc()` immediately before the parent `ExecPS2` into the embedded loader.
  - this repo's earlier HDD diagnostics also recorded that the embedded-loader boundary only became stable once EE-side SIF teardown before `ExecPS2` was removed from the parent handoff.
  - comparison against `wLaunchELF` and `PlayStation2-Basic-BootLoader-Extended` also showed another remaining mismatch: this repo's embedded loader had no separate original HDD source-context argument, so it could only make reset decisions from the mounted `pfs0:/...` load target.
  - follow-up repo comparison then showed the remaining source-context gap was broader than the loader alone: Lua had usually already normalized HDD POPSTARTER to mounted `pfs1:` / `pfs3:` paths before the reboot loader saw it, so the loader was still not being given the original HDD path it needed to force the `pfs0:` remount pattern used by `wLaunchELF`.
  - broader comparison against `wLaunchELF` also showed the remaining ownership mismatch was not just reset policy: the parent/loader boundary there does not pre-unmount PFS state and the embedded loader calls `SifLoadElf` directly after `SifInitRpc(0)`, without `SifLoadFileInit/Exit`.
  - a later 2026-03-28 re-test on that exact-boot-mount/source-context source still black-screened for `D-10`, so full raw-source reconstruction alone was still not the missing link.
  - repo comparison against the local `ps2sdk` tree then showed the remaining drift was structural: the header still documented a partition-aware loader contract, but the live reboot path was still using a custom source-context channel instead of the same partition/load-path/argv split.
  - current source therefore keeps the restored non-HDD POPSTARTER path, seeds the exact boot `pfs1:` mount metadata from `etc/boot.lua` into Lua-side HDD mount tracking, and replaces that ad hoc reboot handoff with an explicit partition-aware contract across `bin/POPSLDR/system.lua`, `src/luasystem.cpp`, `src/elf_loader/src/elf.c`, and `src/elf_loader/src/loader/src/loader.c`.
  - on that contract, Lua passes exact HDD partition context separately from the mounted load path, normalizes the partition-aware exec filename back to generic `pfs:/...`, routes HDD partition-aware launches through cold external-launch prep so the old tracked `pfsN:` mount is not preserved into exec, and the parent remounts `pfs0:` from that partition while reusing the mounted relpath Lua already resolved.
  - a 2026-03-29 hardware result on the prior partition-aware source no longer black-screened, but the launcher regained control with `rc=-1 (returned after 22618 ms)`, which meant that specific artifact had moved the remaining failure past the old black-screen boundary and into the embedded-loader or target-`ExecPS2` handoff.
  - a later 2026-03-29 GitHub artifact re-test on that broader partition-aware/current-source line black-screened again, so the returned-rc boundary is not yet stable enough to treat as the new steady state.
  - repo history comparison then showed that this partition-aware reboot path had drifted away from the original parent-side embedded-loader jump contract in `src/elf_loader/src/elf.c`: it no longer performed the BRAM wipe or the original `SifInitRpc`/`SifLoadFileInit`/`SifLoadFileExit` and `SifExitIopHeap`/`SifExitRpc`/`SifExitCmd` sequence around that final `ExecPS2`.
  - repo history comparison also showed that earlier child-loader `fileXio` experiments had never been retested after the later parent-side jump-contract fixes, so they were not a clean control for the current boundary.
  - later repo audit also showed that POPSLoader's normal POPSTARTER launch path passes only the selector as target `argv[0]`, while the newer HDD child-loader path had started prepending a replacement executable path; that changed the HDD-backed POPSTARTER argv layout away from the working non-HDD path.
  - repo audit also found that selected-profile state and stored canonical profile paths could drift apart, so a chosen Profile 1/default path could still launch another profile's canonical HDD POPSTARTER path without the user realizing it.
  - current source restores that original parent-side jump contract, returns the actual embedded-loader `ExecPS2` result instead of collapsing it to `-1`, keeps legacy `System.loadELF(path, reboot_iop, selector)` on POPSTARTER's normal one-argument selector contract, aligns the child loader closer to `wLaunchELF` / `PlayStation2-Basic-BootLoader-Extended` by removing the post-reset MC module reload and exiting SIF command state before the final target `ExecPS2`, routes partition-aware HDD launches through the explicit `System.loadELFWithPartition(path, reboot_iop, partition_context, selector)` API and mounted-`pfs0:` `SifLoadElf` once the parent has already remounted the target partition, normalizes stale canonical profile-path state before launch/save, keeps the older iomanX-aware `fileXio` path only for direct `pfs:` / `hdd:` loads with no partition-aware HDD context, and now exposes the real exec filename separately from the probe/open path in the launcher popup.
  - 2026-05-19 source audit found that several current-source defects must be fixed before treating new hardware results as clean controls: Lua mounted-PFS fallback can leave stale launch context, normal HDD game labels can fail fallback partition parsing, the fallback path can skip the pre-exec gate even when reconstruction failed, `System.loadELF(..., args..., partition_context)` can leak the partition context into target argv, the generic embedded-loader default-argv contract is unreachable, and the child loader still uses `snprintf`/`strncat` despite older docs claiming that risk was avoided. See `HDD_POPSTARTER_HANDOFF.md`.
  - 2026-05-19 source change applies the handoff's recommended fixes (except for the child-loader `snprintf`/`strncat` cleanup, which would require regenerating the embedded loader blob and was intentionally deferred):
    1. `bin/POPSLDR/system.lua` adds `NormalizeHddPartitionLabelForMount` so `ResolveFallbackMountedPfsExecPath` accepts the bare partition labels (e.g. `__.POPS`) returned by `ParseHddGameEntry`. Previously the fallback parsed only `hdd0:`-prefixed labels and always failed for normal HDD game entries.
    2. `RunPOPStarterGame` now resyncs `context.exec_path`/`exec_partition_context`/`exec_mounted_path`/`exec_original_slot`/`exec_pfs_slot`/`source_pfs_slot`/`cold_external_launch`/`keep_hdd_slots`/`keep_hdd_slots_after_load` and the matching `launch_diagnostics` fields after a successful fallback, so `LaunchEngine` no longer consumes stale pre-fallback values.
    3. The HDD pre-exec gate is skipped only when the fallback actually reconstructed a partition-aware path; if reconstruction failed in non-strict mode, the gate now runs so its own partition-recovery logic can succeed or fail loudly instead of silently launching with stale context.
    4. `src/luasystem.cpp` exposes `System.loadELFWithPartition(path, reboot_iop, partition_context, args...)`. The legacy `System.loadELF` trailing partition_context detection has been removed; partition_context can no longer be copied into target argv. `LaunchEngine` calls the new binding when `context.exec_partition_context` is set.
    5. `src/elf_loader/src/elf.c` `ExecuteViaEmbeddedLoader` no longer rejects `argc == 0`, so the documented child-loader default-argv synthesis (`build_default_target_arg0`) is reachable. The HDD POPSTARTER-specific `argv[0]` guard in `ExecuteHddBackedViaEmbeddedLoader` is intentionally left in place.
  - a 2026-05-20 artifact screenshot then showed `D-10` returning to the launcher with `POPSTARTER HDD pre-exec gate failed: Cannot resolve HDD partition context`, `POP:pfs3:/POPS/POPSTARTER.ELF`, and `APP:hdd0:+OPL:pfs:/APPS/PS1_POPSLOADER/`.
  - 2026-05-20 source follow-up fixes the argument-shifted failure popup call sites, lets Lua parse `hdd0:PART:` partition-context strings, lets shared HDD recovery candidates accept safe bare labels such as `__.POPS`, and changes mounted-PFS fallback to recover the actual mounted POPSTARTER source partition before falling back to the selected HDD game partition. It does not change the POPSTARTER selector `argv[0]` contract.
  - a 2026-05-20 latest-artifact `D-15` report then showed USB boot with USB sidecar/cwd `POPSTARTER.ELF` plus an HDD title black-screening. Current source follow-up restores legacy `System.loadELF(path, reboot_iop, selector)` one-argument selector behavior for normal/non-HDD POPSTARTER launches and keeps HDD partition context on `System.loadELFWithPartition(...)`.
  - a later 2026-05-20 readable-diagnostic screenshot then showed the pre-exec gate failing on the loader-facing generic exec path `pfs:/POPS/POPSTARTER.ELF`; source now derives a real mounted probe path for `ValidateHddPopstarterExecGate()` while keeping the generic `pfs:/...` exec path for the partition-aware C loader contract.
  - a later 2026-05-20 report narrowed the non-HDD POPSTARTER regression to default/cwd sidecar resolution: explicit `mass:/POPS/POPSTARTER.ELF` launches, but default `POPSTARTER.ELF` can stop at `Cant find POPSTARTER ELF`. Current source now includes the live current directory in sidecar lookup and derives fallback sidecar paths from boot/app directories instead of blindly appending to raw boot strings.
  - 2026-05-20 simplification pass addresses the over-engineering risk: normal HDD-backed POPSTARTER launches no longer use Lua partition context, generic `pfs:/...` exec rewriting, the Lua HDD pre-exec gate, the mounted-PFS fallback remount path, or the embedded-loader reboot path by default. They keep the resolved executable path and call legacy `System.loadELF(path, 0, selector)`.
  - a 2026-05-20 hardware result on that direct non-reboot artifact still black-screened before POPSTARTER debug screens, so the next source pass removes the remaining HDD-only parent-side pre-`ExecPS2` cleanup from `LoadELFFromFileExecPS2()` (`fileXioUmount`, `SifExitIopHeap`, `SifExitRpc`, `SifExitCmd`) to match the working non-HDD POPSTARTER handoff more closely.
  - hardware status after the 2026-05-20 source follow-up remains `Unknown (verify on hardware)`. The handoff doc verification sequence (`D-15` first, then `D-10` `X`, then `D-10` `R2`, then `D-14`, then `D-12` sanity, then `U-10` separately) still applies.
  - current source still keeps the `R2` selector-path experiment for HDD game launches, but that remains secondary to restoring and preserving the non-HDD POPSTARTER baseline for HDD titles.
- `BOOT.ELF` after HDD page init:
  - repo history shows the BOOT.ELF modal originally used a simpler non-reboot `System.loadELF(elf_path, 0, elf_path)` path without launch-CWD setup, and later source changed it to `reboot_iop = 1` plus launch-CWD.
  - a later 2026-03-29 hardware report said BOOT.ELF still behaved incorrectly once HDD runtime had been initialized, which points more narrowly at carried HDD/IOP state than BOOT.ELF lookup itself.
  - current working inference is that this `U-10` failure may share the same underlying handoff/state-poisoning boundary as `D-10`, but that remains an inference rather than a proven shared root cause.
  - current source therefore keeps the no-launch-CWD rollback, re-enables `reboot_iop = 1` for BOOT.ELF only when HDD runtime has already been loaded, and uses a BOOT.ELF-specific cold external-launch prep that clears the exec keep mask and unmounts tracked HDD slots instead of preserving boot PFS state.
  - current hardware status on that conditional-reboot/cold-prep source is still `Unknown (verify on hardware)`.
- PAL asset proportions:
  - code compensates for PAL layout,
  - final display result still needs hardware confirmation.
- 2026-05-22 Diagnostic Sentinels & USB Control Test Decision:
  - A series of targeted sentinels were executed to debug the post-load/post-reset SIF RPC handshake hang (Teal/Blue freeze) on D-10.
  - SifLoadFile (`SENTINEL_SIFLOADFILE_POPSTARTER.ELF`) and fileXioInit (`SENTINEL_FILEXIOINIT_POPSTARTER.ELF`) sentinels passed on hardware, showing that initial target-side setup and fileXio services are fully stable post-handoff.
  - Post-reset SifInitRpc sentinels (`TARGET-IOPRESET`, `POST-RESET INITCMD SPLIT`, and `POSTINITCMD RPCMODE1`) hung, proving the rebooted IOP fails to respond to RPC initialization.
  - Manual RPCINIT handshake probing and retry sentinels timed out, confirming the IOP does not signal `SIF_SREG_RPCINIT` after resetting.
  - Resetting the IOP with UDNL arguments (`SifIopReset("rom0:UDNL rom0:EELOADCNF", 0)`) via `SENTINEL_TARGET_IOPRESET_UDNL_RPCINIT_POPSTARTER.ELF` also timed out (PURPLE/MAGENTA loop), ruling out the blank reset argument as the sole cause of the SIF handshake hang.
  - The USB control path (USB POPSLOADER.ELF + USB sidecar/CWD POPSTARTER.ELF) was verified on hardware to work successfully, including when selecting games from the HDD listing.
  - *Source/Device Boundary established*:
    - **Known-good**: USB POPSLOADER.ELF + USB sidecar/CWD POPSTARTER.ELF works, including when selecting HDD games.
    - **Known-bad**: HDD POPSLOADER.ELF + HDD sidecar/CWD POPSTARTER.ELF fails. HDD POPSTARTER.ELF fails regardless of selected game device/listing.
    - **Interpretation**: The failure does not follow the selected game device or the HDD game listing by itself. The failure follows the HDD-backed POPSTARTER / HDD-backed loader-origin state.
  - *Updated Diagnostic Boundary*: The next investigation focuses on what differs when POPSTARTER.ELF is resolved, loaded, and executed from HDD versus USB sidecar/CWD, including file-open/mount state, current working directory/source device state, argv/environment passed to POPSTARTER, and IOP module state left behind by loading the target ELF from HDD.


