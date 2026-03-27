Last updated: 2026-03-26

# DECISIONS

## Decision Log Format
Each entry records:
- Date (`YYYY-MM-DD`)
- Decision
- Rationale
- Implications
- Evidence

## Decision Log

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
- Implications: startup docs and validation must cover boot source plus configured paths.
- Evidence: `bin/POPSLDR/system.lua` (`CollectStartupBackendTargets`, `AutoInitStartupBackends`).

### 2026-03-26 — PAL UI uses the same 640x448 raster layout as NTSC-authored UI assets
- Decision: PAL mode keeps the UI raster at `640x448` instead of stretching the authored layout vertically.
- Rationale: reduce PAL squish on menus and authored UI assets.
- Implications: final on-TV proportions still require hardware confirmation.
- Evidence: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.

### 2026-03-26 — Release ZIP contract is strict and PATCH_5-based
- Decision: CI package includes exact `PS1_POPSLOADER/*` launcher files plus `POPS/PATCH_5.BIN`, and rejects legacy `POPS/*.tm2` payloads.
- Rationale: prevent release drift and ambiguous installation instructions.
- Implications: docs and workflow validation must stay synchronized.
- Evidence: `.github/workflows/compilation.yml`.

### 2026-03-27 — HDD POPSTARTER load routes through embedded loader with fileXio
- Decision: `LoadELFFromFileExecPS2` detects pfs:/hdd: paths and routes them through `ExecuteViaEmbeddedLoader` instead of `SifLoadElf`. `ExecuteViaEmbeddedLoader` no longer tears down IOP state before ExecPS2. The embedded loader uses `fileXioInit` + `fileXioOpen/Read/Lseek/Close` to load the ELF, and does not reset IOP for pfs:/hdd: targets (POPSTARTER manages its own IOP reset).
- Rationale: `SifLoadElf` (IOMAN/rom0:LOADFILE) cannot access iomanX-only pfs: paths and hangs indefinitely. The embedded loader in BRAM is the only safe load path: it avoids clobbering the still-running POPSLoader at 0x100000 and keeps HDD drivers active for the fileXio load.
- Implications: loader binary grows slightly due to `-lfileXio`; BOOT.ELF and OSDSYS paths are unaffected (they do not use `LoadELFFromFileExecPS2` with pfs: paths). HDD `argv0_selector` must include the game partition so POPSTARTER can remount after its own IOP reset.
- Evidence: `src/elf_loader/src/elf.c` (routing), `src/elf_loader/src/loader/src/loader.c` (fileXio branch), `bin/POPSLDR/system.lua` (argv0_selector construction).

## Open Investigations
- HDD `POPSTARTER.ELF` fix applied; awaits hardware re-test (D-10).
- `BOOT.ELF` after HDD page init:
  - current hardware status is `Unknown (verify on hardware)`.
- PAL asset proportions:
  - code compensates for PAL layout,
  - final display result still needs hardware confirmation.
