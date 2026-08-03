<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/usb-mode -->
<!-- primary snapshot: 20170629123547  |  12 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/usb-mode/: 20210301201703, 20241207051934 -->
# usb-mode

# **POPStarter for USB Device Storage Type**

______________________________________________________________________________________________________________

## *Requirements :*

- **POPS decrypted files :**

To use POPStarter with an external HDD or a flash disk, you have to find and download the compressed POPS file. This file is named “POPS_IOX.PAK”...

<table class="wiki"> <tr> <td> <strong>File name</strong> </td> <td> <strong>MD5</strong> </td> <td> <strong>Description</strong> </td> </tr> <tr> <td> POPS_IOX.PAK </td> <td> <a href="/ShaolinAssassin/popstarter-documentation-stuff/commits/a625d0b3036823cdbf04a3c0e1648901">a625d0b3036823cdbf04a3c0e1648901</a> </td> <td> POPS.PAK with network modules embedded </td> </tr> </table>

- **Other Software Requirements :**

. A software that allows you to convert your disc images to the POPS virtual CDROM format (such as [CUE2POPS](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version))
. A PS2 software that allows you to execute the POPStarter ELFs (such as [uLaunchELF](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/related-stuff), or [Free MC Boot](http://ichiba.geocities.jp/ysai187/PS2/FMCB/)), or a GUI to execute POPSTARTER.ELF by selecting the VCDs (such as [uLE_kHn](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version))

- **Hardware Requirements :**

. A PS2 console which is able to run PS2 unsigned code
. An USB mass storage device, FAT12 or FAT16 or FAT32 formatted (not NTFS !)

______________________________________________________________________________________________________________

## *Installation :*

- **a) Installing the Emulator :**

1.  Find and download the emulator compressed file;
2.  Create a directory named “POPS” in the root of your USB device;
3.  Copy POPS_IOX.PAK  into the “POPS” directory you’ve just created.

- **b) Installing your PS1 Games :**

1. Convert your BIN/CUE disc images to .VCD files using the latest stable version of [CUE2POPS](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vcd) ;
2. Put your .VCD files in the “POPS” directory which is in the root of your USB device.

- **c) Installing POPStarter :**

1. Rename the POPStarter ELF as the name of your VCDs, replace the .VCD extension with a .elf extension, add the XX. prefix;   [example : for running a VCD named “Gran Turismo.VCD”, the POPStarter ELF must be renamed as “XX.Gran Turismo.elf”]
2. Copy or leave the ELFs where you want to run them from.
3. Enjoy !

**Note :** you no longer need PFS_WRAP.BIN since OBT8, it’s now embedded into POPStarter ELF.

______________________________________________________________________________________________________________

## *Example of Setup :*

```

=== USB DEVICE, NEW LAUNCH TYPE ===
POPS/POPS_IOX.PAK
POPS/Crash Bandicoot.VCD
XX.Crash Bandicoot.elf

```

______________________________________________________________________________________________________________

## *USB launch type :*

USB supports only 1 launch type – the “new” one :

<table class="wiki"> <tr> <td> </td> <td> <strong>USB launch type</strong> </td> </tr> <tr> <td> <strong>Prefix for POPStarter.ELF</strong> </td> <td> XX. </td> </tr> <tr> <td> <strong>POPStarter folder name</strong> </td> <td> POPS or POPS# </td> </tr> <tr> <td> <strong>Game name</strong> </td> <td> Name of the Game.VCD </td> </tr> <tr> <td> <strong>Description</strong> </td> <td> Launch type introduced in POPStarter 13 WIP 02. Allows to run VCDs from an USB mass storage device. </td> </tr> <tr> <td> <strong>Example</strong> </td> <td> With the POPStarter ELF renamed as XX.Some Game.elf, POPStarter will launch Some Game.VCD which is in the POPStarter folder named POPS or POPS0 or POPS1 up to POPS9 placed in USB root. </td> </tr> </table>

______________________________________________________________________________________________________________

## *Additional notes :*

- The USB hard disk / flash disk has to be FAT12 or FAT16 or FAT32 formatted, AND DEFRAGMENTED.

- If you use several POPS# folders, the usual files for the POPS folder (POPS_IOX.PAK & the TM2s) must remain in the main POPS folder.

- If you have a BIOS.BIN, a PATCH_#.BIN, a TROJAN_#.BIN or a VMCDIR.TXT in the POPS folder, you’ll have to copy them to all the POPS# folder you create.

- You can still use the old POPS.ELF+IOPRP252.IMG files (POPS.PAK), but updating to POPS_IOX.PAK is highly recommended.

- You can use your own USB modules (usbd.irx & usbhdfsd.irx, case sensitive, lowercase, no file size restriction) from mc#:/POPSTARTER/. When a file can’t be found in mc0:/POPSTARTER/, POPStarter tries to load it from mc1:/POPSTARTER/.... Mass is not supported (anymore).

- The third character of the ELF prefix is a dot (XXdot).

- The prefix has to be uppercase.

- The file extension .VCD has to be uppercase.

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
