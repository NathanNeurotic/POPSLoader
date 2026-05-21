Last updated: 2026-05-20

# ROADMAP

## Status Snapshot
- Core launcher functionality is present in code for MMCE, MX4SIO, HDD (PFS), USB, Disc (`DKWDRV`), settings persistence, cover preview, path editing, startup backend auto-init, and exit flows.
- The shared default/Profile 1 local POPSTARTER baseline was restored by rolling back to the `BETA-10-play-CHECKPOINT2` resolver behavior; user hardware confirmed that fix.
- Recorded hardware previously confirmed `D-12` startup/Profile lookup is restored, `D-16` first-entry USB discovery is restored, and `D-15` non-HDD-POPSTARTER HDD-game launch was restored; a 2026-05-20 latest-artifact report regressed `D-15` again with USB boot + USB sidecar `POPSTARTER.ELF` + HDD game black-screening.
- A follow-up 2026-05-20 report narrowed the non-HDD sidecar regression to default/cwd POPSTARTER resolution: explicit `mass:/POPS/POPSTARTER.ELF` launches, while default `POPSTARTER.ELF` can stop at `Cant find POPSTARTER ELF`; current source expands the sidecar search and remains `Unknown (verify on hardware)`.
- The main stabilization blocker is still HDD-backed `POPSTARTER.ELF` execution when the launcher, sidecar/CWD, or configured POPSTARTER path lives on HDD (`D-10`, `D-14`).
- One 2026-03-29 artifact briefly moved `D-10` to a returned `rc=-1`, but later artifacts returned to black screen, so that was not a stable new boundary.
- Current repo line now uses the direct non-reboot legacy selector handoff as the default for HDD-backed POPSTARTER too: keep the resolved executable path, avoid Lua partition-context/generic-`pfs:/` rewriting on normal `X`, avoid HDD-only parent cleanup immediately before `ExecPS2`, and preserve the partition-aware/embedded-loader code only as a non-default fallback surface until hardware proves it is needed.
- The latest EE-side HDD direct-load workaround was reverted after it did not fix `D-10` and coincided with a reported HDD-game regression when POPSTARTER stayed on the non-HDD boot device.
- `HDD_POPSTARTER_HANDOFF.md` is the current source-audit handoff for this blocker. It separates source-confirmed defects from hardware-only unknowns and should be read before new `D-10` / `D-14` fix attempts.
- `HDD (exFAT)`, `SMB (v1)`, and `ILINK` remain intentionally unimplemented menu entries.
- Detailed experiment chronology lives in `QA_REGRESSION_MATRIX.md` and `DECISIONS.md`; `STATE.md` also summarizes the source-inferred Settings/Profile POPSTARTER path save/load integrity risk as `Unknown (verify on hardware)` without attributing `D-10`, `D-14`, or `U-10` to it.

## Immediate Priorities

### 1) HDD-backed POPSTARTER exec
- Reproduce and resolve `D-10`:
  - POPSLoader booted from HDD,
  - HDD game launched from HDD (PFS),
  - `POPSTARTER.ELF` resolved from HDD sidecar/CWD or configured HDD path,
  - current reported result: black-screen hang, or on recent readable-diagnostic artifacts returned pre-exec gate popups for partition-context resolution and generic `pfs:/...` accessibility.
  - restore and preserve `D-15`, `D-12`, `D-16`, `U-05`, and shared Profile 1/default sidecar behavior while iterating.
  - treat `D-14` as the paired non-HDD-game repro for the same HDD-backed POPSTARTER blocker.
  - fix source-confirmed handoff defects before broader experiments: stale Lua fallback context, plain-label fallback partition parsing, over-broad fallback gate skip, partition-context argv leakage, embedded-loader contract drift, mounted-PFS source-partition recovery, failure-popup diagnostic argument order, and generic-`pfs:/` gate probing.
  - use `QA_REGRESSION_MATRIX.md` for the full experiment chronology instead of rebuilding that ledger here.

### 2) External exit/launch re-validation
- Re-run `U-05` (`OSDSYS`) and `U-10` (`BOOT.ELF after HDD page init`) on current source after the BOOT.ELF-specific conditional-reboot/cold-prep change for HDD-initialized sessions.
- Treat `U-10` as potentially sharing the same underlying handoff/state-poisoning boundary as `D-10`, but do not assume a `D-10` fix automatically resolves `U-10` without hardware confirmation.
- Record exact run results in `QA_REGRESSION_MATRIX.md` instead of carrying them only in chat history.

### 3) Startup/page split re-validation
- Re-run HDD boot with a large HDD library on current source.
- Expected:
  - boot-time HDD auto-init should make the device runtime ready without building the HDD games list,
  - first HDD page entry should still perform partition scan and game-list build normally.

### 4) Display and UX verification
- Re-run `U-06` to confirm PAL/NTSC menu asset proportions on hardware.
- Re-run `U-08` and `U-09` on slower/large libraries to judge whether busy overlays communicate activity clearly enough.

### 5) Coverage and documentation
- Add concrete run logs for:
  - device switching without runtime locks (`D-13`),
  - keyboard layout persistence (`S-09`),
  - boot-device label display (`U-11`).
- Keep `README.md`, `STATE.md`, `DECISIONS.md`, and `QA_REGRESSION_MATRIX.md` synchronized.

## Secondary Work

### 1) Unimplemented menu paths
- Implement `HDD (exFAT)` flow.
- Implement `SMB (v1)` flow.
- Implement `ILINK` flow.

### 2) Art/asset behavior
- Keep current cover behavior stable:
  - sidecar PNG beside the selected `.VCD`,
  - HDD common art from `hdd0:__common/POPS/ART/<title>.png`.
- Keep `default.png` optional in CI artifacts; missing default-cover builds must fall back to embedded `MISSING.png`.
- Decide whether a broader ART system still needs to exist beyond those current code paths.

### 3) Install/build clarity
- Keep CI package layout and docs synchronized.
- Keep GitHub-built hardware artifacts self-identifying: package `BUILD_INFO.txt` and fail CI when expected embedded runtime markers are missing.
- Keep README installation steps explicit enough for users who are not familiar with PS2 launcher layouts.

### 4) Settings page UI redesign
- 2026-05-19: first pass, single-page label/hint/value layout grouped into three sections with consistent metrics and a dirty indicator.
- 2026-05-20: second pass moves to an OPL-style focused-list model. D-pad Up/Down moves a highlight bar between rows (skipping section headers and spacers); D-pad Left/Right cycles the focused value; X activates the focused row (cycles a cycle row, opens the path editor for a path row, or fires the menu action for an action row); O discards and exits; Start still resets defaults; Select still toggles hide-text. Adds Keyboard Layout as its own cycle row and surfaces Save Changes / Reset Defaults / Cancel as menu items at the bottom. The Square / L1 / R1 / Triangle one-button-per-field shortcuts are gone -- the whole interaction is D-pad-driven.
- Hardware verification pending alongside the D-10/D-14/U-10 retest sequence. Walk the S-01..S-09 and U-01..U-11 rows on the next artifact to confirm parity (Square no longer toggles Video Standard; cycle it via Left/Right or X on the focused row).
- Future polish (deferred, optional):
  - If we grow Settings beyond ~14 visible rows, add scrolling.
  - Consider grouping into category sub-pages (OPL pattern: top-level lists categories, each opens a child page) once there are more settings to justify the navigation cost.

## Deferred Ideas
- Additional themes/skins.
- Broader network/backend support after SMB and ILINK have defined baselines.
- More ambitious artwork cache policy after current launch/runtime issues are stable.
