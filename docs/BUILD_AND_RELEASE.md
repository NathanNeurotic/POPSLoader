# Build & Release

## Build Requirements

- PS2SDK/ps2dev toolchain (`PS2DEV`, `PS2SDK` expected by the Makefile).
- `ps2-packer` and `bin2c` from PS2SDK.
- `7z` to create the release archive via `make package`.
- A valid `sio2man/<variant>/sio2man.irx` path for the build.

## Local Build Commands

```bash
make clean elfloader all SIO2MAN_IRX=sio2man/<variant>/sio2man.irx
```

- `make elfloader` builds the embedded custom ELF loader.
- `make all` produces `bin/enceladus.elf` and the packed `bin/POPSLOADER.ELF`.

### Packaging

```bash
make package
```

- Creates `bin/pkg/` with `POPSLOADER.ELF`, Lua scripts, PNG assets, and `PATCH_5.BIN`.
- Emits `POPSLoader.7z` containing `bin/pkg/*`, `LICENSE`, and `README.md`.

### Variant Builds

```bash
make variants
```

Builds each `sio2man/*/sio2man.irx` variant, producing distinct ELF names.

## CI (GitHub Actions)

- The CI workflow enumerates `sio2man/*/sio2man.irx` variants and builds in a `ps2dev/ps2dev:latest` container.
- Each variant:
  - Builds `POPSLOADER_<variant>.ELF` and packages `POPSLoader_<variant>.7z`.
  - Uploads the ELF, `bin/pkg/*`, and the 7z archive as artifacts.

### Release Behavior

- **`main` branch:** CI attempts to create a “Development build” prerelease with `Enceladus.tar.gz` (artifact creation is not defined in-repo).
- **Tags (`v*`):** CI uses `softprops/action-gh-release` but references an undefined `steps.tag.outputs.VERSION`.

> These release steps appear incomplete and should be confirmed.

## Evidence

- `Makefile`
- `.github/workflows/compilation.yml`
- `src/elf_loader/Makefile`
