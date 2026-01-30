# Development

## Build prerequisites
- PS2DEV/ps2sdk toolchain with `PS2SDK` and `PS2DEV` configured, and tools such as `ps2-packer` and `bin2c` available in the toolchain path.【F:Makefile†L30-L49】
- Packaging requires `7z` (CI installs `p7zip`).【F:Makefile†L132-L135】【F:.github/workflows/compilation.yml†L12-L14】

## Build instructions
- Release build (packed ELF): `make all` → `bin/POPSLOADER.ELF`.【F:Makefile†L61-L69】
- Build ELF loader: `make elfloader` → `src/elf_loader/libcustom-elf-loader.a`.【F:Makefile†L107-L112】
- Package archive: `make package` → `POPSLoader.7z`.【F:Makefile†L132-L135】
- Debug build: set `DEBUG=1` (enables `-DDEBUG`), then build normally. Example: `make DEBUG=1 all`.【F:Makefile†L16-L27】

## Packaging and running on device
- **Flat Layout (Recommended)**: `POPSLOADER.ELF` and runtime assets (`system.lua`, images, IRX) live in the same directory.
- **Legacy Layout (Fallback)**: `POPSLOADER.ELF` at root, assets in `POPSLDR/`.
- The boot script (`etc/boot.lua`) and system script (`bin/POPSLDR/system.lua`) handle asset resolution, prioritizing the application directory (`APP_DIR`) over legacy paths.

## Troubleshooting (common build issues)
- **Missing PS2DEV/PS2SDK**: Ensure `PS2SDK`/`PS2DEV` are set and toolchain binaries are on `PATH` (Makefile uses both).【F:Makefile†L30-L49】
- **Packaging fails**: `make package` uses `7z`; install p7zip/7z on your host if missing.【F:Makefile†L132-L135】【F:.github/workflows/compilation.yml†L12-L14】
- **ELF not found**: `make package` depends on the packed ELF (`bin/POPSLOADER.ELF`). Run `make all` first if needed.【F:Makefile†L61-L69】【F:Makefile†L132-L135】
