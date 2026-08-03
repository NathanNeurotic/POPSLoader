<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/cue2pops-and-toolbox-changelogs -->
<!-- primary snapshot: 20240910020532  |  5 captures, 2 distinct content version(s) -->
<!-- other distinct versions retained in _versions/cue2pops-and-toolbox-changelogs/: 20170629133415 -->
# cue2pops-and-toolbox-changelogs

# **CUE2POPS changelog :**

______________________________________________________________________________________________________________

## *CUE2POPS (stand alone versions) :*

- **[2016/11/03 – v2.3](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-97#post-917595)**

```
- Bugfix for the input file being overwritten (the issue which was reported by MonkeyBoyJoey).
- The ability to handle the .bin file from the workdir (without the full .cue file path in the command
line) was restored.
Apparently it got broken when I extracted the cue2pops function from ToolBox.exe lol.
- The output file path which is generated from the .cue file path (when you don't specify an output file
name, ie drag'n'drop) is checked before the creation of the VCD.
If for some oddball reason the output file extension is not .VCD, CUE2POPS will display an error and not
create the file.
```

- **[2016/07/23 – v2.2](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-84#post-895401)**

```
Not documented.
```

- **[2014/10/19 – v2.1b2](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-43#post-781168)**

```
Part of Toolbox v1.0.
```

- **[2013/12/27 – v2.1b1](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-23#post-719131)**

```
- Support for VCDs with high TOC.
```

- **[2013/05/16 – v2.0](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-10#post-674126)**

```
- Fixed : dumpsize not known / daTrack_ptr set to zero when running a non-debug build.
- Fixed : False-positive Y-Pos pattern detections.
- Fixed : Incorrect Track Type in the descriptor A2.
- Blocked non-MODE2/2352 dumps.
- The NTSCpatcher console output is no longer restricted to the DEBUG build.
- Introduced the title identification system.
- Introduced NTSC Patcher exceptions (deny_vmode), for Crash Bandicoot [SCES-00344].
- Added the Y-Pos fix for PAL VMODE.
- Introduced game cheats (command "trainer"), for Crash Bandicoot NTSC J, NTSC U/C and PAL.
- Introduced game fixes (automatic), for MGS Special Missions [SLES-02136].
- Pregap correctors (gap--, gap-- and the unconditional one) were rewritten.
- The CUE2POPS version identifier is now 0x20.
```

- **[2013/04/22 – v1.2](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-5#post-667711)**

```
- Fixed : dumpsize not known / daTrack_ptr set to zero when trying to patch a single track game to NTSC.
- The CUE2POPS version identifier is now 0x02.
```

- **[2013/04/19 – v1.1](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-4#post-667149)**

```
- A bit of sanitization.
- Fixed : the INDEX 01 of TRACK 01 = 00:02:00 (mistakenly marked as 00:00:00 in the previous build, without a pregap).
- Now adds 2 seconds to all tracks unconditionally.
- Writes a CUE2POPS version identifier in the POPS header, for interaction with POPStarter Revision 10.
```

- **2013/04/06 – v1.0**

```
Initial release.
```

______________________________________________________________________________________________________________

## *[Toolbox](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/toolbox-commands) :*

**Note :** this tool is discontinued.

- **[2014/10/19 – v1.0](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-43#post-781168)**

```
Initial release
```

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
