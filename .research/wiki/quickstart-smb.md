<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-smb -->
<!-- primary snapshot: 20250106111812  |  12 captures, 2 distinct content version(s) -->
<!-- other distinct versions retained in _versions/quickstart-smb/: 20191020121159 -->
# quickstart-smb

# **Quick start guide for SMB :**

______________________________________________________________________________________________________________

*(updated ~ 2020/02/09)*

This is a step-by-step basic guide for new POPStarter users. If you are already familiar with POPStarter, you don’t need it. Quickstarter pack includes last POPStarter version (Rev 13 Beta 2019/06/05).

- **Download :** [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter_SMB_Quickstarter_Pack_20200209.zip)

______________________________________________________________________________________________________________

## *Step-by-step :*

**a) Installing the emulator :**

Since POPS (the emulator) is copyrighted by SONY, it can not be redistributed with POPStarter. You have to find it. It’s made of 1 file (for SMB mode).

```
POPS_IOX.PAK - MD5 : a625d0b3036823cdbf04a3c0e1648901
```

1. Find and download POPS_IOX.PAK ;

1. Create a directory named POPS in your PS2 shared folder ;

1. Copy POPS_IOX.PAK into POPS directory you’ve just created.

**b) Installing your PS1 Games :**

POPStarter/POPS doesn’t support PS1 disc images as .iso – but only as .VCD.

1. Create a disc image of your PS1 game as .BIN/.CUE;

1. Drag & drop your .CUE file over CUE2POPS.EXE to convert your BIN/CUE disc image to .VCD file (you can convert several games at once by running BULK_CUE2POPS.BAT);

1. Put your .VCD files in POPS directory of your PS2 shared folder.

**c) Installing POPStarter :**

1. Edit the 2 .DAT files (syntax below) included with the network modules with your network settings;

1. Create a directory named POPSTARTER in the root of your PS2 memory card and put the network modules and the .DAT files in it;

1. Rename the POPStarter ELF as the name of your VCDs, replace the .VCD extension with a .ELF extension, add the SB. prefix (example : for running a VCD named “Crash Bandicoot.VCD”, the POPStarter ELF must be renamed as “SB.Crash Bandicoo.ELF”) ;

1. Copy the ELFs where you want to run them from (example : mass:/POPSTARTER/SB.GAME.ELF).

Now, check your setup. It must be the same as this :

```
mc#:/POPSTARTER/IPCONFIG.DAT
mc#:/POPSTARTER/SMBCONFIG.DAT
mc#:/POPSTARTER/poweroff.irx
mc#:/POPSTARTER/ps2dev9.irx
mc#:/POPSTARTER/smsutils.irx
mc#:/POPSTARTER/ps2ip.irx
mc#:/POPSTARTER/ps2smap.irx
mc#:/POPSTARTER/smbman.irx
smb0:/My Shared Folder/POPS/POPS_IOX.PAK
smb0:/My Shared Folder/POPS/GAME.VCD
mass:/POPSTARTER/SB.GAME.ELF
```

=> to launch your game, run SB.GAME.ELF. Need help ? Ask over at [PSX-Place](https://www.psx-place.com/threads/popstarter-beta-from-2019-06-05.19139/).

______________________________________________________________________________________________________________

## *.DAT syntax :*

- **SMBCONFIG.DAT syntax :**

In a single line :

```
SERVER IP ADDRESS space SHARE NAME
```

Example :

```
192.168.0.254 My Shared Folder
```

You can also specify a port, like this (default is 445) :

```
192.168.0.254:139 My Shared Folder
```

For user authentication, write your username to line 2 and your password to line 3.

Example :

```
192.168.0.254 My Shared Folder
MyName
MyPassword
```

For guest access, don’t write anything to line 2 and 3.

- **IPCONFIG.DAT syntax :**

In a single line :

```
PS2 IP ADDRESS space NETMASK space GATEWAY
```

Example :

```
192.168.0.13 255.255.255.0 192.168.0.254
```

______________________________________________________________________________________________________________

### [**Wiki Homepage**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Home)
