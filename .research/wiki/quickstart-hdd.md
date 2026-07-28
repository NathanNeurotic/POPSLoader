<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-hdd -->
<!-- primary snapshot: 20250215035940  |  18 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/quickstart-hdd/: 20170822060406, 20191112101938 -->
# quickstart-hdd

# **Quick start guide for internal HDD :**

______________________________________________________________________________________________________________

*(updated ~ 2020/02/09)*

This is a step-by-step basic guide for new POPStarter users. If you are already familiar with POPStarter, you don’t need it. Quickstarter pack includes last POPStarter version (Rev 13 Beta 2019/06/05).

- **Download :** [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter_HDD_Quickstarter_Pack_20200209.zip)

______________________________________________________________________________________________________________

## *Step-by-step :*

**a) Installing the emulator :**

Since POPS (the emulator) is copyrighted by SONY, it can not be redistributed with POPStarter. You have to find it. It’s made of 2 files (for HDD mode).

```
POPS.ELF     - MD5 : 355a892a8ce4e4a105469d4ef6f39a42
IOPRP252.IMG - MD5 : 1db9c6020a2cd445a7bb176a1a3dd418
```

1. Find and download POPS.ELF & IOPRP252.IMG ;

1. Create a directory named POPS in the __common partition of your PS2 HDD ;

1. Paste POPS.ELF and IOPRP252.IMG into the “POPS” directory you’ve just created.

**b) Installing your PS1 Games :**

POPStarter/POPS doesn’t support PS1 disc images as .iso – but only as .VCD.

1. Create a disc image of your PS1 game as BIN/CUE ;

1. Drag & drop your .cue file over CUE2POPS.EXE to convert your BIN/CUE disc image to VCD file (you can convert several games at once by running BULK_CUE2POPS.BAT) ;

1. Create a partition named __.POPS in your PS2 HDD, large enough so you can put all your VCDs inside ;

1. Transfer your VCD files in __.POPS partition. The easiest & recommended method is using [RadHostClient](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/radhostclient).

**c) Installing POPStarter :**

1. Rename the POPStarter ELF as the name of your VCDs, replace the .VCD extension with a .ELF extension (example : for running a VCD named “Crash Bandicoot.VCD”, the POPStarter ELF must be renamed as “Crash Bandicoot.ELF”) ;

1. Copy the ELFs in __common/POPS.

Now, check your setup. It must be the same as this one :

```
hdd:/__common/POPS/IOPRP252.IMG
hdd:/__common/POPS/POPS.ELF
hdd:/__common/POPS/GAME.ELF
hdd:/__.POPS/GAME.VCD
```

=> to launch your game, run GAME.ELF.

**Note :** tired of renaming tons of ELF files ? Put uLE_kHn_20191110/BOOT in mc0:/BOOT folder and put POPSTARTER.ELF (not renamed) in __common/POPS directory. This special uLE version can launch .VCD directly – just like you would do for any .ELF file.

```
hdd:/__common/POPS/IOPRP252.IMG
hdd:/__common/POPS/POPS.ELF
hdd:/__common/POPS/POPSTARTER.ELF
hdd:/__.POPS/GAME.VCD
mc0:/BOOT/BOOT.ELF
```

Need help ? Ask over at [PSX-Place](https://www.psx-place.com/threads/popstarter-beta-from-2019-06-05.19139/).

______________________________________________________________________________________________________________

### [**Wiki Homepage**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Home)
