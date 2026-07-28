<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/cheat-engine -->
<!-- primary snapshot: 20200920023545  |  7 captures, 4 distinct content version(s) -->
<!-- other distinct versions retained in _versions/cheat-engine/: 20170629113247, 20170919040953, 20240324023510 -->
# cheat-engine

# **Cheat Engine**

______________________________________________________________________________________________________________

POPStarter has an embedded cheat engine that supports Gameshark/Action Replay PS1 codes (PS1 RAW codes of types 30, 50, 80 and D0 are supported). Some basic rules about the cheat engine :

- codes will be stored into a txt file named CHEATS.TXT placed into the VMC game folder (each game will have his own dedicated CHEATS.TXT file) ;

- each code line has to start with the $ character otherwise the code is not enabled ;

- each code line must have a space between the adress and the value ;

**Example :**

[Castlevania – Symphony of the Night [NTSC-U]](https://gamehacking.org/game/88578)

CHEATS.TXT location :

```
POPS/Castlevania Symphony of the Night (NTSC-U)/CHEATS.TXT

```

CHEATS.TXT content :

```
$SAFEMODE
$80097BA0 270F // Infinite Health

```

**Notes :**

- It is **highly recommended** to have to [$SAFEMODE command](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats) code at the very first line of the CHEATS.TXT file ;

- Some PS1 games need mastercodes otherwise they crash (ex : Air Race Championship). Only type C0 are supported. Mastercodes of type C1 (aka activation on delay time) are not and will not be supported ;

- You can disable a code if you remove the $ character from the code ;

- You can enable a code for ALL your games if you place the CHEATS.TXT file in POPS folder ;

- You can find a list of useful generic commands [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats) ;

- A massive PS1 codes list in PS1 RAW format can be found [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/ps1-codes-in-ps1-raw-format) ;

- [Gamehacking.org](http://gamehacking.org/system/psx/all) is also a great place for PS1 cheats code ;

- You can also use POPStarter with a PS2 cheat device ([ps2rd](http://psx-scene.com/forums/f173/ps2rd-releases-63021/index6.html#post1024709), Codebreaker, [Cheat Device PS2](https://github.com/root670/CheatDevicePS2...)). POPS Mastercode is 902377F4 0C0902EF. PS2 RAW codes of types 0, 1 and 2 are supported. A massive PS1 codes list in PS2 RAW format – ready-to-use – can be found [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/ps1-codes-in-ps2-raw-format). In order to use a PS1 code with a PS2 cheat device, you need to convert it to PS2 RAW format : add $[01000000](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/01000000) to the PS1 code adresses and comply with the code type definitions of the target PS2 cheat engine. For more info about how to convert codes, check this [post](https://assemblergames.com/threads/ps2-pops-stuff.45347/page-27#post-760915).

______________________________________________________________________________________________________________

## *Related stuff :*

You may want to give a look at this :

- [Special Cheats – Automated Codes](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats).

- [CHEATS] [Widescreen Codes Archive](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/ps1-widescreen-codes).

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
