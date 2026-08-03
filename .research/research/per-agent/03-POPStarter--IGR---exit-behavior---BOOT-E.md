# Research agent 3: POPStarter: IGR + exit behavior + BOOT.ELF chain + multi-disc / lid hotkeys

## Summary
Fully verified against the PRIMARY source: the CHANGES.TXT shipped inside the canonical 2019-06-05 r13 Beta package (downloaded from archive.org). Confirmed verbatim: (1) the mc0:/BOOT/BOOT.ELF -> mc1:/BOOT/BOOT.ELF -> PS2 Browser/OSDSYS exit chain was added in the 2015/12/07 WIP 06 Beta 13, wired into BOTH the POPS in-game-reset path AND POPStarter's quit-on-failure code; if POPS itself can't init, the launcher is NOT invoked and you drop to OSD. (2) The $IGR0..$IGR5 / $NOIGR CHEATS.TXT commands and their EXACT button combos -- note the canonical changelog assigns $IGR5 = Hold L1+L2+R1+R2+Start+Select to terminate POPS (the OPL-style macro), and $IGR5 was specifically fixed in the final 2019/06/05 build. The $IGR commands were integrated as CHEATS.TXT text in the 2016/11/20 WIP 06 Beta 16 (NOT Beta 13); before that they existed only as standalone binary TROJAN_#.BIN / PATCH_0.BIN patch files. (3) Multi-disc DISCS.TXT + lid hotkeys (Select+L2+R2 + Triangle/Up/Right/Down/Left/Square) landed in the 2016/09/18 WIP 06 Beta 15. (4) There is NO documented BOOT.ELF path override -- a user (Jay-Jay) explicitly asked krHACKen for one on 2016-11-28 and it was never delivered; the only escape routes are replace BOOT.ELF, $NOIGR, $IGR5, or the special 2020-03-21 PATCH_9.BIN that disables POPStarter's bugged ELF loader so IGR falls back to OSDSYS/FMCB -> OPL. The 2020 IGR-fix PATCH_9.BIN is a DIFFERENT file from the stock PAL-patcher-disable PATCH_9.BIN (same name, both 188-ish bytes but different MD5/role). TROJAN files are POPStarter's name for per-game/global binary patch blobs validated by a number embedded in their header that must match the filename number.

## Prose
PROVENANCE NOTE FOR THE SITE: The single most authoritative artifact for this entire topic is CHANGES.TXT bundled inside POPStarter_r13_Beta_20190605.zip (archive.org item popstarter-r-13-beta-20190605). It is krHACKen's own reverse-chronological changelog from the 2019/06/05 final back to WIP 01, and every IGR/BOOT.ELF/multi-disc claim above is quotable from it line-for-line. For the site, host that CHANGES.TXT verbatim and deep-link each row to its line. The PS2-HOME tutorial threads (Jay-Jay) are the best secondary/operational sources and are only reachable through the Wayback Machine (the live ps2-home.com returns HTTP 403 to automated fetchers and the older ASSEMblergames/Bitbucket wiki is dead) -- always cite the dated web.archive.org snapshot, not the live URL.\n\nTIMELINE (verified): 2014 (WIP 02, 2014/08/22) IGR skin + IRX loaders default-on in the config table, and the IGR behaviour modifiers ship as standalone TROJAN_#.BIN files in the bundle. 2015/12/07 (WIP 06 Beta 13) adds the mc0->mc1->Browser BOOT.ELF launcher to both the POPS IGR path and POPStarter's quit-on-failure code, and removes the old function skipper (config offset $412) and ps2host/napLink launchers. This Beta-13 change is precisely what BROKE the old 'hold-the-button-to-reach-OPL' trick (Jay-Jay's 2016 tutorial was marked obsolete because of it). 2016/09/18 (Beta 15) adds full CD-lid emulation + DISCS.TXT multi-disc with the Select+L2+R2+arrow hotkeys. 2016/11/20 (Beta 16) integrates the IGR modifiers as $IGR0..$IGR5/$NOIGR CHEATS.TXT text commands (alongside $D2LS) and adds the untested Select+L2+R2+X soft-reset. 2019/06/05 (r13 Beta, the canonical build) fixes the previously-broken $IGR5. Separately, on 2020/03/21 krHACKen released the special PATCH_9.BIN that disables the bugged ELF loader, restoring an IGR path to OPL via OSDSYS/FMCB.\n\nPRACTICAL EXIT RECIPES: (1) Cleanest 'return to my launcher' = put your launcher at mc0:/BOOT/BOOT.ELF (or mc1:); IGR-quit lands there. (2) 'Return to OPL' on a setup without a usable BOOT.ELF = drop the 2020 PATCH_9.BIN in the POPS folder, then use FreeMcBoot Configurator to repoint the OSDSYS button action to mc#:/OPL/OPNPS2LD.ELF and save SYS-CONF/FREEMCB.CNF; in-game L1+SELECT+START -> YES -> hold the button until OPL boots. (3) 'Just kill POPS instantly, no menu' = $IGR5 in CHEATS.TXT (or drop TROJAN_5.BIN) -> hold L1+L2+R1+R2+Start+Select. (4) 'Disable IGR entirely' = $NOIGR (or PATCH_0.BIN). Remember a single CHEATS.TXT in the POPS root can override per-game ones, and only ONE IGR behavior is active at a time.

## Entries (15)

```json
[
  {
    "name": "BOOT.ELF exit chain: mc0:/BOOT/BOOT.ELF -> mc1:/BOOT/BOOT.ELF -> Browser/OSDSYS",
    "effect": "On in-game reset (IGR quit) AND on POPStarter quit-on-failure, the launcher looks for mc0:/BOOT/BOOT.ELF, then mc1:/BOOT/BOOT.ELF; if not found/invalid it exits to the PS2 Browser (OSDSYS, which then runs FMCB/FHDB if installed on a compatible console). Added 2015/12/07 WIP 06 Beta 13.",
    "scope": "Global POPStarter behavior, all storage modes (USB/HDD/SMB); since 2015/12/07 Beta 13 through the 2019/06/05 r13 final. mc0 is tried before mc1.",
    "conflicts": "If POPS itself cannot init (can't load modules / can't open the VCD) the BOOT.ELF launcher is NOT invoked and you are kicked straight to the OSD. No way to point the chain at MASS/HDD paths -- BOOT.ELF must physically live on a memory card (mc0/mc1).",
    "provenance": "PRIMARY: CHANGES.TXT inside POPStarter_r13_Beta_20190605.zip, lines 388-391 (downloaded from https://archive.org/details/popstarter-r-13-beta-20190605). Verbatim re-quoted by Jay-Jay on PS2-HOME: https://web.archive.org/web/20230619145423/https://www.ps2-home.com/forum/viewtopic.php?t=127 (lines 149-150).",
    "confidence": "primary",
    "example": "Put your launcher (uLaunchELF, FMCB menu, etc.) at mc0:/BOOT/BOOT.ELF so IGR-quit returns there instead of the bare Browser."
  },
  {
    "name": "No documented BOOT.ELF path override",
    "effect": "There is NO config/command to redirect the exit chain away from mc0/mc1:/BOOT/BOOT.ELF. The path is hard-coded.",
    "scope": "All r13 builds through 2019/06/05.",
    "conflicts": "A user requested an override and it was never implemented. Only escapes: (a) replace BOOT.ELF with your launcher, (b) $NOIGR / $IGR5 to suppress the menu, (c) the 2020 PATCH_9.BIN that disables the ELF loader so it falls back to OSDSYS.",
    "provenance": "PRIMARY/NEAR-PRIMARY: Jay-Jay, 2016-11-28: 'Hopefully @krHACKen can figure out way that we can change the path to something else instead of BOOT.ELF, since for me, BOOT.ELF is uLaunch.' -- https://web.archive.org/web/20230619145423/https://www.ps2-home.com/forum/viewtopic.php?t=127 (line 152). No override appears anywhere in the canonical CHANGES.TXT.",
    "confidence": "near-primary",
    "example": "Want IGR to land in uLaunchELF? You must name uLaunchELF itself BOOT.ELF and place it at mc0:/BOOT/BOOT.ELF."
  },
  {
    "name": "Default IGR trigger: L1 + SELECT + START",
    "effect": "With no modifier set, the default in-game-reset combo opens POPStarter's IGR menu (an Asian-language reset/return prompt). The IGR 'skin' is enabled by default in the config table.",
    "scope": "All r13 betas; menu text is Japanese unless a translated IGR texture (IGR skin) is installed.",
    "conflicts": "Overridden by any $IGR#/$NOIGR command or a TROJAN_#.BIN/PATCH_0.BIN patch in the game/POPS folder.",
    "provenance": "PRIMARY: CHANGES.TXT line 702 'IGR skin and IRX loaders are now enabled by default (in the configuration table)' (2014/08/22 WIP 02). NEAR-PRIMARY combo + 'Asian language' note: Jay-Jay https://web.archive.org/web/20230619145423/https://www.ps2-home.com/forum/viewtopic.php?t=127 (lines 78-80, 123-125).",
    "confidence": "primary",
    "example": "During a PS1 game hold L1+SELECT+START -> IGR menu -> select YES -> press a button to confirm exit."
  },
  {
    "name": "$IGR0",
    "effect": "Hold L1+L2+R1+R2+X+Down to OPEN the IGR menu.",
    "scope": "CHEATS.TXT command, integrated 2016/11/20 WIP 06 Beta 16. Place in POPS/CHEATS.TXT (global) or POPS/GAME/CHEATS.TXT (per-game). Equivalent standalone file: TROJAN_0.BIN.",
    "conflicts": "Mutually exclusive with other $IGR#/$NOIGR (one IGR behavior at a time). A global CHEATS.TXT can override per-game.",
    "provenance": "PRIMARY: CHANGES.TXT line 303 '$IGR0 [Hold L1+L2+R1+R2+X+Down to open the IGR menu]'.",
    "confidence": "primary",
    "example": "$IGR0"
  },
  {
    "name": "$IGR1",
    "effect": "Hold Start+Select to OPEN the IGR menu.",
    "scope": "CHEATS.TXT command (Beta 16, 2016/11/20). Standalone equivalent: TROJAN_1.BIN.",
    "conflicts": "Mutually exclusive with other $IGR#/$NOIGR.",
    "provenance": "PRIMARY: CHANGES.TXT line 304 '$IGR1 [Hold Start+Select to open the IGR menu]'.",
    "confidence": "primary",
    "example": "$IGR1"
  },
  {
    "name": "$IGR2",
    "effect": "Hold L1+L2+R1+R2+Start+Select to OPEN the IGR menu.",
    "scope": "CHEATS.TXT command (Beta 16, 2016/11/20). Standalone equivalent: TROJAN_2.BIN.",
    "conflicts": "Mutually exclusive with other $IGR#/$NOIGR.",
    "provenance": "PRIMARY: CHANGES.TXT line 305 '$IGR2 [Hold L1+L2+R1+R2+Start+Select to open the IGR menu]'.",
    "confidence": "primary",
    "example": "$IGR2"
  },
  {
    "name": "$IGR3",
    "effect": "Hold L1+L2+R1+R2+X+Down to TERMINATE POPS directly (no IGR menu).",
    "scope": "CHEATS.TXT command (Beta 16, 2016/11/20). Standalone equivalent: TROJAN_3.BIN.",
    "conflicts": "Mutually exclusive with other $IGR#/$NOIGR.",
    "provenance": "PRIMARY: CHANGES.TXT line 306 '$IGR3 [Hold L1+L2+R1+R2+X+Down to terminate POPS (no IGR menu)]'.",
    "confidence": "primary",
    "example": "$IGR3"
  },
  {
    "name": "$IGR4",
    "effect": "Hold Start+Select to TERMINATE POPS directly (no IGR menu).",
    "scope": "CHEATS.TXT command (Beta 16, 2016/11/20). Standalone equivalent: TROJAN_4.BIN.",
    "conflicts": "Mutually exclusive with other $IGR#/$NOIGR. WARNING: the Portuguese PDFCoffee/Scribd manual mistranslates the order, mapping this combo to '$IGR5' -- the canonical CHANGES.TXT order above is authoritative.",
    "provenance": "PRIMARY: CHANGES.TXT line 307 '$IGR4 [Hold Start+Select to terminate POPS (no IGR menu)]'.",
    "confidence": "primary",
    "example": "$IGR4"
  },
  {
    "name": "$IGR5",
    "effect": "Hold L1+L2+R1+R2+Start+Select to TERMINATE POPS directly (no IGR menu). This is the OPL-style no-popup exit macro. $IGR5 was broken in earlier r13 builds and FIXED in the final 2019/06/05 build.",
    "scope": "CHEATS.TXT command (Beta 16, 2016/11/20; fixed 2019/06/05). Standalone equivalent: TROJAN_5.BIN.",
    "conflicts": "Mutually exclusive with other $IGR#/$NOIGR. Combo matches OPL's own IGR exit macro (L1+L2+R1+R2+START+SELECT).",
    "provenance": "PRIMARY: CHANGES.TXT line 308 '$IGR5 [Hold L1+L2+R1+R2+Start+Select to terminate POPS (no IGR menu)]' + line 9 'I vaguely remember that $IGR5 was not working, and was fixed in this last build.' OPL macro corroboration: https://github.com/ps2homebrew/Open-PS2-Loader/discussions/543",
    "confidence": "primary",
    "example": "$IGR5"
  },
  {
    "name": "$NOIGR",
    "effect": "Disables the IGR menu entirely (no in-game reset trigger).",
    "scope": "CHEATS.TXT command. Standalone equivalent: PATCH_0.BIN.",
    "conflicts": "Mutually exclusive with any $IGR# trigger. Disabling IGR means the only exit is whatever the game itself or a hard reset provides.",
    "provenance": "PRIMARY: CHANGES.TXT line 309 '$NOIGR [Disables the IGR menu]'. PATCH_0.BIN equivalent: https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909 (PATCH_0.BIN 'Disables the IGR menu').",
    "confidence": "primary",
    "example": "$NOIGR"
  },
  {
    "name": "TROJAN_#.BIN / PATCH_#.BIN (binary IGR patch files)",
    "effect": "Standalone binary patch blobs that change IGR behavior WITHOUT a CHEATS.TXT: TROJAN_0..5 == $IGR0..$IGR5, PATCH_0 == $NOIGR, TROJAN_9 == 'No 2nd Pad in IGR', TROJAN_7 == cumulative game-fix bundle (r6, fixes as of 2020/05/20). 'TROJAN' is POPStarter's NAME for a patch file, NOT malware.",
    "scope": "Copy to the game VMC folder (per-game) or to the POPS folder (all games). Pre-date the $IGR CHEATS.TXT commands (the modifiers shipped in the release bundle from 2014; integrated as text commands in Beta 16 2016/11/20).",
    "conflicts": "POPStarter REFUSES to load a PATCH/TROJAN file if the number in the filename does not match the number embedded in the file header. To reuse a slot you must hex-edit the header number to match the new filename. PATCH_9.BIN filename is overloaded (see its own row).",
    "provenance": "PRIMARY: PS2-HOME 'POPStarter In-Game-Reset (Trojans and Patches)', Jay-Jay 2016-09-27: https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909 (file table + 'POPStarter will refuse to load the PATCH/TROJAN file if the number in its filename doesn't match the number in its header'). Bundle history: CHANGES.TXT line 689.",
    "confidence": "primary",
    "example": "Copy TROJAN_5.BIN into mass0:/POPS/ to make EVERY game exit on L1+L2+R1+R2+Start+Select (same as $IGR5) without editing CHEATS.TXT. MD5s: TROJAN_0 9c431cb92e72d38dcd015d2d1840e3c5 (246B), TROJAN_1 d5551d731a0eae6745e894d8a1b823ed (248B), TROJAN_5 fb0ee2841ca3c40f2483ac4c00c4594c (260B), PATCH_0 b8d32e32d9d27c58e6558f9ad538f555 (221B), TROJAN_9 b6960e9a26034723eeea0ebcbe114334 (250B)."
  },
  {
    "name": "PATCH_9.BIN (2020 IGR-loader-disable build) -- IGR-back-to-OPL fix",
    "effect": "A special PATCH_9.BIN released 2020-03-21 disables POPStarter's bugged ELF loader (the Beta-13 BOOT.ELF launcher) so that on IGR-quit POPStarter falls back to OSDSYS/the Browser; with FMCB's button action repointed to OPNPS2LD.ELF, IGR then chains into OPL. Distinct from the stock PAL-patcher PATCH_9.BIN.",
    "scope": "Copy to the POPS folder (mass0:/POPS/, ?:/PS2SMB/POPS/, hdd0:__common/POPS/). Requires FMCB installed; configure via FreeMcBoot Configurator and save SYS-CONF/FREEMCB.CNF.",
    "conflicts": "FILENAME COLLISION: the OTHER PATCH_9.BIN (stock) instead disables POPStarter's automatic PAL patcher (equivalent to $NOPAL) -- same name, different file/MD5/purpose. Don't mix them up. IGR-back-to-OPL was impossible from Beta 13 until this 2020 file. OPL IGR paths must point to a physical MC (mc0/mc1), never MASS/HDD.",
    "provenance": "PRIMARY/NEAR-PRIMARY: PS2-HOME 'How to exit from POPStarter and return to OPL', Jay-Jay UPDATE 2020-03-21/22: https://web.archive.org/web/20230619145423/https://www.ps2-home.com/forum/viewtopic.php?t=127 (lines 76,84-118,175). Stock PAL-disable PATCH_9.BIN: https://web.archive.org/web/20240407083519/https://www.ps2-home.com/forum/viewtopic.php?t=144 (lines 231-237).",
    "confidence": "primary",
    "example": "mass0:/POPS/PATCH_9.BIN ; FMCB Configurator -> set the OSDSYS button action to mc1:/OPL/OPNPS2LD.ELF ; in-game hold L1+SELECT+START, choose YES, hold the button until OPL boots (can take up to ~1 min)."
  },
  {
    "name": "Multi-disc DISCS.TXT + lid/disc-swap hotkeys",
    "effect": "DISCS.TXT (one VCD filename per line, up to 4) plus CD lid open/close emulation enables in-game disc swapping. Hotkeys (since 2016/09/18 Beta 15): Select+L2+R2+Triangle = open lid; +Up = insert disc 1; +Right = disc 2; +Down = disc 3; +Left = disc 4; +Square = close lid.",
    "scope": "Place DISCS.TXT in the VMC folder of every disc of the game. Max 4 filenames; each filename <=89 chars; all VCDs must be in the same partition/folder. On internal HDD use IMAGE0.VCD / IMAGE1.VCD in the SAME PP. partition (POPStarter only looks for IMAGE0.VCD when booting HDD-OSD mode); same VMC is shared so no VMCDIR.TXT needed.",
    "conflicts": "Disc change cannot cross partitions (cannot unmount/mount). The earlier Beta-14-era build only exposed lid open/close (Select+L2+R2+Triangle / +Square) without the Up/Right/Down/Left disc inserts.",
    "provenance": "PRIMARY: CHANGES.TXT lines 316-372 (2016/09/18 WIP 06 Beta 15: 'CD lid open/close emulation', 'DISCS.TXT file handler', the full hotkey table and limitations). HDD IMAGE0/IMAGE1.VCD detail: https://web.archive.org/web/20240407083519/https://www.ps2-home.com/forum/viewtopic.php?t=144 (lines 295-303). Lid-only earlier hotkeys: CHEATS lines 587-588.",
    "confidence": "primary",
    "example": "DISCS.TXT for a 2-disc game on HDD:\nIMAGE0.VCD\nIMAGE1.VCD\nIn-game: Select+L2+R2+Triangle (open lid) -> Select+L2+R2+Right (disc 2) -> Select+L2+R2+Square (close lid)."
  },
  {
    "name": "Quit-on-failure uses the same BOOT.ELF chain",
    "effect": "POPStarter's quit-on-failure code (when POPStarter itself, not POPS, decides to bail) runs the SAME mc0/mc1:/BOOT/BOOT.ELF -> Browser chain as the IGR exit. Added together in Beta 13.",
    "scope": "Since 2015/12/07 Beta 13.",
    "conflicts": "Only applies when POPStarter reaches the failure path; a POPS init failure bypasses it and drops to OSD.",
    "provenance": "PRIMARY: CHANGES.TXT line 389 '...to the in-game reset function of POPS and to the quit-on-failure code of POPStarter.'",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "Untested PS1 software-reset hotkey: Select+L2+R2+X",
    "effect": "An additional, explicitly-untested PS1 software reset hotkey combo was added alongside the IGR modifier integration.",
    "scope": "Added in the same era as the $IGR commands (around Beta 16). Marked untested by the author.",
    "conflicts": "Author flagged it untested; reliability unknown. Note an older build also used Hold Select+L2+R2+X as a speed-up (FPS boost) hotkey -- combo reuse across builds.",
    "provenance": "PRIMARY: CHANGES.TXT line 310 'Added hotkeys to an untested PS1 software reset system, Select+L2+R2+X'. Speed-up reuse: CHANGES line 588 region.",
    "confidence": "primary",
    "example": ""
  }
]
```

## New findings

- The $IGR0..$IGR5 / $NOIGR CHEATS.TXT commands were integrated in the 2016/11/20 WIP 06 Beta 16 -- NOT Beta 13. Beta 13 (2015/12/07) only added the BOOT.ELF chain; the IGR modifiers existed earlier ONLY as standalone binary TROJAN/PATCH files.
- CANONICAL ORDER CORRECTION: per the shipped CHANGES.TXT, $IGR4 = Start+Select terminate and $IGR5 = L1+L2+R1+R2+Start+Select terminate. The widely-mirrored Portuguese manual swaps these two -- the manual is wrong; the base report's $IGR5 combo is right.
- $IGR5 was BROKEN in earlier r13 builds and was specifically fixed in the final 2019/06/05 build (CHANGES.TXT line 9) -- the canonical package is the only one where $IGR5 reliably works.
- TROJAN/PATCH validation rule (primary): POPStarter refuses to load a TROJAN_#.BIN/PATCH_#.BIN unless the number embedded in the file's HEADER matches the number in its FILENAME; to repurpose a slot you must hex-edit the header. This is the precise mechanism that distinguishes TROJAN/PATCH files.
- Exact 1:1 mapping recovered: TROJAN_0..5 == $IGR0..$IGR5, PATCH_0 == $NOIGR, plus TROJAN_9 = 'No 2nd Pad in IGR' and TROJAN_7 = cumulative game-fix bundle (r6, 2020/05/20). MD5 hashes and byte sizes for each captured.
- PATCH_9.BIN is genuinely TWO different files sharing a name: (a) the stock PAL-patcher-disable file (= $NOPAL behavior, documented in the t=144 wiki) and (b) the 2020-03-21 ELF-loader-disable file that fixes IGR-back-to-OPL (documented in the t=127 thread). Both confirmed from separate primary threads.
- The 'no BOOT.ELF path override' claim is now DIRECTLY evidenced, not just inferred: Jay-Jay publicly asked krHACKen for a configurable path on 2016-11-28 and it was never implemented through the final r13.
- HDD multi-disc has an extra constraint absent from the base report: both discs must share one PP. partition, the first VCD MUST be named IMAGE0.VCD (POPStarter only looks for IMAGE0.VCD in HDD-OSD boot), second IMAGE1.VCD, and they share one VMC (no VMCDIR.TXT needed).
- Quit-on-failure and IGR-quit share the identical BOOT.ELF chain; but a POPS init failure (can't load modules / open VCD) bypasses the launcher entirely and drops to OSD.
- An additional untested 'PS1 software reset' hotkey Select+L2+R2+X was added with the IGR integration (CHANGES.TXT line 310); the same combo was earlier used as a speed-up/FPS-boost hotkey, an example of combo reuse across builds.

## Gaps

- The byte-level config-table offsets that hold the DEFAULT IGR combo / IGR-skin-enable flag are not enumerated in CHANGES.TXT (only 'IGR skin enabled by default in the configuration table', line 702). The full config-table map remains lost.
- TROJAN_7.BIN ('cumulative r6, fixes as of 2020/05/20') and TROJAN_9.BIN ('No 2nd Pad in IGR') button-combo cells render as image glyphs in the archived page; their combos weren't text-extractable (TROJAN_7 is a game-fix bundle, not an IGR-combo, so likely N/A; TROJAN_9 modifies 2nd-pad behavior, not the trigger).
- The exact MD5/size of the 2020-03-21 IGR-fix PATCH_9.BIN vs the stock PAL-disable PATCH_9.BIN was not cross-diffed byte-for-byte; the t=9909 table lists a PATCH_9.BIN at 9db1e18bae92c4991e3de7e2a752558c (188B) but does not state which of the two roles that hash corresponds to.
- Whether the POPSLoader fork changes/overrides the BOOT.ELF chain was not investigated here (this topic is upstream POPStarter only).

## Sources

- primary: https://archive.org/details/popstarter-r-13-beta-20190605 (canonical 2019-06-05 r13 Beta package; CHANGES.TXT extracted and quoted throughout)
- primary: https://web.archive.org/web/20230619145423/https://www.ps2-home.com/forum/viewtopic.php?t=127 (PS2-HOME 'How to exit from POPStarter and return to OPL', Jay-Jay; 2016 obsolete note + 2020-03-21 PATCH_9.BIN IGR-to-OPL fix + verbatim Beta-13 changelog + the no-path-override request)
- primary: https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909 (PS2-HOME 'POPStarter In-Game-Reset (Trojans and Patches)', Jay-Jay 2016-09-27; TROJAN_#/PATCH_# file table, MD5s, header-number-matching rule)
- near-primary: https://web.archive.org/web/20240407083519/https://www.ps2-home.com/forum/viewtopic.php?t=144 (PS2-HOME POPStarter Guide/Wiki; stock PAL-disable PATCH_9.BIN, HDD IMAGE0/IMAGE1.VCD multi-disc)
- community: https://github.com/ps2homebrew/Open-PS2-Loader/discussions/543 (OPL 'Game Exit button combo' -- corroborates the L1+L2+R1+R2+START+SELECT OPL exit macro that POPStarter's $IGR5 mirrors; OPL IGR paths must be on MC0/MC1)
- mirror (use with caution -- translation errors): https://pdfcoffee.com/manual-popstarter-pdf-free.html and https://www.scribd.com/document/922268974/manual-popstarter (Portuguese POPStarter manual; mistranslates $IGR4/$IGR5 ordering vs the canonical CHANGES.TXT)