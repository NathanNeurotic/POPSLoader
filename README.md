# POPSLoader

<p align="center">
  <img src="banner.jpg" alt="POPSLoader Banner" width="800"/>
</p>

POPSLoader is a graphical PlayStation 2 homebrew launcher designed to easily browse and launch your PS1 games (using POPStarter) from various storage devices. It features a clean, responsive layout, cover art support, sound effects, an on-screen keyboard, and direct memory card exit shortcuts.

The current public release is **BETA-12** (released 2026-06-18). Development continues on the `BETA-12-PLAY` branch; rolling test artifacts are published continuously (see [Development & Building](#development--building)).

---

## Highlights

POPSLoader's stable backbone, hardware-confirmed across an extended validation pass:

*   **Fixed HDD POPSTARTER Handoff (D-10)**: Resolved the long-standing "D-10" black-screen hang when launching games using an HDD-backed POPStarter configuration. Hardware-confirmed.
*   **Fixed Cross-Device POPSTARTER (D-14 / D-15)**: HDD-backed POPSTARTER with non-HDD games and non-HDD POPSTARTER with HDD games both launch cleanly. Hardware-confirmed.
*   **DKWDRV from Memory Card and custom HDD path**: Both launch routes work — the MC route via a reboot-IOP path with synthesized argv, the HDD custom path via a partition-aware route. Hardware-confirmed.
*   **BOOT.ELF Exit from POPSLoader**: Returns to wLaunchELF / BOOT.ELF via the embedded-loader route, including the previously broken HDD-launched case (`U-10`). Hardware-confirmed.
*   **Single-device Settings parity**: Every install — USB / MX4SIO / MMCE **and the internal HDD** — saves settings to `.pldrs` next to the launcher. HDD installs write it on the HDD's own boot partition (read-write mount take-over), no `mc0:` fallback (see [Settings Storage on HDD Installs](#settings-storage-on-hdd-installs)).
*   **In-app HDD game hiding, PAL full-screen, BDMA + MC-folder controls**: The newer Settings work — see the [Settings](#settings) section below.
*   **Polished User Interface**: Layout alignment corrections, cleaner typography, dynamic menu box adjustments, text wrapping, and notification toast hardening.

> [!NOTE]
> The canonical, always-current **Known Issues** list and **hardware-verification status** live in **[STATE.md > Known Issues](STATE.md#known-issues-canonical--the-single-list-readme--agents--rolling_notes-point-here)** (with the full ledger in [QA_REGRESSION_MATRIX.md](QA_REGRESSION_MATRIX.md)). The current open item is the config-specific "Failed to load HDD" from a non-HDD boot; the 2026-06 HDD/PAL/BDMA features are implemented and boot on PCSX2 (HDD confirmed read-write on hardware by provato) and are still validating on hardware.

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
5.  **Add Games**: Copy your PS1 game images in `.VCD` format into the same `POPS` folder. Keep filenames reasonably short — roughly **73 characters is the safe maximum** for a standard `POPS/` folder; longer names can fail to launch (see Troubleshooting).
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
| `hdd:/__common/POPS/POPSTARTER.ELF` | POPStarter launcher binary |
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
| **L1** | Jump to the top of the game list — press again to bounce to the bottom |
| **Left Analog Stick (up / down)** | Fast page-jump through the game list — give it a firm push and hold to fly through large libraries a page at a time |
| **R1** | Refresh / rescan the current device's game list, in place (e.g. after hot-plugging a drive or card). USB / MMCE / MX4SIO / HDD (PFS) re-scan live by default; if *Game list cache* is enabled in Settings they instead rebuild their saved per-device cache. |
| **Cross (X)** | Confirm option / Launch selected game |
| **Circle (O)** | Go back to the Main Menu / Cancel |
| **Triangle (△)** | Exit shortcut / BOOT.ELF shortcut where available |
| **Start** | Open the Settings / Profile Editor |
| **Select** | Toggle "Hide Text Mode" (clears the UI for a clean view of cover art) |
| **Square (□)** | Toggle cover-art preview on / off (in the game list) |
| **Right Analog Stick (up / down)** | Scroll a long game description that doesn't fully fit on screen (when *Game details* are enabled and a `<game>.txt` is present). Speed is set in *Settings → Description scroll speed*. |
| **L3 (left stick click)** | Hide / unhide the selected game (writes/removes a `<name>.hide` marker — works on every device, including the internal HDD). Set *Settings → Game List → Hidden games* to *Visible (manage)* to show hidden games dimmed, then press **L3** on a dimmed entry to unhide it. |
| **R2** | Launch in "HDD Alt" mode (HDD (PFS) game list only — for an HDD-resident POPSTARTER) |

### On-screen Keyboard (Settings path editor)

| Button | Action |
| :--- | :--- |
| **L1 / R1** | Move the text cursor Left / Right |
| **Square (□)** | Delete character (backspace) |
| **R2** | Toggle uppercase / lowercase |

---

## Settings

Press **Start** on the menu to open Settings; changes save when you confirm. Settings persist per install with **single-device parity** — every device, **including the internal HDD**, saves a `.pldrs` file next to the launcher. HDD installs write that sidecar **on the HDD boot partition itself** (POPSLoader remounts its own boot partition read-write to do so — there is no `mc0:` fallback for HDD installs). For the full rules, see **[STATE.md > Settings](STATE.md#settings-single-device-parity)**.

### Startup

| Setting | Options | What it does |
| :--- | :--- | :--- |
| **Boot Page** | **Carousel** (default) · MX4SIO · USB · MMCE · HDD (PFS) | Where POPSLoader lands after the boot sequence. *Carousel* shows the normal device wheel. Pick a device and POPSLoader opens **straight into that device's game list** at startup (it loads that backend automatically). A `-page=` launch argument still overrides this for that one boot. |

### Carousel Devices

| Setting | Options | What it does |
| :--- | :--- | :--- |
| **(one row per device: MMCE, MX4SIO, HDD (exFAT), HDD (PFS), USB, i.Link, SMB, Disc)** | **Shown** (default) · Hidden | Hide or show each entry on the main device carousel. Set unused or not-yet-implemented backends (e.g. HDD (exFAT), SMB, i.Link) to **Hidden** to remove them from the wheel. At least one device must stay **Shown**. Saved with your settings (`HIDDEN_DEVICES`); hidden entries are skipped during carousel navigation with no gaps, and launch behavior is unchanged. |

### Game List

| Setting | Options | What it does |
| :--- | :--- | :--- |
| **Multi-disc games** | **Show all discs** (default) · First disc only | *First disc only* hides the secondary discs of multi-disc games so only disc 1 shows. **Detection is purely by filename** — a disc is hidden if its name contains `(Disc 2)`, `(Disc 3)`, `(CD 2)`, `(Disk 2)`… (any number ≥ 2). So it **only works if you name your files with that convention**, e.g. `Final Fantasy IX (Disc 1).VCD` / `Final Fantasy IX (Disc 2).VCD`. Launch disc 1 and swap discs in-game via your VMC. (PS1 discs carry no shared "this is the same game" metadata, so the filename is the only signal.) Applies to every device. |
| **Hidden games** | **Visible (manage)** (default) · Hidden | Per-game hide layer. Press **L3** on any game to hide or unhide it — hiding writes (or removes) a tiny `<name>.hide` marker next to the game's `.VCD`, exactly like the `<name>.png` cover. *Hidden* filters tagged games out of the list; *Visible (manage)* shows them **dimmed** so you can manage them with L3. In-app hiding works on **every device** — USB / MX4SIO / MMCE / Memory Card **and the internal HDD** (POPSLoader writes the `.hide` on the HDD via its read-write boot-partition mount). |
| **Game details** | **Off** (default) · Left · Center · Right | Shows a per-game blurb from a `<game>.txt` sidecar in a small panel under the cover, in the chosen text alignment (*Off* hides it). Authored line breaks are preserved; scroll a long blurb with the **right analog stick**. |
| **Description scroll speed** | Fast · Medium · **Slow** (default) | How fast — and how firm a stick push — the **right analog stick** scrolls the *Game details* blurb. *Slow* is the most deliberate; *Fast* moves more lines per second. Only relevant when *Game details* is on. |
| **Game list cache** | **Off** (default) · On | When **On**, USB / MMCE / MX4SIO **and the internal HDD (PFS)** save their scanned game list per device so the "Building game list…" rescan only runs once (rebuild it with **R1**). **Off** = always live-scan (the default, unchanged behavior). |

### Other settings

- **Profile / POPSTARTER mode / POPSTARTER path** — which `POPSTARTER.ELF` to use (a per-device profile, or a custom path).
- **DKWDRV Path** — path to `DKWDRV.ELF` used by the Disc option.
- **Video Standard** — **Auto** (default — matches your console's region) / NTSC / PAL. On PAL the UI now renders **natively at 640×512** so it fills the whole screen with no letterbox (NTSC is 640×448). A display-mode change shows a confirm prompt that **auto-reverts** if you don't confirm, so a bad mode can't strand you; you can also hold **Start** during boot to skip past a bad video mode.
- **BDMA Mode** — mass-storage backend mode: **FAT32** (`FAT32-USB (None)`) / **USBEXFAT** (`exFAT-USB`) / **MX4SIO** / **MMCE**. The installed mode is recorded in a `bdma_mode.txt` marker file in the POPSTARTER pack folder (older `.pldr_bdma_mode` markers are still read for compatibility).
- **POPSTARTER Memory Card Folder** — toggles the `mc:/POPSTARTER` folder. Turning it **off deletes** `mc:/POPSTARTER` (with a confirm prompt). It is **interlocked with BDMA Mode**: you can't turn this folder off while BDMA Mode is on, and you can't enable BDMA Mode while this folder is off.
- **Hide UI Text** — clears on-screen text for a clean cover-art view (also toggled with **Select**).
- **Keyboard Layout** — on-screen keyboard layout for the path editor.

---

## BOOT.ELF / wLaunchELF Exit

Selecting **BOOT.ELF** in the exit menu (or pressing the **Triangle** shortcut) will look for:
1. `mc0:/BOOT/BOOT.ELF`
2. `mc1:/BOOT/BOOT.ELF`

If found, BOOT.ELF launches through the embedded-loader handoff with a clean BRAM setup and an explicit `argv[0]`. If you do not have wLaunchELF installed at these paths, this option will fail to boot.

**Hardware-confirmed working** when POPSLoader was launched from USB, MC, MMCE, MX4SIO, OSDmenu, Browser, PSBBN, or HDD.

The `U-10` case (BOOT.ELF exit from an HDD-launched POPSLoader) previously black-screened; it was **fixed in PR #479** (`reboot_iop=0`), hardware-confirmed by Nuno 2026-05-31. History in [docs/archive/U10_INVESTIGATION.md](docs/archive/U10_INVESTIGATION.md).

---

## Internal HDD Notes

*   Internal HDD setups received major reliability improvements in BETA-10-5 (the "B2" PFS-unmount fix at commit `4ae6679`), correcting the partition mount handoffs that previously prevented games from loading.
*   Ensure that your game partition is named matching the `__.POPS` convention, and that the `__common/POPS/` directory contains all necessary POPStarter/POPS emulator binaries.
*   Existing USB/MX4SIO/MMCE setups are unaffected by the HDD fixes and should continue to work normally.

### Settings Storage on HDD Installs

HDD-installed POPSLoader saves its `.pldrs` settings file **on the HDD itself**, in the launcher's boot partition — same single-device behavior as USB / MX4SIO / MMCE, which keep the sidecar at `<install dir>/.pldrs`. To do this POPSLoader takes over its own boot partition's mount and remounts it read-write (the OPL "own your mount" pattern), so there is **no `mc0:` fallback** for HDD installs. The same read-write mount is what lets in-app `.hide` markers (toggled with L3) be written on the HDD. See **[STATE.md > Settings](STATE.md#settings-single-device-parity)** for the canonical rules.

---

## Troubleshooting

### Game does not appear in the menu list
*   Using uppercase `.VCD` is recommended if your games are not being detected, especially on case-sensitive setups.
*   Verify that VCD files are placed directly in the `POPS` (or `__.POPS`) folder, not inside subfolders.

### Game launches to a black screen
*   Verify that `IOPRP252.IMG`, `POPS.ELF`, and the `.PAK` files are present in the POPS folder.
*   Check that your game image `.VCD` is healthy and uncorrupted.

### A game appears in the list but won't launch
*   The most common cause is the **`.VCD` filename being too long**. POPStarter — not POPSLoader — performs the actual launch and enforces a hard length limit. In testing, a **73-character** filename launches while a **74-character** one does not.
*   POPStarter's own documentation lists an **89-character** limit, but that ceiling appears to count the **full path string POPStarter builds** (POPSLoader hands it something like `mass:/POPS/XX.<name>.ELF`), not just the bare filename. So the usable *filename* length is shorter than 89, and a **deeper folder path leaves room for fewer characters** — which is why ~73 is the safe target for a standard `POPS/` folder.
*   **Fix:** shorten the filename (and, if needed, use a shorter folder path). This is a POPStarter constraint and cannot be raised from POPSLoader.

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

Confirmed broken: see the single canonical **[STATE.md > Known Issues](STATE.md#known-issues-canonical--the-single-list-readme--agents--rolling_notes-point-here)** list (currently just the "Failed to load HDD" from a non-HDD boot case).

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
*   **P4NCHOL1NO, VizoR, provato, nuno6573, and the community**: Hardware testing.

---

## Development & Building

GitHub Actions is the canonical build path. The pinned CI image is `ps2dev/ps2dev:v2.0.0`. Every change must pass the CI workflow in `.github/workflows/compilation.yml` before merging; rolling release artifacts for testing are produced by `.github/workflows/rolling-release.yml` on push to `BETA-12-PLAY` and on pull request events. CI now runs a live `luac` syntax gate over the embedded Lua (`bin/POPSLDR/*.lua` + `etc/boot.lua`) and hard-fails on a syntax error — note this catches **syntax** only; runtime and load-order errors still only surface on real PS2 / PCSX2.

POPSLoader is an EE C/C++ application (`src/`) with the entire front-end UI and launch logic written as embedded Lua (`bin/POPSLDR/*.lua`, `etc/boot.lua`) and an embedded IOP-side child ELF loader (`src/elf_loader/`). The Lua scripts, PNG art, IRX modules, and the child loader are all baked directly into the EE ELF at build time via `bin2c`, so the on-card scripts are not read at runtime — building from source is required to change them.

Developer documentation, repository architecture details, and the current state are maintained in:

*   [STATE.md](STATE.md): Current code and hardware status, the canonical Known Issues list, Behavioral Invariants, and Preservation Contracts.
*   [QA_REGRESSION_MATRIX.md](QA_REGRESSION_MATRIX.md): Complete ledger of CI gates and hardware test outcomes.
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
