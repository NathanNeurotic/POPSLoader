# POPSLoader

<p align="center">
  <img src="banner.jpg" alt="POPSLoader Banner" width="800"/>
</p>

POPSLoader is a graphical PlayStation 2 homebrew launcher designed to easily browse and launch your PS1 games (using POPStarter) from various storage devices. It features a clean, responsive layout, cover art support, sound effects, on-screen keyboard, and direct memory card exit shortcuts.

The current public release is **BETA-10-5** (`v1.0.0-rev5`), tagged at commit `9a0ebe2` on 2026-05-27 and hardware-confirmed clean by Nuno on 2026-05-28.

---

## BETA-10-5 Highlights

POPSLoader BETA-10-5 ships the launcher's stable backbone after an extended hardware-validation pass:

*   **Fixed HDD POPSTARTER Handoff (D-10)**: Resolved the long-standing "D-10" black-screen hang when launching games using an HDD-backed POPStarter configuration. Hardware-confirmed.
*   **Fixed Cross-Device POPSTARTER (D-14 / D-15)**: HDD-backed POPSTARTER with non-HDD games and non-HDD POPSTARTER with HDD games both launch cleanly. Hardware-confirmed.
*   **DKWDRV from Memory Card**: Default MC DKWDRV launch path works through a reboot-IOP route with synthesized argv. Hardware-confirmed.
*   **BOOT.ELF Exit from USB-booted POPSLoader**: Returns to wLaunchELF / BOOT.ELF via the embedded-loader non-reboot route. Hardware-confirmed when POPSLoader was launched from USB / OSDmenu / Browser / HOSDMenu / PSBBN.
*   **Per-device Settings Sidecar**: Non-HDD installs (USB / MX4SIO / MMCE) save settings to `APP_DIR/.pldrs` next to the launcher; HDD installs use the legacy `mc0:/POPSTARTER/.pldrs` fallback by design (see Settings Storage below).
*   **Polished User Interface**: Layout alignment corrections, cleaner typography, dynamic menu box adjustments, text wrapping, and notification toast hardening.

### Known broken (after BETA-10-5 + post-release PR #470/#472/#473 + Nuno 2026-05-28 PM verification)

Currently confirmed-broken edge cases:

*   **DKWDRV from a custom HDD path** black-screens. Use the default Memory Card DKWDRV path.
*   **MX4SIO-rooted POPSLoader settings save** — when POPSLoader is launched from `mx4sio:/`, settings save fails with `mx4sio:/<path>/.pldrs may be read-only`. Fix in flight via [PR #476](https://github.com/NathanNeurotic/POPSLoader/pull/476), which translates the boot cwd from `mx4sio:/<rel>/` to the writable `mass*:/` slot dynamically. Workaround until merged: launch POPSLoader from a different device.

(`U-10` BOOT.ELF-exit when POPSLoader was booted from HDD was previously known-broken; Nuno's 2026-05-28 PM hardware test reports BOOT.ELF working across the board including HDD-booted on the post-PR-#473 rolling-release. The cause is not architecturally obvious from PR #470/#472/#473 — investigation notes are preserved in [docs/U10_INVESTIGATION.md](docs/U10_INVESTIGATION.md) in case it regresses.)

See [STATE.md](STATE.md) and [QA_REGRESSION_MATRIX.md](QA_REGRESSION_MATRIX.md) for the full hardware ledger.

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

Selecting **BOOT.ELF** in the exit menu (or pressing the **Triangle** shortcut) will look for:
1. `mc0:/BOOT/BOOT.ELF`
2. `mc1:/BOOT/BOOT.ELF`

If found, BOOT.ELF launches through the embedded-loader handoff with a clean BRAM setup and an explicit `argv[0]`. If you do not have wLaunchELF installed at these paths, this option will fail to boot.

**Hardware-confirmed working "across the board"** (Nuno 2026-05-28 PM on rolling-release post-PR-#470/#472/#473) — including HDD-booted POPSLoader, which was previously the `U-10` known-broken case. The architectural cause of the resolution is not obvious from those PRs; investigation notes are preserved in [docs/U10_INVESTIGATION.md](docs/U10_INVESTIGATION.md) in case the issue regresses.

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
*   For best compatibility and performance, use 200x200 pixel images.

### BOOT.ELF exit option fails or hangs
*   Confirm that a valid wLaunchELF executable is installed on your physical memory card at `mc0:/BOOT/BOOT.ELF` or `mc1:/BOOT/BOOT.ELF`.

---

## Known Issues & Planned Improvements

Confirmed broken (workaround documented above):
*   **DKWDRV from custom HDD path** — use Memory Card DKWDRV path.

(BOOT.ELF exit from HDD-booted POPSLoader (`U-10`) was previously listed here as known-broken; it now passes hardware testing per Nuno 2026-05-28 PM — see Known broken section above.)

Planned for subsequent updates:
*   **Layer C Lazy IRX Loading**: Defer `mmceman`, `ds34bt`, `usbd` IRX loads when not needed by the boot device family, to reduce boot time. PR #471 (DRAFT) ships the `mmceman` portion pending hardware verification.
*   **Settings UI Redesign (Berion)**: Visual overhaul replacing the current OPL-style focused-list with per-category Settings pages. Awaiting Berion's mockup PNGs.
*   **GUI Themes**: Customizable colors / skins / fonts and a setting to skip the boot splash.
*   **In-Game Features**: Support for per-game fixes, cheat codes, Virtual Memory Card (VMC) setups, and multi-disc swap prompts.
*   **`HDD (exFAT)`, `SMB (v1)`, `ILINK`** menu flows: surface as "Not Implemented Yet" until feature work lands.

See [STATE.md](STATE.md) "Known Open Work" and [ROADMAP.md](ROADMAP.md) for the prioritized backlog.

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

GitHub Actions is the canonical build path. The pinned CI image is `ps2dev/ps2dev:v2.0.0`. Every change must pass the CI workflow in `.github/workflows/compilation.yml` before merging; rolling release artifacts for testing are produced by `.github/workflows/rolling-release.yml` on push to `BETA-12-PLAY` and on pull request events.

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
*(Requires a set up PS2DEV SDK environment with `ps2-packer` and matching dependencies.)*

To grab the latest test build, download from the rolling release URL:
[https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/POPSLOADER-rolling-release.zip](https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/POPSLOADER-rolling-release.zip)
