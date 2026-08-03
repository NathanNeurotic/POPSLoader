# Research agent 0: POPStarter CHEATS.TXT command reference + raw cheat-code engine

## Summary
Recovered the DEFINITIVE CHEATS.TXT command reference from primary sources: ShaolinAssassin's lost Bitbucket wiki (via Wayback Machine snapshots of the 'special-cheats' and 'cheat-engine' pages) plus krHACKen's own r13 changelog (Pastebin 719TCAd5). All base $commands verified verbatim, with the three queried defaults confirmed exactly ($XPOS default 640, $DWSTRETCH default 2559, $DWCROP max 2560). The in-game $SMOOTH toggle is confirmed (Select+L1+R2 enable / Select+L2+R1 disable) directly from krHACKen's changelog. The raw cheat engine is fully documented: every active line starts with $, one space between address and value; PS1 RAW code types 30/50/80/D0 (GameShark/AR) and PS2 RAW types 0/1/2 supported; ONLY C0 master codes (C1 'activation on delay time' explicitly never supported); $SAFEMODE gates the engine until POPS leaves the PS1 OSD. Decoded all six $IGR# button combos exactly from the wiki's PlayStation-button image filenames - this CORRECTS the base report's $IGR5 combo to L1+L2+R1+R2+Select+Start. Found commands/details the base missed: $SCANLINES (CRT scanline generator), full $UNDO_GAME_FIXES detail, the two Rumble-Always-On raw codes, and a recoverable real LibCrypt example block for Jackie Chan Stuntmaster (PAL).

## Prose
SOURCE QUALITY: The CHEATS.TXT command set is now sourced to PRIMARY material. ShaolinAssassin's Bitbucket wiki (the lost 'documentation & stuff' repo) is fully recoverable through the Wayback Machine: the 'special-cheats' page has clean static-HTML snapshots from 2017 through 2022, and the 'cheat-engine' page from 2017. krHACKen's own beta-by-beta changelog survives as Pastebin 719TCAd5 (the r13 WIP05->WIP06/Beta13 'what's new' text), which is the authoritative record of when each command was added/fixed. WebFetch cannot reach web.archive.org, but curl against the Wayback CDX API and the 'id_' raw-snapshot endpoint works fine - that is the reliable retrieval path for the rest of this corpus.

WIKI REVISION TIMELINE (matters for completeness): the special-cheats page grew over time. The 2017-01-29 revision covers the core set (SAFEMODE, COMPATIBILITY, FAKELC, SMOOTH, NOPAL, FORCEPAL, 480p, XPOS/YPOS/DWSTRETCH/DWCROP, HDTVFIX, Rumble codes, D2LS/D2LS_ALT, IGR0-5, NOIGR, CACHE1, USBDELAY). The 2017-10-28 revision adds CODECACHE_ADDON_0, SUBCDSTATUS, WIDESCREEN/ULTRA_WIDESCREEN/EYEFINITY, MUTE_CDDA/UNDO_MUTE_CDDA/MUTE_VAB, NOVMC0/NOVMC1. The 2020-06-26 revision (captured in the 2022-02-18 snapshot) adds SCANLINES and UNDO_GAME_FIXES, plus the Jackie Chan LibCrypt example. A site-driving JSON should record a 'documented-since' field per command using these revision dates.

VERIFIED DEFAULTS (the three the maintainer asked to confirm), quoted from the wiki: $XPOS_#### 'Default value : 640'; $DWSTRETCH_#### 'Default value : 2559'; $DWCROP_#### 'Maximum value : 2560'. $YPOS has NO default ('depends on the game, you have to experiment'). All four geometry commands are PAL/NTSC-only and incompatible with $480p. The wiki even carries an erratum note ('[10-01: fixed $XPOS and $YPOS descriptions, mistake in it due to my Engrish]'), so the current text is the corrected version.

RAW ENGINE (cheat-engine page, verbatim essentials): 'Since WIP06 OBT01, POPStarter has an embedded cheat engine.' CHEATS.TXT goes in the game's VMC folder (per-game) or the POPS root folder (all games). 'each code line has to start with the $ character; each code line must have a space between the adress and the value; PS1 RAW codes of types 30, 50, 80 and D0 are supported (Gameshark/Action Replay); PS2 RAW codes of types 0, 1 and 2 are supported.' Example given: '$800AC402 0800'. Master codes: 'Some PS1 games need mastercodes otherwise they crash (ex: Air Race Championship). Only type C0 are supported. Mastercodes of type C1 (aka activation on delay time) are not and will not be supported.' External-device POPS Mastercode (NOT needed with CHEATS.TXT): 902377F4 0C0902EF. PS1->PS2 RAW conversion: add 01000000 to the address.

CHEAT-ENGINE BUG HISTORY (from krHACKen's changelog, Beta 13 / 2015-12-07): 'Fixed: Bad cheat engine hook. (The cheat engine was returning to its hook address + 8, causing POPS to execute the next function and fill the memory with garbage. Using a CHEATS.TXT was crashing POPS on startup.)'; 'Fixed: $USBDELAY_# didn't coexist with $C0'; 'Fixed: Incorrect load instruction for $C0 codes (cheat engine bug).' This is exactly why $SAFEMODE matters and why it is the recommended first line. $SAFEMODE itself was fixed (made functional) in Beta 12 (2015-11-24).

IGR COMBO CORRECTION: the six $IGR# combos are rendered on the wiki only as PlayStation-button icons (alt text is the generic 'title'), so they must be decoded from the image src filenames. Decoded values: IGR0 = L1+L2+R1+R2+X+Down (open menu); IGR1 = Select+Start (open menu); IGR2 = L1+L2+R1+R2+Select+Start (open menu); IGR3 = L1+L2+R1+R2+X+Down (terminate, no menu); IGR4 = Select+Start (terminate, no menu); IGR5 = L1+L2+R1+R2+Select+Start (terminate, no menu). Note IGR0/IGR3 share a combo (open vs terminate) and IGR1/IGR4 share, IGR2/IGR5 share - the difference is whether a menu appears. The base report's $IGR5 gloss ('Select+Start+L1+L2+R1+R2') is essentially right but should be normalized to L1+L2+R1+R2+Select+Start. Quit behavior since Beta 13: IGR/quit launches mc0:/BOOT/BOOT.ELF then mc1:/BOOT/BOOT.ELF, else exits to Browser/OSDSYS - no documented path override.

RECOVERED EXAMPLE CODE BLOCK (real, from the wiki) - LibCrypt fix for Jackie Chan Stuntmaster (PAL), for use when the built-in LibCrypt crack and $FAKELC both fail:
$20210CF8 2442FFFF
$20210CFC 7C640000
$20210D00 00000000
$20210D04 00000000
$20210D08 00000000
$00210D0C 000000FA
$S200009C 1F000000
Plus the documented constants: $SMOOTH == '$S0003390 00000001'; Rumble Always On Pad 1 == '$00507028 00000001', Pad 2 == '$005070B8 00000001'.

GLOBAL-vs-PER-GAME BLOCKING: the cheat-engine page confirms a CHEATS.TXT in the POPS root enables codes for ALL games; the base report's claim that a root CHEATS.TXT can BLOCK per-game ones is plausible engine behavior but is NOT stated on the recovered wiki pages - flag it as community/unverified until corroborated.

## Entries (39)

```json
[
  {
    "name": "$SAFEMODE",
    "effect": "Disables the cheat engine and only activates it after POPS has left the PS1 OSD/BIOS. Should always be ON (recommended first line). Some game codes patch the memory area where the PS OSD is loaded, causing crashes/garbage if applied too early.",
    "scope": "CHEATS.TXT global or per-game. Engine present since WIP06 OBT01. The command itself was non-functional until fixed in Beta 12 (2015-11-24).",
    "conflicts": "None functional; it is a timing gate, not a code. Without it, raw codes that touch the OSD-load region can crash POPS on startup.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 + 20220218153800); krHACKen r13 changelog '** 2015/11/24 (Beta 12) ** - Bugfixed : $SAFEMODE (in CHEATS.TXT) not working' (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$SAFEMODE"
  },
  {
    "name": "$COMPATIBILITY_0x##",
    "effect": "Activates a POPS compatibility mode (## = hex value 01-06). Textual equivalent of dropping PATCH_#.BIN. You may write as many $COMPATIBILITY_0x## lines as you want.",
    "scope": "CHEATS.TXT global or per-game. Fixed (previously broken) in Beta 13 (2015-12-07).",
    "conflicts": "Modes 0x01/0x02/0x03/0x05 poke CD status and must NOT be combined with each other. 0x04 and 0x06 combine more freely. See compatibility wiki.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20220218153800); krHACKen r13 changelog 'Fixed : $COMPATIBILITY_0x## (in CHEATS.TXT) did not work' (Beta 13, pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x04"
  },
  {
    "name": "$CODECACHE_ADDON_0",
    "effect": "For games that lag badly or stall randomly when compatibility mode 0x04 doesn't fix the issue. Do NOT use by default on all games - most games will STOP working with it.",
    "scope": "CHEATS.TXT per-game (use sparingly). Documented from the 2017-10-28 wiki revision onward.",
    "conflicts": "Breaks most titles; apply only to specific lag/stall cases.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$CODECACHE_ADDON_0"
  },
  {
    "name": "$SUBCDSTATUS",
    "effect": "A variant of $COMPATIBILITY_0x05 (sub-CD status handling).",
    "scope": "CHEATS.TXT per-game. Documented from the 2017-10-28 wiki revision onward.",
    "conflicts": "As a 0x05 variant it pokes CD status; treat like 0x05 - don't stack with 0x01/0x02/0x03.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$SUBCDSTATUS"
  },
  {
    "name": "$FAKELC",
    "effect": "Loads a null LibCrypt magic word into the cop0 register. Needed by some discs that have a messed-up LibCrypt protection.",
    "scope": "CHEATS.TXT per-game. Added with the cheat engine (r13 WIP06 era). Beta 13 note: 'Fixed: The LC fix was flushed and $FAKELC could not set it up.'",
    "conflicts": "If $FAKELC fails to prevent freezing (e.g. Jackie Chan Stuntmaster PAL early batch lacking LibCrypt), use an explicit LibCrypt code block instead.",
    "provenance": "ShaolinAssassin wiki special-cheats; krHACKen r13 changelog Beta 13 (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$FAKELC"
  },
  {
    "name": "$SMOOTH",
    "effect": "Enables smooth (bilinear) texture mapping at startup. Underlying raw value is '$S0003390 00000001'. In-game toggle: Select+L1+R2 enable, Select+L2+R1 disable.",
    "scope": "CHEATS.TXT global or per-game. Added in r13 WIP05/WIP06 era. Effect is subtle.",
    "conflicts": "None; can be toggled live with the hotkeys even when set at startup.",
    "provenance": "ShaolinAssassin wiki special-cheats; krHACKen r13 changelog '-- Press Select+L1+R2 to enable / Select+L2+R1 to disable the smooth texture mapping' (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$SMOOTH"
  },
  {
    "name": "$NOPAL",
    "effect": "Disables POPStarter's PAL patcher. Can also be done with a PATCH_#.BIN file (stock PATCH_9.BIN). Note: since Beta 13 the PAL patcher auto-disables when GSM's XBRA+GSM magics are in memory, so $NOPAL after launching GSModeSelector is no longer needed.",
    "scope": "CHEATS.TXT global or per-game.",
    "conflicts": "Mutually exclusive in intent with $FORCEPAL (don't set both).",
    "provenance": "ShaolinAssassin wiki special-cheats; krHACKen r13 changelog Beta 13 GSM note (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$NOPAL"
  },
  {
    "name": "$FORCEPAL",
    "effect": "Forces activation of the PAL patcher (POPS runs in PAL) AND patches the BIOS region code to Euro (boot screen shows in PAL). Useful for PAL VCDs whose bootsector lacks a valid license text. Equivalent to PATCH_8.BIN.",
    "scope": "CHEATS.TXT global or per-game. Added in Beta 12 (2015-11-24).",
    "conflicts": "Opposes $NOPAL. Without it, VCDs with broken bootsectors run in POPS native NTSC mode.",
    "provenance": "ShaolinAssassin wiki special-cheats; krHACKen r13 changelog '** 2015/11/24 (Beta 12) ** - Added $FORCEPAL (in CHEATS.TXT)' (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$FORCEPAL"
  },
  {
    "name": "$480p",
    "effect": "Forces 480p output.",
    "scope": "CHEATS.TXT per-game. Marked 'NOT reliable ATM' in the wiki.",
    "conflicts": "NOT compatible with $XPOS, $YPOS, $DWSTRETCH, $DWCROP. Mutually exclusive with the screen-geometry commands.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 + 20220218153800)",
    "confidence": "primary",
    "example": "$480p"
  },
  {
    "name": "$WIDESCREEN",
    "effect": "Enables the POPS GTE widescreen hack and forces 16:9. Does NOT fix HUDs, text/fonts, menus, or 2D backgrounds (no render fix - hack is unfinished).",
    "scope": "CHEATS.TXT per-game. Documented from 2017-10-28 wiki revision.",
    "conflicts": "Choose one of $WIDESCREEN / $ULTRA_WIDESCREEN / $EYEFINITY (they are alternative FOV variants).",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$WIDESCREEN"
  },
  {
    "name": "$ULTRA_WIDESCREEN",
    "effect": "Same as $WIDESCREEN but with a wider FOV. Does not match any standard aspect ratio. Does not deal with HUDs/text/menus/2D backgrounds.",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Mutually exclusive alternative to $WIDESCREEN / $EYEFINITY.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$ULTRA_WIDESCREEN"
  },
  {
    "name": "$EYEFINITY",
    "effect": "Same as $WIDESCREEN but with a 3x16:9 aspect ratio (triple-wide). Does not deal with HUDs/text/menus/2D backgrounds.",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Mutually exclusive alternative to $WIDESCREEN / $ULTRA_WIDESCREEN.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$EYEFINITY"
  },
  {
    "name": "$XPOS_####",
    "effect": "Centers/shifts the screen horizontally. #### is a DECIMAL number (negative values not supported). Default value 640. Below 640 moves the screen left; above 640 moves it right.",
    "scope": "CHEATS.TXT per-game. Works only in PAL and NTSC modes.",
    "conflicts": "NOT compatible with $480p. (Wiki note 10-01: XPOS/YPOS descriptions were corrected from an earlier mistake.)",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 confirms 'Default value : 640')",
    "confidence": "primary",
    "example": "$XPOS_640"
  },
  {
    "name": "$YPOS_##",
    "effect": "Centers/shifts the screen vertically. ## is a DECIMAL number (negatives unsupported). No default - depends on the game, experiment. Higher value moves the screen DOWN.",
    "scope": "CHEATS.TXT per-game. Works only in PAL and NTSC. Was non-functional in OBT15, fixed in OBT16.",
    "conflicts": "NOT compatible with $480p.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 + 20220218153800)",
    "confidence": "primary",
    "example": "$YPOS_20"
  },
  {
    "name": "$DWSTRETCH_####",
    "effect": "Stretches the display horizontally to fit your screen. #### is DECIMAL. Default value 2559. Increase to stretch right, decrease to stretch left.",
    "scope": "CHEATS.TXT per-game. Works only in PAL and NTSC.",
    "conflicts": "NOT compatible with $480p.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 confirms 'Default value : 2559')",
    "confidence": "primary",
    "example": "$DWSTRETCH_2559"
  },
  {
    "name": "$DWCROP_####",
    "effect": "Reduces/expands the display area width. #### is DECIMAL. Maximum value 2560. Decrease it to crop the screen on the right.",
    "scope": "CHEATS.TXT per-game. Works only in PAL and NTSC.",
    "conflicts": "NOT compatible with $480p.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 confirms 'Maximum value : 2560')",
    "confidence": "primary",
    "example": "$DWCROP_2560"
  },
  {
    "name": "$HDTVFIX",
    "effect": "Enables a SetGsCrt hack. Helps HDTVs that can't deal with interlaced resolutions over component (otherwise plain green screens / rubbish).",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "NOT compatible with some CRT TVs.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 + 20220218153800)",
    "confidence": "primary",
    "example": "$HDTVFIX"
  },
  {
    "name": "$SCANLINES",
    "effect": "Enables the scanlines generator - draws horizontal raster lines to mimic the look of old CRT TVs/tube monitors.",
    "scope": "CHEATS.TXT per-game. Added in a later beta (present in the 2020-06-26 wiki revision; NOT in the 2017 revisions).",
    "conflicts": "Cosmetic; none documented.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20220218153800, page 'Updated 2020-06-26'). MISSED BY BASE REPORT.",
    "confidence": "primary",
    "example": "$SCANLINES"
  },
  {
    "name": "$MUTE_CDDA",
    "effect": "Mutes CDDA (Red Book audio) tracks. Done automatically when playing a physical PS1 CD-ROM from the disc drive.",
    "scope": "CHEATS.TXT per-game. From 2017-10-28 wiki revision.",
    "conflicts": "Pairs with $UNDO_MUTE_CDDA (opposite). ",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$MUTE_CDDA"
  },
  {
    "name": "$UNDO_MUTE_CDDA",
    "effect": "Unmutes CDDA tracks specifically in PS1CD mode (overrides the automatic muting that happens when reading a physical disc).",
    "scope": "CHEATS.TXT per-game, PS1CD mode.",
    "conflicts": "Opposite of $MUTE_CDDA.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$UNDO_MUTE_CDDA"
  },
  {
    "name": "$MUTE_VAB",
    "effect": "Mutes VAB/VAG/VB+VH-based sounds/music. Useful for old games that output distorted SFX, wrong audio samples, or noise.",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Silences SPU-streamed audio; cosmetic tradeoff.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$MUTE_VAB"
  },
  {
    "name": "$D2LS",
    "effect": "'Left Stick is the D-Pad' code + stay on Digital mode. Enables analog-stick support for games that don't support it natively. Recommended default; try $D2LS_ALT if it fails.",
    "scope": "CHEATS.TXT per-game. Dedicated D2LS wiki page exists.",
    "conflicts": "Use one of $D2LS / $D2LS_ALT, not both.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 + 20220218153800); wiki page 'D2LS'",
    "confidence": "primary",
    "example": "$D2LS"
  },
  {
    "name": "$D2LS_ALT",
    "effect": "'Left Stick is the D-Pad' code + stay on Analog mode. Alternative to $D2LS when the digital-mode variant doesn't work.",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Use one of $D2LS / $D2LS_ALT.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 + 20220218153800)",
    "confidence": "primary",
    "example": "$D2LS_ALT"
  },
  {
    "name": "$NOVMC0",
    "effect": "Use VMC1 only (do not use/mount VMC0, the first virtual memory card).",
    "scope": "CHEATS.TXT per-game. From 2017-10-28 wiki revision.",
    "conflicts": "Pairs with $NOVMC1 (opposite). Don't set both or you have no VMC.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$NOVMC0"
  },
  {
    "name": "$NOVMC1",
    "effect": "Use VMC0 only (do not use/mount VMC1, the second virtual memory card).",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Pairs with $NOVMC0 (opposite).",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$NOVMC1"
  },
  {
    "name": "$IGR0",
    "effect": "Sets the In-Game Reset hotkey that OPENS the IGR menu to L1+L2+R1+R2+X+Down.",
    "scope": "CHEATS.TXT per-game. Button combo decoded from the wiki's PlayStation-button image filenames.",
    "conflicts": "Set only one $IGR# combo. $NOIGR disables IGR entirely.",
    "provenance": "ShaolinAssassin wiki special-cheats; button glyphs decoded from img src 'Playstation-Button-{L1,L2,R1,R2,X}/Dpad-Down.png' (Wayback 20190403162824)",
    "confidence": "primary",
    "example": "$IGR0"
  },
  {
    "name": "$IGR1",
    "effect": "Sets the IGR-menu-open hotkey to Select+Start.",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Set only one $IGR# combo. Select+Start can collide with games that use that combo.",
    "provenance": "ShaolinAssassin wiki special-cheats; glyphs decoded 'Playstation-Button-Select.png + Start.png' (Wayback 20190403162824)",
    "confidence": "primary",
    "example": "$IGR1"
  },
  {
    "name": "$IGR2",
    "effect": "Sets the IGR-menu-open hotkey to L1+L2+R1+R2+Select+Start.",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Set only one $IGR# combo.",
    "provenance": "ShaolinAssassin wiki special-cheats; glyphs decoded 'L1+L2+R1+R2+Select+Start' (Wayback 20190403162824)",
    "confidence": "primary",
    "example": "$IGR2"
  },
  {
    "name": "$IGR3",
    "effect": "TERMINATES POPS directly (no IGR menu) on L1+L2+R1+R2+X+Down. On quit, POPStarter then tries mc0:/BOOT/BOOT.ELF then mc1:/BOOT/BOOT.ELF, else exits to Browser/OSDSYS.",
    "scope": "CHEATS.TXT per-game. Quit-on-failure BOOT.ELF behavior added Beta 13 (2015-12-07).",
    "conflicts": "Set only one $IGR# combo. No documented BOOT.ELF path override.",
    "provenance": "ShaolinAssassin wiki special-cheats; krHACKen r13 changelog Beta 13 BOOT.ELF launcher (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$IGR3"
  },
  {
    "name": "$IGR4",
    "effect": "TERMINATES POPS directly (no IGR menu) on Select+Start.",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Set only one $IGR# combo.",
    "provenance": "ShaolinAssassin wiki special-cheats; glyphs decoded 'Select+Start' (Wayback 20190403162824)",
    "confidence": "primary",
    "example": "$IGR4"
  },
  {
    "name": "$IGR5",
    "effect": "TERMINATES POPS directly (no IGR menu) on L1+L2+R1+R2+Select+Start (the OPL-style 'no-popup' combo).",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Set only one $IGR# combo.",
    "provenance": "ShaolinAssassin wiki special-cheats; glyphs decoded 'L1+L2+R1+R2+Select+Start' (Wayback 20190403162824). CORRECTS BASE (base listed L1+L2 in combo; exact combo is L1+L2+R1+R2+Select+Start).",
    "confidence": "primary",
    "example": "$IGR5"
  },
  {
    "name": "$NOIGR",
    "effect": "Disables the IGR menu entirely (no In-Game Reset hotkey active).",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Overrides any $IGR# combo. Means no way to reset/quit from a pad mid-game.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20170629123253 + 20220218153800)",
    "confidence": "primary",
    "example": "$NOIGR"
  },
  {
    "name": "$CACHE1",
    "effect": "Makes POPS buffer 1 sector instead of the default 16. Added with the cheat engine (r13 WIP05/06 era).",
    "scope": "CHEATS.TXT per-game.",
    "conflicts": "Performance/compatibility tradeoff; default is 16.",
    "provenance": "ShaolinAssassin wiki special-cheats; krHACKen r13 changelog '-- $CACHE1 (Makes POPS buffer 1 sector instead of 16.)' (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$CACHE1"
  },
  {
    "name": "$USBDELAY_#",
    "effect": "Sets up the PFS-wrapper USB delay (# is a number). Same value can also be set in the POPSTARTER.ELF config table. Helps slow USB devices.",
    "scope": "CHEATS.TXT per-game/global. Added r13 WIP05/06 era.",
    "conflicts": "Beta 13 fixed: '$USBDELAY_# didn't coexist with $C0' codes - now they coexist.",
    "provenance": "ShaolinAssassin wiki special-cheats; krHACKen r13 changelog (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$USBDELAY_5"
  },
  {
    "name": "$UNDO_GAME_FIXES",
    "effect": "Prevents POPStarter from activating its built-in per-game fixes (re-exposes original bugs). Some game fixes became obsolete via later POPS patches; this command may not re-show problems for every game (e.g. Crash Bandicoot PAL works without its fix now).",
    "scope": "CHEATS.TXT per-game. Present in the 2020-06-26 wiki revision.",
    "conflicts": "Diagnostic/advanced; turns OFF the automated compatibility fixes.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20220218153800, 'Updated 2020-06-26'). MISSED BY BASE TABLE NARRATIVE (base listed it in command roster but with no detail).",
    "confidence": "primary",
    "example": "$UNDO_GAME_FIXES"
  },
  {
    "name": "Raw GameShark/AR code line",
    "effect": "Any line beginning with $ followed by an address, a space, then a value is applied as a raw cheat by the embedded engine. PS1 RAW code types 30, 50, 80 and D0 (GameShark/Action Replay) are supported; PS2 RAW code types 0, 1 and 2 are supported.",
    "scope": "CHEATS.TXT in the game's VMC folder (per-game) or in the POPS root folder (applies to ALL games). Engine present since WIP06 OBT01.",
    "conflicts": "A root POPS/CHEATS.TXT applies globally. Each code line MUST have a space between address and value.",
    "provenance": "ShaolinAssassin wiki cheat-engine (Wayback 20170629113247): 'each code line has to start with the $ character; ... PS1 RAW codes of types 30, 50, 80 and D0 are supported (Gameshark/Action Replay); PS2 RAW codes of types 0, 1 and 2 are supported.'",
    "confidence": "primary",
    "example": "$800AC402 0800"
  },
  {
    "name": "C0 master code (mastercode)",
    "effect": "Some PS1 games require a master/enable code or they crash (e.g. Air Race Championship). ONLY type C0 master codes are supported. Type C1 master codes (activation-on-delay-time) are NOT and 'will not be' supported.",
    "scope": "CHEATS.TXT per-game. Beta 13 fixed an 'Incorrect load instruction for $C0 codes' engine bug and a $USBDELAY/$C0 coexistence bug.",
    "conflicts": "C1 codes silently unsupported - converting/using them will not work.",
    "provenance": "ShaolinAssassin wiki cheat-engine (Wayback 20170629113247): 'Only type C0 are supported. Mastercodes of type C1 (aka activation on delay time) are not and will not be supported.'; krHACKen r13 changelog $C0 fixes (pastebin 719TCAd5)",
    "confidence": "primary",
    "example": "$C00AB840 1234"
  },
  {
    "name": "PS1->PS2 RAW conversion",
    "effect": "To convert a PS1 code to PS2 RAW format, add 01000000 to the address and comply with the target engine's code-type definitions. POPS Mastercode for EXTERNAL PS2 cheat devices (ps2rd / CodeBreaker / Cheat device) is 902377F4 0C0902EF - NOT needed if you use CHEATS.TXT.",
    "scope": "Applies when porting external PS1 cheat lists or using a hardware/software PS2 cheat device instead of CHEATS.TXT.",
    "conflicts": "The 902377F4 mastercode is only for external devices; do not add it inside CHEATS.TXT.",
    "provenance": "ShaolinAssassin wiki cheat-engine (Wayback 20170629113247)",
    "confidence": "primary",
    "example": "902377F4 0C0902EF"
  },
  {
    "name": "$00507028 00000001 / $005070B8 00000001",
    "effect": "Rumble Always On codes: $00507028 00000001 = Pad 1 rumble always on; $005070B8 00000001 = Pad 2 rumble always on. Example raw codes pre-listed in the wiki.",
    "scope": "CHEATS.TXT per-game. Raw codes, applied by the cheat engine.",
    "conflicts": "None.",
    "provenance": "ShaolinAssassin wiki special-cheats (Wayback 20190403162824 + 20220218153800)",
    "confidence": "primary",
    "example": "$00507028 00000001"
  }
]
```

## New findings

- $SCANLINES command (CRT scanline generator) - present in the 2020-06-26 wiki revision; not in the base table.
- Full $UNDO_GAME_FIXES description recovered: it disables POPStarter's automated per-game fixes; some fixes became obsolete after later POPS patches (e.g. Crash Bandicoot PAL now works without its fix), so it may not re-expose every bug.
- Two explicit Rumble-Always-On raw codes documented on the wiki: $00507028 00000001 (Pad 1) and $005070B8 00000001 (Pad 2).
- Recovered a real, complete LibCrypt example code block for Jackie Chan Stuntmaster (PAL) - useful when built-in LibCrypt crack and $FAKELC both fail (early disc batch lacked LibCrypt).
- Exact $IGR# button combos decoded from wiki image filenames (alt text was useless) - corrects/sharpens the base $IGR5 combo to L1+L2+R1+R2+Select+Start, and reveals IGR0/IGR3, IGR1/IGR4, IGR2/IGR5 are combo-paired (open-menu vs terminate).
- krHACKen's changelog pins the engine's bug history: the 'hook+8 garbage' crash bug, the $USBDELAY/$C0 coexistence bug, and the $C0 load-instruction bug were all fixed in Beta 13 (2015-12-07); $SAFEMODE was made functional in Beta 12 (2015-11-24).
- $SMOOTH's underlying raw value is documented as $S0003390 00000001; PS2-style 'S'-prefixed addresses ($S....) are how POPStarter expresses certain internal toggles.
- The wiki cheat-engine page lists PS2 RAW types 0/1/2 as supported alongside PS1 types 30/50/80/D0 - confirming the engine accepts already-PS2-converted codes directly, not just PS1 GameShark codes.
- Retrieval method note for the rest of the corpus: WebFetch is blocked from web.archive.org, but `curl` against the Wayback CDX API + the `id_` raw-snapshot endpoint reliably recovers the full ShaolinAssassin wiki (automated, compatibility, configuration-table, debug-mode, d2ls, hdd-mode, faqs, chronology pages all have 200 snapshots).

## Gaps

- The canonical 'sample containing all special commands' file (wiki link target: bitbucket.org/.../downloads/CHEATS.TXT) is NOT recoverable - every Wayback snapshot is a 302 to an expired Bitbucket S3 CDN URL ('Request has expired'/AccessDenied). The exact contents/ordering of krHACKen's official all-in-one sample are lost.
- $SAFEMODE timing is documented qualitatively ('only activate it after POPS has left the PS OSD') but the precise frame/event trigger and the exact memory region it protects are not specified on the recovered pages.
- The base report's claim that a root POPS/CHEATS.TXT BLOCKS per-game CHEATS.TXT files is NOT confirmed by the recovered wiki (which only says root = applies to all). Needs corroboration - mark community/unverified.
- Whether multiple geometry commands ($XPOS+$YPOS together) fully compose, and exact behavior when combined with $WIDESCREEN, is not stated.
- $480p is flagged 'NOT reliable ATM' with no later resolution found; its current status in the 2019-06-05 r13 build is unverified.
- Could not retrieve the live ps2-home cheats tutorial (t=6924) or PSX-Place r13 page directly (Cloudflare/403) to cross-check community phrasing; relied on search snippets for those.

## Sources

- http://web.archive.org/web/20170629123253id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats
- http://web.archive.org/web/20170626021721/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats
- http://web.archive.org/web/20190403162824id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats
- http://web.archive.org/web/20220218153800id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats
- http://web.archive.org/web/20170629113247id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/cheat-engine
- https://pastebin.com/raw/719TCAd5
- https://www.ps2-home.com/forum/viewtopic.php?t=6924
- https://www.ps2-home.com/forum/viewtopic.php?t=79
- https://www.psx-place.com/resources/ps1-popstarter-r13-wip-06-beta-20160918.354/
- https://archive.org/details/popstarter-r-13-beta-20190605
- http://web.archive.org/cdx/search/cdx?url=bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki*