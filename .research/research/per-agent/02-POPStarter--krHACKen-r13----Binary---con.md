# Research agent 2: POPStarter (krHACKen r13) — Binary / config-table offsets in POPSTARTER.ELF/.KELF + build & debug behavior

## Summary
FULLY RECONSTRUCTED. The 'lost' ShaolinAssassin Bitbucket config-table wiki was recovered intact from the Wayback Machine (snapshots 2017-06-26 through 2024-03-24; live page now 404). It documents the COMPLETE 32-byte POPStarter r13 configuration table from offset $410 to $42F (1040 dec), one byte per setting. Every offset, value and effect was cross-verified two ways: (1) against the recovered wiki text, and (2) against a byte-level hexdump of the actual POPSTARTER.ELF and .KELF shipped in the canonical 2019-06-05 r13 package (downloaded from archive.org item popstarter-r-13-beta-20190605), which also contains krHACKen's own 38KB CHANGES.TXT. The base report's four seed offsets are confirmed/corrected: $410 = debug-text display (00=off default, 01-FE=page delay, FF=realtime); $413 = USB access delay (default 0x02); $42A = PAL/480p (00=off, 01=auto-PAL default, 02=force 480p); and the big correction — $412 is the SetGsCrt/HDTVFIX hack in r13, NOT a 'function skipper'. The function skipper DID live at $412 but was REMOVED in WIP06 Beta 13 (2015-12-07) to save ~10KB; the freed byte was later repurposed for HDTVFIX (Beta 15/16, 2016). The USB-delay offset also migrated: the old PFS-wrapper delay was at $417 (default 0x05->0x00 across 2015 betas), while the embedded-USB-module access delay in final r13 is $413; $417 is now 'NOT USED'. The 'classic 00 vs debug FF' label is community shorthand but is grounded in the real $410 semantics (verified shipped byte = 0x00). Safe hex-patching recipes and the equivalent PPF bunch-pack on-load patches are included.

## Prose
RECONSTRUCTION STATUS: COMPLETE and HIGH-CONFIDENCE. This page is no longer 'lost' — the ShaolinAssassin Bitbucket config-table wiki survives in the Wayback Machine with 12 healthy 200-status snapshots between 2017-06-26 and 2024-03-24 (it only began 404-ing in 2025). I recovered its full text and, crucially, cross-checked every byte against a real hexdump of the canonical POPSTARTER.ELF/.KELF from the 2019-06-05 r13 package on archive.org, plus krHACKen's own CHANGES.TXT shipped inside that package.\n\nTHE TABLE. POPStarter r13 stores a single contiguous 32-byte configuration table at file offset 0x410 (1040 dec) through 0x42F. Each byte is one setting. The ELF (167,700 B) and KELF (167,708 B — the 8-byte delta is the KELF signature wrapper, not the table) carry byte-identical tables. The verified factory default table is: 00 00 00 02 40 00 03 01 | 00 00 00 00 00 00 00 00 | 01 00 01 01 01 01 01 01 | 01 00 01 01 01 01 01 03. Patch by direct hex edit of either file, or via the PPF bunch pack with PPF-O-Matic; always back up the original 32 bytes first (krHACKen's explicit warning).\n\nTHE FOUR BASE-REPORT SEEDS, ADJUDICATED. (1) $410 = debug text display: 00=off (this is the shipped default and the basis of the 'classic' label), 01-FE=delay per page (18 dec is a readable value), FF=realtime like POPStarter 12. The base's '$410->04 debug print' is imprecise: 04 would just be a short page delay, not an on/off flag. (2) $413 = USB access delay, default 0x02 — confirmed. (3) $42A: base said '02=480p' which is correct, but the byte is multi-valued — 00=PAL patcher off, 01=auto-PAL (default), 02=force 480p. (4) $412 'function skipper REMOVED in beta 13' — THE BIG ONE. The function skipper genuinely lived at $412 and was removed in WIP06 Beta 13 (2015-12-07, '...POPStarter function skipper (config table offset $412)... Saved about 10KB'). But that freed the byte, and by Beta 15/16 (2016) $412 was REPURPOSED as the SetGsCrt/HDTVFIX toggle. So in the canonical r13 build, $412 = HDTVFIX (default 0x00), and 'function skipper' is purely historical. Treat the base claim as a version-confusion, not a current fact.\n\nUSB DELAY — TWO OFFSETS, DON'T CONFLATE. The 2015 PFS-wrapper era put the USB delay at $417 (default 0x05 in Beta 2, dropped to 0x00 by Beta 8). The final r13 embeds the USB modules directly and its access delay is at $413 (default 0x02); $417 is documented 'NOT USED' (residual byte 0x01 in the shipped ELF). Old guides that say 'patch 417h for USB delay' describe the obsolete path. For a modern 'drive not detected' fix, patch $413. And note the critical caveat from the ps2-home debug tutorial: the $USBDELAY_# CHEATS.TXT command patches POPS (for smoother streaming during play) and does NOT make POPStarter see the drive — only the $413 ELF byte does that.\n\nDEBUG / BUILD BEHAVIOR. There is one binary; 'debug' vs 'classic' is the state of $410 (and optionally $411 halt-on-error). Canonical downloads ship classic ($410=00). To debug a non-booting game: hexedit $410 to FF (realtime) or ~12 (paced), or apply DEBUG_AND_HALT.PPF (sets $410 + $411 so it freezes on the diagnostic). SMB-mode setups effectively run debug-on already (per the tutorial). The debug screen reports which files load and where the launch fails. The 'classic 00 vs debug FF' phrase is community shorthand, but it's accurate and grounded — not a myth.\n\nHEX-PATCHING RECIPES (safe, common):\n- Force 480p: $42A = 02 (or $480p in CHEATS.TXT).\n- Fix HDTV green-screen over component: $412 = 01 (or $HDTVFIX).\n- USB drive not detected: raise $413 from 02 toward 05/0A/higher.\n- Read the debug screen: $410 = 12 (paced) or FF (realtime); add $411 = 01 to halt on error (or just apply DEBUG_AND_HALT.PPF).\n- Disable all auto-patching (clean slate for diagnosis): $42F = 00 (NO_AUTO_PATCH.PPF). LibCrypt-only: $42F = 02 (LC_ONLY.PPF).\n- Disable VMCs: $429 = 01 (NO_VMC.PPF); first VMC only: $429 = 02 (ONLY_1ST_VMC.PPF).\n- Hardcode compatibility modes globally: write mode bytes into $418-$41F (one per slot, up to 8). Per-game CHEATS.TXT $COMPATIBILITY_0x## is preferred. Remember modes 01/02/03/05 poke CD status and must not be combined.\n\nFor the static site, the 32 offset rows form a clean JSON table keyed by offset; the PPF bunch pack, the default-byte string, and the debug recipes are natural sidebars. Confidence is 'primary' on every offset because each is double-sourced (recovered wiki + live ELF hexdump).

## Entries (28)

```json
[
  {
    "name": "$410",
    "effect": "Display of the debug texts/pages. 0x00 = debug printing DISABLED (factory default of the 'classic' r13 ELF/KELF). 0x01..0xFE = delay between each page of debug text (higher = longer pause; ~0x12/18 dec is a readable value). 0xFF = debug texts shown in realtime with no delay (the behavior of POPStarter 12 and lower).",
    "scope": "POPSTARTER.ELF / .KELF, config-table byte 1 of 32 (offset 0x410 = 1040 dec). r13 (all builds since the table was relaid). SMB-mode distributions ship with debug effectively enabled; USB/iHDD users must turn it on.",
    "conflicts": "This is the entire basis of the community 'classic 00 vs debug FF' label: 00 = silent build, FF = realtime-debug build. Setting a mid delay (15-25 dec) is the practical fix when debug text scrolls too fast to read. Equivalent to applying DEBUG_AND_HALT.PPF (which also halts on error). No conflict with other bytes.",
    "provenance": "PRIMARY: ShaolinAssassin wiki 'configuration-table' via Wayback https://web.archive.org/web/20170626021731/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table and /web/20220321112104/ (same text). Default byte 0x00 verified by direct hexdump of POPSTARTER.ELF in archive.org item popstarter-r-13-beta-20190605. Community delay-value advice: ps2-home debug tutorial https://web.archive.org/web/20190808161830/http://www.ps2-home.com/forum/viewtopic.php?t=5311",
    "confidence": "primary",
    "example": "Hex-edit POPSTARTER.ELF: set byte at file offset 0x410 to 12 (hex, =18 dec) for paced debug pages, or FF for realtime. Equivalent prebuilt patch: apply DEBUG_AND_HALT.PPF with PPF-O-Matic."
  },
  {
    "name": "$411",
    "effect": "Break/halt POPStarter execution after an error has occurred. 0x00 = print the error message briefly, then kick the user to the PS2 OSD (browser). 0x0X (non-zero) = print the error message and sleep on that screen indefinitely (lets you read it).",
    "scope": "POPSTARTER.ELF/.KELF config-table byte at offset 0x411. r13. Default 0x00.",
    "conflicts": "Pairs with $410: DEBUG_AND_HALT.PPF sets both $410 (show debug) and $411 (halt on error) so a failing launch freezes on its diagnostic screen instead of bouncing to OSD.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017-06-26 / 2022-03-21 snapshots). Default 0x00 verified by ELF hexdump (r13 2019-06-05).",
    "confidence": "primary",
    "example": "Set 0x411 to 0x01 to freeze on the error/debug screen when a game fails to boot."
  },
  {
    "name": "$412",
    "effect": "SetGsCrt hack (the feature exposed as the $HDTVFIX cheat). 0x00 = disabled (default). 0x01 = enabled. Forces a static interlace parameter to help HDTVs/LED TVs that cannot handle POPS interlaced resolutions over component (otherwise show plain green screens / garbage).",
    "scope": "POPSTARTER.ELF/.KELF config-table byte at offset 0x412. r13. Default 0x00. Implemented Beta 15 (2016-09-18), made opt-in/default-off Beta 16 (2016-11-20).",
    "conflicts": "IMPORTANT HISTORY: in PRE-r13 builds offset 0x412 held the 'POPStarter function skipper', which krHACKen REMOVED in WIP06 Beta 13 (2015-12-07) to save ~10KB. The freed offset 0x412 was later REPURPOSED for the SetGsCrt/HDTVFIX hack. So 'function skipper at 0x412' is true only as pre-Beta-13 history; in the canonical 2019 r13 ELF, 0x412 = HDTVFIX. krHACKen warns SetGsCrt is INCOMPATIBLE with some CRT TVs (hence default-off). Equivalent to the $HDTVFIX CHEATS.TXT command.",
    "provenance": "PRIMARY: function-skipper removal = r13 CHANGES.TXT, 2015/12/07 (WIP06 Beta 13): 'Removed... POPStarter function skipper (config table offset $412)... Saved about 10KB'. HDTVFIX reassignment = CHANGES.TXT 2016/11/20 (Beta 16): 'patch the offset 412h of the ELF/KELF (0x00 == disabled, 0x01 == enabled)' and SetGsCrt in 2016/09/18 (Beta 15). Wiki config-table (Wayback 2017/2022) lists 0x412 = 'SetGsCrt hack'. CHANGES.TXT shipped inside archive.org popstarter-r-13-beta-20190605.",
    "confidence": "primary",
    "example": "$HDTVFIX in CHEATS.TXT, OR hex-edit POPSTARTER.ELF byte 0x412 = 0x01, to fix green-screen on a component HDTV. Leave 0x00 on CRTs."
  },
  {
    "name": "$413",
    "effect": "USB access delay applied AFTER the execution of POPStarter's embedded USB modules (i.e. how long POPStarter waits before reaching the USB device). Default 0x02. Increase if POPStarter fails to access your USB device.",
    "scope": "POPSTARTER.ELF/.KELF config-table byte at offset 0x413. r13 final. Default value 0x02 verified in shipped ELF. USB operation mode.",
    "conflicts": "DO NOT confuse with the $USBDELAY_# CHEATS.TXT command: $USBDELAY_# patches POPS (smooths gameplay/streaming) and does NOT help POPStarter SEE the drive. Only the $413 ELF byte fixes a 'can't find USB device' failure. Also distinct from the old PFS-wrapper USB delay that lived at offset 0x417 in the 2015 betas (see $417).",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): '$413 ... USB access delay ... 0x02 should be fine. Increase the value if POPStarter fails to access your USB device'. Default 0x02 verified by ELF hexdump (r13 2019-06-05). $USBDELAY-vs-$413 distinction: ps2-home debug tutorial (Wayback 2019-08-08).",
    "confidence": "primary",
    "example": "USB drive not detected: hex-edit POPSTARTER.ELF byte 0x413 from 02 up to e.g. 05, 0A, or higher until the drive mounts."
  },
  {
    "name": "$414",
    "effect": "RESERVED (in USB operation mode). Must be 0x40. Not a user tunable.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x414. r13. Default 0x40 (verified).",
    "conflicts": "Changing it can break USB operation. Leave at 0x40.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): '$414 RESERVED (in USB operation mode) Must be 0x40'. Default 0x40 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$415",
    "effect": "User ID for individual VMCs. 0x00 = function disabled (default). To assign an ID to the VMC pair, set this byte to the ASCII code of a digit '0'..'9' (0x30..0x39).",
    "scope": "POPSTARTER.ELF/.KELF byte 0x415. r13. Default 0x00.",
    "conflicts": "Lets multiple users keep separate VMCs from the same game install. Value must be a literal ASCII digit byte (e.g. 0x31 for '1'), not the raw number 0x01.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): '$415 User ID for individual VMCs ... value must be an ASCII character of 0..9'. Default 0x00 verified by ELF hexdump.",
    "confidence": "primary",
    "example": "Set 0x415 = 0x32 (ASCII '2') so this build creates/uses VMCs tagged for user 2."
  },
  {
    "name": "$416",
    "effect": "POPS dev9 module loading (in USB operation mode). 0x00 = let POPS load dev9. 0x03 = forbid its loading (default = 0x03). Set 0x00 to wake the NIC up (e.g. for debugging).",
    "scope": "POPSTARTER.ELF/.KELF byte 0x416. r13. Default 0x03 (verified).",
    "conflicts": "Only relevant in USB mode. Default 0x03 keeps dev9/NIC off during USB play.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): '$416 POPS dev9 module loading ... Default is 0x03 ... set this to 0x00' to wake the NIC. Default 0x03 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$417",
    "effect": "Marked 'NOT USED' in the r13 config-table wiki (vestigial). HISTORICALLY this was the PFS-wrapper USB delay (PFS_WRAP.BIN era): default hardcoded 0x05 in Beta 2 (2015-06-25), later changed to 0x00 in Beta 8 (2015-10-23). In the final r13 ELF the byte reads 0x01 and the live USB delay moved to $413.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x417. r13 wiki = NOT USED; 2015 betas = PFS-wrapper USB delay. Shipped r13 byte = 0x01 (verified).",
    "conflicts": "This is the source of the 'USB delay at 417h' claim seen in old guides; it applied to the external PFS_WRAP.BIN delay, NOT the embedded-USB-module access delay (which is $413 in r13). Do not patch 0x417 expecting a USB-detect fix in r13 — use $413.",
    "provenance": "PRIMARY: r13 CHANGES.TXT 2015/06/25 (Beta 2) 'offset 417h value is the USB delay used by the PFS wrapper r3 (default hardcoded value is 0x05)' and 2015/10/23 (Beta 8) 'the default USB delay value of the PFS wrapper (in the config table, offset 417h of the ELF) is zero'. Wiki (2017/2022) lists $417 = 'NOT USED'. Shipped byte 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$418-$41F (8 bytes)",
    "effect": "Force a single compatibility mode (one byte per slot, 8 slots = force up to 8 compatibility modes simultaneously). Per byte: 0x00 = no mode forced; 0x0X = force that compatibility mode AND disable the automatic activator.",
    "scope": "POPSTARTER.ELF/.KELF bytes 0x418 through 0x41F. r13. All default 0x00 (verified). The 8-slot design was added in WIP 02 (2014-08-22): 'configuration table now allows you to force up to 8 compatibility modes together'.",
    "conflicts": "Hardcoded equivalent of writing $COMPATIBILITY_0x## lines in CHEATS.TXT. CRITICAL: modes 0x01/0x02/0x03/0x05 poke CD status and MUST NOT be combined with each other. Forcing any mode here disables POPStarter's automatic per-game mode activator unless $42F is tuned to still apply forced modes.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): eight consecutive '$418..$41F Force a single compatibility mode' rows. 8-mode design = CHANGES.TXT 2014/08/22 (WIP 02). All-zero default verified by ELF hexdump.",
    "confidence": "primary",
    "example": "To hardcode mode 0x04 + mode 0x06 globally: 0x418 = 0x04, 0x419 = 0x06 (rest 0x00). Prefer per-game CHEATS.TXT $COMPATIBILITY_0x04 unless you want a global build."
  },
  {
    "name": "$420",
    "effect": "Patch the genuine HDD check. 0x00 = don't patch. 0x01 = patch (default). Effectively a no-op for end users: on a PS2 a homebrew ATAD is used; on a PSX the original POPS ATAD is used. krHACKen: 'Totally useless... Leave it to 0x01'.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x420. r13. Default 0x01 (verified).",
    "conflicts": "No practical reason to change.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$421",
    "effect": "Loading/execution of the OSD shell of the POPS built-in BIOS. 0x00 = load into user memory and execute (don't patch). 0x01 = don't load/don't execute (default 0x00). 0x01 has the same effect as compatibility mode 0x06 — skips CD checks and the PS logo. Neither value works if the user supplies a BIOS.BIN.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x421. r13. Default 0x00 (verified).",
    "conflicts": "Hardcoded equivalent of compatibility mode 0x06 / $COMPATIBILITY_0x06. Overridden by a user BIOS.BIN.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x00 verified by ELF hexdump.",
    "confidence": "primary",
    "example": "Set 0x421 = 0x01 to globally skip the BIOS OSD shell / PS logo (same as mode 6)."
  },
  {
    "name": "$422",
    "effect": "Exception breakpoints control. 0x00 = break the emulator (default 0x01 in shipped ELF). 0x01 = NOP the break instructions of the 2nd-stage exception handler, allowing the user to trigger IGR after the emulation has crashed (in a few cases).",
    "scope": "POPSTARTER.ELF/.KELF byte 0x422. r13. Shipped default 0x01 (verified).",
    "conflicts": "Debug/recovery aid. Lets you IGR out of a crashed emulator instead of a hard hang in some cases.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$423",
    "effect": "Original SLBB-00001 disc0 integrity check control. 0x00 = don't skip the integrity check. 0x01 = skip it (shipped default 0x01).",
    "scope": "POPSTARTER.ELF/.KELF byte 0x423. r13. Default 0x01 (verified).",
    "conflicts": "Relates to the PSX/PSBBN SLBB-00001 boot disc path.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$424",
    "effect": "IGR exit method. 0x00 = original SLBB-00001+PSBBN method (reads MBR itself, no cache flush, no IOP reset — 'crashy for most users'). 0x01 = POPStarter r13 method (shipped default 0x01).",
    "scope": "POPSTARTER.ELF/.KELF byte 0x424. r13. Default 0x01 (verified).",
    "conflicts": "The r13 IGR method (0x01) is what enables the mc0:/BOOT/BOOT.ELF -> mc1:/BOOT/BOOT.ELF -> OSDSYS exit chain introduced in Beta 13 (2015-12-07). Leaving 0x00 reproduces the old crashy exit.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). BOOT.ELF launcher = CHANGES.TXT 2015/12/07. Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$425",
    "effect": "IOPCD stack size patch (in USB operation mode). 0x00 = don't patch. 0x01 = patch (shipped default 0x01).",
    "scope": "POPSTARTER.ELF/.KELF byte 0x425. r13. Default 0x01 (verified). USB mode.",
    "conflicts": "",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$426",
    "effect": "Delcro's patches (in USB operation mode). 0x00 = don't apply to POPS. 0x01 = apply to POPS (shipped default 0x01).",
    "scope": "POPSTARTER.ELF/.KELF byte 0x426. r13. Default 0x01 (verified). USB mode.",
    "conflicts": "",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$427",
    "effect": "Emulator modules loading-failure behavior. 0x00 = don't patch (kick to PS2 OSD). 0x01 = patch: ignore the returned code of an injected IRX and continue (shipped default 0x01). 'For your h4x0ring needz.'",
    "scope": "POPSTARTER.ELF/.KELF byte 0x427. r13. Default 0x01 (verified).",
    "conflicts": "Developer/modder convenience for custom injected IRX modules.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$428",
    "effect": "Internal HDD initialization-failure behavior. 0x00 = don't patch (kick to PS2 OSD). 0x01 = patch: ignore and continue (shipped default 0x01). 'For your h4x0ring needz.'",
    "scope": "POPSTARTER.ELF/.KELF byte 0x428. r13. Default 0x01 (verified).",
    "conflicts": "",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$429",
    "effect": "Virtual Memory Cards control. 0x00 = use both VMCs (default). 0x01 = don't use VMCs at all. 0x02 = use only the first VMC in the first virtual slot.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x429. r13. Default 0x00 (verified).",
    "conflicts": "Hardcoded equivalent of the $NOVMC0/$NOVMC1 cheats. PPF equivalents: NO_VMC.PPF (=0x01) and ONLY_1ST_VMC.PPF (=0x02).",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): '$429 Virtual Memory Cards control ... 0x00 both, 0x01 none, 0x02 just first'. PPF names from same wiki's PPF bunch-pack section. Default 0x00 verified by ELF hexdump.",
    "confidence": "primary",
    "example": "Disable all VMCs globally: 0x429 = 0x01 (or apply NO_VMC.PPF)."
  },
  {
    "name": "$42A",
    "effect": "Automatic PAL patch upon European VCD recognition / video-mode forcing. 0x00 = disabled. 0x01 = enabled (default; auto-PAL when 'Euro' is found at VCD offset $102514). 0x02 = FORCE 480p output.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x42A. r13. Default 0x01 (verified). 480p calc added Beta 15 (2016-09-18).",
    "conflicts": "0x02 (480p) is the hardcoded equivalent of the $480p CHEATS.TXT command; krHACKen notes it cannot be done via a PATCH_#.BIN. Setting 0x00 disables the auto-PAL patcher (equivalent of $NOPAL / NO_PAL.PPF). Some games (e.g. Dead Or Alive) output an unsupported signal in 480p. Auto-PAL expects literal 'Euro' at VCD offset 0x102514.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): '$42A ... 0x00 Disabled / 0x01 Enabled / 0x02 Force 480p'. 480p recipe also in CHANGES.TXT 2016/09/18 and 2016/11/20 ('0x02 at the offset $42A'). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": "Force 480p: hex-edit POPSTARTER.ELF byte 0x42A = 0x02 (or put $480p in CHEATS.TXT). Disable PAL patcher globally: 0x42A = 0x00 (or $NOPAL)."
  },
  {
    "name": "$42B",
    "effect": "Resident modules loader. 0x00 = disabled. 0x01 = enabled (shipped default 0x01). Loads POPS/MODULE_0.IRX .. POPS/MODULE_9.IRX AFTER the IOP is reset with IOPRP252.IMG.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x42B. r13. Default 0x01 (verified).",
    "conflicts": "Enables the MODULE_#.IRX user-driver injection system (kills matching embedded POPS drivers). Bugfixed/re-fixed across WIP06 and RIP06.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): '$42B Resident modules loader ... POPS/MODULE_0.IRX ... up to MODULE_9.IRX ... AFTER the IOP gets reset with IOPRP252.IMG'. Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$42C",
    "effect": "Software PowerOff fix. 0x00 = disabled. 0x01 = enabled (shipped default 0x01). Purpose uncertain even to the author ('Can't remember... Perhaps redundant... Prolific, mass?').",
    "scope": "POPSTARTER.ELF/.KELF byte 0x42C. r13. Default 0x01 (verified).",
    "conflicts": "Author admits ambiguity about what this actually does (possibly Prolific/mass-storage related poweroff).",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$42D",
    "effect": "IGR textures loader. 0x00 = disabled. 0x01 = enabled (shipped default 0x01). Loads POPS/IGR_BG.TM2, POPS/IGR_NO.TM2, POPS/IGR_YES.TM2 for the IGR menu skin.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x42D. r13. Default 0x01 (verified).",
    "conflicts": "PPF equivalent to disable: DEFAULT_IGR_TEXTURES.PPF (sets 0x00, reverts to built-in IGR textures).",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): '$42D IGR textures loader ... POPS/IGR_BG.TM2 POPS/IGR_NO.TM2 POPS/IGR_YES.TM2'. PPF name from same wiki. Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$42E",
    "effect": "Game license/region check of the POPS built-in BIOS. 0x00 = leave unpatched. 0x01 = patch so it does not loop the check when the VCD isn't NTSC-J (shipped default 0x01). The patch NOPs the loop; the PS logo is not shown when a non-JAP game is run.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x42E. r13. Default 0x01 (verified).",
    "conflicts": "Trade-off: enabling region-free skips the PS logo for non-JP titles.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022). Default 0x01 verified by ELF hexdump.",
    "confidence": "primary",
    "example": ""
  },
  {
    "name": "$42F",
    "effect": "POPStarter automatic compatibility-mode activator (master switch). 0x00 = enable nothing. 0x01 = enable automatic compatibility-mode activation. 0x02 = enable the other subroutines (e.g. LibCrypt cracks when available). 0x03 = enable ALL (shipped default 0x03). 0x04 = enable 'test mode'. Special case: if 0x03 AND a mode is force-set in $418-$41F, it auto-changes to 0x02 (applies the forced modes, not the automatic ones). 'Test mode' (0x04) disables per-game fixes, automated compat modes and LibCrypt fixes, and enables integrated test-hacks.",
    "scope": "POPSTARTER.ELF/.KELF byte 0x42F (last byte of the 32-byte table). r13. Default 0x03 (verified). 0x04 'test mode' added WIP06 Prototype 2 (2017-05-27).",
    "conflicts": "PPF equivalents: NO_AUTO_PATCH.PPF (=0x00, disables everything), LC_ONLY.PPF (=0x02, LibCrypt only, no compat modes), NO_LC_CRACKS.PPF (disables built-in LC cracks + automated modes). 0x04 is a developer/diagnostic mode that strips all normal fixes — not for normal play. The 0x04 'test mode' value was NOT present in the 2016-11-20 wiki snapshot but appears in later snapshots and in CHANGES.TXT (Prototype 2/3).",
    "provenance": "PRIMARY: Wayback config-table wiki (2022-03-21 snapshot lists 0x04 test mode; 2017-06-26 snapshot lists 0x00-0x03 only). Test mode at 42Fh = CHANGES.TXT 2017/05/27 (Proto 2) and 2017/05/30 (Proto 3): 'test mode, value 04h at ELF/KELF offset 42Fh'. PPF names = wiki PPF bunch-pack. Default 0x03 verified by ELF hexdump.",
    "confidence": "primary",
    "example": "Disable all automatic patching globally: 0x42F = 0x00 (or apply NO_AUTO_PATCH.PPF). LibCrypt-only build: 0x42F = 0x02 (or LC_ONLY.PPF)."
  },
  {
    "name": "Config table location/size",
    "effect": "The POPStarter r13 ELF and KELF contain a 32-byte configuration table starting at file offset $410 (1040 decimal) and running through $42F. Every byte is one setting; values are patched directly (hex edit) or via on-load patches. There is NO documented offset above $42F — the table is exactly 32 bytes.",
    "scope": "POPSTARTER.ELF and POPSTARTER.KELF, r13. The ELF (167700 B) and KELF (167708 B) in the 2019-06-05 package carry byte-identical config tables.",
    "conflicts": "krHACKen warning: 'Unless you know exactly what it is for... please don't tamper with it... Make a backup of the default config before you start changing values.' Always back up before hex-editing.",
    "provenance": "PRIMARY: Wayback config-table wiki (2017/2022): 'The POPStarter r13 ELF and KELF have a 32 bytes long configuration table, starting from the offset $410 (or 1040 in decimal).' Table bounds + ELF==KELF equality verified by direct hexdump of both files in archive.org popstarter-r-13-beta-20190605.",
    "confidence": "primary",
    "example": "Default 32-byte table (r13 2019-06-05), $410..$42F: 00 00 00 02 40 00 03 01 00 00 00 00 00 00 00 00 01 00 01 01 01 01 01 01 01 00 01 01 01 01 01 03"
  },
  {
    "name": "PPF bunch pack (on-load patches)",
    "effect": "krHACKen/ShaolinAssassin shipped a set of .PPF patches (apply over POPSTARTER.ELF with PPF-O-Matic) that toggle config-table bytes without manual hex editing: NO_LC_CRACKS.PPF (disable built-in LC cracks + automated modes), DEBUG_AND_HALT.PPF (set $410 debug print + $411 halt), NO_VMC.PPF ($429=01), ONLY_1ST_VMC.PPF ($429=02), NO_PAL.PPF ($42A=00), FORCE_MODEX.PPF (hardcode a mode into $418-$41F), DEFAULT_IGR_TEXTURES.PPF ($42D=00), LC_ONLY.PPF ($42F=02), NO_AUTO_PATCH.PPF ($42F=00).",
    "scope": "Applied to POPSTARTER.ELF/.KELF, r13 (DEBUG_AND_HALT and NO_LC_CRACKS noted 'from WIP05'; the rest 'new' as of the 2016-11-20 wiki).",
    "conflicts": "PPF-O-Matic is flagged by some AV (false positive, per ps2-home tutorial). These are the user-friendly equivalent of the hex offsets above; do not stack contradictory ones.",
    "provenance": "PRIMARY: ShaolinAssassin wiki PPF bunch-pack section, Wayback 2017-06-26 snapshot (https://web.archive.org/web/20170626021731/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table). DEBUG_AND_HALT usage = ps2-home debug tutorial (Wayback 2019-08-08).",
    "confidence": "primary",
    "example": "Use PPF-O-Matic to apply DEBUG_AND_HALT.PPF onto POPSTARTER.ELF to turn on the diagnostic screen instead of hand-editing $410/$411."
  },
  {
    "name": "'classic 00 vs debug FF' build label",
    "effect": "Community shorthand for the two states of config byte $410: a 'classic' build ships with $410=0x00 (debug printing OFF, silent boot) and a 'debug' build has $410=0xFF (realtime debug text, the old POPStarter-12 behavior). It is NOT a separate codebase — same ELF, one byte differs (plus optionally $411 for halt).",
    "scope": "POPSTARTER.ELF/.KELF byte $410. The canonical r13 download ships 'classic' ($410=00). SMB-mode setups effectively run with debug on.",
    "conflicts": "VERDICT: the LABEL itself is community shorthand (not literal krHACKen terminology), but it is FULLY GROUNDED in the primary $410 semantics — the wiki explicitly states 0x00=off and 0xFF=realtime, and the shipped ELF byte is 0x00. So 'classic vs debug' is an accurate, if informal, description, not a myth. The only nuance the label glosses over: any value 0x01-0xFE gives PACED debug (not just the 00/FF extremes), and DEBUG_AND_HALT also flips $411.",
    "provenance": "near-primary: derived from PRIMARY $410 definition (Wayback config-table wiki 2017/2022) + verified shipped byte 0x00 (ELF hexdump) + community debug practice (ps2-home tutorial, Wayback 2019-08-08). The exact phrase 'classic 00 vs debug FF' is community usage, corroborated but not a verbatim krHACKen string.",
    "confidence": "near-primary",
    "example": "'Classic': $410=00. 'Debug (realtime)': $410=FF. 'Debug (readable/paced)': $410=12 (18 dec)."
  }
]
```

## New findings

- RECOVERED the entire 'lost' config-table wiki page from Wayback (12 good snapshots 2017-2024; live now 404). It is NOT actually lost — full text retrievable. Snapshot URLs captured for every claim.
- The config table is EXACTLY 32 bytes, $410-$42F. There is NO offset above $42F. Earlier reports implying scattered offsets are wrong — it's one contiguous table.
- Captured ALL 32 default bytes by hexdumping the real shipped r13 ELF: 00 00 00 02 40 00 03 01 00 00 00 00 00 00 00 00 01 00 01 01 01 01 01 01 01 00 01 01 01 01 01 03. ELF and KELF config tables are byte-identical.
- MAJOR CORRECTION to base report: $412 in r13 = SetGsCrt/HDTVFIX hack (default 0x00), NOT 'function skipper'. The function skipper was at $412 only in PRE-Beta-13 builds and was REMOVED 2015-12-07; $412 was then REPURPOSED for HDTVFIX. Both facts are true at different times — the base report conflated them.
- CORRECTION: the USB-delay story spans TWO offsets. $413 = embedded-USB-module access delay (r13, default 0x02). $417 = the OLD PFS-wrapper USB delay (2015 betas, default 0x05 then 0x00) and is marked 'NOT USED' in r13. Old guides citing '417h' refer to the obsolete PFS-wrapper delay.
- Recovered SIXTEEN previously-undocumented (in the base report) offsets: $411 (break-on-error/halt), $414 (RESERVED=0x40), $415 (per-VMC user ID, ASCII digit), $416 (POPS dev9 loading), $418-$41F (8-byte force-compatibility-mode array), $420 (HDD check), $421 (BIOS OSD shell = mode-6 equivalent), $422 (exception breakpoints/IGR-after-crash), $423 (SLBB-00001 integrity), $424 (IGR exit method — gates the BOOT.ELF chain), $425 (IOPCD stack), $426 (Delcro patches), $427/$428 (module/HDD failure ignore), $429 (VMC control), $42B (MODULE_#.IRX resident loader), $42C (software poweroff), $42D (IGR textures), $42E (region/license check), $42F (auto-patch master switch incl. 0x04 test mode).
- Recovered the PPF BUNCH PACK: ready-made on-load patches (DEBUG_AND_HALT, NO_VMC, ONLY_1ST_VMC, NO_PAL, FORCE_MODEX, DEFAULT_IGR_TEXTURES, LC_ONLY, NO_AUTO_PATCH, NO_LC_CRACKS) that map to specific config bytes — the user-friendly alternative to hex editing. Recovered from the 2017 wiki snapshot.
- Verdict on 'classic 00 vs debug FF': it IS community shorthand (not verbatim krHACKen), but it is ACCURATE — grounded in the wiki's $410 definition and the verified shipped byte 0x00. Nuance: values 0x01-0xFE give paced (not just 00/FF) debug, and SMB-mode distributions effectively ship debug-on.
- KEY CAVEAT recovered: the $USBDELAY_# CHEATS.TXT command patches POPS (gameplay smoothing), NOT POPStarter, so it does NOT fix 'USB drive not detected' — only the $413 ELF byte does. The base report listed $USBDELAY_# without this distinction.
- 0x42F 'test mode' value 0x04 was added in WIP06 Prototype 2 (2017-05-27) and appears in the 2022 wiki snapshot but NOT the 2016 snapshot — a documented table evolution.
- $424 (IGR exit method = 0x01 'r13 method', default) is what enables the mc0:->mc1:/BOOT/BOOT.ELF->OSDSYS exit chain from Beta 13. Connects the config table to the IGR/exit behavior topic.

## Gaps

- The 'Default values:' image/table on the wiki (a graphic listing all defaults) is referenced but rendered as an image in the snapshots; I reconstructed the defaults instead from the shipped ELF hexdump (more authoritative anyway). The original default-values GRAPHIC was not OCR'd.
- The PPF bunch-pack files (NO_VMC.PPF etc.) themselves were not downloaded/binary-verified; their config-byte mappings are inferred from the wiki descriptions + the matching offset semantics, not from disassembling each PPF.
- $417's shipped byte is 0x01 while the wiki says 'NOT USED' and old betas used it for PFS-wrapper delay — the exact meaning of the residual 0x01 in the final r13 ELF is not documented (likely vestigial); not independently confirmed.
- $42C 'Software PowerOff fix' — even krHACKen could not remember its exact function; no primary explanation exists.
- Whether any community 'debug' prebuilt ELF was distributed with $410 pre-set to FF (vs users patching it themselves) is not firmly established; the canonical download is 'classic' (00) and debug is enabled via PPF/hexedit or comes pre-on in SMB setups.
- The exact origin phrase 'classic 00 vs debug FF' could not be traced to a single verbatim krHACKen post; it is community usage corroborated by the $410 semantics.

## Sources

- https://web.archive.org/web/20170626021731/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table (PRIMARY — recovered config-table wiki, updated 2016-11-20, incl. PPF bunch pack)
- https://web.archive.org/web/20220321112104/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table (PRIMARY — later config-table wiki snapshot, updated 2018-07-26, incl. 0x42F test-mode 0x04)
- http://web.archive.org/cdx/search/cdx?url=bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table (PRIMARY index — 12 snapshots 2017-06-26..2024-03-24, all HTTP 200; 2025-08-25 = 404)
- https://archive.org/details/popstarter-r-13-beta-20190605 (PRIMARY — canonical r13 2019-06-05 package: POPSTARTER.ELF, POPSTARTER.KELF, CHANGES.TXT)
- https://archive.org/download/popstarter-r-13-beta-20190605/POPStarter_r13_Beta_20190605.zip (PRIMARY — actual binaries hexdumped for default config-table bytes)
- https://web.archive.org/web/20190808161830/http://www.ps2-home.com/forum/viewtopic.php?t=5311 (near-primary — ps2-home POPSTARTER DEBUG troubleshooting tutorial: $410 delay values, DEBUG_AND_HALT.PPF, $413 vs $USBDELAY_#, SMB debug-on)
- https://pdfcoffee.com/manual-popstarter-pdf-free.html (mirror — POPStarter manual v2.3, PT-BR: confirms 0x42A=480p and 0x412=HDTVFIX)
- https://www.scribd.com/document/922268974/manual-popstarter (mirror — same manual v2.3)
- https://www.ps2-home.com/forum/viewtopic.php?t=1819 (community — krHACKen POPStarter Betas changelog thread; corroborates Beta 13 function-skipper removal and offsets)
- https://pastebin.com/719TCAd5 (community — WIP06 beta changelog mirror corroborating $417 PFS-wrapper USB delay default 0x05/0x00)
- https://www.psx-place.com/threads/popstarter.19139/ (community — main POPStarter thread)
- https://www.psx-place.com/resources/ps1-popstarter-r13-wip-06-beta-20160918.354/ (community — r13 WIP06 beta resource)