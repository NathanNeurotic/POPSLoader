## From the official thread — storage, modules & modern devices

> Sourced from the [official psx-place POPStarter thread](https://www.psx-place.com/threads/popstarter.19139/).
> **krHACKen** items are authoritative.

- **Internal-HDD partition scan order is `__.POPS → __.POPS0 → __.POPS1 → … → __.POPS9`.** Unlike `mass:`↔
  `mass0:`, **`__.POPS` is NOT aliased to `__.POPS0`** — so your *second* games partition must be `__.POPS0`
  (not `__.POPS1`). *(krHACKen-authored doc, via Peppe90)*
- **IRX loader:** POPStarter loads up to **`MODULE_0.IRX` … `MODULE_9.IRX`** from the **POPS folder root only**
  (never the per-game VMC folder), after the IOP is reset with the POPS IOPRP. For special input devices
  **`SIO2MAN.IRX` must be `MODULE_0.IRX`** — load order matters. *(ShaolinAssassin / AKuHAK)*
- **Dual POPS-binary resolution:** POPStarter uses `POPS_IOX.PAK` (USB) **or** `POPS.ELF` + `IOPRP252.IMG`
  (in `__common/POPS`) depending on which device is mounted. If an internal-HDD install is incomplete, launching
  shunts straight back to uLaunchELF when no USB stick is present. *(SG-17)* — POPS binaries are
  Sony-copyright; supply them yourself (see [Downloads](downloads.html) for checksums).
- **Global TROJAN path on internal HDD:** `hdd0:/__common/POPS/TROJAN_7.BIN` (alongside `POPS.ELF`). *(El_isra)*
- **Display names live in `conf_apps.cfg` as `display_name=path`, never in the filename.** OPL set this
  standard in v0.8; PSXtreme / the POPStarter Game Installer deliberately generate opaque unique filenames
  (`HWC…VCD`) so patched/region/version variants of the same game never collide. *(krHACKen)*
- **Launcher prefixes are device-specific and not interchangeable:** `XX.` for USB, `SB.` for SMB — and you
  must also edit `title.cfg` to match. *(Lambada)*

### Modern storage (post-abandonment community drivers)

- **exFAT on USB** works via **[BDMAssault](https://github.com/israpps/BDMAssault)** (israpps). *(Ripto)*
- **MX4SIO (SD2PSX-style) and MMCE (SD2PSX / PSXMemCard / MemCard PRO2)** are supported through community
  driver packs (El_isra, 2025): MMCE via **[mmceman](https://github.com/ps2-mmce/mmceman/releases/tag/popstarter)**,
  MX4SIO via BDMAssault. Both use the **same USB folder layout & prefix** and appear on OPL's APPS page.
  *(El_isra / TnA-Plastic)* — this is exactly what the modern **POPSLoader** fork wraps.
