# POPSLoader

![POPSLoader interface](https://github.com/user-attachments/assets/0a5ded44-3012-4608-bddf-9adbf1173cc6)

**POPSLoader** is a PlayStation 2 PS1-game browser and launcher. It supports the original **POPStarter + Sony POPS** VCD workflow, and the **Ember** PS1 core as a separate, experimental emulator. Browse by storage device, launch titles, manage settings and artwork, or return to BOOT.ELF.

**[Downloads](https://github.com/NathanNeurotic/POPSLoader/releases) · [GitHub Wiki](https://github.com/NathanNeurotic/POPSLoader/wiki) · [Website](https://nathanneurotic.github.io/POPSLoader/popsloader.html) · [Known issues / hardware status](STATE.md) · [Rolling archive](https://mega.nz/folder/W9wXyLjD#8hk7Wv-EEPfKPTDN-guKdQ)**

## Choose your download

| Channel | Package | Who should use it |
| --- | --- | --- |
| **Official 1.4.0** | [Official 1.4.0 release](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.4.0) | Network-only UDPFS with restart-safe configuration, localization fixes, and the existing Ember Beta-2 option. Console UDPFS/Ember acceptance remains pending. |
| Prior stable 1.2.3 | [Release 1.2.3](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.2.3) | Preserved POPStarter-only baseline without Ember. |
| **POPSLoader 1.3.0 ([Ember](https://github.com/Gageformer/Ember) Beta-2)** | [Release 1.3.0](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.3.0) | Versioned Ember-enabled release with [Gageformer](https://github.com/Gageformer)'s **existing Beta-2 core**. Emulator hardware compatibility is still experimental. |
| **Rolling** | [Latest rolling prerelease](https://github.com/NathanNeurotic/POPSLoader/releases/tag/rolling-release) | Latest `dev` build; changes frequently. Includes Ember. |
| Experimental | [Experimental channel](https://github.com/NathanNeurotic/POPSLoader/releases/tag/experimental) | Independent `experimental` branch; it may differ from both stable and rolling. |

Passing CI proves builds and packages passed automated checks; **it does not prove that a game, device, controller or VMC works on a physical PS2**. Consult the [hardware QA matrix](QA_REGRESSION_MATRIX.md).

## Install POPSLoader with Ember Beta-2

Download the full [POPSLoader 1.4.0 PS1_POPSLOADER.zip](https://github.com/NathanNeurotic/POPSLoader/releases/download/1.4.0/PS1_POPSLOADER.zip) or `PS1_POPSLOADER-<version>.zip` from the [latest rolling release](https://github.com/NathanNeurotic/POPSLoader/releases/tag/rolling-release). From 1.4.0 on, every rolling and experimental ZIP name ends with its build version (for example `PS1_POPSLOADER-v1.4.0-928.zip`), and the release notes name that version at the top. Its device-root layout is:

~~~text
APPS/
  PS1_POPSLOADER/
    POPSLOADER.ELF
    POPSTARTER.ELF
    icon.sys
    list.icn
    copy.icn
    del.icn
    title.cfg
    APPINFO.PBT

POPS/                      POPStarter and RiptOPL-matched support assets

EMBER/
  ember.elf                 Unmodified Ember core; beta licence included
  LICENSE-BETA.txt
  games/
    ExampleGame/
      ExampleGame.cue
      ExampleGame.bin        ZERO-BYTE illustration, not a playable disc

PS1_POPSLOADER.psu          Alternative app-only PS2 memory-card save
~~~

1. **Application:** Copy `APPS/PS1_POPSLOADER/` to your launcher’s APPS location and run `POPSLOADER.ELF`. Alternatively import **[PS1_POPSLOADER.psu](https://github.com/NathanNeurotic/POPSLoader/releases/download/1.4.0/PS1_POPSLOADER.psu)** using a PS2 PSU-capable save manager. Its PS2 save header is named `PS1_POPSLOADER` and contains **exactly those eight direct files, with no nested folder**.
2. **POPStarter:** Copy `POPS/` to the storage-device root. Add your own lawfully obtained Sony POPS files (`POPS.ELF`, `POPS.PAK`, `POPS_IOX.PAK` and `IOPRP252.IMG`) as required. Those copyrighted emulator components are **not included**.
3. **Ember:** Copy `EMBER/` to the same device root. Add **your own 512 KiB PlayStation BIOS** at `EMBER/bios.bin` and your own disc images under `EMBER/games/<GameFolder>/`, with a `.cue` and matching `.bin` tracks. **No BIOS or commercial game images are provided**. The included `ExampleGame.bin` is intentionally empty: delete or replace this non-playable example.
4. **Artwork:** POPStarter uses `POPS/<GameName>.VCD`; Ember uses `EMBER/games/<GameFolder>/`. For removable storage, covers go in the device-root `ART/` as `<VCD-basename>_COV.png` or `<Ember-folder>_COV.png`; `_ICO.png` is the optional disc icon.

For **stable 1.2.3**, use that release's existing installation layout, which does **not** include Ember. See the [installation guide](docs/wiki/Installation-Guide.md) and [release ZIP/PSU specification](docs/wiki/Release-Formats.md).

### Storage and device status

| Device | POPStarter / VCD | Ember development |
| --- | --- | --- |
| USB FAT32/exFAT, MX4SIO, MMCE | `<device>:/POPS/<Game>.VCD` | `<device>:/EMBER/games/<GameFolder>/`; scanning host-tested |
| Internal exFAT HDD (BDMA/ATA) | Root `POPS/` on mounted `mass:` | Library scan host-tested; console handoff unverified |
| Internal APA/PFS HDD | `__.POPS*` / `__common/POPS/` | `__.EMBER*` partition scan host-tested; writes unverified |
| SMBv1 | SMB share `POPS/` | Enumeration host-tested; mount and handoff unverified |
| UDPFS | Full network POPS reads / VMC writes; no USB required | Enumeration host-tested; console handoff unverified |
| i.Link | Hidden/unsupported in POPSLoader | **Deferred** until RiptOPL demonstrates reliable i.Link on PS2 hardware |

HDD/PFS artwork belongs under `__common/POPS/ART/`. The 1.4.0 UDPFS mode uses UDPFS Assault 1.0.0 with no USB requirement; later builds use its TEST pre-release, which also plays `POPS/*.cue` games without conversion; end-to-end console UDPFS behavior is not hardware-certified. SMBv1 and UDPFS use mutually exclusive network stacks: restart before switching between them. See [device details](docs/wiki/Device-Support.md) and [UDPFS setup](docs/UDPFS_BDMA.md).

### Ember options and safety

Set the bundled **Ember Beta-2** core's global options under **Settings → Ember PS1 Core**. On an `[Ember]` game row, press **L2** for timing, dither, shading and controller overrides; `Default` inherits the global option. Ember may create virtual memory cards in each game folder on writable media. **Game launch, controller operation after the keep-IOP handoff and VMC persistence remain unverified on real hardware.** POPStarter VCD success does not establish Ember success.

Credits and redistribution: [Gageformer's Ember](https://github.com/Gageformer/Ember) (unmodified core with `EMBER/LICENSE-BETA.txt`), [RiptOPL / Open-PS2-Loader](https://github.com/NathanNeurotic/Open-PS2-Loader) (device/backend reference), [Okeanos's BDM-UDPFS Assault](https://github.com/Okeanos86/BDMAssault) and [israpps BDM Assault](https://github.com/israpps/BDMAssault). The [weekly Ember Watch](.github/workflows/ember-watch.yml) verifies upstream asset digests, **not** hardware gameplay.

## Main features

- Cover-art PS1 browser for POPStarter VCD games and separate labeled Ember games.
- USB, MX4SIO, MMCE, APA/PFS and internal exFAT device flows, plus network modes.
- Per-device game visibility, settings, game lists and RiptOPL-style artwork.
- SMBv1 and opt-in UDPFS VCD browsing with explicit network configuration.
- Adjustable video, boot page, display and menu navigation; Triangle Exit menu and BOOT.ELF chainloading.

**Current limitations:** Ember console game launch, controller and VMC support still require evidence; i.Link remains unsupported; UDPFS and reported device issues require physical testing. Track verified regressions and dates in [STATE.md](STATE.md) and the [QA matrix](QA_REGRESSION_MATRIX.md).

For complete menus, controls, recovery, troubleshooting and developer details, continue below or use the [maintained GitHub Wiki](https://github.com/NathanNeurotic/POPSLoader/wiki).

---

## Controls

Navigate POPSLoader using a standard PS2 controller.

### Menus & Game List

| Button | Action |
| :--- | :--- |
| **D-pad Up / Down** | Scroll through the game list |
| **D-pad Left / Right** | Page Up / Page Down (jump through large lists) |
| **L1** | Jump to the top of the game list — press again to bounce to the bottom |
| **Left Analog Stick (up / down)** | Navigate the game list item-by-item — the stick folds into the d-pad, so a held push scrolls smoothly with the same auto-repeat (only an analog/DualShock pad's stick is read; a digital pad is ignored). Push the stick **left / right** to page-jump like the d-pad. |
| **R1** | Refresh / rescan the current device's game list, in place (e.g. after hot-plugging a drive or card). USB / MMCE / MX4SIO / HDD (PFS) re-scan live by default; if *Game list cache* is enabled in Settings they instead rebuild their saved per-device cache. |
| **Cross (X)** | Confirm option / Launch selected game. On a **Japanese-ROM console** the convention flips automatically: **Circle confirms and Cross cancels** (POPSLoader reads `rom0:ROMVER` at boot), and every on-screen button hint follows. |
| **Circle (O)** | Go back to the Main Menu / Cancel (Cross on a Japanese-ROM console) |
| **Start** | Open Settings |
| **Select** | Toggle "Hide Text Mode" (clears the UI for a clean view of cover art). Works on the device list and the game lists; on the Settings page use *Display → Hide UI Text* instead. |
| **Right Analog Stick (up / down)** | Scroll a long game description that doesn't fully fit on screen (when *Game details* are enabled and a `<game>.txt` is present). |
| **L3 (left stick click)** | Hide / unhide the selected game (writes/removes a `<name>.hide` marker — works on every device, including the internal HDD). Set *Settings → Game List → Hidden games* to *Visible (manage)* to show hidden games dimmed, then press **L3** on a dimmed entry to unhide it. |
| **R3 (right stick click)** | Reveal / re-hide this device's hidden games — a **temporary view for this session only**. When *Settings → Game List → Hidden games* is set to *Hidden* (games filtered out of the list), press **R3** to rebuild the list with them shown dimmed so you can manage them (then **L3** unhides); press **R3** again to hide them. Nothing is saved: the persisted setting lives in *Settings → Game List → Hidden games* and comes back in force when you leave the page or reboot. |
| **R2** | Launch in "HDD Alt" mode (HDD (PFS) game list only — for an HDD-resident POPSTARTER) |

### On-screen Keyboard (Settings path editor)

| Button | Action |
| :--- | :--- |
| **L1 / R1** | Move the text cursor Left / Right |
| **Square (□)** | Delete character (backspace) |
| **R2** | Toggle uppercase / symbols — letters shift to UPPERCASE, and the digit/bracket keys type `@ # $ % ^ * " < > \| { } ~ \`` (for usernames, hidden shares ending `$`, and symbol passwords). The on-screen label always names the mode R2 will **switch to**. |
| **Circle (O)** | Close the keyboard. With unsaved typing it asks for a **second press** (within ~1.5 s) before discarding |

The keyboard opens **uppercase with the cursor on the first letter row** and the **number row sits at the top**. The layout itself (QWERTY / DVORAK / ABC / AZERTY / QWERTZ / ABNT) is picked in *Settings → Startup → Keyboard Layout*.

---

## Settings

Press **Start** on the menu to open Settings. Inside Settings, **Start** opens the **Save Changes / Reset Defaults / Discard & Exit** menu (they are no longer rows in the list); changes save when you confirm. Settings persist per install with **single-device parity** — every device, **including the internal HDD**, saves a `.pldrs` file next to the launcher. HDD installs write that sidecar **on the HDD boot partition itself** (POPSLoader remounts its own boot partition read-write to do so — there is no `mc0:` fallback for HDD installs). For the full rules, see **[STATE.md > Settings](STATE.md#settings-single-device-parity)**.

### Startup

| Setting | Options | What it does |
| :--- | :--- | :--- |
| **Boot Page** | **Carousel** (default) · MX4SIO · USB · MMCE · HDD (PFS) · HDD (exFAT) | Where POPSLoader lands after the boot sequence. *Carousel* shows the normal device wheel. Pick a device and POPSLoader opens **straight into that device's game list** at startup (it loads that backend automatically). If the chosen device is hidden (e.g. an HDD Boot Page after switching *Internal HDD* the other way), boot lands on the carousel with a message saying why. A `-page=` launch argument still overrides this for that one boot. |

### Device List

| Setting | Options | What it does |
| :--- | :--- | :--- |
| **(one row per device: MMCE, MX4SIO, USB, i.Link, SMB, Disc)** | Shown · Hidden (**i.Link ships Hidden**) | Hide or show each entry on the main device carousel. **i.Link is Hidden by default** (its flow isn't implemented yet); every other device defaults to Shown. Set unused backends to **Hidden** to remove them from the wheel, or show i.Link if you want it. At least one device must stay **Shown**. Saved with your settings (`HIDDEN_DEVICES`); hidden entries are skipped during carousel navigation with no gaps, and launch behavior is unchanged. |
| **Internal HDD** | PFS · exFAT (APA-Jail) · **Both (default)** | Picks which internal-HDD page(s) show on the carousel — the classic Sony APA/PFS page, the APA-Jail **exFAT** page (BDMA ATA backend), or **both** (the default). PFS (APA) and exFAT **coexist** — showing both does not gate either one (saved as `HDD_FS`). A `-page=ata` (or `exfat`) launch argument still opens the exFAT page regardless of this setting. |

### Game List

| Setting | Options | What it does |
| :--- | :--- | :--- |
| **Multi-disc games** | **Show all discs** (default) · First disc only | *First disc only* hides the secondary discs of multi-disc games so only disc 1 shows. **Detection is purely by filename** — a disc is hidden if its name contains `(Disc 2)`, `(Disc 3)`, `(CD 2)`, `(Disk 2)`… (any number ≥ 2). So it **only works if you name your files with that convention**, e.g. `Final Fantasy IX (Disc 1).VCD` / `Final Fantasy IX (Disc 2).VCD`. Launch disc 1 and swap discs in-game via your VMC. (PS1 discs carry no shared "this is the same game" metadata, so the filename is the only signal.) Applies to every device. |
| **Hidden games** | **Visible (manage)** (default) · Hidden | Per-game hide layer. Press **L3** on any game to hide or unhide it — hiding writes (or removes) a tiny `<name>.hide` marker next to the game's `.VCD`. *Hidden* filters tagged games out of the list; *Visible (manage)* shows them **dimmed** so you can manage them with L3. In-app hiding works on **every device** — USB / MX4SIO / MMCE / Memory Card **and the internal HDD** (POPSLoader writes the `.hide` on the HDD via its read-write boot-partition mount). |
| **Game details** | **Off** (default) · Left · Center · Right | Shows a per-game blurb from a `<game>.txt` sidecar in a small panel under the cover, in the chosen text alignment (*Off* hides it). The `.txt` lives in the same fixed top-level `ART/` folder as the cover and is named after the **exact** game filename, so a multi-disc game needs one `.txt` per disc. (The internal PFS HDD is the one exception: there the disc-marker-stripped name is still tried first.) Authored line breaks are preserved; scroll a long blurb with the **right analog stick**. |
| **Retro GEM Game ID** | **On** | Reads the PS1 title ID out of the `.VCD` — from `SYSTEM.CNF` **inside the disc image**, not from the filename — and emits it optically at launch so a **Retro GEM** applies that game's per-game profile. There is no data channel for this: the ID is drawn as a small pattern of coloured sprites that the mod decodes off the video output, so it appears briefly at the bottom of the launch overlay. Harmless without the mod, and a disc with no readable title ID simply emits nothing rather than a guess. Format credit: [CosmicScale](https://github.com/CosmicScale)'s Retro-GEM tools and [saildot4k](https://github.com/saildot4k)'s [wLaunchELF_R3Z](https://github.com/saildot4k/wLaunchELF_R3Z). |
| **Cover art** | **On** (default) · Off | Draws each game's cover in the preview box beside the list. **Off** shows the plain jewel-case placeholder instead and hides optional disc icons (`<name>_ICO.png`). Covers are always read from one fixed place — a top-level `<device>:/ART/` folder, named `<name>_COV.png` (the OPL convention) — with no folder choice for local devices (UDPFS also checks beside the VCD in `udpfs:/POPS/`). Both covers and optional `_ICO.png` icons are fetched by a shared background worker, so browsing never stalls waiting on the card, and a cover that genuinely is not there is remembered as missing and not looked for again that session. The internal HDD keeps its fixed `__common/POPS/ART/` layout. |
| **Game list cache** | **Off** (default) · On | When **On**, USB / MMCE / MX4SIO **and the internal HDD (PFS)** save their scanned game list per device so the "Building game list…" rescan only runs once (rebuild it with **R1**). **Off** = always live-scan (the default, unchanged behavior). |

### Other settings

- **POPSTARTER Path** — which `POPSTARTER.ELF` to use. Leave it on **Automatic** (the default) and POPSLoader resolves it per device at launch: **(1)** the game device's own `<device>:/POPS/POPSTARTER.ELF` if present — on the internal **PFS HDD** this step is `hdd0:__common/POPS/POPSTARTER.ELF` instead; **(2)** the `POPSTARTER.ELF` next to where `POPSLOADER.ELF` launched from; **(3)** the `mc0:`/`mc1:/POPSTARTER` fallback. Or set an explicit path — it is tried **first**, and if it doesn't resolve (drive unplugged, typo) the launch silently falls back to the same Automatic order; you're only warned when **no** `POPSTARTER.ELF` is found anywhere. (The old 16-entry Profile preset list is gone — and if you had a preset selected, it's carried over into this path automatically on first boot, so nothing stops launching. No more `pfsN` partition numbers on screen.) Clearing the path in the editor returns it to Automatic.
- **DKWDRV Path** — path to `DKWDRV.ELF` used by the Disc option.
- **Video Standard** — **Auto** (default — matches your console's region) / NTSC / PAL. On PAL the UI now renders **natively at 640×512** so it fills the whole screen with no letterbox (NTSC is 640×448). A display-mode change shows a confirm prompt that **auto-reverts** if you don't confirm, so a bad mode can't strand you; you can also hold **Start** during boot to skip past a bad video mode.
- **Overscan (CRT inset)** — **Off** (default) up to a numeric inset, adjusted in steps of **5** (OPL-style render inset, same math as OPL's overscan). Pulls the whole UI slightly toward the center of the screen so nothing is lost in a CRT's overscan border. The change previews live as you adjust it; backing out of Settings without saving restores the previous value. *(Mainly useful on a real CRT; on a flat panel you'll usually leave it Off.)*
- **Boot sound** — **On** (default) / Off. Plays the startup chime over the boot splash. Turn it **Off** for a silent boot. (Hardware-confirmed to save and survive a reboot.)
- **BDMA Mode** — mass-storage backend mode: **FAT32** (`FAT32-USB (None)`) / **USBEXFAT** (`exFAT-USB`) / **MX4SIO** / **MMCE** / **ATA** (`exFAT-HDD (ata)` — an internal SATA/IDE drive formatted exFAT; *new, validating on hardware*). The installed mode is recorded in a `bdma_mode.txt` marker file in the POPSTARTER pack folder (older `.pldr_bdma_mode` markers are still read for compatibility).
- **Adaptive BDMA** — *(new, validating on hardware)* stages the right BDMA drivers for the **game you launch**, automatically, so MMCE and USB (and MX4SIO / exFAT-HDD) games can coexist without flipping BDMA Mode between launches. It checks first and skips the write when the correct drivers are already on the card. With Adaptive BDMA on, USB launches always stage the exFAT-USB pair (`USBEXFAT`). That pair reads FAT32 drives too, so one variant plays every USB stick and nothing has to guess the filesystem. Using POPStarter's own built-in FAT32 stack is a manual-only choice now: set **BDMA Mode** to `FAT32` with Adaptive **Off**. Default **On** — changed 2026-07-28 after a tester reported the BDM Assault drivers were never installed for ATA. They never were, for any device: the staging machinery was complete and correct, it simply never ran, because it sat behind a setting nobody knew to turn on. The cost of On is that every device gets a variant staged unless you opt out.
- **POPSTARTER Memory Card Folder** — toggles the `mc:/POPSTARTER` folder. Turning it **off deletes** `mc:/POPSTARTER` (with a confirm prompt). It is **interlocked with BDMA Mode**: you can't turn this folder off while BDMA Mode is on (or while Adaptive BDMA is on), and you can't enable either while this folder is off.
- **Hide UI Text** — **On** (default) / Off; clears on-screen text for a clean cover-art view (also toggled with **Select**). It ships **On**, so a fresh install starts with the on-screen text hidden.
- **Keyboard Layout** — on-screen keyboard layout for the path editor: **QWERTY** (default) / DVORAK / ABC / AZERTY / QWERTZ / ABNT. This is the only place the layout is chosen; the keyboard itself no longer carries a layout strip.
- **Credits** — *Settings → About → Credits*. (It used to be a Triangle shortcut advertised in every footer.)

### SMB / Network

Browse and launch PS1 games from an **SMBv1** network share via the **SMB** carousel entry. Networking is **lazy**: nothing network-related runs at boot; the stack comes up only when you open the SMB page. *(Browsing and launching are confirmed working on a **static** IP setup. **DHCP** needs a build newer than `bb62f2be` — earlier builds deleted the address file POPStarter depends on, so a DHCP setup would list games and then fail to boot them.)*

| Setting | Default | What it does |
| :--- | :--- | :--- |
| **SMB modules** | Not installed | Installs the in-game SMB streaming pack (6 IRX + `SMBCONFIG.DAT`/`IPCONFIG.DAT`) into `mc:/POPSTARTER` on Save. Turning it **off removes those 8 files from BOTH memory card slots** — POPSTARTER reads mc0 with a per-file mc1 fallback, so a half-removal would leave it still finding modules and a stale `SMBCONFIG.DAT` holding your server, share and plaintext password. **Required to LAUNCH games** — browsing works without it, and the loader warns (and blocks a launch) when it's missing. Interlocked with the *POPSTARTER Memory Card Folder* toggle. |
| **IP assignment** | Static | DHCP or Static, and this controls **browsing only**. POPSTARTER cannot obtain an address itself, so the **PS2 IP / Netmask / Gateway** rows must be filled in either way — they are what gets written to `IPCONFIG.DAT` for the game to use. Nothing is invented for you; blank means blank. |
| **Server IP** | *(blank)* | The SMB server's IP address. (NetBIOS names are not supported — use the IP.) **No defaults are supplied for any network field.** They used to be pre-filled with a guessed home-LAN layout, which read as configuration the user had chosen and hid the real values; on first run every field is now empty, and existing `IPCONFIG.DAT`/`SMBCONFIG.DAT` on the memory card are loaded instead. |
| **Port** | *(blank)* | The server's SMB TCP port. **Stock SMB servers listen on 445**; leave blank and POPSTARTER uses 445. Written into `SMBCONFIG.DAT` as `SERVER:PORT` — **always explicit**, including `:445`, because these files are read back as well as written. |
| **Share** | *(blank)* | The share name. **Leave it blank** and the SMB page lists the server's shares in an in-app picker; your choice is saved. |
| **User / Password** | *(guest)* | Credentials, when the share needs them (either one set = credentials are used, in-app and in-game). Values are trimmed except the password; the R2 symbol shift types `@ # $ %` etc. |

Share layout: `\\server\share\POPS\Game.VCD` (plus the usual POPS support files). Launches hand POPStarter an `SB.<name>.ELF` selector and it streams the `.VCD` from the share using the installed pack's `SMBCONFIG.DAT`.

**SMB fails to connect?** The error names the failing step. "No network link" = cable/adapter; "DHCP failed" = try Static; "Can't reach the server" = check Server IP **and Port** (stock servers = 445); "Server refused SMBv1" = enable SMBv1 support on the host (modern Windows/Samba disable it by default); "SMB login failed" = credentials; "Share not found" = share name (or use the blank-Share picker).

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

## Loading extra IRX drivers

At boot POPSLoader loads **every `.irx` file sitting in its own folder**, next to `POPSLOADER.ELF`, in directory order. If it finds none there it then tries an `IRX/` subfolder. That is how you add a driver POPSLoader does not ship — put the `.irx` beside the ELF and it is loaded.

There is no allow-list and no prompt, so **anything** with an `.irx` extension in that folder is loaded, whether or not you meant it. Two consequences worth knowing:

*   Keep the folder tidy. A driver you copied there once to test is still being loaded every boot, months later.
*   A driver that hangs waiting on hardware you do not have will hang the boot. The most common way to hit this is running POPSLoader from a **downloads folder** that still contains loose drivers, or under an **emulator** where the hardware a driver probes is only a stub. If POPSLoader boots on a real console but hangs in an emulator, move the loose `.irx` files out of the folder and try again — that is the first thing to check.

Use the `IRX/` subfolder if you want the drivers kept but not tangled up with whatever else lands in your download directory.

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
*   **This is the most common reason art does not appear after updating.** The PNG filename must match the `.VCD` game filename with the OPL `_COV` suffix (e.g. `Crash Bandicoot.VCD` requires `Crash Bandicoot_COV.png`). **The `_COV` is not optional and will not be made optional:** it is OPL's convention, and matching it is what lets one art folder serve both OPL and POPSLoader. Accepting a bare `<name>.png` here would break that sharing. Note the details sidecar does NOT take the suffix -- it is `<name>.txt` -- so it is easy to get one right and the other wrong. Only the exact game filename is tried, so a multi-disc game needs one cover **per disc** (`Game (Disc 1)_COV.png`, `Game (Disc 2)_COV.png`). A single shared cover for the whole set no longer works.
*   Place the cover or optional `_ICO.png` disc icon in the top-level **`ART/`** folder at the device root. For local devices this is the only artwork location; UDPFS additionally checks beside the VCD in `udpfs:/POPS/`. There is no user-selectable art folder. On the internal HDD covers live in `__common/POPS/ART/`.
*   Confirm cover-art preview is enabled in *Settings → Game List → Cover art* (default **On**). Square is not bound in the game list.
*   For best compatibility and performance, use 200x200 pixel, 8-bit-per-channel RGBA PNG images. Release 1.2.0 can render RGB PNG covers invisible; adding an opaque alpha channel is the workaround ([issue #575](https://github.com/NathanNeurotic/POPSLoader/issues/575)). Version 1.2.1 includes the RGB decoder correction; hardware validation is tracked in [STATE.md](STATE.md).

### BOOT.ELF exit option fails or hangs
*   Confirm that a valid wLaunchELF executable is installed on your physical memory card at `mc0:/BOOT/BOOT.ELF` or `mc1:/BOOT/BOOT.ELF`.

---

## Known Issues & Planned Improvements

Confirmed broken: see the single canonical **[STATE.md > Known Issues](STATE.md#known-issues-canonical--the-single-list-readme--agents--rolling_notes-point-here)** list (currently: the "Failed to load HDD" from a non-HDD boot case, and the SMB connect failure whose root cause is fixed in code and awaiting its first hardware run — the full 2026-07-07 audit and fixes are in [docs/REPO_AUDIT_2026-07-07.md](docs/REPO_AUDIT_2026-07-07.md)).

Planned for subsequent updates:
*   **Layer C Lazy IRX Loading**: Defer device-specific IRX modules so they only load when the boot device family needs them, reducing boot time. The `mmceman` portion has **landed** (PR #471): it is now loaded eagerly only when POPSLoader is booted from an MMCE device, and deferred everywhere else. Further deferral of `ds34bt` / `usbd` was **declined** (2026-06-22): both hard-import `usbd` and the only available defer trigger is the boot device family — not the same as pad transport — so deferring them would strand USB / Bluetooth controller input (unrecoverable without a reboot) for a small boot-time gain. They are kept loaded eagerly; the Layer C effort is closed at the `mmceman` win.
*   **Settings UI Redesign ([Berion](https://www.psx-place.com/members/berion.1431))**: Visual overhaul replacing the current OPL-style focused-list with per-category Settings pages. Awaiting Berion's mockup PNGs.
*   **GUI Themes**: Customizable colors / skins / fonts and a setting to skip the boot splash.
*   **In-Game Features**: Support for per-game fixes, cheat codes, Virtual Memory Card (VMC) setups, and multi-disc swap prompts.
*   **`HDD (exFAT)`** menu flow: now **implemented** as a `mass:` backend via BDMA Mode `ATA` (built, CI/Rolling green) — **validating on hardware**.
*   **`SMB (v1)`** network game browsing: now **implemented** (settings, an "SMB modules" install toggle, lazy connect, share browse, launch, and disconnect-on-exit; built, CI/Rolling green) — **browse + launch hardware-confirmed on a static IP config**; the DHCP path was fixed in `bb62f2be` and is not yet confirmed.
*   **`i.Link`** remains intentionally hidden/unsupported. Ember i.Link development is deferred until RiptOPL proves reliable support on physical PS2 hardware.

See [STATE.md](STATE.md) "Known Open Work" and [ROADMAP.md](ROADMAP.md) for the prioritized backlog.

---

## Credits

*   **[israpps (El_isra)](https://github.com/israpps)**: Original POPSLoader project creator and BDM Assault reference work.
*   **[Gageformer](https://github.com/Gageformer/Ember)**: Ember PS1 emulator, bundled unmodified with its beta licence.
*   **[Okeanos](https://github.com/Okeanos86/BDMAssault)**: UDPFS Assault PS1 network read/write driver.
*   **Daniel Santos**: Creator of the Enceladus runtime foundation.
*   **[krHACKen](https://www.psx-place.com/members/krhacken.98/)**: Author of [POPStarter](https://www.psx-place.com/resources/popstarter.683/).
*   **[AstroSnail](https://github.com/AstroSnail)**: Recovered and contributed an original Bitbucket Git clone of [ShaolinAssassin](https://github.com/ShaolinAssassin)'s [POPStarter](https://www.psx-place.com/resources/popstarter.683/) documentation wiki (2,140 historical commits, 2016–2024). Its complete edit history complements our Wayback-recovered pages; original authors retain credit. See [provenance](.research/research/original-git-provenance.md).
*   **[Berion](https://www.psx-place.com/members/berion.1431)**: User interface design and theme assets.
*   **[nuno6573](https://github.com/nuno6573)**: Cover-art engine integrations, scripting, and hardware testing.
*   **[Hugopocked](https://www.psx-place.com/members/hugopocked.47440/)**: [POPStarter](https://www.psx-place.com/resources/popstarter.683/) fixes.
*   **[saildot4k](https://github.com/saildot4k) (R3Z3N)**: BDMA-ATA (exFAT internal-HDD / ATA backend), the [wLaunchELF_R3Z](https://github.com/saildot4k/wLaunchELF_R3Z) reference work our USB fixes are built on, the settings-UI review rounds, fixes, feedback, and oversight.
*   **[oldman63](https://github.com/oldman63) (Sári Gábor)**: The complete Hungarian localization, plus the localization bug reports that hardened it for every language.
*   **sAGA**: Relentless hardware testing and pin-sharp reports — the USB enumeration saga, the internal-HDD freeze diagnosis rounds, and UI suggestions that shipped.
*   **[CosmicScale](https://github.com/CosmicScale)**: exFAT internal-HDD hardware verification and the per-device [POPSTARTER](https://www.psx-place.com/resources/popstarter.683/) idea.
*   **FifthFox**: The per-device USB-delay POPSTARTER report that shaped the launch resolver.
*   **[Ripto / NathanNeurotic](https://github.com/NathanNeurotic)**: Maintenance, UI polishing, and release engineering.
*   **P4NCHOL1NO, VizoR, provato, TnA-Plastic, and the community**: Hardware testing.

*(GitHub's sidebar can't be trusted to show this repo's contributors — it omits the contributors box on forked repositories — so this list is the canonical one. If you contributed and aren't here, that's a bug: open an issue.)*

---

## Development & Building

GitHub Actions is the canonical build path. The pinned CI image is `ps2dev/ps2dev:v2.0.0`. Every change must pass the CI workflow in `.github/workflows/compilation.yml` before merging; rolling release artifacts for testing are produced by `.github/workflows/rolling-release.yml` on push to `dev`. Pull-request events build and run the same gates but no longer publish: the publish step is gated on `github.event_name == 'push'` (PR #511, 2026-07-16). CI now runs a live `luac` syntax gate over the embedded Lua (`bin/POPSLDR/*.lua` + `etc/boot.lua`) and hard-fails on a syntax error — note this catches **syntax** only; runtime and load-order errors still only surface on real PS2 / PCSX2.

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

To grab the latest test build, download `POPSLOADER-rolling-release-<version>.zip` from the rolling release page:
[https://github.com/NathanNeurotic/POPSLoader/releases/tag/rolling-release](https://github.com/NathanNeurotic/POPSLoader/releases/tag/rolling-release)

The ZIP name ends with the build version, so the link above points at the release page rather than a fixed file
name. `POPSLOADER.ELF` and `PS1_POPSLOADER.psu` keep fixed names, so
`https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/POPSLOADER.ELF` always fetches the newest build.

> 🗄️ **Permanent archive (MEGA):** the GitHub `rolling-release` pre-release only ever holds the *latest* build; every push overwrites it. So **every** branch rolling build is also archived permanently to MEGA as one self-contained zip, each in its own immutable `run_<number>` folder (nothing is ever overwritten there). Click the **MEGA Rolling Archive** badge at the top of this README, or [browse the archive here](https://mega.nz/folder/W9wXyLjD#8hk7Wv-EEPfKPTDN-guKdQ), to grab any past build.
