<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/troubleshooting-games -->
<!-- primary snapshot: 20240909123815  |  3 captures, 1 distinct content version(s) -->
# troubleshooting-games

# [COMPATIBILITY] **Troubleshooting games**

______________________________________________________________________________________________________________

You can use the Cheat Engine feature to troubleshoot problematic games.

Here is a ready-to-use [CHEATS.TXT](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/CHEATS.TXT) file with all possible combinaison of modes which can help you and save you time :

```
Single compatibility mode test
// mode 1 = help restoring the music/voices in several games
COMPATIBILITY_0×01
------------------------------------------------------------------
// mode 2 = help restoring the music/voices + not breaking the MDECoding of FMVs
COMPATIBILITY_0×02
------------------------------------------------------------------
// mode 3 = help restoring the music/voices in several games
COMPATIBILITY_0×03
------------------------------------------------------------------
// mode 4 = fixes slowdowns, flickering, and many other glitches
COMPATIBILITY_0×04
------------------------------------------------------------------
// mode 5 = made for fixing the cutscenes of the PAL Resident Evil: Director’s Cut
COMPATIBILITY_0×05
------------------------------------------------------------------
// mode 6 = un-freeze somes games at startup
COMPATIBILITY_0×06
==================================================================
Combinaison of 2 compatibility modes
// modes 1+4
COMPATIBILITY_0×01
COMPATIBILITY_0×04
------------------------------------------------------------------
// modes 1+6
COMPATIBILITY_0×01
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 2+4
COMPATIBILITY_0×02
COMPATIBILITY_0×04
------------------------------------------------------------------
// modes 2+6
COMPATIBILITY_0×02
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 3+4
COMPATIBILITY_0×03
COMPATIBILITY_0×04
------------------------------------------------------------------
// modes 3+6
COMPATIBILITY_0×03
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 4+5
COMPATIBILITY_0×04
COMPATIBILITY_0×05
------------------------------------------------------------------
// modes 4+6
COMPATIBILITY_0×04
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 6+5
COMPATIBILITY_0×06
COMPATIBILITY_0×05
==================================================================
Combinaison of 3 compatibility modes
// modes 1+4+6
COMPATIBILITY_0×01
COMPATIBILITY_0×04
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 2+4+6
COMPATIBILITY_0×02
COMPATIBILITY_0×04
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 3+4+6
COMPATIBILITY_0×03
COMPATIBILITY_0×04
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 4+5+6
COMPATIBILITY_0×04
COMPATIBILITY_0×05
COMPATIBILITY_0×06
```

- **How to use it :**

1. Copy/past all lines into a CHEATS.TXT file (or download [it](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/CHEATS.TXT) ).

2. Put that file into the game VMC folder.

3. Use uLE Text editor to active the wanted combinaison (+ $) and let the other lines unedited.

Ex : modes 3+4 enabled

```
Single compatibility mode test
// mode 1 = help restoring the music/voices in several games
COMPATIBILITY_0×01
------------------------------------------------------------------
// mode 2 = help restoring the music/voices + not breaking the MDECoding of FMVs
COMPATIBILITY_0×02
------------------------------------------------------------------
// mode 3 = help restoring the music/voices in several games
COMPATIBILITY_0×03
------------------------------------------------------------------
// mode 4 = fixes slowdowns, flickering, and many other glitches
COMPATIBILITY_0×04
------------------------------------------------------------------
// mode 5 = made for fixing the cutscenes of the PAL Resident Evil: Director’s Cut
COMPATIBILITY_0×05
------------------------------------------------------------------
// mode 6 = un-freeze somes games at startup
COMPATIBILITY_0×06
==================================================================
Combinaison of 2 compatibility modes
// modes 1+4
COMPATIBILITY_0×01
COMPATIBILITY_0×04
------------------------------------------------------------------
// modes 1+6
COMPATIBILITY_0×01
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 2+4
COMPATIBILITY_0×02
COMPATIBILITY_0×04
------------------------------------------------------------------
// modes 2+6
COMPATIBILITY_0×02
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 3+4
$COMPATIBILITY_0×03
$COMPATIBILITY_0×04
------------------------------------------------------------------
// modes 3+6
COMPATIBILITY_0×03
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 4+5
COMPATIBILITY_0×04
COMPATIBILITY_0×05
------------------------------------------------------------------
// modes 4+6
COMPATIBILITY_0×04
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 6+5
COMPATIBILITY_0×06
COMPATIBILITY_0×05
==================================================================
Combinaison of 3 compatibility modes
// modes 1+4+6
COMPATIBILITY_0×01
COMPATIBILITY_0×04
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 2+4+6
COMPATIBILITY_0×02
COMPATIBILITY_0×04
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 3+4+6
COMPATIBILITY_0×03
COMPATIBILITY_0×04
COMPATIBILITY_0×06
------------------------------------------------------------------
// modes 4+5+6
COMPATIBILITY_0×04
COMPATIBILITY_0×05
COMPATIBILITY_0×06
```

- **Tip :** start by mode 0×04.

If you find a combinaison that improves emulation, do not forget to report it on the official compatibility lists :

- [HDD](https://docs.google.com/forms/d/17fb0I0GxnPpIuCvayFgFhd8MlozcBqR42kdzuOA5b1I/viewform)

- [USB](https://docs.google.com/forms/d/10oPoxZvdtiO3YOe9kX_isgCkJMizCD_nvcf6TH4Xvck/viewform)

- [SMB](https://docs.google.com/forms/d/1zimkx1nufqgF808EyoDqC9_USV2FqSQKlka678wo67w/viewform)

______________________________________________________________________________________________________________

# [**Home**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Home)
