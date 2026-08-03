<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vcd -->
<!-- primary snapshot: 20250226173918  |  7 captures, 1 distinct content version(s) -->
# vcd

# **Convert your PS1 games to VCD format**

______________________________________________________________________________________________________________

POPS doesn’t support PS1 games images as .iso. It uses virtual CD-ROM format (VCD files). You need to create a 1:1 image of your PS1 game, first in BIN+CUE format using your favorite dump software, then to convert it to VCD.

Your BIN image must be a raw MODE2/2352 dump and the CUE a standard ASCII cuesheet. Open the CUE file in a text editor and check the first lines. If you can see “MODE2/2352”, it’s ok.

- **How to convert to VCD format :**

To convert your PS1 games from BIN+CUE to VCD format, you need to use the last version of [CUE2POPS](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version).

1. Put your BIN+CUE image of your PS1 game in CUE2POPS folder ;

1. Drag and drop your CUE file on CUE2POPS.EXE file ;

1. A VCD image of your game is created in CUE2POPS folder.

**Notes :**

- You can convert several games at once by running the BULK_CUE2POPS.BAT. BULK_CUE2POPS.BAT must be placed in CUE2POPS folder, along with your PS1 game images, as BIN+CUE ;

- If your PS1 game images has several .bin file, you can merge them into a single BIN+CUE file using [CDmage Version 1.02.1 Beta 5](http://aybabtu.chez.com/cdmage1-02-1b5.zip) ;

- For multi-disc games, please read this section about how to use the [swap disc feature](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/multi-disc).

______________________________________________________________________________________________________________

## *POPS2CUE :*

**Download :** [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/apps-last-version)

This tool reverts back the conversion from VCD to BIN+CUE or (CUE only) files. See the screenshot for commands.

______________________________________________________________________________________________________________

[**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
