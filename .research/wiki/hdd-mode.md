<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/hdd-mode -->
<!-- primary snapshot: 20170629165244  |  12 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/hdd-mode/: 20200807220614, 20250215021824 -->
# hdd-mode

# **POPStarter for internal HDD**

______________________________________________________________________________________________________________

## *Requirements :*

- **POPS decrypted files :**

To use POPStarter with an internal HDD, you have to find and download the POPS decrypted files. These files are named “POPS.ELF” and “IOPRP252.IMG”...

<table class="wiki"> <tr> <td> <strong>File name</strong> </td> <td> <strong>MD5</strong> </td> <td> <strong>Description</strong> </td> </tr> <tr> <td> POPS.ELF </td> <td> <a href="/ShaolinAssassin/popstarter-documentation-stuff/commits/355a892a8ce4e4a105469d4ef6f39a42">355a892a8ce4e4a105469d4ef6f39a42</a> </td> <td> main SLBB-00001 ELF, decrypted </td> </tr> <tr> <td> IOPRP252.IMG </td> <td> <a href="/ShaolinAssassin/popstarter-documentation-stuff/commits/1db9c6020a2cd445a7bb176a1a3dd418">1db9c6020a2cd445a7bb176a1a3dd418</a> </td> <td> can be found in some retail game discs and $CEI SDKs too </td> </tr> </table>

- **Other Software Requirements :**

. A software that allows you to convert your disc images to the POPS virtual CDROM format (such as [CUE2POPS](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version))
. A software that allows you to manage/create partitions in your PS2 HDD (such as [AKuHAK’s uLaunchELF build](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/related-stuff) or [uLE_kHn build](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version))
. A software that allows you to copy the decrypted POPS files to the __common partition of your PS2 HDD (such as [AKuHAK’s uLaunchELF build](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/related-stuff) or [uLE_kHn build](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version))
. A software that allows you to transfer the converted disc images to your PS2 HDD (such as [PFSshell](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/related-stuff), or [uLaunchELF](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version) and [RadHostClient](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/related-stuff))
. A PS2 software that allows you to execute the POPStarter ELFs (such as [uLaunchELF](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version), or [Free Harddisk Drive Boot](http://ichiba.geocities.jp/ysai187/PS2/FMCB/)) or a GUI to execute POPSTARTER.ELF by selecting the VCDs (such as [uLE_kHn](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version) )

- **Hardware Requirements :**

. A PS2 console which is able to run PS2 unsigned code;
. A network adapter with/or a HDD interface;
. A PS2-formatted HDD that fits your network adapter/HDD interface.

______________________________________________________________________________________________________________

## *Installation :*

- **a) Installing the Emulator :**

1. Find and download the decrypted emulator files;
2. Create a directory named “POPS” in the “__common” partition of your PS2 HDD;
3. Paste POPS.ELF and IOPRP252.IMG into the “POPS” directory you’ve just created.

- **b) Installing your PS1 Games :**

1. Convert your BIN/CUE disc images to .VCD files using the latest stable version of [CUE2POPS](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vcd) ;
2. Create a partition named “__.POPS” in your PS2 HDD, large enough so you can put all your VCDs inside.
Note : +__.POPS is not correct. Use [AKuHAK’s uLaunchELF build](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/related-stuff) or [uLE_kHn build](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version) to create a partition without +.

- **c) Installing POPStarter :**

1. Rename the POPStarter ELF as the name of your VCDs, replace the .VCD extension with a .elf extension [example : for running a VCD named “Gran Turismo.VCD”, the POPStarter ELF must be renamed as “Gran Turismo.elf”] ;
2. Copy or leave the ELFs where you want to run them from ;
3. Enjoy !

______________________________________________________________________________________________________________

## *Example of Setup :*

```

=== INTERNAL HDD, NEW LAUNCH TYPE ===
__common/POPS/IOPRP252.IMG
__common/POPS/POPS.ELF
__.POPS/Crash Bandicoot.VCD
__sysconf/FMCB/Crash Bandicoot.elf

```

______________________________________________________________________________________________________________

## *POPSTARTER.KELF :*

POPStarter bundle comes with a file named POPSTARTER.KELF (KELF = Krypo-ELF = ELF embedded into a container). It can be used if you have SONY Browser 2.00 (aka HDDOSD) installed on your HDD. Otherwise, it’s useless.

**Notes if you use the POPStarter.KELF :**

- Partition name prefix is of course PP. (PP(dot)) ;

- 1 partition = 1 game – you can’t install several games into a single partition (unless it’s a multi-disc game).

Read [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter-hddosd) for a guide about how to set it up.

______________________________________________________________________________________________________________

## *HDD Launch types (advanced) :*

HDD supports 3 “launch types”. The “launch type” relies on the prefix of your ELF names. Each type uses his own way to name the VCD file :

<table class="wiki"> <tr> <td> </td> <td> <strong>Old launch type</strong> </td> <td> <strong>Alternate old launch type</strong> </td> <td> <strong>New launch type</strong> </td> </tr> <tr> <td> <strong>HDDOSD compatible</strong> </td> <td> Yes </td> <td> No </td> <td> No </td> </tr> <tr> <td> <strong>Partition shown in the HDDOSD/PSBBN/PSX XMB</strong> </td> <td> Yes </td> <td> No </td> <td> – </td> </tr> <tr> <td> <strong>Prefix for POPStarter.ELF</strong> </td> <td> PP. (if used) </td> <td> __. </td> <td> No prefix </td> </tr> <tr> <td> <strong>Prefix for partition name</strong> </td> <td> PP. </td> <td> __. </td> <td> __.POPS or __.POPS# </td> </tr> <tr> <td> <strong>Game name</strong> </td> <td> IMAGE0.VCD (all uppercase) </td> <td> IMAGE0.VCD (all uppercase) </td> <td> Name of the Game.VCD </td> </tr> <tr> <td> <strong>Examples</strong> </td> <td> (1) </td> <td> (2) </td> <td> (3) </td> </tr> <tr> <td> <strong>Description</strong> </td> <td> Launch type that was used in POPStarter 12 and older. Allows to install one VCD per partition. </td> <td> Launch type that was used in POPStarter 12 and older. Allows to install one VCD per partition. </td> <td> Launch type introduced in POPStarter 13 WIP 01. Allows to put multiple VCDs in a single partition. </td> </tr> </table>

**Examples :**

(1) With the POPStarter ELF renamed as PP.SomeGame.elf, POPStarter will launch IMAGE0.VCD which is in the partition named PP.SomeGame.

(2) With the POPStarter ELF renamed as __.SomeGame.elf, POPStarter will launch IMAGE0.VCD which is in the partition named __.SomeGame.

(3) With the POPStarter ELF renamed as Some Game.elf, POPStarter will launch Some Game.VCD which is in the partition named __.POPS or __.POPS0 or __.POPS1… up to __.POPS9.

**Examples of Setups :**

```

=== INTERNAL HDD, OLD LAUNCH TYPE (HDDOSD COMPATIBLE) ===
__common/POPS/IOPRP252.IMG
__common/POPS/POPS.ELF
PP.Crash_Bandicoot/EXECUTE.KELF
PP.Crash_Bandicoot/IMAGE0.VCD

```

```

=== INTERNAL HDD, ALTERNATE OLD LAUNCH TYPE (HIDDEN PARTITION) ===
__common/POPS/IOPRP252.IMG
__common/POPS/POPS.ELF
__.Crash_Bandicoot/IMAGE0.VCD
__sysconf/FMCB/__.Crash Bandicoot.elf

```

```

=== INTERNAL HDD, NEW LAUNCH TYPE ===
__common/POPS/IOPRP252.IMG
__common/POPS/POPS.ELF
__.POPS/Crash Bandicoot.VCD
__sysconf/FMCB/Crash Bandicoot.elf

```

______________________________________________________________________________________________________________

## *Additional notes :*

- The internal HDD has to be PS2 formatted. If you need to format it, use the latest WIP version of AKuHAK’s uLaunchELF HDD edition.

- The partition names are case sensitive, and have to match the POPStarter ELF names.

- The third character of the ELF prefix (when used) is a dot (PPdot / __dot ).

- The prefix (when used) has to be uppercase.

- The file extension .VCD has to be uppercase.

- Whitespaces are not allowed in the partition names (for old launch types).

______________________________________________________________________________________________________________

## *Related stuff :*

You may want to give a look at this :

- [HDD] [Transfer VCD files using PFSSHELL 0.2a](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/pfsshell)

- [HDD] [Transfer VCD files over network using RadHostClient](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/radhostclient)

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
