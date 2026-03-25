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
- HDD list/browse flow is implemented, but HDD-resident `POPSTARTER.ELF` launch remains hardware-failing on this branch across both the partition-aware embedded-loader path and the current mounted-`pfs` direct-launch variants. A new code asymmetry was identified (pfs slot stripping in `canonicalize_partition_loader_path` + fileXio path never tested with stable entry) and a bounded fix is now staged for hardware validation. See `FAILURES.md` and `QA_REGRESSION_MATRIX.md`.

## Main Menu Feature Status
- `MMCE`: implemented.
- `MX4SIO`: implemented.
- `HDD (PFS)`: implemented.
- `USB`: implemented.
- `Disc (DKWDRV)`: implemented.
- `HDD (exFAT)`: not implemented.
- `SMB (v1)`: not implemented.

## Known Open Work
- Resolve the hardware-verified black screen when `POPSTARTER.ELF` is launched from HDD/PFS. A bounded fix addressing the pfs slot stripping bug in `canonicalize_partition_loader_path` and the fileXio dispatch in the embedded loader is staged for hardware validation. See `FAILURES.md`.
- Treat HDD D-10 as a broader plateau, not an open invitation for more micro-probes or repeated loader swaps: the last durable hardware stage is `embedded loader entry`, later screen-backed halts still collapse to flash-then-black, and recent standard mounted-`pfs` direct-launch variants (`26fc65d`, `59be355`, `d4a604e`) also still black-screen. See `FAILURES.md`.
- Do not continue the same post-entry embedded-loader halt family without a new code asymmetry or a materially different observability source. The pfs slot stripping bug (new evidence) now justifies the current fileXio dispatch attempt. See `FAILURES.md`.
- Implement HDD exFAT menu flow.
- Implement SMB menu flow.
- Implement ART system.
- Expand documented hardware validation runs.
- Add clearer end-user installation layout guidance for launcher variants.

## Verification Status
- Code/build/package statements above are repository-verified.
- Hardware behavior is `Unknown (verify on hardware)` unless recorded in `QA_REGRESSION_MATRIX.md` run logs.
