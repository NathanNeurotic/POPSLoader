# POPSLoader

<p align="center">
  <img src="banner.jpg" alt="POPSLoader Banner" width="800"/>
</p>

POPSLoader is a graphical PlayStation 2 homebrew launcher designed to easily browse and launch your PS1 games (using POPStarter) from various storage devices. It features a clean, responsive layout, cover art support, sound effects, on-screen keyboard, and direct memory card exit shortcuts.

The current public release is **BETA 10**.

---

## BETA 10 Highlights

POPSLoader BETA 10 introduces critical bug fixes and usability improvements tested on real PS2 hardware:

*   **Fixed HDD POPSTARTER Handoff**: Resolved the long-standing "D-10" black screen hang when launching games using an HDD-backed POPStarter configuration.
*   **Fixed wLaunchELF / BOOT.ELF Exit**: Exiting to BOOT.ELF / wLaunchELF no longer black-screens on the tested setup. The final fix uses the normal embedded-loader handoff instead of the failed special reset path.
*   **Restored UI Options**: The `BOOT.ELF` option is fully visible again in the Exit modal, and the **Triangle** key shortcut has been restored.
*   **Polished User Interface**: Includes layout alignment corrections, cleaner typography, dynamic menu box adjustments, and text wrapping.

---

## Supported Devices

POPSLoader supports scanning and booting games from the following backends:

*   **USB** (`mass:`)
*   **MX4SIO** (SD card via memory card slot adapter)
*   **MMCE** (Multi-Memory Card Emulator)
*   **Internal HDD** (using PS2 ATA network adapter)

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
Place all files on the root of your storage device (`mass:/`, `slot:/`, etc.) in a folder named `POPS`:

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

Navigate POPSLoader using a standard PS2 controller:

| Button | Action |
| :--- | :--- |
| **D-pad Up / Down** | Scroll through the game list |
| **D-pad Left / Right** | Page Up / Page Down (jump through large lists) |
| **Cross (X)** | Confirm option / Launch selected game |
| **Circle (O)** | Go back to the Main Menu / Cancel |
| **Triangle (△)** | Exit shortcut / BOOT.ELF shortcut where available |
| **Start** | Open the Settings / Profile Editor |
| **Select** | Toggle "Hide Text Mode" (clears the UI for a clean view of cover art) |
| **L1 / R1** | Move text cursor Left / Right (inside on-screen keyboard) |
| **Square (□)** | Delete character (inside on-screen keyboard) |
| **R2** | Toggle uppercase / lowercase (inside on-screen keyboard) |

---

## BOOT.ELF / wLaunchELF Exit

POPSLoader BETA 10 fixes the crash when returning to your memory card bootloader.
*   Selecting **BOOT.ELF** in the exit menu (or pressing the **Triangle** shortcut) will look for:
    1. `mc0:/BOOT/BOOT.ELF`
    2. `mc1:/BOOT/BOOT.ELF`
*   If found, BOOT.ELF now launches through the normal embedded-loader handoff with a clean BRAM setup and an explicit argv[0].
*   If you do not have wLaunchELF installed at these paths, this option will fail to boot.

---

## Internal HDD Notes

*   Internal HDD setups received major reliability improvements in BETA 10, correcting the partition mount handoffs that previously prevented games from loading.
*   Ensure that your game partition is named matching the `__.POPS` convention, and that the `__common/POPS/` directory contains all necessary POPStarter/POPS emulator binaries.
*   Existing USB/MX4SIO/MMCE setups are unaffected by the HDD fixes and should continue to work normally.

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
*   For best compatibility and performance, use 200x200 pixel images.

### BOOT.ELF exit option fails or hangs
*   Confirm that a valid wLaunchELF executable is installed on your physical memory card at `mc0:/BOOT/BOOT.ELF` or `mc1:/BOOT/BOOT.ELF`.

---

## Known Issues & Planned Improvements

The following improvements and investigations are planned for subsequent updates:

*   **Boot & Scan Speed**: Optimization of directory parsing and backend discovery.
*   **Modchip Compatibility**: Investigate black-screen hangs on certain modchipped consoles.
*   **Setting Modernization**: Transition away from legacy profile setups to a cleaner, custom path system (such as DKWDRV/POPStarter path configuration).
*   **Enhanced Backend Detection**: Improve automatic discovery for `usb:`, `mx4sio:`, and `ata:` using IOCTL queries.
*   **UI Customization & Themes**: Integrate graphical updates (by Berion) and add settings to customize or skip the boot splash sequence.
*   **In-Game Features**: Support for per-game fixes, cheat codes, Virtual Memory Card (VMC) setups, and multi-disc swap prompts.
*   **SMB (v1) Support**: Implement network game scanning and launching via SMB v1.

---

## Credits

*   **israpps (El_isra)**: Original POPSLoader project creator.
*   **Daniel Santos**: Creator of the Enceladus runtime foundation.
*   **Berion**: User interface design and theme assets.
*   **nuno6573**: Cover-art engine integrations.
*   **Hugopocked**: POPStarter fixes.
*   **Ripto / NathanNeurotic**: Maintenance, UI polishing, and release engineering.

---

## Development & Building

Developer documentation, repository architecture details, and building prerequisites are maintained in the following files:

*   [STATE.md](STATE.md): Detailed current code and hardware status details.
*   [QA_REGRESSION_MATRIX.md](QA_REGRESSION_MATRIX.md): Complete ledger of hardware test outcomes.
*   [ARCHITECTURE.md](ARCHITECTURE.md): Structural data-flow documentation.

To build the launcher binary from source, run:
```sh
make clean elfloader all
```
*(Requires a set up PS2DEV SDK environment with `ps2-packer` and matching dependencies.)*
