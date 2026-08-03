<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Home -->
<!-- primary snapshot: 20160707014842  |  45 captures, 8 distinct content version(s) -->
<!-- other distinct versions retained in _versions/Home/: 20170625193955, 20170810173809, 20191108225502, 20221202231316, 20230206105020, 20240619080817, 20250419152805 -->
<!-- MERGED: this document losslessly unions every distinct snapshot of the "Home" wiki page. -->
# Home

# **Introduction to POPStarter rev13 – Official documentation**

<!-- Title evolved across snapshots:
     - 20160707: "Introduction to POPStarter rev13"
     - 20170625 / 20170810: "Introduction to POPStarter rev13 – unofficial documentation"
     - 20171027 onward (20191108, 20221202, 20230206, 20240619, 20250419): "Introduction to POPStarter rev13 – Official documentation" -->

______________________________________________________________________________________________________________

## *Disclaimer :*

POPStarter is a launcher which lets you play your PS1 games in combination with $ony’s PS1 emulator for PS2 (known as “POPS” or “SLBB-00001”). Unlike the previous POPStarter versions and the proofs of concept, POPStarter r13 does NOT contain the emulator itself or libraries that belong to $ony. It is safe to publish in forums/sites that don’t tolerate warez stuff, as long as it’s not repacked with the decrypted emulator files or things like a PS BIOS.

POPStarter is available for free download. If you spent an outrageous amount of money in ordering a HDD that contains preinstalled games and POPStarter, YOU HAVE BEEN ROBBED. Never purchase a physical copy of POPStarter when the “seller” wants more $$$ than the media price and the shipping fees.

______________________________________________________________________________________________________________

## *Downloads :*

POPStarter releases evolved across snapshots. The most recent / final release is listed first; older releases are preserved below for the historical record.

### Final release (latest snapshots: 20191108, 20221202, 20230206, 20240619, 20250419)

- **FINAL RELEASE :** **[POPStarter Revision 13 Beta 2019/06/05](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter_r13_Beta_20190605.zip)**

```
- Compiled with jan 14 2019 USB drivers.
- One (or more) non-working command was fixed too.
I vaguely remember that $IGR5 was not working, and was fixed in this last build.
- This is the POPStarter version everyone should use, 2019/06/05. This is the last beta.
```

### Earlier final release (snapshot: 20171027 / 20170810-era "Official documentation")

- **FINAL RELEASE :** **[POPStarter Revision 13 RIP 06](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter_r13_RIP_06.zip)**

```
- Code cleanup
- USBD and USBHDFSD drivers reverted to builds from WIP 02
Since the drivers from prototype 2 reduced performances in BOTH POPStarter and POPS.
- Bugfixed : POPStarter wasn't loading MODULE_#.IRX.
Massive thanks to ShaolinAssassin for helping me to find what was broken.
- POPStarter now accepts PS2CD and PS2CDDA disc types.
In other words, you can now perform the disc swap trick with a pressed PS2 CDROM, in uLE or Swap Magic for example.
Your original disc (PS1/PS2) track 1 (data track) must have an equal or bigger TOC than the track 1 of your backup.
- Automated $COMPATIBILITY_0x05 for Resident Evil SLES-00200/SLES-00227/SLES-00228 as requested.
```

### Earlier beta release bundle (snapshots: 20170625, 20170810)

- **LATEST BETA VERSION BUNDLE :** [POPStarter Revision 13, WIP 06, OBT 17](http://aybabtu.chez.com/kHn/SOFTWARES/POPStarter_r13_WIP_06_OBT_20170128.zip)

*Changelog [Rev 13, WIP 06, OBT 17]*

```

- Added support for the HDD-OSD 1.00J pfs launch argument.

```

### Oldest releases (snapshot: 20160707)

- **LATEST STABLE VERSION :** [POPStarter Revision 13, WIP 05](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter%20r13%20WIP%2005.zip)

- **LATEST BETA VERSION :** [POPStarter Revision 13, WIP 06, OBT 13](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter_r13_WIP_06_OBT_13_20151207.zip)

______________________________________________________________________________________________________________

## *Official Thread :*

The official discussion thread moved hosts over time as forums went offline. All known thread URLs are preserved below.

- **(latest snapshots: 20191108 onward)** [PS2] POPS stuff & POPStarter @[PSX-Place](https://www.psx-place.com/threads/popstarter-beta-from-2019-06-05.19139/)

- **(snapshots: 20171027 "Official documentation")** [PS2] POPS stuff & POPStarter @[ASSEMblergames](https://assemblergames.com/threads/ps2-pops-stuff.45347/)

- **(snapshot: 20170810)** [PS2] POPS stuff… @[ASSEMblergames](https://assemblergames.com/threads/ps2-pops-stuff.45347/)

- **(snapshots: 20160707, 20170625)** [PS2] POPS stuff… @[ASSEMblergames](http://assemblergames.com/l/threads/ps2-pops-stuff.45347/)

______________________________________________________________________________________________________________

## *Compatibility Lists :*

Compatibility-list sources evolved substantially. All distinct lists, forms, and table formats from every snapshot are unioned below.

### ElOtroLado Compatibility List (latest — snapshots: 20221202, 20230206, 20240619, 20250419)

The community-maintained ElOtroLado list became the active source in later snapshots. Status note across snapshots: "[UPDATED – 20/01/2023]" (20221202) → "[UPDATED – 03/04/2023]" (20230206) → "[Updated regularly]" (20240619, 20250419).

| **Device** | **Compatibility list** | **Submit reports** |
| --- | --- | --- |
| **Internal HDD, USB & SMB** | [here](http://elpatas.epizy.com/pops/pops0-9.html?i=2) | [here](https://www.elotrolado.net/hilo_ho-pops-emulador-de-psx-para-ps2_1874054) |

(Older 20221202 snapshot listed this same ElOtroLado list with only the **Compatibility list** column — no submit-reports link yet — under the heading "ElOtroLado Compatibility List : [UPDATED – 20/01/2023]".)

### Official Compatibility Lists (table format — snapshots: 20171027, 20191108, 20221202, 20230206)

Marked **[OBSOLETE & DEATH]** in the 20221202 and 20230206 snapshots (these still carried the official Google Docs lists alongside the newer ElOtroLado list). The 20240619 and 20250419 snapshots dropped the official lists entirely in favor of ElOtroLado.

| **Device** | **Compatibility list** | **The form for submitting reports** |
| --- | --- | --- |
| **Internal HDD** | [here](https://docs.google.com/spreadsheet/ccc?key=0AkthiKwj1VJMdFIzb3NuOWU2eWZqUDNwVl9uTzFPTGc#gid=0) | [here](https://docs.google.com/forms/d/17fb0I0GxnPpIuCvayFgFhd8MlozcBqR42kdzuOA5b1I/viewform) |
| **USB Device** | [here](https://docs.google.com/spreadsheet/ccc?key=0AkthiKwj1VJMdGJyVDdyRXBQR0RsOTNrM3hvaFdacmc#gid=0) | [here](https://docs.google.com/forms/d/10oPoxZvdtiO3YOe9kX_isgCkJMizCD_nvcf6TH4Xvck/viewform) |
| **SMB** | [here](https://docs.google.com/spreadsheets/d/1LoLl_YVY2qlJN6F3Ubwd0AvqkeK0tbHqrIEjBiGmDpQ/edit#gid=0) | [here](https://docs.google.com/forms/d/1zimkx1nufqgF808EyoDqC9_USV2FqSQKlka678wo67w/viewform) |

### Official compatibility lists (bullet format — snapshots: 20170625, 20170810 "unofficial documentation")

The same official Google Docs lists/forms appeared earlier in a bullet layout (note: the SMB compatibility-list URL in these snapshots had no `/edit#gid=0` suffix):

- **[Internal HDD]**

  - [Compatibility list](https://docs.google.com/spreadsheet/ccc?key=0AkthiKwj1VJMdFIzb3NuOWU2eWZqUDNwVl9uTzFPTGc#gid=0)
  - [The form for submitting reports](https://docs.google.com/forms/d/17fb0I0GxnPpIuCvayFgFhd8MlozcBqR42kdzuOA5b1I/viewform)

- **[USB Device]**

  - [Compatibility list](https://docs.google.com/spreadsheet/ccc?key=0AkthiKwj1VJMdGJyVDdyRXBQR0RsOTNrM3hvaFdacmc#gid=0)
  - [The form for submitting reports](https://docs.google.com/forms/d/10oPoxZvdtiO3YOe9kX_isgCkJMizCD_nvcf6TH4Xvck/viewform)

- **[SMB]**

  - [Compatibility list](https://docs.google.com/spreadsheets/d/1LoLl_YVY2qlJN6F3Ubwd0AvqkeK0tbHqrIEjBiGmDpQ)
  - [The form for submitting reports](https://docs.google.com/forms/d/1zimkx1nufqgF808EyoDqC9_USV2FqSQKlka678wo67w/viewform)

______________________________________________________________________________________________________________

## *Features :*

This is the union of all feature bullets across every snapshot. Snapshot notes are added inline where wording or presence differed.

- [PSX DVR](https://en.wikipedia.org/wiki/PSX_%28video_game_console%29) support

- CD, HDD, USB & SMB support *(older 20160707 / 20170625 / 20170810 snapshots listed this as "HDD, USB & SMB support" — without CD; "CD" was added from the 20171027 "Official documentation" snapshot onward)*

- High compatibility rate (around 75%/80%) *(only in 20160707; written "around 75%-80%" in 20170625 / 20170810; dropped from later snapshots)*

- CDDA tracks support

- VMC support

- Embedded cheat engine *(earliest 20160707 snapshot called this "Cheat Engine")*

- In-Game-Reset support *(earliest 20160707 snapshot called this "In Game-Reset")*

- In-Game Hotkeys *(earliest 20160707 snapshot called this "Hotkeys"; not present in the 20170625 / 20170810 snapshots)*

- Automatic PAL patcher for PAL games *(earliest 20160707 snapshot called this "Automatic PAL patcher")*

- 480p support (NOT reliable ATM) *(added from the 20170625 snapshot onward; not in 20160707)*

- GTE widescreen hack *(added from the 20171027 "Official documentation" snapshot onward)*

- Multi-disc support *(added from the 20170625 snapshot onward; not in 20160707)*

- Analog and vibration support *(added from the 20170625 snapshot onward; not in 20160707)*

- BIOS & OSD handlers *(present in 20160707, 20170625, 20170810; dropped from the 20171027 "Official documentation" snapshot onward)*

______________________________________________________________________________________________________________

## *Quickstart guides :*

*(Heading dated across snapshots: untitled "Quickstart guides :" in 20170625/20170810; "Quickstart guides (updated ~ 2017/10/27) :" in the 20171027 snapshot; "Quickstart guides (updated ~ 2020/02/09) :" in 20191108, 20221202, 20230206, 20240619, 20250419.)*

Since this documentation is growing – a lot – as POPStarter is developped, I felt that new users could be over either too bored to read the whole documentation or overwhelmed by too much informations at the same time. So I wrote 3 quickstart guides, whose explain how to set-up POPStarter quickly.

**UPDATE 10-01-2017 :** *(present in the 20170625 / 20170810 "unofficial documentation" snapshots)*

I’ve been told by krHACKen that the last POPStarter beta (**Revision 13, WIP 06, OBT 16**) can be considered stable enough to be used as daily gaming version. So I updated the quickstart guides accordingly, and created the SMB guide.

*(Later snapshots replaced that UPDATE note with a "which version the packs bundle" line:)*

- "These packs include now Rev 13 RIP 06 as POPStarter version." *(20171027 snapshot)*
- "These packs include now Rev 13 Beta 2019/06/05 as POPStarter version." *(20191108, 20221202, 20230206, 20240619, 20250419 snapshots)*

The three quickstart guides:

- **[Quickstart guide for Internal HDD](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-hdd)**

- **[Quickstart guide for USB Device Storage Type](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-usb)**

- **[Quickstart guide for SMB](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-smb)**

______________________________________________________________________________________________________________

## *Announcement :* *(snapshots: 20171027 onward)*

POPStarter project is [officially abandonned by krHACKen](https://www.metagames-eu.com/forums/playstation-2/popstarter-revision-13-sorties-et-developpements-36-134569.html#post1776252).

*(The "Last build" line differs by snapshot:)*
- **(20171027 snapshot)** Last build – [Rev 13 RIP 06](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter_r13_RIP_06.zip) – was released on 2017/10/20.
- **(20191108 onward)** Last build – [Rev 13 Beta 2019/06/05](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/POPStarter_r13_Beta_20190605.zip) – was released on 2019/06/05.

POPStarter src code is unreleased. Some stuff you need to know about it [here](https://assemblergames.com/threads/ps2-pops-stuff-popstarter.45347/page-112#post-953611).

Thanks anyone who contributed, supported and helped this project.

*(Signature line differs by snapshot: "~shaolinassassin, 2017/10/27" in the 20171027 snapshot; "~shaolinassassin, 2020/02/09" in 20191108, 20221202, 20230206, 20240619, 20250419.)*

~shaolinassassin, 2020/02/09

______________________________________________________________________________________________________________

# **[>>  ENTER WIKI  <<](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)** *(present from the 20170625 snapshot onward)*

______________________________________________________________________________________________________________

## *Wiki Table of content :* *(present only in the earliest snapshot, 20160707; replaced by the "ENTER WIKI" link in all later snapshots — preserved here in full because it enumerates every sub-page of the wiki)*

[**0. News**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/News)

[**1.  Convert your PS1 games to VCD format**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/VCD)

- [VCD creation](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/VCD)

- [Multi-disc games](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/VCD)

- [Toolbox commands](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Toolbox%20commands)

[**2.  POPStarter for internal HDD**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/HDD%20mode)

[**3.  POPStarter for USB device storage type**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/USB%20mode)

[**4.  POPStarter for SMB**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/SMB%20mode)

[**5.  Game Compatibility**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Game%20Compatibility)

- [Compatibility rates](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Game%20Compatibility)

- [Compatibility Lists and Forms](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Game%20Compatibility)

- [Compatibility Modes](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Game%20Compatibility)

- [Game fixes](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Game%20Compatibility)

- [Automated fixes](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Game%20Compatibility)

[**6.  Features and settings**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Features)

- [General note](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Features)

- [Virtual Memory Cards](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/VMC)

- [Hotkeys](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Hotkeys)

- [Cheat Engine](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Cheat%20Engine)

- [In-Game Reset](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/IGR)

- [BIOS & OSD Handler](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/BIOS%20OSD)

- [uLE_kHn](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/uLE_kHn)

- [Advanced Settings](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/POPStarter%20Configuration%20Table)

**7. Help**

- [POPStarter Help](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Help)

- [FAQ](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/FAQs%20)

- [Known bugs](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Known%20bugs)

**8. About POPStarter & POPS**

- [POPStarter changelog](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Changelog)

- [Toolbox/CUE2POPS changelog](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/CUE2POPS_Toolbox%20changelogs)

- [POPS’ History](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/History)

[**9. Downloads**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads)

[**10. Related stuff…**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Related%20Stuff)

- [Softwares](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Related%20Stuff)

- [Threads – POPStarter around the web](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Related%20Stuff)

- [Guides/informations :](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Guides)

.......... [EXE] [POPStarter BATCHER v0.2](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter_batcher)
…....... [HDD] [Transfer VCD files using PFSSHELL 0.2a](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Pfsshell) .
.......... [HDD] [Transfer VCD files over network using RadHostClient](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/RadHostClient) .
.......... [COMPATIBILITY] [Troubleshooting games](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Troubleshooting%20games)
…....... [VMC] [Use your PS1 MC saves with POPStarter](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/PS1%20MC%20saves%20to%20VMC)
.......... [VMC] [Use your VMC saves on a PS1 retail console](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/VMC%20to%20PS1%20MC%20)
.......... [IGR] [Make your own IGR textures](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/IGR%20textures)
…....... [SPECIAL DEVICE] [Use your [special device] with POPS](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Special%20devices)
…....... [CHEATS] [Widescreen Codes Archive](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/WS%20codes)

______________________________________________________________________________________________________________

## *Need help ?* *(present only in the earliest snapshots, 20160707 / 20170625-era; dropped once the dedicated "ENTER WIKI" entry point was added)*

Ask over at [ASSEMblergames](http://assemblergames.com/l/threads/ps2-pops-stuff.45347/) or at [psx-scene](http://psx-scene.com/forums/f19/popstarter-wiki-155496/).

______________________________________________________________________________________________________________
*Original documentation : krHACKen – updated by ShaolinAssassin*
