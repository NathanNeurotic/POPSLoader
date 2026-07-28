# Research agent 5: VMC + VMCDIR.TXT + DISCS.TXT + multi-folder POPS + VMC grouping + edge cases (POPStarter)

## Summary
Fully recovered and verified the VMC/VMCDIR.TXT/DISCS.TXT topic from the ORIGINAL ShaolinAssassin Bitbucket wiki via the Wayback Machine (web.archive.org CDX API + id_ raw snapshots). Every base fact is confirmed primary-source: VMCDIR.TXT = one line, <=103 bytes, no / \\ :, target stays inside POPS, other assets stay in the game folder; DISCS.TXT = up to 4 lines (>4 breaks it), VCD filename <=89 chars, all VCDs same partition, copy to every disc folder; OSD.BIN beats BIOS.BIN ('BIOS.BIN is ignored'). Disc-swap hotkeys decoded byte-exact from archived button-glyph image filenames: Select+L2+R2 + Triangle(open)/Up(D1)/Right(D2)/Down(D3)/Left(D4)/Square(close). Found substantial NEW material the base missed: VMCs are SLOT0.VMC(port1)+SLOT1.VMC(port2) with PS1 retail saves imported into SLOT1.VMC; offset $429 (not $42A) sets how many VMCs are created (2/1/none); the full OSD.BIN v1 header structure; the 'flashes the whole VMC' mechanism explaining why shared VMCDIRs are data-safe; the POPS-vs-VMC-folder priority rule with its single CHEATS.TXT video-mode exception; the multi-folder POPS0..POPS9 caveat that VMCDIR/BIOS/PATCH/TROJAN must be duplicated into every POPS# folder while POPS_IOX.PAK+TM2s stay in main POPS; HDD VMCs live in __common/POPS/; and the DISCS_POOPER.EXE automation tool.

## Prose
RECOVERY METHOD (reusable for the whole corpus): WebFetch is blocked from web.archive.org, and ps2-home.com returns 403 to WebFetch, but the original ShaolinAssassin Bitbucket wiki is fully recoverable via curl against the Wayback CDX API plus the 'id_' raw-snapshot modifier. The CDX query 'http://web.archive.org/cdx/search/cdx?url=bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki&matchType=prefix&output=text&fl=original,timestamp,statuscode' returns the entire wiki page index with snapshot timestamps; then 'https://web.archive.org/web/<timestamp>id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/<page>' returns the raw archived HTML, from which '<' tags can be stripped and the body cut at 'window.__initial_state__'. Button-combo hotkeys that render as images (not text) are recoverable by grepping the raw HTML for the archived glyph filenames (e.g. Playstation-Button-Select.png, Playstation-Dpad-Up.png, Playstation-Button-S.png), which decode the exact controller sequence. This same technique should drive tasks #4/#5 (recovering the downloadables and embedded textures): the downloads CDX (url=...popstarter-documentation-stuff/downloads*) already surfaced discs_pooper.exe, batcher_0.3.1.exe, cheats.txt, compatibility_modes.7z, cue2pops_2.3.7z, debug_and_halt.ppf, disc_combining_kits.7z and more, all with statuscode 302->retrievable.\n\nMENTAL MODEL FOR THE SITE: There are exactly two asset locations - the POPS folder (global, all games) and the per-game VMC/game folder - and a single override rule (VMC folder wins, with the lone CHEATS.TXT-video-mode exception). VMCDIR.TXT only relocates the SLOT0/SLOT1 VMC pair; every other asset still loads from the game folder. Put VMCDIR.TXT in POPS root to collapse the whole library onto one shared VMC pair (per-user save sets, or shared saves), which is safe because POPS flashes the entire VMC rather than per-block. DISCS.TXT is the orthogonal multi-disc mechanism: up to 4 VCD names (same partition), copied to every disc folder, with hardware-style lid/disc hotkeys; pair it with a VMCDIR.TXT pointing all discs at disc 1's folder so a multi-disc game keeps one save card. The wiki's documented limits (103 bytes / 1 line for VMCDIR.TXT; 4 lines / 89-char names for DISCS.TXT) are firm; note POPSLoader's own testing shows the practical VCD-name ceiling is lower (~73) because it is a full-path buffer.\n\nVERSION ANCHORS worth carrying into the changelog topic: swap-disc = OBT 15; SMB launch type = PB13 WIP06 / OBT 08; __.POPS multi-VCD-per-partition HDD launch = POPStarter 13 WIP 01; OSD/BIOS handlers documented as of the 2016-11-18 page update.

## Entries (13)

```json
[
  {
    "name": "VMCDIR.TXT",
    "effect": "One-line text file placed in a game's VMC folder that redirects where POPS saves/reads the two VMC files (SLOT0.VMC + SLOT1.VMC). All other POPStarter assets (TROJANs, PATCHes, CHEATS.TXT) still load from the game folder; only the VMC pair is taken from the named destination folder. Target folder must remain inside the POPS folder. Forbidden chars: / \\ : . Not loaded if >103 bytes or >1 line.",
    "scope": "Per-game when placed in the game's VMC/game folder; GLOBAL (single shared VMC pair for ALL games) when placed in the POPS root folder. USB/SMB/HDD all supported. Destination folder must be one level under POPS.",
    "conflicts": "If placed in POPS root it is applied to every game and overrides per-game VMC isolation (but mounts/loads the existing VMCs without overwriting, so no data loss). When the same VMCDIR.TXT exists in both POPS root and the game folder, the game-folder copy wins (general priority rule). For multi-folder setups (POPS0..POPS9) it must be copied into every POPS# folder. Destination outside POPS is rejected.",
    "provenance": "ShaolinAssassin Bitbucket wiki 'vmc' page, archived snapshot 2017-06-29 (web.archive.org/web/20170629133617id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vmc). Verbatim: 'VMCDIR.TXT will not be loaded if it's bigger than 103 bytes or if it contains more than 1 line.' 'Characters that are obviously not allowed are / \\ and :' 'Target folder must remain in POPS folder.'",
    "confidence": "primary",
    "example": "Save 'BLAHBLAH' as VMCDIR.TXT into mass:/POPS/MY_GAME/  ->  POPS reads mass:/POPS/BLAHBLAH/SLOT0.VMC + SLOT1.VMC while TROJAN/PATCH/CHEATS still load from mass:/POPS/MY_GAME/"
  },
  {
    "name": "VMCDIR.TXT (shared VMC grouping)",
    "effect": "Multiple games point at one VMC folder so they share a single VMC pair (e.g. all FF8 discs, or a per-user save set). Place a VMCDIR.TXT naming the same destination folder into each game's folder.",
    "scope": "Per group of games (each game folder gets a VMCDIR.TXT naming the shared folder). Also used to give multiple users their own VMC folders for the same library.",
    "conflicts": "Shared VMCs are mounted/loaded, not overwritten, so simultaneous use across games is data-safe per the wiki. Do not point two simultaneously-running contexts at the same pair (single-console, so not an issue in practice).",
    "provenance": "wiki 'vmc' page (20170629133617). Verbatim: 'This feature is useful when you are several users and want to use different VMCs.' and the smb example with three games all using smb:/YourSharedFolder/POPS/SAVES/SLOT0.VMC via a POPS-root VMCDIR.TXT containing 'SAVES'.",
    "confidence": "primary",
    "example": "smb:/Share/POPS/VMCDIR.TXT contains 'SAVES'; Crash Bandicoot.VCD, Tekken.VCD, Castlevania.VCD all save into smb:/Share/POPS/SAVES/SLOT0.VMC + SLOT1.VMC"
  },
  {
    "name": "SLOT0.VMC / SLOT1.VMC",
    "effect": "The two virtual memory card image files POPS auto-creates on first launch, one folder per game named after the VCD (e.g. POPS/Crash Bandicoot/SLOT0.VMC). SLOT0 = memory card port 1, SLOT1 = port 2. PS1 retail saves imported via MemcardRex go into SLOT1.VMC per the wiki's PMC->VMC guide. Standard PS1 MC images, editable in MemcardRex.",
    "scope": "Per game by default. Created relative to the VCD: POPS/<GameName>/SLOTx.VMC. On HDD, inside __common/POPS/<vmcfolder>/.",
    "conflicts": "Number of VMCs created (2, 1, or none) is controlled by POPSTARTER.ELF hex offset $429, NOT $42A (which is 480p per the base config table). POPS does not save to a physical MC because it flashes the WHOLE VMC, not a single block.",
    "provenance": "wiki 'vmc' (20170629133617): 'a new folder named GAME ... contains 2 files - SLOT0.VMC & SLOT1.VMC ... change that behaviour to have only 1 VMC created - or not at all ... offset $429.' wiki 'pmc-to-vmc' (20170629154811): 'the VMC of your game (SLOT1.VMC, in POPS directory)'. wiki 'faqs' (20170629120342): 'POPS doesnt save on a single memory card block but flashes the whole VMC.'",
    "confidence": "primary",
    "example": "POPS/Crash Bandicoot.VCD  ->  POPS/Crash Bandicoot/SLOT0.VMC  +  POPS/Crash Bandicoot/SLOT1.VMC"
  },
  {
    "name": "DISCS.TXT",
    "effect": "Multi-disc swap list. One VCD filename per line (WITH .VCD extension), up to 4 lines = disc 1..4. Enables in-game disc swapping without a PS1 reboot (the swap-disc feature). Copy into the VMC/game folder of EVERY disc.",
    "scope": "Per multi-disc game. Must be copied to all disc folders (so launching from any disc gets the list). VCD files must be in the same partition/folder. Feature present since OBT 15 (open beta test 15).",
    "conflicts": "Hard cap of 4 lines: if DISCS.TXT has more than 4 lines the feature will not work. Each VCD filename must not exceed 89 characters (note: POPStarter's real usable path buffer is shorter in practice ~73 chars per POPSLoader's own findings, since it is a full-path buffer, not a bare-name buffer). For >4 discs, install first 4, play to disc 4, then swap in discs 5-7. .TXT must be uppercase. Without a PS1-reboot requirement you can just swap VMCs manually instead.",
    "provenance": "wiki 'multi-disc' (web.archive.org/web/20170626061653id_/.../wiki/multi-disc): 'Create a DISCS.TXT text file containing the file names of your VCDs, one file name per line (with VCD extension)' 'Up to 4 file names in DISCS.TXT.' 'A file name must not exceed 89 characters.' 'The VCD files have to be in the same partition/folder.' 'If you have more than 4 lines in the DISCS.TXT file, the feature will not work.' '~73 usable' nuance from POPSLoader memory note reference-vcd-filename-limit (#503).",
    "confidence": "primary",
    "example": "DISCS.TXT (in BOTH MGS_CD1/ and MGS_CD2/):\\nMGS_CD1.VCD\\nMGS_CD2.VCD"
  },
  {
    "name": "Disc-swap hotkey: Open lid",
    "effect": "Opens the virtual PS1 CD lid so a new disc can be inserted.",
    "scope": "In-game, multi-disc games with DISCS.TXT. OBT 15+.",
    "conflicts": "Note: a SEPARATE simpler 'open the PS1 CD lid' hotkey (Select+L2+R1) also exists in the general hotkeys table; the multi-disc open-lid combo below is the 4-button Triangle variant.",
    "provenance": "wiki 'hotkeys' (20170626021730) + 'multi-disc' (20170626061653); decoded from archived button-glyph image filenames (Playstation-Button-Select/L2/R2/T.png).",
    "confidence": "primary",
    "example": "Select + L2 + R2 + Triangle"
  },
  {
    "name": "Disc-swap hotkeys: Insert Disc 1/2/3/4 + Close lid",
    "effect": "Insert disc N (= DISCS.TXT line N), then close the lid to resume. Disc1=Up, Disc2=Right, Disc3=Down, Disc4=Left; close lid=Square.",
    "scope": "In-game, multi-disc games with DISCS.TXT. OBT 15+.",
    "conflicts": "D-pad direction maps to DISCS.TXT LINE number, not physical disc label; ordering in DISCS.TXT defines which direction loads which VCD. Close-lid glyph is Square (confirmed identical 'Playstation-Button-S.png' in both the multi-disc and hotkeys pages).",
    "provenance": "wiki 'multi-disc' (20170626061653) and 'hotkeys' (20170626021730), decoded from archived glyph filenames: Select+L2+R2 + {Up=3199916752, Right=2374122730, Down=202135531, Left=4108913469, Square=3011564833-Playstation-Button-S.png}.",
    "confidence": "primary",
    "example": "Insert Disc 2: Select + L2 + R2 + Right ; Close lid: Select + L2 + R2 + Square"
  },
  {
    "name": "VMCDIR.TXT for multi-disc (single VMC pair)",
    "effect": "Combine DISCS.TXT with a VMCDIR.TXT (naming disc 1's VMC folder) placed in every disc folder so all discs of one game share a single VMC pair - avoids manual VMC copy/paste between disc folders.",
    "scope": "Per multi-disc game. VMCDIR.TXT must be placed into disc 1 AND disc 2 (and any further disc) VMC folders, naming the disc-1 VMC folder.",
    "conflicts": "Required only when discs would otherwise have separate VMC folders; without it, saves made on disc 1 are not visible on disc 2 unless VMCs are manually copied. Same 103-byte/1-line/forbidden-char rules as any VMCDIR.TXT.",
    "provenance": "wiki 'multi-disc' (20170626061653): 'You can use the VMCDIR.TXT file to use only 1 pair of VMCs for a multi-disc game. This VMCDIR.TXT must be placed into disc 1 and disc 2 VMC folders.'",
    "confidence": "primary",
    "example": "MGS/VMCDIR.TXT and MGS_2/VMCDIR.TXT both contain 'MGS' (disc-1 folder name) -> both discs save into POPS/MGS/SLOT0.VMC+SLOT1.VMC"
  },
  {
    "name": "OSD.BIN over BIOS.BIN precedence",
    "effect": "If an OSD replacement image named OSD.BIN exists in the VMC dir (or POPS folder) it is injected into POPS's built-in BIOS and used; when OSD.BIN is present, BIOS.BIN is IGNORED. BIOS.BIN alone lets you reach MC manager / play CDDA tracks via the built-in shell. If neither exists, POPS uses its built-in BIOS.",
    "scope": "Per-game (VMC/game folder) or global (POPS folder). HDD example path: __common/POPS/PBPX-95000.MY_GAME/OSD.BIN.",
    "conflicts": "OSD.BIN strictly wins over BIOS.BIN (mutually exclusive). OSD.BIN must satisfy a strict header (see header row) or it won't load. Using a BIOS/OSD does NOT improve game compatibility.",
    "provenance": "wiki 'bios-osd-handlers' (web.archive.org/web/20170629161024id_/.../wiki/bios-osd-handlers): 'If you put an OSD replacement image ... named as OSD.BIN ... it will be injected in the built-in BIOS ... When using a OSD replacement file, BIOS.BIN is ignored.'",
    "confidence": "primary",
    "example": "POPS/MY_GAME/OSD.BIN present -> OSD.BIN used, POPS/MY_GAME/BIOS.BIN silently ignored"
  },
  {
    "name": "OSD.BIN header structure (v1)",
    "effect": "Valid OSD replacement file format. Offset 0h-8h identifier 'PS-X OSD'; offset Ch = image version (non-NULL); offset Eh = OSD build (non-NULL); offset 1Ch-20h = OSD loadable segment size (header excluded); offset 20h-34h = OSD name, 1-20 ASCII chars, 0x00-terminated. OSD Load Address and Entrypoint must be multiples of 0x10000. Total file size = header length + OSD size.",
    "scope": "OSD.BIN files used with POPStarter (the BIOS-injection path).",
    "conflicts": "Identifier must be exactly 'PS-X OSD'; version (Ch) and build (Eh) cannot be NULL; load addr/entrypoint must be multiples of 0x10000; name >=1 char. Violations -> file not loaded.",
    "provenance": "wiki 'bios-osd-handlers' (20170629161024), 'OSD Replacement Image [Version 1] Header Structure' table verbatim.",
    "confidence": "primary",
    "example": "Bytes 0-7 = 'PS-X OSD'; name field at 0x20 = 'MY OSD\\0'; load addr 0x?0000"
  },
  {
    "name": "POPS/VMC folder priority rule",
    "effect": "Any external file (TROJAN_#.BIN, PATCH_#.BIN, BIOS.BIN, OSD.BIN, CHEATS.TXT, VMCDIR.TXT, DISCS.TXT) can live in two locations: the POPS folder (applies to ALL games) or the game's VMC folder (applies only to that game). When the same type exists in both, the VMC-folder copy has priority.",
    "scope": "All POPStarter external assets, all storage backends.",
    "conflicts": "ONLY exception: when two CHEATS.TXT (POPS + VMC folder) are loaded at once and one contains special cheats that change the video mode - that interaction is special-cased (base report's 'root CHEATS.TXT may block per-game' note).",
    "provenance": "wiki 'general-note' (web.archive.org/web/20170629125310id_/.../wiki/general-note): 'the file which is in the VMC folder has priority; Only exception ... is when 2 CHEATS.TXT files are loaded ... and that CHEATS.TXT file contains special cheats changing the video mode.'",
    "confidence": "primary",
    "example": "PATCH_5.BIN in POPS/ (all games) vs PATCH_5.BIN in POPS/MY_GAME/ -> the MY_GAME copy is used for that game"
  },
  {
    "name": "Multi-folder POPS0..POPS9 (USB)",
    "effect": "Up to 11 game folders scanned at USB root: POPS, POPS0, POPS1 ... POPS9. A renamed POPStarter ELF 'XX.Some Game.elf' launches Some Game.VCD found in any of these folders.",
    "scope": "USB mass: storage. SMB/HDD have their own equivalents (smb POPS folder; HDD __.POPS / __.POPS0..__.POPS9 partitions).",
    "conflicts": "POPS_IOX.PAK and the TM2 (IGR texture) files must stay in the MAIN POPS folder. BIOS.BIN, PATCH_#.BIN, TROJAN_#.BIN and VMCDIR.TXT meant to be global must be COPIED into every POPS# folder you create - they do not propagate automatically.",
    "provenance": "wiki 'usb-mode' (web.archive.org/web/20170629123547id_/.../wiki/usb-mode): 'POPStarter folder named POPS or POPS0 or POPS1 up to POPS9' 'If you use several POPS# folders, the usual files ... (POPS_IOX.PAK & the TM2s) must remain in the main POPS folder.' 'If you have a BIOS.BIN, a PATCH_#.BIN, a TROJAN_#.BIN or a VMCDIR.TXT in the POPS folder, you'll have to copy them to all the POPS# folder you create.'",
    "confidence": "primary",
    "example": "mass:/POPS0/Tekken.VCD with ELF 'XX.Tekken.elf'; mass:/POPS0/VMCDIR.TXT copied from mass:/POPS/VMCDIR.TXT"
  },
  {
    "name": "HDD VMC location",
    "effect": "On internal HDD, VMCs live inside the __common partition under POPS/<vmcfolder>/, alongside per-game BIOS/OSD assets - separate from the VCD which lives in its own __.POPS / PP. / __. partition.",
    "scope": "Internal HDD (hdd:) mode. VCD in game partition; VMC + assets in __common/POPS/.",
    "conflicts": "POPS.ELF + IOPRP252.IMG go in __common/POPS/. Partition names are case-sensitive and (for old launch types) must match the renamed POPStarter ELF and contain no whitespace. POPStarter 13 WIP01 added the __.POPS multi-VCD-per-partition launch type.",
    "provenance": "wiki 'hdd-mode' (web.archive.org/web/20170629165244id_/.../wiki/hdd-mode) and 'bios-osd-handlers' example path '__common/POPS/PBPX-95000.MY_GAME/BIOS.BIN'.",
    "confidence": "primary",
    "example": "__common/POPS/PBPX-95000.MY_GAME/SLOT0.VMC  (VCD itself in __.POPS/MY_GAME.VCD)"
  },
  {
    "name": "DISCS_POOPER.EXE",
    "effect": "PC helper tool that automates multi-disc setup: drop all VCDs of a game + DISCS_POOPER.EXE in a folder, run it; it creates a VMC folder for each VCD, a DISCS.TXT inside each, and a VMCDIR.TXT inside each so all discs share one VMC pair.",
    "scope": "PC-side prep tool. Output VCD+VMC folders are then moved into POPS.",
    "conflicts": "Does NOT comply with the 4-CD swap limit - do not use with more than 4 VCDs. (POPS VCD Manager wizard is a later GUI alternative that also generates DISCS.TXT + VMCDIR.TXT.)",
    "provenance": "wiki 'multi-disc' (20170626061653): 'DISCS_POOPER is a little program that does the boring job for you ... creates a VMC folder for each VCD ... a DISCS.TXT inside each ... a VMCDIR.TXT ... Doesn't comply with 4 CDs limit'. Download was hosted on the Bitbucket downloads page (discs_pooper.exe, archived).",
    "confidence": "primary",
    "example": "Folder with MGS_CD1.VCD + MGS_CD2.VCD + DISCS_POOPER.EXE -> auto-generates both DISCS.TXT and VMCDIR.TXT pairs"
  }
]
```

## New findings

- VMCs are specifically SLOT0.VMC (memory-card port 1) and SLOT1.VMC (port 2); PS1 retail-console saves imported via MemcardRex are placed into SLOT1.VMC per the wiki's PMC->VMC guide.
- Hex offset $429 in POPSTARTER.ELF controls how many VMCs are auto-created (two, one, or none) - the base report only cited $42A (480p); $429 is the VMC-count control and was missing from the base.
- Full OSD.BIN [Version 1] header structure recovered verbatim: 'PS-X OSD' identifier at 0h-8h, version at Ch (non-NULL), build at Eh (non-NULL), loadable size at 1Ch-20h, name at 20h-34h (1-20 ASCII, 0x00-terminated), load address + entrypoint must be multiples of 0x10000, file size = header + OSD size.
- Mechanism behind safe VMC sharing: POPS 'flashes the whole VMC' on every save rather than writing a single MC block - this is also why physical-MC saving is unsupported and why a POPS-root VMCDIR.TXT can mount a shared pair without data loss.
- The POPS-folder-vs-VMC-folder priority rule (VMC-folder copy wins for ALL asset types) plus its single documented exception: two CHEATS.TXT files where one changes video mode - this is the precise mechanism behind the base's 'root CHEATS.TXT may block per-game' note.
- Multi-folder caveat: VMCDIR.TXT, BIOS.BIN, PATCH_#.BIN and TROJAN_#.BIN must be manually COPIED into every POPS0..POPS9 folder (they don't propagate), while POPS_IOX.PAK and the TM2 IGR-texture files must stay only in the main POPS folder.
- On HDD, VMCs and per-game BIOS/OSD assets live in the __common partition under __common/POPS/<vmcfolder>/, decoupled from the VCD which sits in its own __.POPS/PP./__. partition.
- Close-lid disc-swap glyph confirmed as Square (identical 'Playstation-Button-S.png' asset) in BOTH the multi-disc and hotkeys wiki pages, resolving any Square-vs-Cross ambiguity in the button combo.
- DISCS_POOPER.EXE is a PC tool that auto-generates DISCS.TXT + a shared-VMC VMCDIR.TXT for each VCD in a folder (4-VCD limit); it was hosted on the Bitbucket downloads page (discs_pooper.exe, archived) - a recoverable downloadable for the corpus.
- The swap-disc feature is explicitly gated to OBT 15+ (open beta test 15); the SMB launch type to PB13 WIP06/OBT08, and the __.POPS multi-VCD-per-partition HDD launch type to POPStarter 13 WIP01 - useful version-anchoring for the changelog topic.

## Gaps

- Exact byte length of the VCD-name PATH buffer that produces the real-world ~73-char usable limit (vs the wiki's stated 89) is documented in POPSLoader's own notes but not in the original wiki; the 89 is the wiki figure, ~73 is empirical - the precise buffer size/offset in POPSTARTER.ELF was not located in the recovered wiki.
- VMC file exact size/block count not stated on the recovered FAQ/VMC pages (PS1 MC standard is 128KB/15 blocks; the wiki only says they are standard MemcardRex-editable PS1 MC images - the explicit size figure was not quoted by the wiki and is inferred, so left out of the rows).
- Whether offset $429 values are literally 00/01/02 (none/one/two VMCs) was not numerically enumerated on the recovered 'vmc' page - it only points to the configuration-table page (separately archived); the precise byte values were not cross-checked here.
- The r13 (2019-06-05) package readme text itself was not directly fetched in this pass; multi-disc/VMC behavior is taken from the 2016-2017 wiki snapshots which match r13 behavior, but a line-by-line r13-readme confirmation is still outstanding.
- No-reboot vs reboot disc-swap distinction: the wiki says swap-disc is only needed when the game requires a swap without PS1 reboot, but does not enumerate which games reboot - left as a general note.

## Sources

- https://web.archive.org/web/20170629133617id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vmc (primary)
- https://web.archive.org/web/20170626061653id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/multi-disc (primary)
- https://web.archive.org/web/20170626021730id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/hotkeys (primary)
- https://web.archive.org/web/20170629161024id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/bios-osd-handlers (primary)
- https://web.archive.org/web/20170629125310id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/general-note (primary)
- https://web.archive.org/web/20170629165244id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/hdd-mode (primary)
- https://web.archive.org/web/20170629123547id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/usb-mode (primary)
- https://web.archive.org/web/20170629154811id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/pmc-to-vmc (primary)
- https://web.archive.org/web/20170629161204id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vmc-to-pmc (primary)
- https://web.archive.org/web/20170629120342id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/faqs (primary)
- https://web.archive.org/web/20170627200840id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-usb (primary)
- https://web.archive.org/web/20170629160319id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/smb-mode (primary)
- https://www.ps2-home.com/forum/viewtopic.php?t=2091 (near-primary, blocked 403 but indexed: 'Need examples of how to use VMCDIR.TXT and DISCS.TXT')
- https://www.ps2-home.com/forum/viewtopic.php?t=1593 (near-primary, blocked 403: 'How to use the multi disc with POPStarter')
- https://www.psx-place.com/threads/how-do-i-switch-discs-in-popstarter.33583/ (community)
- https://www.psx-place.com/resources/pops-vcd-manager.1284/ (community/tool mirror)
- http://web.archive.org/cdx/search/cdx?url=bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff* (primary index/CDX API)