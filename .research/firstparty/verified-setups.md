## Maintainer-verified file structures (confirmed working)

> These exact layouts are **first-party, tested by the POPSLoader maintainer** across multiple OPL forks
> (Daily Build "Tenth Anniversary", Grimdoomer, official 1.1.0 / 1.2.0 betas) — the highest-confidence setups
> on this site. The `Soul Blade` examples below use SLUS_002.40; substitute your own game. Save `title.cfg`
> as **`.cfg`, not `.txt`**, and it's best **not** to put the game ID in the `.VCD` filename for the
> uLE_kHn (also seen as `wLE_kHn`) / POPSLoader listings.

### USB mass storage

**OPL — all versions — APPS page (renamed-ELF method):**
```
mass:/POPS/SLUS_002.40.Soul Blade.VCD            (converted from your BIN/CUE PS1 backup)
mass:/POPS/SLUS_002.40.Soul Blade/               (per-game VMC + HugoPocked fixes folder)
mass:/POPS/POPS_IOX.PAK
mass:/APPS/PS1_Soul Blade/XX.SLUS_002.40.Soul Blade.ELF   (a renamed copy of POPSTARTER.ELF)
mass:/APPS/PS1_Soul Blade/title.cfg
        title=[PS1] Soul Blade
        boot=XX.SLUS_002.40.Soul Blade.ELF
```

**OPL Daily Build (Tenth Anniversary) — PS1 page (direct VCD):**
```
mass:/POPS/POPSTARTER.ELF
mass:/POPS/SLUS_002.40.Soul Blade.VCD
mass:/POPS/SLUS_002.40.Soul Blade/
mass:/POPS/POPS_IOX.PAK
```

**POPSLoader APP (USB):**
```
mass:/POPS/POPS_IOX.PAK
mass:/POPS/POPSTARTER.ELF
mass:/POPS/Soul Blade.VCD
mass:/POPS/Soul Blade/
mass:/APPS/PS1_POPSLDR/POPSLOADER.ELF
mass:/APPS/PS1_POPSLDR/title.cfg
        title=[PS1] !POPSLOADER
        boot=POPSLOADER.ELF
```

**HugoPocked per-game fixes:** drop them in a folder named after the VCD, e.g. `123.VCD` → `mass:/POPS/123/`.

### exFAT on USB — BDMAssault enabler (case-sensitive!)

israpps' [BDMAssault](https://github.com/israpps/BDMAssault) renames `usbd_bd_assault.irx` and
`bdm_assault.irx`. Place on a memory card (exact case matters):
```
mc?:/POPSTARTER/usbd.irx
mc?:/POPSTARTER/usbhdfsd.irx
mc?:/SYS-CONF/USBD.IRX
mc?:/SYS-CONF/USBHDFSD.IRX
```

### SMB (Ethernet)

Confirmed on recent Grimdoomer, Daily Build, and the official OPL betas.
**Required `mc?:/POPSTARTER/` files for SMB:** `IPCONFIG.DAT`, `SMBCONFIG.DAT`, `poweroff.irx`, `ps2dev9.irx`,
`ps2ip.irx`, `ps2smap.irx`, `smbman.irx`, `SMSUTILS.irx`, `usbd.irx`, `usbhdfsd.irx` (the last two are the
BDMA exFAT drivers).
```
smb:/POPS/SLUS_002.40.Soul Blade.VCD
smb:/POPS/POPS_IOX.PAK
smb:/POPS/POPSTARTER.ELF
smb:/APPS/Soul Blade/SB.SLUS_002.40.Soul Blade.ELF   (renamed POPSTARTER.ELF — note the SB. prefix for SMB)
smb:/APPS/Soul Blade/title.cfg
        title=[PS1]Soul Blade
        boot=SB.SLUS_002.40.Soul Blade.ELF
```

### Internal SATA/IDE HDD/SSD — PFS-APA

**OPL — all versions — APPS page:**
```
hdd:/__.POPS/SLUS_002.40.Soul Blade.VCD
hdd:/__common/POPS/IOPRP252.IMG
hdd:/__common/POPS/POPS.ELF
hdd:/__common/POPS/POPSTARTER.ELF
hdd:/+OPL/APPS/Soul Blade/SLUS_002.40.Soul Blade.ELF   (renamed POPSTARTER.ELF)
hdd:/+OPL/APPS/Soul Blade/title.cfg
        title=[PS1]Soul Blade
        boot=SLUS_002.40.Soul Blade.ELF
```

### exFAT internal — NOT supported, except via APA-Jail

POPStarter does **not** support internal exFAT storage directly. With APA-Jail you can do:
```
exfat:hdd:APPS/Soul Blade/SLUS_002.4.0.Soul Blade.ELF
exfat:hdd:APPS/Soul Blade/title.cfg   (title=Soul Blade / boot=SLUS_002.4.0.Soul Blade.ELF)
apa:hdd:/__.POPS/SLUS_002.4.0.Soul Blade.VCD
apa:hdd:/__common/POPS/IOPRP252.IMG
apa:hdd:/__common/POPS/POPS.ELF
apa:hdd:/__common/POPS/POPSTARTER.ELF
apa:hdd:/__common/POPS/POPS_IOX.PAK
```

> **Note on POPS files** (`POPS_IOX.PAK`, `POPS.ELF`, `IOPRP252.IMG`): Sony-copyrighted — supply your own and
> verify against the checksums on the [Downloads](downloads.html) page.
