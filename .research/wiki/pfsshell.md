<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/pfsshell -->
<!-- primary snapshot: 20250215031216  |  13 captures, 2 distinct content version(s) -->
<!-- other distinct versions retained in _versions/pfsshell/: 20170629154515 -->
# pfsshell

# [HDD] **Transfer VCD files using PFSSHELL 0.2a**

______________________________________________________________________________________________________________

## *Hardware Requirements :*

- PS2 HDD formatted, with a __.POPS partition, locally connected to your PC

## *Software Requirements :*

- [PFSSHELL 0.2a](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/pfsshell-0.2a.7z) (running under winxp – or enable XP compatibility mode). You can find an updated version of this program [here](https://github.com/uyjulian/pfsshell) by @[uyjulian](https://assemblergames.com/members/uyjulian.103145/) – but you have to compile it yourself.

______________________________________________________________________________________________________________

### *Video tutorial :* [here](https://www.youtube.com/watch?v=ks5CN-Kfv04)

### *Text version – based on the video :*

**Transfer one VCD :**

1. Put your VCDs files in the psshell 0.2a folder.

2. Run pfsshell.exe

3. Select your PS2 HDD using the following command line :

```
device hddX:
```

X = the number of your PS2 HDD.

If you get this message : “ps2hdd: drive status 0, format version [00000002](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/00000002)”, continue.

4. You now need to mount the __.POPS VCD partition, using the following command line :

```
mount __.POPS
```

5. Transfer your 1st VCD file using the following command line :

```
put NAMEOFYOURVCD.VCD
```

6. Once the transfer is over, you can transfer another VCD or quit the programm running :

```
umount
```

then

```
exit
```

7. Done.

**Transfer several VCD at once :**

*[Original tutorial by ElPatas]* [@elotrolado](http://www.elotrolado.net/hilo_ho-pops-emulador-de-psx-para-ps2_1874054) –  *[.bat files thanks to [deba5er](http://psx-scene.com/forums/members/deba5er/) ]*

1. Get these [files](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/pfsshell-0.2a.7z).

2. Open command prompt, then type “cmd”.

3. You need to launch the .bat file from it’s folder. In the example below, pfshell is placed into D: partition, into a folder named “CD Juegos PSX”.

4. Execute the .bat running the following command line :

```
pfs.bat hddX: __.POPS *.VCD
```

- where X is the number of your PS2 HDD;

- __.POPS the partition where the VCDs will be transfer;

- *.VCD means to tranfer all files with .VCD extension.

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
