<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/smb-mode -->
<!-- primary snapshot: 20200812185303  |  5 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/smb-mode/: 20170629160319, 20240310054522 -->
# smb-mode

# **POPStarter for SMB**

______________________________________________________________________________________________________________

## *Requirements :*

**POPS compressed file :**

To use POPStarter in SMB mode, you have to find and download the compressed POPS file. This file is named “POPS_IOX.PAK”...

<table class="wiki"> <tbody><tr> <td> <strong>File name</strong> </td> <td> <strong>MD5</strong> </td> <td> <strong>Description</strong> </td> </tr> <tr> <td> POPS_IOX.PAK </td> <td> <a href="https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/a625d0b3036823cdbf04a3c0e1648901">a625d0b3036823cdbf04a3c0e1648901</a> </td> <td> POPS.PAK with network modules embedded. </td> </tr> </tbody></table>

**Other Software Requirements :**

- A software that allows you to convert your disc images to the POPS virtual CDROM format (such as [CUE2POPS](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version)) ;

- A PS2 software that allows you to execute the POPStarter ELFs (such as [uLaunchELF](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/related-stuff), or [Free Harddisk Drive Boot](http://ichiba.geocities.jp/ysai187/PS2/FMCB/)) or a GUI to execute POPSTARTER.ELF by selecting the VCDs (such as [uLE_kHn](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version)) ;

- [PS2 network modules](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/network_modules.7z) ;

- A text editor (such as Notepad).

**Hardware Requirements :**

- A PS2 console which is able to run PS2 unsigned code ;

- A PS2 console with a network interface (network adaptor or native) ;

- A network cable ;

- A PS2 Memory Card.

______________________________________________________________________________________________________________

## *Installation :*

**a) Installing the emulator :**

1. Find and download the compressed emulator files ;

1. Create a directory named “POPS” in your PS2 shared folder ;

1. Copy POPS_IOX.PAK  into the “POPS” directory you’ve just created.

**b) Installing your PS1 Games :**

1. Convert your BIN/CUE disc images to .VCD files using the latest stable version of [CUE2POPS](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vcd) ;

1. Put your .VCD files in the “POPS” directory of your PS2 shared folder.

**c) Installing POPStarter :**

1. Grab the network modules and edit the 2 .DAT files (syntax below) with your network settings;

1. Paste the network modules and the .DAT files into mc#/:POPSTARTER/ folder;

1. Rename the POPStarter ELF as the name of your VCDs, replace the .VCD extension with a .ELF extension, add the SB. prefix (example : for running a VCD named “Crash Bandicoot (PAL).VCD”, the POPStarter ELF must be renamed as “SB.Crash Bandicoot (PAL).ELF”) ;

1. Copy or leave the ELFs where you want to run them from ;

1. Enjoy !

- **SMBCONFIG.DAT syntax :**

In a single line,

```
SERVER IP ADDRESS space SHARE NAME

```

**Example :**

```
192.168.0.254 My Shared Folder

```

You can also specify a port, like this (default is 445) :

```
192.168.0.254:139 My Shared Folder

```

For user authentication, write your username to line 2 and your password to line 3.

**Example :**

```
192.168.0.254 My Shared Folder
MyName
MyPassword

```

**Note :** for guest access, don’t write anything to line 2 and 3.

- **IPCONFIG.DAT syntax :** *(this file is optionnal in SMB mode)*

In a single line,

```
PS2 IP ADDRESS space NETMASK space GATEWAY

```

**Example :**

```
192.168.0.13 255.255.255.0 192.168.0.254

```

______________________________________________________________________________________________________________

## *Example of setup :*

```
=== SMB LAUNCH TYPE ===
mc#:/POPSTARTER/IPCONFIG.DAT
mc#:/POPSTARTER/SMBCONFIG.DAT
mc#:/POPSTARTER/poweroff.irx
mc#:/POPSTARTER/ps2dev9.irx
mc#:/POPSTARTER/smsutils.irx
mc#:/POPSTARTER/ps2ip.irx
mc#:/POPSTARTER/ps2smap.irx
mc#:/POPSTARTER/smbman.irx
smb0:/YourSharedFolder/POPS/POPS_IOX.PAK
smb0:/YourSharedFolder/POPS/Crash Bandicoot (PAL).VCD
mass:/SB.Crash Bandicoot (PAL).ELF

```

______________________________________________________________________________________________________________

## *SMB launch type :*

SMB supports only 1 launch type – the “new” one :

<table class="wiki"> <tbody><tr> <td> </td> <td> <strong>SMB launch type</strong> </td> </tr> <tr> <td> <strong>Prefix for POPStarter.ELF</strong> </td> <td> SB. </td> </tr> <tr> <td> <strong>POPStarter folder name</strong> </td> <td> POPS </td> </tr> <tr> <td> <strong>Game name</strong> </td> <td> GAME.VCD </td> </tr> <tr> <td> <strong>Description</strong> </td> <td> Launch type introduced in POPStarter 13 WIP 06, OBT 08. Allows to run VCDs from an SMB share. </td> </tr> <tr> <td> <strong>Example</strong> </td> <td> With the POPStarter ELF renamed as SB.GAME.ELF, POPStarter will launch GAME.VCD which is in POPS folder, placed into your shared folder. </td> </tr> </tbody></table>

______________________________________________________________________________________________________________

## *Additional notes :*

- You can NOT use the old POPS.ELF+IOPRP252.IMG files (POPS.PAK) in SMB mode, updating to POPS_IOX.PAK is **mandatory** ;

- You can load the network modules from the MC that is in the second slot too. When a file can’t be found in mc0:/POPSTARTER/, POPStarter tries to load it from mc1:/POPSTARTER/ ;

- Debug infos at startup can not be skipped in SMB mode ;

- The third character of the ELF prefix is a dot (SBdot) ;

- The file extension .VCD has to be uppercase ;

- The prefix has to be uppercase.

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
