# POPSLoader

<p align="center">
  <img src="banner.jpg" alt="POPSLoader Banner" width="800"/>
</p>

POPSLoader is a graphical PlayStation 2 homebrew launcher designed to easily browse and launch your PS1 games (using POPStarter) from various storage devices. It features a clean, responsive layout, cover art support, sound effects, an on-screen keyboard, and direct memory card exit shortcuts.

The current public release is **BETA-10-5** (`v1.0.0-rev5`), tagged at commit `9a0ebe2` on 2026-05-27 and hardware-confirmed clean by Nuno on 2026-05-28. Development continues on the `BETA-12-PLAY` branch; rolling test artifacts are published continuously (see [Development & Building](#development--building)).

---

## BETA-10-5 Highlights

POPSLoader BETA-10-5 ships the launcher's stable backbone after an extended hardware-validation pass:

*   **Fixed HDD POPSTARTER Handoff (D-10)**: Resolved the long-standing "D-10" black-screen hang when launching games using an HDD-backed POPStarter configuration. Hardware-confirmed.
*   **Fixed Cross-Device POPSTARTER (D-14 / D-15)**: HDD-backed POPSTARTER with non-HDD games and non-HDD POPSTARTER with HDD games both launch cleanly. Hardware-confirmed.
*   **DKWDRV from Memory Card**: Default MC DKWDRV launch path works through a reboot-IOP route with synthesized argv. Hardware-confirmed.
*   **BOOT.ELF Exit from USB-booted POPSLoader**: Returns to wLaunchELF / BOOT.ELF via the embedded-loader non-reboot route. Hardware-confirmed when POPSLoader was launched from USB / OSDmenu / Browser / HOSDMenu / PSBBN.
*   **Per-device Settings Sidecar**: Non-HDD installs (USB / MX4SIO / MMCE) save settings to `APP_DIR/.pldrs` next to the launcher; HDD installs use the legacy `mc0:/POPSTARTER/.pldrs` fallback by design (see Settings Storage below).
*   **Polished User Interface**: Layout alignment corrections, cleaner typography, dynamic menu box adjustments, text wrapping, and notification toast hardening.

### Known issues (current)

*   **"Failed to load HDD" when POPSLoader is launched from a non-HDD device** (USB / Memory Card), on some configurations. Most setups list the HDD fine. Workaround: launch POPSLoader from the HDD, or open the HDD page a few seconds after the menu appears. Config-specific; under investigation.

**Recently fixed (hardware-confirmed) — no longer broken:**

*   **DKWDRV from a custom HDD path** — fixed (PRs #486/#487: partition-aware route + live pfs-slot scan; Nuno 2026-06-04/06-06).
*   **BOOT.ELF exit from an HDD-launched POPSLoader** (`U-10`) — fixed (PR #479: `reboot_iop=0`; Nuno 2026-05-31).
*   **HOSDmenu / specific wLaunchELF builds failing to launch POPSLoader** — fixed (launcher-agnostic IOP cold reboot).
*   **MX4SIO-rooted settings save** — fixed (PRs #476 + #477; Nuno 2026-05-29).

See [STATE.md](STATE.md) and [QA_REGRESSION_MATRIX.md](QA_REGRESSION_MATRIX.md) for the full hardware ledger.

---

## Supported Devices

POPSLoader's main menu exposes the following backends:

*   **MMCE** (Multi-Memory Card Emulator, e.g. MemoryCard PRO / SD2PSX)
*   **MX4SIO** (SD card via memory card slot adapter)
*   **HDD (PFS)** (internal HDD via the PS2 network/ATA adapter)
*   **USB** (`mass:`)
*   **Disc (DKWDRV)** (boot DKWDRV to play PS1 discs)

> [!NOTE]
> The main menu also lists **HDD (exFAT)**, **i.Link**, and **SMB (v1)**, but these flows are not implemented yet — selecting them shows a "not implemented" notice. See [Known Issues & Planned Improvements](#known-issues--planned-improvements).

> [!NOTE]
> Game compatibility and drive loading performance may vary depending on your specific console model, adapter type, and the quality of your POPStarter/POPS binaries.

---

## Quick Install

To set up POPSLoader:

1.  **Download the Release**: Download and extract the latest `POPSLOADER.zip` package.
2.  **Copy Launcher Files**: Copy the `PS1_POPSLOADER/` folder to the device or memory card from which you want to launch POPSLoader.
3.  **Place POPS Files**: Put the `PATCH_5.BIN` file (included in the `POPS/` directory of the ZIP) into your active `POPS` folder (see directory structures below).
4.  **Add POPStarter & POPS Files**: Add your POPStarter executable (`POPSTARTER.ELF`) and the required POPS support files (`IOPRP252.IMG`, `POPS.ELF`, `POPS.PAK`, `POPS_IOX.PAK`) to your `POPS` folder. These copyrighted Sony POPS files are not included in the release package.
5.  **Add Games**: Copy your PS1 game images in `.VCD` format into the same `POPS` folder.
6.  **Launch**: Run `POPSLOADER.ELF` using wLaunchELF, Free McBoot, or your preferred ELF launcher.

---

## Folder Layout

Ensure your directories and files match these paths exactly depending on your storage device:

### USB / MX4SIO / MMCE Setup
Place all files on the root of your storage device (`mass:/`, `mx4sio:/`, `mmce0:/`, etc.) in a folder named `POPS`:

| File Path | Description |
| :--- | :--- |
| `<device>:/POPS/GameName.VCD` | Your PS1 game image |
| `<device>:/POPS/GameName.png` | Optional cover art (200x200 8-bit PNG recommended) |
| `<device>:/POPS/IOPRP252.IMG` | Required POPS support file |
| `<device>:/POPS/POPSTARTER.ELF` | POPStarter launcher binary |
| `<device>:/POPS/POPS.ELF` | POPS emulator engine binary |
| `<device>:/POPS/POPS.PAK` | Emulator resources payload |
| `<device>:/POPS/POPS_IOX.PAK` | Emulator input/output resources payload |

### Internal HDD Setup
Place VCD game files inside your dedicated POPS partitions, and system binaries inside `__common/POPS/`:

| File Path | Description |
| :--- | :--- |
| `hdd:/__.POPS/GameName.VCD` | Your PS1 game image (can also use partitions `__.POPS0` through `__.POPS9`) |
| `hdd:/__common/POPS/ART/GameName.png` | Cover art folder |
| `hdd:/__common/POPS/IOPRP252.IMG` | Required POPS support file |
| `hdd:/__common/POPS/POPS.ELF` | POPS emulator engine binary |
| `hdd:/__common/POPS/POPS.PAK` | Emulator resources payload |
| `hdd:/__common/POPS/POPS_IOX.PAK` | Emulator input/output resources payload |

---

## Controls

Navigate POPSLoader using a standard PS2 controller.

### Menus & Game List

| Button | Action |
| :--- | :--- |
| **D-pad Up / Down** | Scroll through the game list |
| **D-pad Left / Right** | Page Up / Page Down (jump through large lists) |
| **Cross (X)** | Confirm option / Launch selected game |
| **Circle (O)** | Go back to the Main Menu / Cancel |
| **Triangle (△)** | Exit shortcut / BOOT.ELF shortcut where available |
| **Start** | Open the Settings / Profile Editor |
| **Select** | Toggle "Hide Text Mode" (clears the UI for a clean view of cover art) |
| **Square (□)** | Toggle cover-art preview on / off (in the game list) |
| **R2** | Launch in "HDD Alt" mode (HDD (PFS) game list only — for an HDD-resident POPSTARTER) |

### On-screen Keyboard (Settings path editor)

| Button | Action |
| :--- | :--- |
| **L1 / R1** | Move the text cursor Left / Right |
| **Square (□)** | Delete character (backspace) |
| **R2** | Toggle uppercase / lowercase |

---

## Settings

Press **Start** on the menu to open Settings; changes save when you confirm. Settings persist per install — every device saves a `.pldrs` file next to the launcher, **except HDD installs, which save to `mc0:/POPSTARTER/.pldrs`** (see [Settings Storage on HDD Installs](#settings-storage-on-hdd-installs); the HDD driver can't reliably write to its own partition, so the memory card is used instead). No settings are ever written to the HDD.

### Startup

| Setting | Options | What it does |
| :--- | :--- | :--- |
| **Boot Page** | **Carousel** (default) · MX4SIO · USB · MMCE · HDD (PFS) | Where POPSLoader lands after the boot sequence. *Carousel* shows the normal device wheel. Pick a device and POPSLoader opens **straight into that device's game list** at startup (it loads that backend automatically). A `-page=` launch argument still overrides this for that one boot. |

### Game List

| Setting | Options | What it does |
| :--- | :--- | :--- |
| **Multi-disc games** | **Show all discs** (default) · First disc only | *First disc only* hides the secondary discs of multi-disc games so only disc 1 shows. **Detection is purely by filename** — a disc is hidden if its name contains `(Disc 2)`, `(Disc 3)`, `(CD 2)`, `(Disk 2)`… (any number ≥ 2). So it **only works if you name your files with that convention**, e.g. `Final Fantasy IX (Disc 1).VCD` / `Final Fantasy IX (Disc 2).VCD`. Launch disc 1 and swap discs in-game via your VMC. (PS1 discs carry no shared "this is the same game" metadata, so the filename is the only signal.) Applies to every device. |

### Other settings

- **Profile / POPSTARTER mode / POPSTARTER path** — which `POPSTARTER.ELF` to use (a per-device profile, or a custom path).
- **DKWDRV Path** — path to `DKWDRV.ELF` used by the Disc option.
- **Video Standard** — NTSC / PAL.
- **BDMA Mode** — mass-storage backend mode (FAT32 / exFAT).
- **Hide UI Text** — clears on-screen text for a clean cover-art view (also toggled with **Select**).
- **Keyboard Layout** — on-screen keyboard layout for the path editor.

---

## BOOT.ELF / wLaunchELF Exit

Selecting **BOOT.ELF** in the exit menu (or pressing the **Triangle** shortcut) will look for:
1. `mc0:/BOOT/BOOT.ELF`
2. `mc1:/BOOT/BOOT.ELF`

If found, BOOT.ELF launches through the embedded-loader handoff with a clean BRAM setup and an explicit `argv[0]`. If you do not have wLaunchELF installed at these paths, this option will fail to boot.

**Hardware-confirmed working** when POPSLoader was launched from USB, MC, MMCE, MX4SIO, OSDmenu, Browser, PSBBN, or HDD.

The `U-10` case (BOOT.ELF exit from an HDD-launched POPSLoader) previously black-screened; it was **fixed in PR #479** (`reboot_iop=0`), hardware-confirmed by Nuno 2026-05-31. History in [docs/U10_INVESTIGATION.md](docs/U10_INVESTIGATION.md).

---

## Internal HDD Notes

*   Internal HDD setups received major reliability improvements in BETA-10-5 (the "B2" PFS-unmount fix at commit `4ae6679`), correcting the partition mount handoffs that previously prevented games from loading.
*   Ensure that your game partition is named matching the `__.POPS` convention, and that the `__common/POPS/` directory contains all necessary POPStarter/POPS emulator binaries.
*   Existing USB/MX4SIO/MMCE setups are unaffected by the HDD fixes and should continue to work normally.

### Settings Storage on HDD Installs

HDD-installed POPSLoader saves its settings file to `mc0:/POPSTARTER/.pldrs` rather than next to `POPSLOADER.ELF`. This is intentional: the bundled `ps2hdd-osd.irx` driver has read-write limitations that we can't reliably work around without an IRX swap that risks regressing `D-10`. Non-HDD installs (USB / MX4SIO / MMCE) keep the per-device sidecar at `<install dir>/.pldrs`.

---

## Troubleshooting

### Game does not appear in the menu list
*   Using uppercase `.VCD` is recommended if your games are not being detected, especially on case-sensitive setups.
*   Verify that VCD files are placed directly in the `POPS` (or `__.POPS`) folder, not inside subfolders.

### Game launches to a black screen
*   Verify that `IOPRP252.IMG`, `POPS.ELF`, and the `.PAK` files are present in the POPS folder.
*   Check that your game image `.VCD` is healthy and uncorrupted.

### Cover art is not showing up
*   Check that the cover image is in `.png` format.
*   The PNG filename must match the `.VCD` game filename exactly (e.g. `Crash Bandicoot.VCD` requires `Crash Bandicoot.png`).
*   Ensure the cover art is placed in the same folder as the VCD (or `__common/POPS/ART/` on HDD).
*   Confirm cover-art preview is enabled — press **Square (□)** in the game list to toggle it.
*   For best compatibility and performance, use 200x200 pixel images.

### BOOT.ELF exit option fails or hangs
*   Confirm that a valid wLaunchELF executable is installed on your physical memory card at `mc0:/BOOT/BOOT.ELF` or `mc1:/BOOT/BOOT.ELF`.

---

## Known Issues & Planned Improvements

Confirmed broken (workaround documented above):
*   **"Failed to load HDD" from a non-HDD boot**, on some configurations — boot from HDD, or wait a moment before opening the HDD page.

Planned for subsequent updates:
*   **Layer C Lazy IRX Loading**: Defer device-specific IRX modules so they only load when the boot device family needs them, reducing boot time. The `mmceman` portion has **landed** (PR #471): it is now loaded eagerly only when POPSLoader is booted from an MMCE device, and deferred everywhere else. Further deferral of `ds34bt` / `usbd` remains future work — they are still loaded at boot today.
*   **Settings UI Redesign (Berion)**: Visual overhaul replacing the current OPL-style focused-list with per-category Settings pages. Awaiting Berion's mockup PNGs.
*   **GUI Themes**: Customizable colors / skins / fonts and a setting to skip the boot splash.
*   **In-Game Features**: Support for per-game fixes, cheat codes, Virtual Memory Card (VMC) setups, and multi-disc swap prompts.
*   **`HDD (exFAT)`, `SMB (v1)`, `i.Link`** menu flows: currently surface as "Not Implemented Yet" until feature work lands.

See [STATE.md](STATE.md) "Known Open Work" and [ROADMAP.md](ROADMAP.md) for the prioritized backlog.

---

## Credits

*   **israpps (El_isra)**: Original POPSLoader project creator.
*   **Daniel Santos**: Creator of the Enceladus runtime foundation.
*   **krHACKen**: Author of POPStarter.
*   **Berion**: User interface design and theme assets.
*   **nuno6573**: Cover-art engine integrations and scripting.
*   **Hugopocked**: POPStarter fixes.
*   **Ripto / NathanNeurotic**: Maintenance, UI polishing, and release engineering.
*   **P4NCHOL1NO, VizoR, and the community**: Hardware testing.

---

## Development & Building

GitHub Actions is the canonical build path. The pinned CI image is `ps2dev/ps2dev:v2.0.0`. Every change must pass the CI workflow in `.github/workflows/compilation.yml` before merging; rolling release artifacts for testing are produced by `.github/workflows/rolling-release.yml` on push to `BETA-12-PLAY` and on pull request events.

POPSLoader is an EE C/C++ application (`src/`) with the entire front-end UI and launch logic written as embedded Lua (`bin/POPSLDR/*.lua`, `etc/boot.lua`) and an embedded IOP-side child ELF loader (`src/elf_loader/`). The Lua scripts, PNG art, IRX modules, and the child loader are all baked directly into the EE ELF at build time via `bin2c`, so the on-card scripts are not read at runtime — building from source is required to change them.

Developer documentation, repository architecture details, and the current state are maintained in:

*   [STATE.md](STATE.md): Current code and hardware status.
*   [QA_REGRESSION_MATRIX.md](QA_REGRESSION_MATRIX.md): Complete ledger of CI gates and hardware test outcomes.
*   [TRUTHSHEET.md](TRUTHSHEET.md): Non-negotiable behavioral invariants.
*   [ROADMAP.md](ROADMAP.md): Prioritized backlog.
*   [DECISIONS.md](DECISIONS.md): Decision log with rationale and evidence.
*   [ARCHITECTURE.md](ARCHITECTURE.md): Structural data-flow documentation.

To build the launcher binary locally (optional; CI is canonical), run:
```sh
make clean elfloader all
```
This cleans, force-regenerates the embedded child ELF loader (`elfloader`), then compiles every EE/IOP object, embeds all assets, links, strips, and runs `ps2-packer` to produce the packed `bin/POPSLOADER.ELF`. It requires a configured PS2DEV SDK environment (`ps2dev/ps2dev:v2.0.0` toolchain) with `ps2-packer` and the `bin2c` tool on `PATH`.

To grab the latest test build, download from the rolling release URL:
[https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/POPSLOADER-rolling-release.zip](https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/POPSLOADER-rolling-release.zip)
