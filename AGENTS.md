# POPSLoader embedded-asset distribution notes

## Embedded runtime assets
- Runtime assets are embedded into `POPSLOADER.ELF` from `bin/POPSLDR/**` using `assets/embed_manifest.txt`.
- Explicit sidecars are **not** embedded and remain external: `POPSTARTER.ELF`, `icon.sys`, `list.icn`, `copy.icn`, `del.icn`, `APPINFO.PBT`, `title.cfg`.
- Variant sidecars (`*.mmce`, `*.mx4sio`, `*.usbexfat`) are excluded from embedding and packaging.

## Updating embedded assets
1. Edit `assets/embed_manifest.txt` (`VIRTUAL_PATH|SOURCE_PATH`).
2. Run a build or `python3 tools/gen_embed_assets.py --check`.
3. Build fails if paths are malformed, duplicated, or missing.

## Runtime lookup
- Embedded keys are canonical, no leading slash (example: `POPSLDR/IMG/USB.png`).
- Use `embed:/...` URIs for explicit embedded requests.
- Runtime access is provided by `embedfs_*` and Lua `System.embed*` helpers.

## Packaging rules
- `make package` must output `POPSLoader.zip` containing only:
  - `POPSLOADER.ELF`
  - `POPSTARTER.ELF`
  - `icon.sys`
  - `list.icn`
  - `copy.icn`
  - `del.icn`
  - `APPINFO.PBT`
  - `title.cfg`
