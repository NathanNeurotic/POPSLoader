## From the official thread — troubleshooting & known issues

> Sourced from the [official psx-place POPStarter thread](https://www.psx-place.com/threads/popstarter.19139/).
> **krHACKen** items are authoritative.

### IGR / BOOT.ELF exit chain
- **Black screen after pressing "YES" on the IGR exit popup = your `mc?:/BOOT/BOOT.ELF` is incompatible with
  POPStarter.** Two fixes: (1) **disable POPStarter's internal ELF loader** so it drops to the PS2 Browser
  instead of running BOOT.ELF, or (2) **repack BOOT.ELF with a different packer** (e.g. NRLPack). *(krHACKen)*
- **`PATCH_9.BIN` (in the POPS folder) disables the bugged ELF loader and restores normal IGR.** Caveat: with
  it in place, **OPL-DB can no longer launch the PS1 games** — only the uLaunchELF (`uLE_kHn`) launch path
  works. *(krHACKen)*

### Failure-signature gotchas
- **OPL config files left in the POPS folder** (`conf_elm.cfg`, `conf_elmz.cfg`, maybe more) make POPStarter
  **silently kick back to the OSD with no error**. Remove them. *(krHACKen)*
- **You CANNOT fix HDD mode by copying USB/HDD drivers into `__common/POPS`.** USB drivers renamed
  `MODULE_#.IRX` don't help; `ATAD.IRX` is incompatible with the other drivers, and `HDDLOAD.IRX` is the MBR
  KELF loader (the wrong module). *(krHACKen / sp193 — kills a persistent myth)*
- **`$HDTVFIX` forces 480i and breaks 240p on CRTs.** Some installers (PSF Batchkit Manager) add it silently;
  remove it to restore 240p. *(BloodRaynare)*
- **The OPL "DB" fork (not stock OPL) corrupts TROJAN loading** — use official OPL to launch PS2 games. *(HWNJ)*
- **VMC fragmentation** can make a save vanish or a game refuse to launch; **defragging the drive** restores it.
  *(Peppe90 / HWNJ)*

### Hardware / network specifics
- **SMB on Windows 10:** enable **"SMB 1.0/CIFS"** (the PS2 is SMBv1-only) and either disable
  password-protected sharing **or** (better) create a dedicated Windows user with a password and grant it
  share access; share a **subfolder**, not the whole drive. *(jolek / Arcueid)*
- **SCPH-700xx consoles** often need extra `USBD.IRX` / `USBHDFSD.IRX` via the IRX loader to fully init HDD
  (PS-logo freeze otherwise); VCDs go in `hdd:/__.POPS/` (with the dot). *(jolek)*
- **DS3 over Bluetooth drifts / goes haywire under POPStarter** (all builds) — use the wired-USB DS3 IRX
  files instead. *(CosmicScale)*

### Open / unresolved signatures (recorded for posterity)
- SCPH-77004 PAL slim: universal black-screen even when SMB debug shows all "Done"; signature
  `FFS Wrapper r6a : 35` then black. *(exo12)*
- SMB: VMC save-dir not auto-created over Samba; manually creating it hangs on "Validating the resource
  directory." *(SicariusLeif)* · SMB launch can fail with `LOGON has failed (0)`. *(RandomGuy2024)*
