# Research agent 1: POPStarter Compatibility PATCH_#.BIN modes, $COMPATIBILITY_0x##, and TROJAN files

## Summary
Recovered the lost ShaolinAssassin Bitbucket wiki (the primary documentation) via the Wayback Machine and cross-verified against krHACKen's changelog, the PS2-HOME "Trojans and Patches" thread, and community manuals. KEY CLARIFICATION of the three asset types: (1) PATCH_#.BIN = compatibility-MODE forcers (PATCH_1..6 = modes 0x01..0x06) plus PATCH_0 (disable IGR) and the PAL/NTSC patch files (PATCH_8 PAL / PATCH_9 NTSC=$NOPAL); (2) TROJAN_#.BIN serve TWO roles — (a) "IGR behaviour modifiers" (TROJAN_0..5 = alternate IGR button combos / quit methods, TROJAN_9 = no-2nd-pad-in-IGR) and (b) cumulative per-game "game fixes" bundles (TROJAN_7 = cumulative r6 game-fix pack, 2020-05-20); (3) CHEATS.TXT = $commands + raw GS/AR codes. A PATCH/TROJAN's number must match a number embedded in its header or POPStarter refuses to load it. NEW vs base report: compatibility MODE 0x07 exists ($COMPATIBILITY_0x07, fixes missing textures e.g. Tomb Raider III) — base report stopped at 0x06. The "no-combine 0x01/0x02/0x03/0x05" rule is PRIMARY-confirmed ("variants of the same hack"). The 2020-03-21 PATCH_9.BIN filename-collision is confirmed: same name as the stock $NOPAL file but a totally different krHACKen file that restores IGR-exit-to-OPL which BETA-13 broke. PATCH_7.BIN is genuinely undocumented in the surviving wiki (ambiguous). Config-table note: "function skipper" at offset $412 was removed in Beta 12 (2015/11/24), not Beta 13.

## Prose
PROVENANCE NOTE FOR THE SITE: The single most important recovery here is that the lost ShaolinAssassin Bitbucket wiki (bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki) — the de-facto primary documentation for POPStarter — is fully archived in the Wayback Machine and can be harvested page-by-page using the raw-content suffix (web.archive.org/web/<timestamp>id_/<url>). The CDX index lists ~70 live wiki pages. WebFetch cannot reach web.archive.org in this environment, but curl with a browser User-Agent works.\n\nTHE THREE ASSET TYPES (the core clarification this topic demanded):\n1) PATCH_#.BIN = compatibility-MODE forcers and a few special toggles. PATCH_1..6 hardwire modes 0x01..0x06; mode 0x07 (missing-texture fix) is reachable via $COMPATIBILITY_0x07 / runtime. PATCH_0 disables the IGR menu (==$NOIGR). PATCH_8 forces PAL (==$FORCEPAL, file documented only in a community mirror), PATCH_9 (stock) disables the PAL patcher to run PAL games as NTSC (==$NOPAL).\n2) TROJAN_#.BIN is krHACKen's name for a binary patch asset — explicitly NOT malware. It does double duty: TROJAN_0..5 are IGR behaviour modifiers (they change the reset button combo and whether reset opens the IGR menu or just terminates POPS; the $IGR0..5 CHEATS.TXT commands are the exact equivalents), TROJAN_9 is the 'No 2nd Pad in IGR' variant, and TROJAN_7 is a cumulative per-game FIX bundle (2020-05-20). The per-game 'game fixes' (AntiCrash/LoadinFix/Boot Fix/SkipVSync/Skip-CutScenes) come from the separate 'game fixes archive' as TROJAN files keyed to disc IDs.\n3) CHEATS.TXT is plain text — $commands plus raw GameShark/Action Replay codes. Many $commands are exact equivalents of dropping a PATCH/TROJAN ($COMPATIBILITY_0x##==PATCH_#, $IGR#==TROJAN_#, $NOIGR==PATCH_0, $NOPAL==stock PATCH_9).\n\nHOW THEY INSTALL (identical for all three): drop in a game's VMC folder for that one game, or in the POPS folder for all games. Every PATCH/TROJAN carries a number in its header that must match the number in its filename, or POPStarter silently refuses to load it — so to run two copies you must rename AND hex-edit the header.\n\nTHE NO-COMBINE RULE is primary-confirmed: modes 0x01/0x02/0x03/0x05 are 'variants of the same hack' (all poke CD status) and may not be combined — use exactly one. 0x04, 0x06 and 0x07 are independent; documented safe combos are 1+4, 2+4, 3+6, 1+4+6.\n\nTHE PATCH_9 FILENAME COLLISION (document both, separately): There are two unrelated files both named PATCH_9.BIN. (A) The long-standing STOCK PATCH_9.BIN == $NOPAL, which disables POPStarter's automatic PAL patcher so a PAL VCD plays in POPS's native NTSC mode (the wiki already calls it 'obsolete (still working tho)' because GSM v0.23x auto-detection usually makes it unnecessary). (B) A SEPARATE 2020-03-21 krHACKen file that reuses the name PATCH_9.BIN and restores the IGR/quit-to-launcher exit that BETA-13 broke ('IGR back to OPL'); the community also describes it as disabling POPStarter's bugged ELF loader / fixing the IGR black-screen-to-Browser. Same filename, different binary (PATCH_9.7z MD5 9db1e18bae92c4991e3de7e2a752558c, 188 bytes), distributed via the IGR 'Trojans and Patches' thread rather than the PAL/NTSC docs. For the searchable site these should be two distinct records that explicitly cross-warn each other.\n\nPATCH_7 remains the genuine unknown: it is absent from every recovered primary artifact and only survives as forum/manual lore; treat as unverified. Do not confuse it with the verified TROJAN_7.BIN game-fix bundle.

## Entries (25)

```json
[
  {
    "name": "$COMPATIBILITY_0x##",
    "effect": "CHEATS.TXT command that activates a compatibility mode at runtime. ## is a hexadecimal value (01..07). You can write as many $COMPATIBILITY_0x## lines as you want (subject to the no-combine rule below).",
    "scope": "Per-game (POPS/GAME/CHEATS.TXT) or global (POPS/CHEATS.TXT). POPStarter r13.",
    "conflicts": "Modes 0x01/0x02/0x03/0x05 are mutually exclusive (see no-combine rule). Equivalent to dropping the matching PATCH_#.BIN, or hardcoding via config offsets $418-$41F.",
    "provenance": "PRIMARY: ShaolinAssassin wiki 'special-cheats' page, Wayback 2017-06-26 — https://web.archive.org/web/20170626021721/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x04"
  },
  {
    "name": "PATCH_1.BIN  ==  mode 0x01",
    "effect": "\"Helps restoring the music/voices in several games.\"",
    "scope": "Drop in game VMC dir (one game) or POPS dir (all games). r13.",
    "conflicts": "MUST NOT be combined with modes 0x02/0x03/0x05 (variants of the same hack). May combine with 0x04, 0x06.",
    "provenance": "PRIMARY: wiki 'compatibility' page, Wayback 2017-06-29 — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility",
    "confidence": "primary",
    "example": "Copy PATCH_1.BIN into the game's VMC folder, OR put $COMPATIBILITY_0x01 in CHEATS.TXT"
  },
  {
    "name": "PATCH_2.BIN  ==  mode 0x02",
    "effect": "\"A variant of mode 0x01, with a second hack for not breaking the MDECoding of FMVs (was designed for the Colony Wars series).\"",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "MUST NOT be combined with 0x01/0x03/0x05. May combine with 0x04/0x06.",
    "provenance": "PRIMARY: wiki 'compatibility', Wayback 2017-06-29 — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x02"
  },
  {
    "name": "PATCH_3.BIN  ==  mode 0x03",
    "effect": "\"Can be used if the mode 0x01 doesn't provide the expected results.\" (alternate to 0x01)",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "MUST NOT be combined with 0x01/0x02/0x05. May combine with 0x04/0x06.",
    "provenance": "PRIMARY: wiki 'compatibility', Wayback 2017-06-29 — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x03"
  },
  {
    "name": "PATCH_4.BIN  ==  mode 0x04",
    "effect": "\"Fixes slowdowns, flickering, and many other glitches (prevents the emulator from writing a garbage value in two of the virtual GPU registers).\"",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "SAFE to combine with 0x01/0x02/0x03/0x06 (it is NOT one of the mutually-exclusive variants). Documented combos: 1+4, 2+4, 1+4+6.",
    "provenance": "PRIMARY: wiki 'compatibility', Wayback 2017-06-29 — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x01\\n$COMPATIBILITY_0x04   (1+4 combo is allowed)"
  },
  {
    "name": "PATCH_5.BIN  ==  mode 0x05",
    "effect": "\"Made for fixing the cutscenes of the PAL Resident Evil: Director's Cut.\"",
    "scope": "Game VMC dir or POPS dir. r13. Still shipped as PATCH_5.BIN.",
    "conflicts": "MUST NOT be combined with 0x01/0x02/0x03. May combine with 0x04/0x06.",
    "provenance": "PRIMARY: wiki 'compatibility', Wayback 2017-06-29 — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x05"
  },
  {
    "name": "PATCH_6.BIN  ==  mode 0x06",
    "effect": "\"Disables the OSD shell of the emulator's built-in BIOS, making some games that freeze on startup run.\"",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "SAFE to combine (not one of the exclusive variants). Documented combos: 3+6, 1+4+6.",
    "provenance": "PRIMARY: wiki 'compatibility', Wayback 2017-06-29 — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x06"
  },
  {
    "name": "mode 0x07  ($COMPATIBILITY_0x07)",
    "effect": "\"Fixes the missing textures problems (example: Tomb Raider III).\"  NEW vs base report — base stopped at 0x06. Added in Beta 13 / WIP-era. Note: this is a runtime mode; the per-game texture fix for older titles also ships as a TROJAN game-fix.",
    "scope": "r13. Via $COMPATIBILITY_0x07 in CHEATS.TXT (no documented stock PATCH_7.BIN for it — see PATCH_7 row).",
    "conflicts": "Not listed among the exclusive 0x01/0x02/0x03/0x05 set; treated as independent.",
    "provenance": "PRIMARY: wiki 'compatibility' lists mode 0x07; krHACKen changelog 'New compatibility mode ($COMPATIBILITY_0x07) - fixes missing textures' — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility  AND  https://web.archive.org/web/20170629142002/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter-changelog",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x07"
  },
  {
    "name": "NO-COMBINE RULE (0x01/0x02/0x03/0x05)",
    "effect": "\"Caution: Modes 0x01, 0x02, 0x03 and 0x05 cannot be enabled in the same time or combined. These are variants of the same hack and they are conflicting, so use only one of them at a time.\"  These four poke CD status; 0x04/0x06/0x07 are independent and combinable.",
    "scope": "All compatibility-mode entry points (PATCH file, CHEATS.TXT, hardcoded). r13.",
    "conflicts": "Self — the rule IS the conflict. Valid combos explicitly given: 1+4, 2+4, 3+6, 1+4+6.",
    "provenance": "PRIMARY: wiki 'compatibility', Wayback 2017-06-29 — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility",
    "confidence": "primary",
    "example": "OK: $COMPATIBILITY_0x01 + $COMPATIBILITY_0x04.  WRONG: $COMPATIBILITY_0x01 + $COMPATIBILITY_0x02"
  },
  {
    "name": "PATCH_7.BIN",
    "effect": "UNDOCUMENTED / AMBIGUOUS. Does NOT appear in the surviving ShaolinAssassin wiki, the r13 changelog, the IGR/Trojans thread download table, or the community manual (which jumps PATCH_6 -> PATCH_8). Older (2014 krHACKen, ASSEMblergames) usage reportedly forced mode 0x06; later treated as obsolete 'Mode 7'. No primary file recovered. NOTE: the TROJAN_7.BIN that DOES exist is a game-fix bundle, unrelated to any 'PATCH_7'.",
    "scope": "Unknown / legacy. NOT in r13 stock asset set.",
    "conflicts": "Cannot be assessed — file unverified.",
    "provenance": "NEGATIVE EVIDENCE: absent from wiki 'compatibility', changelog, IGR thread, and PDFCoffee manual. Community manual skips PATCH_7 — https://pdfcoffee.com/manual-popstarter-pdf-free.html ; IGR/Trojans table lists no PATCH_7 — https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909",
    "confidence": "unverified",
    "example": ""
  },
  {
    "name": "PATCH_8.BIN (PAL / $FORCEPAL)",
    "effect": "Forces PAL output. Maps to the $FORCEPAL behaviour: \"Forces the activation of the PAL patcher (POPS will run it PAL) and patches the BIOS region code to Euro (shows the boot screen in PAL).\" Useful for PAL VCDs with no/broken license text in their bootsector.",
    "scope": "Game VMC dir or POPS dir / or $FORCEPAL in CHEATS.TXT. r13.",
    "conflicts": "Opposite of PATCH_9/$NOPAL (PAL vs NTSC). Don't use both. The named file 'PATCH_8.BIN = PAL' is from a community manual; primary docs document the equivalent $FORCEPAL command, not the literal stock file.",
    "provenance": "MIRROR for file name: community 'Manual POPSTARTER' (Ed. 2.3) 'PATCH_8.BIN = PAL' — https://pdfcoffee.com/manual-popstarter-pdf-free.html . PRIMARY for $FORCEPAL semantics: wiki 'special-cheats' + changelog — https://web.archive.org/web/20170626021721/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats . User report of PATCH_8.BIN for PAL: https://web.archive.org/web/20171013024531/http://www.ps2-home.com/forum/viewtopic.php?t=621",
    "confidence": "mirror",
    "example": "$FORCEPAL   (or drop PATCH_8.BIN)"
  },
  {
    "name": "PATCH_9.BIN  (STOCK = $NOPAL)",
    "effect": "Disables POPStarter's built-in automatic PAL patcher, so a PAL game runs in POPS's native NTSC video mode (lets you then force NTSC with GSM). Equivalent to $NOPAL in CHEATS.TXT. Wiki: '$NOPAL — PATCH_9.BIN now obsolete (still working tho)' because GSM v0.23x auto-detection later made it usually unnecessary.",
    "scope": "Game VMC dir (that game) or POPS dir (all games). r13. THIS is the long-standing stock file.",
    "conflicts": "Opposite of PATCH_8/$FORCEPAL. DISTINCT FILE from the 2020 PATCH_9.BIN (same name, different purpose — see next row). Hardcode-equivalent: NO_PAL.PPF / config offset $42A.",
    "provenance": "PRIMARY: wiki 'special-cheats' ('$NOPAL — PATCH_9.BIN now obsolete') — https://web.archive.org/web/20170626021721/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats ; PAL-on-NTSC thread ('copy PATCH_9.BIN into the VMC directory ... run your game into NTSC') — https://web.archive.org/web/20171013024531/http://www.ps2-home.com/forum/viewtopic.php?t=621",
    "confidence": "primary",
    "example": "$NOPAL   (or drop stock PATCH_9.BIN to run a PAL VCD in NTSC)"
  },
  {
    "name": "PATCH_9.BIN  (2020 — FILENAME COLLISION, IGR-return-to-OPL fix)",
    "effect": "A SEPARATE krHACKen file released 2020-03-21 that REUSES the name PATCH_9.BIN. It restores POPStarter's IGR/quit-to-launcher exit that BETA-13 broke ('Starting with BETA 13 of POPStarter IGR back to OPL was impossible ... He has provided a file ... put inside our POPS folder and IGR back to OPL will now work'). Community shorthand also frames it as disabling POPStarter's bugged ELF loader / fixing the IGR black-screen-to-Browser. MD5 of PATCH_9.7z: 9db1e18bae92c4991e3de7e2a752558c (188 bytes).",
    "scope": "Drop in POPS dir (mass0:/POPS/PATCH_9.BIN, hdd __common/POPS, or SMB share/POPS). Needs FMCB for the OPL-launch setup. r13 + BETA13 era.",
    "conflicts": "NAME-COLLIDES with the stock $NOPAL PATCH_9.BIN — they are different binaries with the same filename; do not confuse them. Distributed via the IGR 'Trojans and Patches' thread, not the PAL/NTSC docs.",
    "provenance": "PRIMARY: PS2-HOME thread t=127 ('UPDATE (March 21, 2020) we can now IGR back to OPL ... copy the file PATCH_9.BIN into your POPS folder ... thanks to the POPSTARTER Developer krHACKen') — https://web.archive.org/web/20230922122931/https://www.ps2-home.com/forum/viewtopic.php?f=54&t=127 ; download row + 2020-03-21 announcement in IGR thread — https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909",
    "confidence": "primary",
    "example": "mass0:/POPS/PATCH_9.BIN   (the 2020 return-to-OPL build, NOT the $NOPAL build)"
  },
  {
    "name": "PATCH_0.BIN",
    "effect": "\"Disables the IGR menu.\" (button combo: none). Equivalent to $NOIGR in CHEATS.TXT. This is an IGR behaviour modifier shipped as a PATCH file. MD5 PATCH_0.zip: b8d32e32d9d27c58e6558f9ad538f555 (221 bytes).",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "Mutually exclusive with the TROJAN_0..5 IGR modifiers (you pick one IGR behaviour). Equivalent CHEATS.TXT command: $NOIGR.",
    "provenance": "PRIMARY: wiki 'igr' page + IGR 'Trojans and Patches' thread download table — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr  AND  https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909",
    "confidence": "primary",
    "example": "Copy PATCH_0.BIN to POPS dir to kill the IGR menu globally (or $NOIGR)"
  },
  {
    "name": "TROJAN file — DEFINITION",
    "effect": "In POPStarter, a 'TROJAN' is NOT malware — it is krHACKen's NAME for a binary patch asset (TROJAN_#.BIN) that POPStarter loads from the game's VMC folder or the POPS folder. TROJANs serve TWO distinct roles: (1) IGR BEHAVIOUR MODIFIERS — TROJAN_0..5 change the In-Game-Reset button combo / quit method; (2) GAME FIXES — per-game-ID fixes (AntiCrash, LoadinFix, Boot Fix, SkipVSync, Skip-CutScenes) distributed in the 'game fixes archive', and bundled cumulatively (e.g. TROJAN_7). DIFFERS FROM PATCH_#.BIN (which forces compatibility MODES 0x01-0x07 / disables IGR) and from CHEATS.TXT (plain-text $commands + raw GameShark/AR codes).",
    "scope": "Game VMC dir (one game) or POPS dir (all games). r13. Both PATCH and TROJAN obey the header-number integrity check.",
    "conflicts": "A TROJAN IGR-modifier conflicts with PATCH_0/other TROJAN IGR-modifiers (pick one IGR behaviour). Game-fix TROJANs are per-game-ID and generally independent. NOT interchangeable with PATCH_#.BIN despite identical install mechanics.",
    "provenance": "PRIMARY: wiki 'compatibility' ('In the game fixes archive, you can find some TROJAN files fixing problematic games. Copy the file in the VMC directory') — https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility ; wiki 'igr' (TROJAN_0..5 as IGR modifiers) — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr",
    "confidence": "primary",
    "example": "Game fix: copy 'WipEout (SCES-00010) AntiCrash' TROJAN into the WipEout VMC dir. IGR mod: copy TROJAN_1.BIN for a Select+R1 reset combo."
  },
  {
    "name": "TROJAN_0.BIN",
    "effect": "IGR behaviour modifier — button combo Select+L1+L2+R1+R2 (the OPL-style 6-button combo) OPENS the IGR menu. MD5 TROJAN_0.zip: 9c431cb92e72d38dcd015d2d1840e3c5 (246 bytes). CHEATS.TXT equivalent: $IGR0.",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "Pick one IGR modifier only (exclusive with PATCH_0 and other TROJAN_1..5/$IGR#).",
    "provenance": "PRIMARY: wiki 'igr' + IGR thread table — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr ; https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909",
    "confidence": "primary",
    "example": "$IGR0   (equivalent to dropping TROJAN_0.BIN)"
  },
  {
    "name": "TROJAN_1.BIN",
    "effect": "IGR behaviour modifier — 2-button combo OPENS the IGR menu (the default-style short combo). CHEATS.TXT equivalent: $IGR1. MD5 TROJAN_1.zip: d5551d731a0eae6745e894d8a1b823ed (248 bytes).",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "Exclusive with other IGR modifiers.",
    "provenance": "PRIMARY: wiki 'igr' + IGR thread — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr",
    "confidence": "primary",
    "example": "$IGR1"
  },
  {
    "name": "TROJAN_2.BIN",
    "effect": "IGR behaviour modifier — 6-button combo OPENS the IGR menu (alternate combo to TROJAN_0). CHEATS.TXT equivalent: $IGR2. MD5 TROJAN_2.zip: 5a5e519f2f396eb5323719a659790bee (245 bytes).",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "Exclusive with other IGR modifiers.",
    "provenance": "PRIMARY: wiki 'igr' + IGR thread — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr",
    "confidence": "primary",
    "example": "$IGR2"
  },
  {
    "name": "TROJAN_3.BIN",
    "effect": "IGR behaviour modifier — 6-button combo TERMINATES POPS immediately (NO IGR menu / no confirmation popup). CHEATS.TXT equivalent: $IGR3. MD5 TROJAN_3.zip: c85f0e2a9ef4e4ea35ab1462493c6a2d (263 bytes).",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "Exclusive with other IGR modifiers.",
    "provenance": "PRIMARY: wiki 'igr' + IGR thread — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr",
    "confidence": "primary",
    "example": "$IGR3"
  },
  {
    "name": "TROJAN_4.BIN",
    "effect": "IGR behaviour modifier — 2-button combo TERMINATES POPS (no IGR menu). CHEATS.TXT equivalent: $IGR4. MD5 TROJAN_4.zip: 8ac51ec7e36e1bf06f6ddd1f072b2c9f (262 bytes).",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "Exclusive with other IGR modifiers.",
    "provenance": "PRIMARY: wiki 'igr' + IGR thread — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr",
    "confidence": "primary",
    "example": "$IGR4"
  },
  {
    "name": "TROJAN_5.BIN",
    "effect": "IGR behaviour modifier — 6-button combo (the no-popup Select+Start+L1+L2+R1+R2 OPL-like combo) TERMINATES POPS with no IGR menu. CHEATS.TXT equivalent: $IGR5. MD5 TROJAN_5.zip: fb0ee2841ca3c40f2483ac4c00c4594c (260 bytes).",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "Exclusive with other IGR modifiers.",
    "provenance": "PRIMARY: wiki 'igr' + IGR thread — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr",
    "confidence": "primary",
    "example": "$IGR5"
  },
  {
    "name": "TROJAN_7.BIN",
    "effect": "GAME-FIX BUNDLE (not an IGR modifier). Described in the IGR/Trojans thread as 'Cumulative r6, fixes as of 2020/05/20' — a cumulative pack of per-game crash/compat fixes, released 2020-08-13. MD5 TROJAN_7.zip: e5e150f8be4da1fa822b90cb9682cf8e (775 bytes — notably larger than the IGR-modifier TROJANs, consistent with a fix bundle).",
    "scope": "Game VMC dir or POPS dir. 2020 era r13.",
    "conflicts": "It is a game-fix asset, distinct from the TROJAN_0..5 IGR-combo modifiers; numbering does not imply an IGR role.",
    "provenance": "PRIMARY: IGR 'Trojans and Patches' thread download table + 2020-08-13 announcement — https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909",
    "confidence": "primary",
    "example": "Drop TROJAN_7.BIN in POPS dir to apply the 2020-05-20 cumulative game fixes"
  },
  {
    "name": "TROJAN_9.BIN",
    "effect": "IGR behaviour modifier variant — 'No 2nd Pad in IGR' (ignores controller port 2 input in the IGR menu, so a 2nd pad can't trigger/navigate IGR). MD5 TROJAN_9.zip: b6960e9a26034723eeea0ebcbe114334 (250 bytes).",
    "scope": "Game VMC dir or POPS dir. r13.",
    "conflicts": "Interacts with the chosen IGR combo; addresses 2-pad IGR misfires.",
    "provenance": "PRIMARY: IGR 'Trojans and Patches' thread download table — https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909",
    "confidence": "primary",
    "example": "Drop TROJAN_9.BIN to stop pad-2 from opening the IGR menu"
  },
  {
    "name": "PATCH/TROJAN header-number integrity check",
    "effect": "POPStarter validates that the NUMBER in a PATCH/TROJAN filename matches a number stored in the file's header. 'POPStarter will refuse to load the PATCH/TROJAN file if the number in its filename doesn't match the number in its header.' To keep an existing file, rename AND hex-edit the header number to match before copying.",
    "scope": "All PATCH_#.BIN and TROJAN_#.BIN, both VMC-dir and POPS-dir. r13.",
    "conflicts": "Renaming a file without editing its header = silently ignored (file won't load). This is exactly the integrity check that the 2015 WIP06 Beta 3 changelog 'fixed TROJAN_#.BIN and PATCH_#.BIN integrity check failures' refers to.",
    "provenance": "PRIMARY: wiki 'igr' page + IGR thread 'How to install' / NOTE — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr ; https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909",
    "confidence": "primary",
    "example": "To run both PATCH_1 and a renamed copy: rename PATCH_1.BIN -> PATCH_3.BIN AND hex-edit the embedded '1' -> '3' in its header."
  },
  {
    "name": "PATCH vs TROJAN vs CHEATS.TXT (install scope)",
    "effect": "All three asset types install the SAME way: copy into a game's VMC folder (applies to that ONE game) OR into the POPS folder (applies to ALL installed games). A root/POPS-level file is global; a per-game file is local. (Note: per the cheat-engine page, a root POPS/CHEATS.TXT enabling a code for all games means a per-game CHEATS.TXT pattern; placement decides scope.)",
    "scope": "USB mass0:/POPS, HDD hdd0:/__common/POPS, SMB smbX:/Share/POPS, or each game's VMC dir. r13.",
    "conflicts": "PATCH = compatibility MODES (0x01-0x07) + IGR-disable (PATCH_0) + PAL/NTSC (8/9). TROJAN = IGR combos (0-5,9) + game fixes (7). CHEATS.TXT = $commands + raw GS/AR codes. They overlap in capability (e.g. $IGR# == TROJAN_#, $COMPATIBILITY_0x## == PATCH_#, $NOIGR == PATCH_0, $NOPAL == PATCH_9) but are different mechanisms.",
    "provenance": "PRIMARY: wiki 'igr' install section + 'compatibility' + 'cheat-engine' — https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr ; https://web.archive.org/web/20170629113247/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/cheat-engine",
    "confidence": "primary",
    "example": "VMC dir = one game; POPS dir = all games (same rule for PATCH, TROJAN, and CHEATS.TXT)"
  }
]
```

## New findings

- Compatibility MODE 0x07 exists and is documented primary: $COMPATIBILITY_0x07 'fixes the missing textures problems (example: Tomb Raider III)'. The base report's mode list stopped at 0x06.
- TROJAN files have TWO clearly-separated roles in the PRIMARY wiki, not one: (a) IGR behaviour modifiers (TROJAN_0..5 = alternate IGR combos / quit methods; TROJAN_9 = 'No 2nd Pad in IGR'), and (b) per-game 'game fixes' from the 'game fixes archive' (AntiCrash Fix, LoadinFix, Boot Fix, SkipVSync, Skip-CutScenes), bundled cumulatively as TROJAN_7 ('Cumulative r6, fixes as of 2020/05/20'). The base report conflated TROJAN with 'a patch file name'.
- PATCH_0.BIN (disables IGR menu, == $NOIGR) is a distinct stock file in the IGR archive — base report only listed $NOIGR.
- The 2020 PATCH_9.BIN filename collision is fully sourced and its real purpose is more specific than the base report's 'disables bugged ELF loader': it is krHACKen's 2020-03-21 fix that RESTORES IGR/quit-to-OPL which BETA-13 had broken (community also frames it as ELF-loader/IGR-black-screen). MD5 of PATCH_9.7z = 9db1e18bae92c4991e3de7e2a752558c (188 bytes). Released via the IGR 'Trojans and Patches' thread, NOT the PAL/NTSC docs.
- The stock $NOPAL PATCH_9.BIN was already declared 'obsolete (still working tho)' in the wiki because GSM v0.23x auto-detection makes it usually unnecessary — adds nuance to the 'still works' note.
- MD5 hashes and byte sizes recovered for every IGR PATCH/TROJAN download (e.g. TROJAN_0.zip 9c431cb9... 246B; PATCH_0.zip b8d32e32... 221B; TROJAN_7.zip e5e150f8... 775B), useful as file-identity fingerprints for the published corpus.
- The header-number integrity check is the same mechanism behind the 2015 WIP06-Beta-3 changelog entry 'fixed TROJAN_#.BIN and PATCH_#.BIN integrity check failures' — connects a changelog line to the documented behaviour.
- A full PPF 'bunch pack' equivalence exists for hardcoding these into POPStarter.ELF: NO_PAL.PPF (==stock PATCH_9/$NOPAL), FORCE_MODEX.PPF (hardcode a mode), LC_ONLY.PPF (LibCrypt only, modes off), NO_AUTO_PATCH.PPF (everything off) — from the configuration-table page.
- The complete Wayback CDX index of the lost ShaolinAssassin wiki was recovered (~70 live pages incl. compatibility, igr, cheat-engine, special-cheats, configuration-table, automated, multi-disc, vmc, smb-mode, scanlines, widescreen, d2ls) — a reusable map for harvesting the rest of the corpus.

## Gaps

- PATCH_7.BIN: no primary file or definition survives. Its very existence as a STOCK r13 asset is unconfirmed — it is absent from the wiki, changelog, IGR download table, and the community manual. The 'forces mode 0x06' (2014 krHACKen) vs 'obsolete Mode 7' framings could not be verified against any recovered primary text; they remain community lore. (Distinct from the verified TROJAN_7.BIN game-fix bundle.)
- PATCH_8.BIN as a literal stock FILE: only documented by name in a community manual (mirror). Primary docs document the equivalent $FORCEPAL CHEATS.TXT command, not a shipped 'PATCH_8.BIN'. Whether a stock PATCH_8.BIN ships in the r13 package (vs users being expected to use $FORCEPAL) is unconfirmed.
- The exact button glyphs for TROJAN_0..5 / $IGR0..5 combos render as blanks in the archived HTML (button images stripped). Mapping to specific buttons (e.g. $IGR5 = Select+Start+L1+L2+R1+R2 from the base report) is plausible but the glyph-exact combos could not be re-read from the Wayback text; the OPEN-vs-TERMINATE action and 2-vs-6-button length ARE confirmed.
- TROJAN_6 and TROJAN_8: not present in the recovered IGR download table (only 0-5, 7, 9). Whether they ever existed is unknown.
- Config-table cross-check: base report says 'function skipper $412 REMOVED in beta 13'; primary changelog places the function-skipper removal in the Beta 12 (2015/11/24) cleanup block, and the surviving config-table page labels $412 as 'SetGsCrt hack'. This config-table detail is a different topic but the date/offset discrepancy with the base report should be reconciled there.
- The 2019-06-05 r13 BETA package's own bundled readme text was not directly retrieved (psx-place download is gated); claims about it rest on the wiki/changelog which the package mirrors.

## Sources

- PRIMARY (lost wiki, Wayback): https://web.archive.org/web/20170629151818/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility
- PRIMARY (lost wiki, Wayback): https://web.archive.org/web/20170629144509/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/igr
- PRIMARY (lost wiki, Wayback): https://web.archive.org/web/20170626021721/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats
- PRIMARY (lost wiki, Wayback): https://web.archive.org/web/20170629113247/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/cheat-engine
- PRIMARY (lost wiki, Wayback): https://web.archive.org/web/20170629130729/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/automated
- PRIMARY (krHACKen changelog, Wayback): https://web.archive.org/web/20170629142002/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter-changelog
- PRIMARY (config table, Wayback): https://web.archive.org/web/20170626021731/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table
- PRIMARY (IGR Trojans+Patches download thread, Wayback): https://web.archive.org/web/20230623044907/https://www.ps2-home.com/forum/viewtopic.php?t=9909
- PRIMARY (2020 PATCH_9 return-to-OPL thread, Wayback): https://web.archive.org/web/20230922122931/https://www.ps2-home.com/forum/viewtopic.php?f=54&t=127
- NEAR-PRIMARY (PAL-on-NTSC, ShaolinAssassin reply, Wayback): https://web.archive.org/web/20171013024531/http://www.ps2-home.com/forum/viewtopic.php?t=621
- MIRROR (community 'Manual POPSTARTER' Ed.2.3, Portuguese): https://pdfcoffee.com/manual-popstarter-pdf-free.html
- COMMUNITY (live, Cloudflare-blocked to bots, listed for canonical URL): https://www.ps2-home.com/forum/viewtopic.php?t=144
- COMMUNITY (canonical r13 WIP06 beta package + changelog): https://www.psx-place.com/resources/ps1-popstarter-r13-wip-06-beta-20160918.354/
- COMMUNITY (Wayback CDX index of all surviving wiki pages): http://web.archive.org/cdx/search/cdx?url=bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki*