<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/bios-osd-handlers -->
<!-- primary snapshot: 20240906220603  |  6 captures, 2 distinct content version(s) -->
<!-- other distinct versions retained in _versions/bios-osd-handlers/: 20170629161024 -->
# bios-osd-handlers

# **BIOS & OSD Handlers**

______________________________________________________________________________________________________________

## *BIOS handler :*

POPStarter has a BIOS handler so you can use your own external PlayStation BIOS dump in remplacement of POPS built-in BIOS. You have to rename it as BIOS.BIN and place it into the VMC game folder (example : __common/POPS/GAME/BIOS.BIN for internal HDD) and POPStarter will use it for this game. You can also place it into the POPS folder (__common/POPS/BIOS.BIN for internal HDD) and your BIOS will be used for all your games (this is NOT recommended). If no BIOS.BIN is found in VMC game folder (or in POPS folder), POPS will use its built-in BIOS.

Though using a BIOS with a game doesn’t improve compatibility, you can use that feature to manage your  PS1 MC saves and listen to your CDDA game tracks…

______________________________________________________________________________________________________________

## *OSD handler :*

POPStarter has an OSD replacement image handler. The OSD replacement image have to be named as OSD.BIN and placed into the VMC game folder of your game (or in POPS folder). When an OSD replacement image is found in your VMC game folder (or in POPS folder), it will be injected in the built-in BIOS.

**Notes :**

- When using a OSD replacement image, “BIOS.BIN” is ignored ;

- 2 OSD replacement examples were released by krHACKen : Import Player CD v1.4 and CodeBreaker Release 2.00 Build 2E. They are copyrighted so I will not share them here ;

- To create your own OSD files, you need a tool named OSD.BIN Maker ;

- More infos about the OSD replacement image @[ASSEMblergames](https://assemblergames.com/threads/ps2-pops-stuff.45347/page-4#post-667305).

**Description of the header structure of an OSD replacement image :**

```
===================================================
OSD Replacement Image [Version 1] Header Structure
===================================================
Offset 0h to 8h		= Identifier (PS-X OSD)
Offset 8h to Ch		= NULL NULL NULL NULL
Offset Ch		= Image version (Currently 0x01 for Version 1, POPStarter Rev.10 compatible)
Offset Dh		= NULL
Offset Eh		= Program/OSD build, user defined
Offset Fh		= NULL
Offset 10h to 14h	= Load Address
Offset 14h to 18h	= Entrypoint
Offset 18h to 1Ch	= RESERVED RESERVED RESERVED RESERVED
Offset 1Ch to 20h	= Size of the OSD (loadable segment size, the header length is excluded)
Offset 20h to 34h	= Program/OSD name, 20 ASCII chars max, terminated with 0x00 (user defined)
Offset 34h to 40h	= UNDEFINED (must be NULL)
Offset 40h		= Executable segment start
========================================
LIMITATIONS AND RESTRICTIONS [Version 1]
========================================
+ The file identifier must be "PS-X OSD"
+ The name of the OSD replacement (in the header, starting from offset 20h) must be at least 1 ASCII character long;
the length can be up to 20 characters
+ The OSD Load Address and the Entrypoint have to be multiples of 10000h
+ The image version (offset Ch) and the OSD build (offset Eh) cannot be NULL
+ NULL/RESERVED/UNDEFINED fields have to be NULL
+ The size of the OSD replacement file (OSD.BIN) has to be the header length PLUS the OSD size
```

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
