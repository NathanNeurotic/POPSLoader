# AGENTS.md (popsplay)

## 1) Project identity
POPSLoader is an open-source launcher for POPStarter, scripted in Lua and based on the Enceladus project.【F:README.md†L1-L4】

## 2) Branch + scope notes
- This guidance is written for branch: `popsplay`.
- Do **not** assume behavior not found in code or repo text; label unknowns as **TODO: verify** and point to where to verify.

## 3) Build + environment
**Toolchain / assumptions (from repo):**
- PS2DEV/ps2sdk toolchain is required; build uses `PS2SDK`, `PS2DEV`, `ps2-packer`, and `bin2c`.【F:Makefile†L30-L48】【F:Makefile†L41-L49】

**Build commands / targets:**
- `make all` → builds `bin/POPSLOADER.ELF`.【F:Makefile†L61-L69】
- `make elfloader` → builds `src/elf_loader/libcustom-elf-loader.a`.【F:Makefile†L107-L112】
- `make package` → creates `POPSLoader.7z` with runtime assets and docs.【F:Makefile†L132-L135】
- CI uses: `make clean elfloader all package`.【F:.github/workflows/compilation.yml†L23-L28】

**Output artifacts:**
- `bin/enceladus.elf` (intermediate).【F:Makefile†L30-L33】
- `bin/POPSLOADER.ELF` (packed release).【F:Makefile†L66-L69】
- `POPSLoader.7z` (packaged archive).【F:Makefile†L132-L135】

## 4) Repository map
- `src/` — C/C++ source, including entrypoint `main.cpp` and Lua/graphics/pad subsystems.【F:src/main.cpp†L1-L22】
- `modules/` — external modules (e.g., `ds34bt`, `ds34usb`) built as libs and IOP modules.【F:Makefile†L51-L60】【F:Makefile†L94-L106】
- `etc/` — build-time Lua boot script (`boot.lua`) embedded into the ELF via bin2c.【F:Makefile†L71-L73】【F:etc/boot.lua†L1-L60】
- `docs/` — project docs site content (Jekyll config + index).【F:docs/index.md†L1-L40】【F:docs/_config.yml†L1-L1】
- `iop/embed/` — embedded IOP module(s), e.g., `mmceman.irx`.【F:iop/embed/mmceman.irx†L1-L1】
- `EMBED/` — PNG/TTF assets embedded into the binary at build time.【F:Makefile†L75-L79】
- `bin/` — packaged runtime assets and POPSLDR scripts (`bin/POPSLDR/*`), plus `bin/changelog`.【F:Makefile†L132-L135】【F:bin/POPSLDR/system.lua†L1-L11】
- `samples/` — sample Lua content (e.g., `fractal.lua`, `helloworld.lua`).【F:samples/fractal.lua†L1-L1】
- `.github/workflows/` — CI build definition for packaging artifacts.【F:.github/workflows/compilation.yml†L1-L35】

## 5) Runtime invariants (critical)
**Device path rules (as evidenced in code):**
- Lua search paths include `mass:/POPSLDR/?.lua`, `mc0:/POPSLDR/?.lua`, and `mc1:/POPSLDR/?.lua`.【F:etc/boot.lua†L1-L1】
- `main.cpp` patches `mass:/` paths by removing an extra slash (`mass:/X` → `mass:X`).【F:src/main.cpp†L88-L96】
- Memory card paths (`mc0:`/`mc1:`) are treated specially in directory listing logic.【F:src/luasystem.cpp†L64-L123】
- TODO: verify `mmce0:/` usage. `mmceman.irx` is embedded, but device path usage is not shown in the reviewed code; inspect other Lua scripts or C/C++ modules for explicit usage.【F:iop/embed/mmceman.irx†L1-L1】

**POPS folder expectations (only when present in code/docs):**
- Default POPStarter path is `mass:/POPS/POPSTARTER.ELF` in `system.lua`.【F:bin/POPSLDR/system.lua†L25-L27】
- POPStarter dependencies are checked under `mass:/POPS/` for USB and `pfs1:/POPS/` for HDD when enabled.【F:bin/POPSLDR/system.lua†L63-L74】
- Usage docs instruct placing `POPSLOADER.ELF` and the `POPSLDR/` folder at USB or internal HDD root.【F:README.md†L6-L7】

**Asset layout expectations (current):**
- Runtime scripts are expected under `POPSLDR/` (e.g., `POPSLDR/system.lua`).【F:etc/boot.lua†L55-L60】
- Packaged runtime assets live under `bin/POPSLDR/` in the repo/package.【F:Makefile†L132-L135】【F:bin/POPSLDR/system.lua†L1-L11】

### Roadmap / active refactor goal
- **No subfolder dependencies: assets should load from ELF directory first.**
- **Keep compatibility fallback for legacy installs.**
- Future changes must preserve fallback behavior unless it is intentionally removed and documented.

## 6) Change discipline
- Prefer a **central path helper** for device/path normalization (avoid re-implementing `mass:/` fixes or directory resolution in multiple places).【F:src/main.cpp†L65-L96】
- Avoid scattering hardcoded paths; reference a single, testable source of truth (e.g., Lua config or a shared helper).【F:etc/boot.lua†L1-L60】
- Logging/debugging: use existing debug output patterns (e.g., `DPRINTF` in C/C++ and `LOG/LOGF` in Lua) instead of introducing new styles.【F:src/main.cpp†L112-L126】【F:etc/boot.lua†L2-L7】
- Keep diffs tight and testable: isolate functional changes, avoid unrelated reformatting, and update docs when runtime paths change.【F:README.md†L6-L10】

## 7) Definition of done for PRs
- Build succeeds in CI (target: `make clean elfloader all package`).【F:.github/workflows/compilation.yml†L23-L28】
- Basic runtime smoke checks (without hardware):
  - TODO: verify available emulator/scripted checks. Inspect `bin/POPSLDR/system.lua` and the sample Lua scripts for any lightweight runtime validations that can be run on a host or in PCSX2.【F:bin/POPSLDR/system.lua†L1-L200】【F:samples/fractal.lua†L1-L1】
- Docs updated if runtime layout changes (e.g., `POPSLDR/` layout, POPStarter paths, or device path rules).【F:README.md†L6-L10】【F:etc/boot.lua†L1-L60】
