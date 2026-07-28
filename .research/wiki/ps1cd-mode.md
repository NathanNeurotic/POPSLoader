<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/ps1cd-mode -->
<!-- primary snapshot: 20240310061934  |  7 captures, 1 distinct content version(s) -->
# ps1cd-mode

# **PS1 CD mode**

______________________________________________________________________________________________________________

PS1 CD mode is a native POPS feature. It lets you play your PS1 games (originals, backups and imports) from the CDVD drive.

**Warning :** playing game CDs is not recommended. Playing game CDs with swap trick is super-not-recommended (see notes).

To use that mode, you must rename POPSTARTER.ELF file using the name you want, as long as there is no VCD (or partition) with such a name in your setup. It saves VMCs to the device according to the ELF prefix.

- GAME.ELF will save into __common/POPS/GAME/SLOT#.VMC ;

- XX.GAME.ELF will save into mass:/POPS/GAME/SLOT#.VMC ;

- SB.GAME.ELF will save into smb:/POPS/GAME/SLOT#.VMC.

You can use a generic name, such as (##.)PS1CD.ELF (PS1CD.ELF or XX.PS1CD.ELF or SB.PS1CD.ELF). When you use a generic name, all games will share the same VMCs (POPS/PS1CD/SLOT#.VMC).

**Example :**

1. Rename POPSTARTER.ELF as “Metal Gear Solid.ELF” (Metal Gear Solid.VCD shall not exist in your setup) ;

1. If you want to make your saves on USB device, add the XX. prefix to the ELF launcher (“XX.Metal Gear Solid.ELF”), if you want to make your saves on SMB, add the SB. prefix to the ELF launcher (“SB.Metal Gear Solid.ELF”) ;

1. Insert your MGS disc in the CDVD drive ;

1. Launch ##.Metal Gear Solid.ELF ;

1. MGS disc should start. When you make a save, it will be stored into POPS/Metal Gear Solid/SLOT#.VMC. You can store external files such as CHEATS.TXT etc… in POPS/Metal Gear Solid folder and they will be loaded from there.

**Backups and imports discs :**

If you want to use a PS1 **import game disc** or a PS1 **backup disc**, you must perform the swap trick (run uLaunchELF, insert an original PS1 original disc – with an equal or bigger TOC than your import game disc/backup disc – then swap with your PS1 import game disc/backup disc) before launching POPSTARTER.ELF (renamed and prefixed). PS2CD and PS2CDDA disc types are accepted to perform the swap trick.

**Notes :**

- Compatibility from physical disc is worse than from HDD/USB/SMB (games tend to freeze or not load) ;

- No CDDA tracks support in this mode (outputs some awful noises instead of the actual CDDA music/sound). You can force CDDA tracks using $UNDO_MUTE_CDDA command in a CHEATS.TXT file ;

- If you use a multi-disc game, use the [hotkeys](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/multi-disc) to swap the discs ;

- We found out after RIP 06 release that the HDD old launch type method (PP.GAME.ELF or __.GAME.ELF) [has a bug](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-112#post-952852) : files from __common/POPS folder (and from __common/POPS/GAME) will not be loaded.

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
