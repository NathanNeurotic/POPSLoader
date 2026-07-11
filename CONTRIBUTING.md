Last updated: 2026-06-22 (BETA-13 in progress)

# CONTRIBUTING

## Purpose
Practical contributor workflow for POPSLoader changes.

`STATE.md` is the canonical status doc. The shared/volatile facts — the Known-Issues list, the Preservation Contracts, the Behavioral Invariants, the Settings (single-device parity) behavior, and the Hardware Status — live there and are **not** restated here; this doc links to the relevant `STATE.md` section instead. Keep distinct workflow guidance here.

*(Scope/runtime-invariant rules formerly in `RULES.md` are folded into this doc; `RULES.md` is archived.)*

## Branch and PR Expectations
- Keep branches short-lived and task-focused.
- Prefer one objective per PR.
- If a change touches runtime behavior and docs, keep the code diff narrow but update the affected root docs in the same PR.
- PR descriptions should spell out:
  - the exact problem,
  - the exact scope,
  - regression risk,
  - checks run,
  - hardware coverage gaps.

## Commit Discipline
- One logical task per commit.
- Use imperative commit messages.
- Keep diffs minimal and localized.
- Avoid unrelated formatting/refactors.

## Scope Discipline
- Keep changes small and tied to one clear objective.
- Use the narrowest file set that can solve the task.
- Avoid mixing runtime logic, packaging policy, and broad refactors in one PR unless explicitly requested.

## Development Guardrails
The full invariant list is in **STATE.md > Behavioral Invariants** — preserve all of it unless the task is an explicit, documented migration. Highlights a contributor must not break:
- embedded-Lua boot chain (`main.cpp -> runScript("boot.lua") -> require("system")`); boot/runtime Lua is embedded-only.
- transactional, per-device settings persistence — edits stage in the UI and commit on Settings/Profile confirm/leave. **HDD installs now persist on the HDD boot partition via the `EnsureBootPartitionWritable` RW take-over; there is no `mc0:` fallback for an HDD-cwd install** (single-device parity). See **STATE.md > Settings (single-device parity)** and **STATE.md > Preservation Contracts**.
- mount-driver-based USB/MX4SIO classification (`sdc`/`mx4` ioctl → MX4SIO; anything else → USB; `mx4sio_bd` loads only on explicit MX4SIO evidence and requires `usbmass_bd` first).
- `mc?:/` alias resolution (`mc0` then `mc1`) for executable path probes.
- backend-specific launch policy for USB / MMCE / MX4SIO / HDD.
- the **BDMA ⟺ POPSTARTER-MC-folder interlock** (BDMA can't be enabled while the folder is off; the folder can't be disabled while BDMA is on) and the destructive folder-disable confirm. See **STATE.md > Behavioral Invariants**.
- **in-app per-game `.hide` on every device including HDD** (L3 toggle, written via the HDD RW mount take-over). See **STATE.md > Behavioral Invariants**.
- no runtime device-family lock gating (the old inert device-lock subsystem was removed in cef61af; device pages are always enterable).
- Do not add unbounded retries/poll loops in runtime paths; keep probe/retry behavior bounded and deterministic.
- Do not silently change POPStarter selector/argv behavior without explicit migration notes.
- Avoid expensive repeated rescans unless explicitly required.
- Avoid adding runtime logging unless requested.

## Packaging Rules
- CI packaging contract must stay synchronized with docs. The strict-verified `compilation.yml` zip (`POPSLOADER.zip`) is an **exact** set — two top dirs only (`PS1_POPSLOADER/` and `POPS/`), no root files, and any mismatch fails the build:
  - `PS1_POPSLOADER/`: `POPSLOADER.ELF`, `POPSTARTER.ELF`, `BUILD_INFO.txt` (so hardware can confirm the exact GitHub-built artifact), `APPINFO.PBT`, `title.cfg`, `icon.sys`, `list.icn`, `copy.icn`, `del.icn`.
  - `POPS/`: `PATCH_5.BIN` and `POPSTARTER.ELF`.
  - `POPSTARTER.ELF` is the only redistributable launcher binary and ships in **both** the `PS1_POPSLOADER/` install dir and `POPS/`. The POPS engine binaries are NOT redistributable and are never bundled — hardware supplies its own.
  - Legacy `POPS/*.tm2` entries are explicitly forbidden by CI.
- The `rolling-release.yml` zip is the loose dev bundle (different layout from the strict install zip): `POPSLOADER.ELF` + `POPSTARTER.ELF` at the zip root, a `POPS/` folder (`PATCH_5.BIN` + `POPSTARTER.ELF`), a `POPSTARTER/` pack folder (BDMA / SMB modules), and a `source/` tree. It is not strict-verified.
- CI build is gated on embedded build-identity markers (`Exec path:`, `PrepareForColdExternalELFLaunch`, `BOOT.ELF launch failed`) being present in `bin/enceladus.elf`, plus an embedded-loader blob staleness check.
- The `ps2dev/ps2dev` container image is pinned to `v2.0.0`.
- The rolling-release workflow publishes a single canonical asset on push-to-`dev` (the active rolling branch; `BETA-12-PLAY` is archival/frozen) and on PR events (last-write-wins on the shared asset).
- **The embedded-Lua syntax gate is now LIVE** (`luac5.4 -p` on the embedded Lua; the workflows `apk add lua5.4` and hard-fail on a syntax error). It used to silently skip because the ps2dev image shipped no `luac`. It catches **SYNTAX only** — runtime nil-global / type / **load-order** errors stay invisible to CI, so still cold-boot test the build in PCSX2 (the `d4b04be` load-order boot brick was exactly such a case).

## Embedded Assets (adding / removing one)
Every Lua script, font, IRX module, and game-list image is compiled **into** `POPSLOADER.ELF` (via `bin2c`); there is no on-disk asset directory at runtime and the asset list is **not** auto-globbed. Adding or removing one means editing **three coordinated places** — miss any one and the build breaks or the asset silently fails to load:
1. **`Makefile`** — add a `bin2c` rule that turns the source file under `bin/POPSLDR/...` into `asset_<name>.c` (the symbol name passed to `$(BIN2S)` is what the C code externs), **and** add the resulting `asset_<name>.o` to the `EMBEDDED_RSC` list so it gets linked. (Optional/large assets can go in `OPTIONAL_EMBEDDED_RSC` instead, which is concatenated into `EMBEDDED_RSC`.)
2. **`src/embed_assets.cpp`** — `extern` the `asset_<name>` symbol and its `size_asset_<name>`, then add an `ASSET_ENTRY("<key>", asset_<name>)` in **both** lookup tables: the bare-name table (e.g. `"frame.png"`) and the path-prefixed table (e.g. `"POPSLDR/IMG/frame.png"`).
3. **`bin/POPSLDR/images.lua`** (images only) — add a `{accessKey, "<bareFilename>"}` row to `IMG_REGISTRATIONS`. The `IMG[...]` metatable looks the asset up by the **bare filename** through `System.getEmbeddedAsset`, so the second field must match the bare-name key from step 2.

Removal is the same three places in reverse (plus drop any fallback wiring). The recent `MISSING.png` removal (`-62KB` ELF) is the worked example: it deleted the `bin2c` rule + `EMBEDDED_RSC` entry, the `extern` + both `ASSET_ENTRY`s, the `images.lua` registration, and the now-unused `IMG_FALLBACKS` fallback. The cover-art placeholders `cover_default.png` + `cover_missing.png` are the current additions and follow this same pattern.

## Runtime Timing (frame-count, not wall-clock)
`Timer.getTime()` returns **microseconds**, not milliseconds (`src/luatimer.cpp` returns the raw `clock() - tick` delta; `CLOCKS_PER_SEC` is `1e6` on the EE toolchain). Code that treats it as ms runs 1000x too fast — that was the root cause of nav auto-repeat "flying" (one press scrolling many rows) before it was reworked.
- **The canonical Enceladus idiom for UI cadence is frame-counting**, not reading the wall clock — the sibling launchers do the same. New per-direction/per-step timing increments a counter once per frame and fires at frame thresholds derived from the live field rate (`nav_fps = (UI.SCR.Y >= 512) and 50 or 60`). See `resolve_nav` / `NavHoldFrames` (nav auto-repeat) and `DescScrollFrames` (description scroll) in `bin/POPSLDR/ui.lua`.
- `os.clock()` (stock Lua, returns **seconds**) is the only pre-converted Lua time source and is currently unused. The action debounce (`MIN_ACTION_MS`) was **removed** — edge-triggering (`pressed = GPAD & ~OLDPAD`) is now the only gate, and the scene-fade / boot-fade / carousel transitions were frame-paced. Prefer frame-counting (or `os.clock()` seconds) for any new timing rather than adding more `Timer.getTime()` math.

## Settings Plumbing
Settings are write-staged in the UI and committed through a single funnel — `PLDR.CommitSettingsChanges(opts)` in `bin/POPSLDR/system.lua` — which serializes the merged state to the per-device config. A new setting touches the whole chain: the parse/serialize round-trip and the `next_*` merge in `system.lua`, plus the UI commit call in `bin/POPSLDR/ui.lua` (e.g. the boot-sound setting flows `UI.BootSound` → `PLDR.CommitSettingsChanges({ boot_sound = ... })` → `PLDR.BOOT_SOUND`). Add the field to every link or it stages but never persists. The user-facing settings **behavior** (single-device parity, the HDD RW take-over) is canonical in `STATE.md > Settings` — don't restate it here.

## Documentation Sync Rules
- If runtime behavior changes, update `STATE.md` first — it is canonical for behavioral invariants, preservation contracts, known issues, and hardware status. Then update the relevant root docs:
  - `STATE.md` (canonical — invariants, preservation contracts, known issues, hardware status)
  - `README.md`
  - `ROADMAP.md`
  - `DECISIONS.md`
  - `QA_REGRESSION_MATRIX.md`
- The other root docs point to `STATE.md` instead of duplicating the shared blocks — when you touch one of those facts, change it in `STATE.md` and leave the pointers alone.
- If behavior is only repo-verified and not hardware-verified, say so explicitly. Post-BETA-11 PR work is `Unknown (verify on hardware)` unless a tester result is recorded in `QA_REGRESSION_MATRIX.md` / `STATE.md > Reported Hardware Status`. Do not call PCSX2-only or implemented-but-unvalidated features "confirmed working on hardware".
- If hardware results contradict the intended code change, document the failure instead of assuming the next patch will fix it.

## Validation Expectations

### Docs-only changes
- Run light sanity checks if available.
- If no doc tooling is available, note `not run`.

### Runtime/build changes
- Run targeted checks first.
- Run broader build/package checks only when risk requires.
- For storage, launch, or exit behavior, document manual verification steps even when they were not run locally.

### Hardware-sensitive behavior
- Use `QA_REGRESSION_MATRIX.md` IDs in test notes.
- Mark untested hardware scenarios explicitly as `Unknown (verify on hardware)`.
- **Preservation contracts** (hardware-load-bearing; must continue to PASS on any new artifact) — the canonical list is **STATE.md > Preservation Contracts**. It covers `D-10` / `D-14` / `D-15` (B2 fix `4ae6679`), DKWDRV from MC, BOOT.ELF from USB-booted POPSLoader (V2 route `d23520a`), and `EnsureBootPartitionWritable` (the boot pfs-slot RW take-over, now load-bearing for HDD settings save and HDD in-app `.hide`). Any launch-path or mount change must not break them.
- The old "HDD-install settings save to `mc0:/POPSTARTER/.pldrs`" preservation contract is **obsolete**: HDD installs now persist on the HDD boot partition via the RW take-over (single-device parity, no `mc0:` fallback). See **STATE.md > Settings** and **STATE.md > Preservation Contracts**.
- **Resolved** (no longer "known broken accepted" — do not document as regressions): `U-10` BOOT.ELF from HDD-booted POPSLoader (PR #479), DKWDRV from a custom HDD path (PRs #486/#487), and the Class-A HOSDmenu / some-wLE start failures. See **STATE.md > Known Issues**.
- For the current open / in-testing items (e.g. "Failed to load HDD" from a non-HDD boot, and the in-testing HDD/PAL/BDMA-folder features), see **STATE.md > Known Issues** — do not re-derive a cause from source.
- The rolling-release workflow publishes to a single canonical URL. Pushing to your PR branch triggers a build that overwrites the asset (last-write-wins). Coordinate with the maintainer if testers are mid-cycle.

## Good Bug Reports
Include:
- expected behavior,
- actual behavior,
- exact repro steps,
- console/storage/backend layout,
- whether the issue occurs only after another page/backend was initialized,
- whether the result came from a local build or a CI workflow artifact.

## Review Checklist
- Scope is narrow and task-aligned.
- Core invariants (**STATE.md > Behavioral Invariants**) and preservation contracts (**STATE.md > Preservation Contracts**) are preserved or intentionally migrated.
- Failure paths remain explicit and user-visible.
- Docs are updated: `STATE.md` first for any shared fact, plus matrix entries.
- Repo-verified / PCSX2-only behavior and hardware-reported behavior are not conflated.
- The build was cold-boot tested in PCSX2 (the live `luac` gate catches syntax only, not load-order/runtime errors).
