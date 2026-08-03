<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-usb -->
<!-- primary snapshot: 20250202192148  |  28 captures, 4 distinct content version(s) -->
<!-- other distinct versions retained in _versions/quickstart-usb/: 20170627200840, 20170814205340, 20191211121732 -->
# quickstart-usb

# **Quick start guide for USB :**

______________________________________________________________________________________________________________

*(updated ~ 2020/02/09)*

This is a step-by-step basic guide for new POPStarter users. If you are already familiar with POPStarter, you don’t need it. Quickstarter pack includes last POPStarter version (Rev 13 Beta 2019/06/05).

- **Download :** [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter_USB_Quickstarter_Pack_20200209.zip)

______________________________________________________________________________________________________________

## *Step-by-step :*

**a) Installing the emulator :**

Since POPS (the emulator) is copyrighted by SONY, it can not be redistributed with POPStarter. You have to find it. It’s made of 1 file (for USB mode).

```
POPS_IOX.PAK - MD5 : a625d0b3036823cdbf04a3c0e1648901
```

1. Find and download POPS_IOX.PAK ;

1. Create a directory named POPS at the root of your USB device ;

1. Copy POPS_IOX.PAK into POPS directory you’ve just created.

**b) Installing your PS1 Games :**

POPStarter/POPS doesn’t support PS1 disc images as .iso – but only as .VCD.

1. Create a disc image of your PS1 game as .BIN/.CUE ;

1. Drag & drop your .CUE file over CUE2POPS.EXE to convert your BIN/CUE disc image to .VCD file (you can convert several games at once by running BULK_CUE2POPS.BAT) ;

1. Put your .VCD files in mass:/POPS directory.

**c) Installing POPStarter :**

1. Rename the POPStarter ELF as the name of your VCDs, replace the .VCD extension with a .ELF extension, add the XX. prefix (example : for running a VCD named “Crash Bandicoot.VCD”, the POPStarter ELF must be renamed as “XX.Crash Bandicoot.ELF”) ;

1. Copy the ELFs in mass:/POPS.

Now, check your setup. It must be the same as this one :

```
mass:/POPS/POPS_IOX.PAK
mass:/POPS/XX.GAME.ELF
mass:/POPS/GAME.VCD
```

=> to launch your game, run XX.GAME.ELF.

**Note :** tired of renaming tons of ELF files ? Put uLE_kHn_20191110/BOOT in mc0:/BOOT folder and put POPSTARTER.ELF (not renamed) in mass:/POPS directory. This special uLE version can launch .VCD directly – just like you would do for any .ELF file.

```
mass:/POPS/POPS_IOX.PAK
mass:/POPS/POPSTARTER.ELF
mass:/POPS/GAME.VCD
mc0:/BOOT/BOOT.ELF
```

Need help ? Ask over at [PSX-Place](https://www.psx-place.com/threads/popstarter-beta-from-2019-06-05.19139/).

______________________________________________________________________________________________________________

### [**Wiki Homepage**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Home)
