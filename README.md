<a href="">!<img width="1536" height="1024" alt="POPSLOADER MMCE on Enceladus" src="https://github.com/user-attachments/assets/bc8ce695-17a6-445b-b09b-1d2b962f6b5d" /></a>
<a href="https://www.github.com/NathanNeurotic/Enceladus/releases">![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nathanneurotic/enceladus/total?style=plastic&logo=playstation%202&logoColor=red&logoSize=auto&label=Downloads&labelColor=gold&color=turquoise%20&link=https%3A%2F%2Fgithub.com%2FNathanNeurotic%2FEnceladus%2Freleases%2Ftag%2FMMCE)</a>

# POPSLoader

POPSLoader is an open-source launcher for POPStarter that is scripted in Lua and built on top of the Enceladus runtime. This repository packages the launcher (POPSLOADER.ELF), runtime Lua scripts, textures, and required modules into a single, portable bundle intended for PlayStation 2 environments such as MMCE and USB mass storage.

POPSLoader was created by [El_isra](https://www.github.com/israpps), and this repository is a fork of his work. Endless thanks to Isra for his contributions and open-source projects gifted to the community.

> **Project lineage**: This project is derived from the [Enceladus](https://github.com/DanielSant0s/Enceladus) Lua environment and retains its GPLv3 licensing.

---

## Table of Contents

- [What POPSLoader Does](#what-popsloader-does)
- [Who This Is For](#who-this-is-for)
- [Quick Start (Just Want to Use It)](#quick-start-just-want-to-use-it)
- [Runtime File Layout](#runtime-file-layout)
- [Where to Put Your Games](#where-to-put-your-games)
- [Running on Hardware or Emulator](#running-on-hardware-or-emulator)
- [Configuration Tips](#configuration-tips)
- [Troubleshooting](#troubleshooting)
- [Repository Layout](#repository-layout)
- [Contributing](#contributing)
- [License](#license)

---

## What POPSLoader Does

POPSLoader is a front-end for POPStarter that makes it easier to:

- Discover and launch your POPS titles using a Lua-driven UI.
- Provide a consistent user experience across MMCE and USB storage setups.

Game patches and modifiers are managed by POPS/POPStarter, not by POPSLoader.

The launcher itself is an EE ELF (POPSLOADER.ELF) that embeds scripts, assets, and IOP modules at build time. These components are also copied to the `bin/` output folder for easy deployment.

## Who This Is For

- **New users** who just want to run POPS games without diving into the build system.
- **Modders and tinkerers** who want to customize POPSLoader’s Lua UI and assets.
- **Developers** who want to customize POPSLoader’s Lua UI and assets.

If you are brand new to PS2 homebrew, focus on the [Quick Start](#quick-start-just-want-to-use-it) and [Runtime File Layout](#runtime-file-layout) sections first.

---

## Quick Start (Just Want to Use It)

1. **Grab a prebuilt release** from the project’s GitHub releases page.
2. **Copy the runtime files** to a folder on your target device (see the layout below).
3. **Place your games and POPS assets** in the correct POPS directory (details below).
4. Launch `POPSLOADER.ELF` from your PS2 launcher of choice.

---

## Runtime File Layout

Wherever you place `POPSLOADER.ELF`, keep **all of its dependencies and `POPSTARTER.ELF` together** in the same folder:

```
POPSLoader/
├── POPSLOADER.ELF
├── POPSTARTER.ELF
├── *.lua
├── *.png
└── PATCH_5.BIN
```

**Notes:**

- Do **not** place files in a `POPSLDR/` subfolder; keep everything together.
- POPSLoader only needs its own runtime files alongside it; POPS content lives under `POPS/`.

---

## Where to Put Your Games

POPSLoader scans the `POPS/` folder under supported storage targets in this order:

1. `mmce1:/POPS/`
2. `mmce0:/POPS/`
3. `mass0:/POPS/`
4. `mass1:/POPS/`
5. `mass2:/POPS/`
6. `mass3:/POPS/`

Your games, patches/cheats, VMCs, and required POPS binary file(s) must live inside the chosen `POPS/` folder (e.g., `device:/POPS/<binary(ies)>`). POPSLoader itself should remain next to its runtime files, not inside `POPS/`.

---

## Running on Hardware or Emulator

### Run over network (ps2client)

If you have a PS2 running PS2Link or PS2Client, you can launch `POPSLOADER.ELF` over the network using those tools. Consult your PS2Link/PS2Client setup guide for exact commands and IP configuration.

---

## Configuration Tips

- **MMCE IGR auto-return:** If you want POPStarter IGR to return to POPSLoader automatically, put runtime files in the root of `mmce0:/` and copy `POPSLOADER.ELF` as `BOOT.ELF`.
- **Custom IGR textures:** To match the POPSLoader UI in POPStarter’s in-game menu, copy `PATCH_5.BIN` (from next to `POPSLOADER.ELF`) into the `POPS/` directory.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| `ps2client` can’t connect | PS2 IP mismatch | Double-check your console IP and PS2Link/PS2Client configuration. |
| POPS titles not showing | Game path not in supported `POPS/` directory | Move games into one of the supported `POPS/` paths. |
| Launcher boots but no UI assets | Assets not next to ELF | Make sure `.lua`, `.png`, and `PATCH_5.BIN` are in the same folder as `POPSLOADER.ELF`. |

If you still get stuck, open an issue with a description of your setup.

---

## Repository Layout

```
bin/          Runtime files (ELF, Lua, assets)
EMBED/        Embedded fonts, textures, boot scripts
etc/          Boot scripts and helper Lua
iop/          IOP modules and embedded assets
modules/      Optional modules (ds34bt, ds34usb, etc.)
sio2man/      SIO2MAN variants and notes
src/          Core C/C++ source for Enceladus runtime and POPSLoader
```

---

## Contributing

Contributions are welcome! If you plan to make changes:

1. Fork the repo.
2. Create a feature branch.
3. Commit your changes.
4. Open a pull request with a clear description and test/build notes.

---

## License

This project is licensed under the GNU General Public License v3.0. See [`LICENSE`](LICENSE) for details.
