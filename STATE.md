Last updated: 2026-03-25

# STATE

## Project Identity
POPSLoader is a PS2 launcher for POPStarter built on Enceladus runtime pieces, with behavior primarily orchestrated by embedded Lua modules (`system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`).

## Current Runtime State (Repo-Verified)
- Boot/runtime uses embedded Lua scripts (filesystem Lua loaders are disabled in runtime).
- Settings are persisted at `mc0:/POPSTARTER/.pldrs`.
- Settings edits are staged and committed on Settings/Profile exit.
- Configurable paths include POPStarter and DKWDRV, with `mc?:/` alias resolution support.
- Implemented selectable BDMA modes: `FAT32`, `USBEXFAT`, `MX4SIO`, `MMCE`.
- USB/MX4SIO split is based on mount-driver identity, not path-prefix heuristics alone.
- Release packaging policy in CI is `PS1_POPSLOADER/*` + `POPS/PATCH_5.BIN` with strict manifest validation.

## Main Menu Feature Status
- `MMCE`: implemented.
- `MX4SIO`: implemented.
- `HDD (PFS)`: implemented.
- `USB`: implemented.
- `Disc (DKWDRV)`: implemented.
- `HDD (exFAT)`: not implemented.
- `SMB (v1)`: not implemented.

## Known Open Work
- **CRITICAL**: Resolve the ExecPS2-to-bram failure that prevents the embedded loader from starting. Diagnostic build confirms the embedded loader's `main()` is never reached. See `FAILURES.md` for confirmed root causes and candidate hypotheses.
- Once the embedded loader starts, address the secondary issue: SifLoadElf cannot access PFS paths (ioman vs iomanX). Pre-read buffer and fileXio fallback code is already in place but untested (loader never ran).
- Implement HDD exFAT menu flow.
- Implement SMB menu flow.
- Implement ART system.
- Expand documented hardware validation runs.
- Add clearer end-user installation layout guidance for launcher variants.

## Verification Status
- Code/build/package statements above are repository-verified.
- Hardware behavior is `Unknown (verify on hardware)` unless recorded in `QA_REGRESSION_MATRIX.md` run logs.
- HDD POPSTARTER diagnostic build tested 2026-03-25: black screen (no GS colors), confirming embedded loader never executes.
