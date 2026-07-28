<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/debug-mode -->
<!-- primary snapshot: 20170810221908  |  15 captures, 4 distinct content version(s) -->
<!-- other distinct versions retained in _versions/debug-mode/: 20170629160859, 20191214022855, 20250420131608 -->
# debug-mode

# **Debug mode**

______________________________________________________________________________________________________________

POPStarter has an embedded debug mode. It’s ON by default in SMB mode (and it can’t be turn OFF in this mode) and it can be turn ON in HDD and USB modes. Use debug mode when something is wrong in your setup.

How to enable POPStarter debug mode :

- **Easy method :** apply [the DEBUG_AND_HALT.PPF](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/DEBUG_AND_HALT.PPF) over POPSTARTER.ELF (or POPSTARTER.KELF) using a PPF patcher (such as [PPF-O-matic](http://www.romhacking.net/utilities/356/)).

1. Launch PPF-O-Matic ;

1. Click on “Load CD Image file” (first floppy icon) ;

1. Change file type from “CD Image file” to “All files” ;

1. Browse to POPSTARTER.ELF location and select it ;

1. Click on “Load PPF file” (second floppy icon) ;

1. Browse to DEBUG_AND_HALT.PPF location and select it ;

1. Click “Apply” and you’re done. Do not forget to rename POPSTARTER.ELF before using it.

- **Advanced method :** hexedit manually POPSTARTER.ELF. See POPStarter Configuration Table [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table).

Take note of the debug message and ask/report it @[ASSEMblergames](https://assemblergames.com/threads/ps2-pops-stuff.45347/) if you need more help.

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
