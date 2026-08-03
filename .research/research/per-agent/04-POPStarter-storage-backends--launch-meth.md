# Research agent 4: POPStarter storage backends, launch methods, and path maps (USB / SMB / internal HDD)

## Summary
Recovered the three primary ShaolinAssassin Bitbucket wiki "mode" pages (usb-mode, smb-mode, hdd-mode), the quickstart-usb/smb pages, the uLE_kHn page, and the popstarter-changelog from the Wayback Machine. These confirm and correct the base report on exact path layouts and per-mode ELF-name prefixes: USB uses an "XX." prefix and scans POPS, POPS0..POPS9 in USB root; SMB uses an "SB." prefix with POPS in the share root plus mc#:/POPSTARTER/ network modules + SMBCONFIG.DAT/IPCONFIG.DAT; internal HDD uses NO prefix (new launch type) on partition __.POPS / __.POPS0..9 with emulator in __common/POPS, and supports two legacy per-partition types (PP. for HDDOSD-visible, __. for hidden) keyed off IMAGE0.VCD. The "debug required for SMB" myth is DECISIVELY REFUTED: the changelog shows SMB shares were added in Beta 8 (2015/10/23) as a normal feature ("NOT password protected, fixed port 445") with no debug gating; the only debug-related caveat is that startup debug text "can not be skipped in SMB mode" (a cosmetic startup-print behavior, not a build requirement). Launch methods are: (1) renamed-ELF-per-game (prefix+name = VCD name), (2) single un-renamed POPSTARTER.ELF direct-VCD via the special uLE_kHn build (NOT "wLE_kHn" — base report typo) or via OPL's Apps tab, and (3) the modern POPSLoader fork (Lua/Enceladus, originally El_isra, now NathanNeurotic) covering MMCE/MX4SIO/USB/APA-HDD.

## Prose
PATH-MAP CHEAT SHEET (all verbatim from the ShaolinAssassin wiki mode pages):

USB (root of FAT12/16/32 + defragmented device):
  POPS/POPS_IOX.PAK            (emulator; MD5 a625d0b3036823cdbf04a3c0e1648901)
  POPS/<Game>.VCD             (also POPS0/ .. POPS9/ in USB root — shared PAK+TM2 stay in main POPS)
  XX.<Game>.elf               (renamed POPSTARTER.ELF launcher; or one un-renamed POPSTARTER.ELF + uLE_kHn)
  mc0:/POPSTARTER/usbd.irx, usbhdfsd.irx   (modules; mc1 fallback)

SMB (POPS at the SHARE ROOT):
  smb0:/<Share>/POPS/POPS_IOX.PAK   (same PAK as USB; MANDATORY in SMB)
  smb0:/<Share>/POPS/<Game>.VCD
  mc0:/POPSTARTER/SMBCONFIG.DAT, IPCONFIG.DAT, smbman.irx (+poweroff/ps2dev9/smsutils/ps2ip/ps2smap.irx)
  SB.<Game>.elf               (launcher; lives anywhere, e.g. mass:/POPSTARTER/SB.<Game>.ELF)
  SMBCONFIG.DAT: line1 'IP[:port] Share Name' (default port 445), line2 user, line3 password (empty L2/L3 = guest)
  IPCONFIG.DAT (optional): 'PS2_IP NETMASK GATEWAY'

INTERNAL HDD (PS2-formatted):
  __common/POPS/POPS.ELF      (decrypted; MD5 355a892a8ce4e4a105469d4ef6f39a42)
  __common/POPS/IOPRP252.IMG  (MD5 1db9c6020a2cd445a7bb176a1a3dd418)
  __.POPS/<Game>.VCD          (new type; also __.POPS0 .. __.POPS9) -> launcher '<Game>.elf' (NO prefix)
  Legacy: PP.<Game>/IMAGE0.VCD (+EXECUTE.KELF, HDDOSD-visible, prefix PP.)  OR  __.<Game>/IMAGE0.VCD (hidden, prefix __.)

LAUNCH METHODS:
  1) Renamed-ELF-per-game: one POPSTARTER.ELF copy per game, named <prefix><VCD-name>.elf.
  2) Single direct-VCD: one un-renamed POPSTARTER.ELF + the special uLE_kHn uLaunchELF build (place its BOOT in mc0:/BOOT), or OPL's 'Apps' tab driving conf_apps.cfg / APPS/<game>/<game>.elf entries. (Base report's 'wLE_kHn' is a typo for 'uLE_kHn'.)
  3) Modern POPSLoader fork (Lua on Enceladus; El_isra -> NathanNeurotic): bundles POPSLOADER.ELF + scripts/textures/modules, drop VCDs in a POPS folder; boots from MC/MMCE/MX4SIO/USB(FAT32/exFAT), runs games from MMCE/MX4SIO/USB/APA-HDD.

THE 'DEBUG REQUIRED FOR SMB' MYTH — REFUTED: POPStarter changelog Beta 8 (2015/10/23): 'Added support for ps2host, napLink (yuck) and SMB (NOT password protected, fixed port 445) shares.' SMB is a standard feature from Beta 8; there is no debug-build gate. The only debug caveat is the wiki smb-mode note 'Debug infos at startup can NOT be skipped in SMB mode' — the boot-time debug text is always shown in SMB mode, which is purely cosmetic and unrelated to needing a 'debug' build.

RECOVERY METHOD NOTE (for the corpus tasks): the lost Bitbucket wiki is fully reconstructable. WebFetch is blocked on web.archive.org, but the Wayback CDX API (http://web.archive.org/cdx/search/cdx?url=bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki*&output=text&fl=timestamp,original,statuscode&collapse=urlkey) lists ~90 snapshotted URLs, and `curl` against a timestamped raw URL of the form https://web.archive.org/web/<TS>id_/<original> returns clean page HTML (HTTP 200) for lossless extraction. Every storage/launch page (usb-mode, smb-mode, hdd-mode, quickstart-usb/smb/hdd, uLE_kHn, popstarter-changelog, multi-disc, configuration-table) was retrieved this way.

## Entries (21)

```json
[
  {
    "name": "USB layout: mass:/POPS/ (root POPS folder)",
    "effect": "USB storage type. POPS folder must be at the ROOT of the USB device. Contains POPS_IOX.PAK (the emulator), the VCD files, and (renamed) launcher ELFs. Device must be FAT12/FAT16/FAT32 (NOT NTFS) and DEFRAGMENTED.",
    "scope": "USB mass storage, POPStarter r13 WIP 02+ (USB launch type introduced WIP 02).",
    "conflicts": "NTFS not supported. Fragmentation causes failures. POPS_IOX.PAK required for USB; old POPS.PAK (POPS.ELF+IOPRP252.IMG) still works but updating is 'highly recommended'.",
    "provenance": "ShaolinAssassin wiki usb-mode, Wayback http://web.archive.org/web/20170629123547/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/usb-mode",
    "confidence": "primary",
    "example": "POPS/POPS_IOX.PAK ; POPS/Crash Bandicoot.VCD ; XX.Crash Bandicoot.elf"
  },
  {
    "name": "USB scan order: POPS, POPS0, POPS1 ... POPS9",
    "effect": "POPStarter looks for the named VCD in POPS or POPS0 or POPS1 ... up to POPS9, all placed in USB root (lets you split a large library across folders). The usual shared files (POPS_IOX.PAK and the TM2 textures) must remain in the MAIN POPS folder; BIOS.BIN / PATCH_#.BIN / TROJAN_#.BIN / VMCDIR.TXT must be COPIED into every POPS# folder you create.",
    "scope": "USB mode. The POPS#-in-USB feature was introduced in POPStarter r13 WIP 06 OBT; reading VCDs from POPS# folders was bugfixed in Beta 11 (2015/11/11).",
    "conflicts": "Per-game asset files (PATCH/TROJAN/BIOS/VMCDIR) are NOT auto-shared across POPS# folders — must be duplicated.",
    "provenance": "wiki usb-mode (Wayback 20170629123547) + popstarter-changelog Beta 11, Wayback http://web.archive.org/web/20170629142002/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter-changelog",
    "confidence": "primary",
    "example": "POPS/Game.VCD or POPS0/Game.VCD or ... POPS9/Game.VCD (launched by XX.Game.elf)"
  },
  {
    "name": "USB launcher ELF naming: XX.<name>.elf (prefix XX.)",
    "effect": "Rename the POPStarter ELF to the VCD's name, swap .VCD for .elf, and add the 'XX.' prefix. Third char of prefix is a dot ('XXdot'). Prefix must be UPPERCASE; the .VCD extension must be UPPERCASE. USB supports ONLY this 'new' launch type.",
    "scope": "USB mode only. (HDD/SMB use different prefixes.)",
    "conflicts": "Lowercase prefix or lowercase .vcd extension breaks matching.",
    "provenance": "wiki usb-mode (Wayback 20170629123547)",
    "confidence": "primary",
    "example": "VCD 'Gran Turismo.VCD' -> ELF 'XX.Gran Turismo.elf'"
  },
  {
    "name": "USB network/USB modules: mc0:/POPSTARTER/ then mc1:/POPSTARTER/",
    "effect": "POPStarter loads usbd.irx/usbhdfsd.irx (and network modules) from the memory card POPSTARTER folder, slot 0 first; if a file is missing it falls back to mc1:/POPSTARTER/. Loading modules from 'mass' is NO LONGER supported. PFS_WRAP.BIN is no longer needed since OBT8 (embedded into the ELF).",
    "scope": "USB mode, beta 8+ (PFS wrapper embedded beta 8 2015/10/23); mc1 fallback added Beta 9 (2015/10/24).",
    "conflicts": "Putting custom usbd.irx/usbhdfsd.irx on mass: will be ignored; they must be on the MC.",
    "provenance": "wiki usb-mode (Wayback 20170629123547) + changelog Beta 8/Beta 9 (Wayback 20170629142002)",
    "confidence": "primary",
    "example": "mc0:/POPSTARTER/usbd.irx ; mc0:/POPSTARTER/usbhdfsd.irx"
  },
  {
    "name": "SMB layout: smb0:/<Share>/POPS/ (POPS in share root)",
    "effect": "SMB/network storage. Create a POPS directory in the PS2 shared folder (must be at the share root, NOT a subdirectory), put POPS_IOX.PAK and the VCDs there. POPS_IOX.PAK is the SAME file as USB mode (MD5 a625d0b3036823cdbf04a3c0e1648901) and is MANDATORY (the old POPS.PAK does NOT work in SMB mode).",
    "scope": "SMB mode. SMB backend added Beta 8 (2015/10/23); SB.-prefixed SMB launch TYPE introduced r13 WIP 06 / OBT 08.",
    "conflicts": "POPS must be at share root or it won't be found. POPS.PAK (legacy) unsupported in SMB. Requires PS2 network adapter/native NIC + cable + MC.",
    "provenance": "wiki smb-mode, Wayback http://web.archive.org/web/20170629160319/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/smb-mode ; quickstart-smb Wayback http://web.archive.org/web/20180208032618/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-smb",
    "confidence": "primary",
    "example": "smb0:/My Shared Folder/POPS/POPS_IOX.PAK ; smb0:/My Shared Folder/POPS/Crash Bandicoot.VCD"
  },
  {
    "name": "SMB launcher ELF naming: SB.<name>.elf (prefix SB.)",
    "effect": "Rename POPStarter ELF to the VCD name, .VCD -> .elf, add 'SB.' prefix (third char is a dot, 'SBdot'). Uppercase prefix and uppercase .VCD required. The ELF itself can live anywhere you launch from (e.g. mass:/POPSTARTER/SB.GAME.ELF), only the VCD must be in the SMB POPS folder.",
    "scope": "SMB mode only. Launch type introduced POPStarter 13 WIP 06, OBT 08.",
    "conflicts": "SMB POPS folder name is fixed 'POPS' (no POPS# multi-folder list documented for SMB).",
    "provenance": "wiki smb-mode (Wayback 20170629160319) + quickstart-smb (Wayback 20180208032618)",
    "confidence": "primary",
    "example": "VCD 'Crash Bandicoot.VCD' -> ELF 'SB.Crash Bandicoot.elf'"
  },
  {
    "name": "SMB modules folder: mc#:/POPSTARTER/ (network IRX + DAT files)",
    "effect": "The PS2-side network modules and the two .DAT config files live in mc0:/POPSTARTER/ (falls back to mc1:/POPSTARTER/ when a file is missing). Documented module set: poweroff.irx, ps2dev9.irx, smsutils.irx, ps2ip.irx, ps2smap.irx, smbman.irx (plus IPCONFIG.DAT, SMBCONFIG.DAT). quickstart-smb shows a minimal set of smbman.irx + the two DATs.",
    "scope": "SMB mode. mc1 fallback added Beta 9 (2015/10/24).",
    "conflicts": "Missing/wrong network modules -> SMB init fails.",
    "provenance": "wiki smb-mode (Wayback 20170629160319) + quickstart-smb (Wayback 20180208032618)",
    "confidence": "primary",
    "example": "mc0:/POPSTARTER/SMBCONFIG.DAT ; mc0:/POPSTARTER/IPCONFIG.DAT ; mc0:/POPSTARTER/smbman.irx"
  },
  {
    "name": "SMBCONFIG.DAT syntax",
    "effect": "Line 1: '<SERVER IP ADDRESS> <SHARE NAME>' (space-separated). Optional ':PORT' appended to IP (default 445; e.g. ':139'). Line 2 = username, Line 3 = plain-text password for authenticated shares; leave lines 2 & 3 EMPTY for guest access.",
    "scope": "SMB mode. Port selection added Beta 11 (2015/11/11); user authentication added Beta 12 (2015/11/24).",
    "conflicts": "Default access is GUEST/non-password (Beta 8). Writing credentials when the share is guest-only (or vice-versa) fails the connection.",
    "provenance": "wiki smb-mode (Wayback 20170629160319) + changelog Beta 11/Beta 12 (Wayback 20170629142002)",
    "confidence": "primary",
    "example": "192.168.0.254 My Shared Folder\\nMyName\\nMyPassword   (or '192.168.0.254:139 My Shared Folder' with empty lines 2-3 for guest)"
  },
  {
    "name": "IPCONFIG.DAT syntax (OPTIONAL)",
    "effect": "Single line: '<PS2 IP ADDRESS> <NETMASK> <GATEWAY>' (space-separated). This file is OPTIONAL in SMB mode (DHCP/auto otherwise).",
    "scope": "SMB mode. Made optional in Beta 11 (2015/11/11).",
    "conflicts": "Only needed for static PS2 IP; omit to let POPStarter use defaults.",
    "provenance": "wiki smb-mode (Wayback 20170629160319) + changelog Beta 11 (Wayback 20170629142002)",
    "confidence": "primary",
    "example": "192.168.0.13 255.255.255.0 192.168.0.254"
  },
  {
    "name": "SMB port: fixed/default 445 (139 selectable)",
    "effect": "SMB uses TCP port 445 by default; an alternate port can be appended to the IP in SMBCONFIG.DAT (e.g. 192.168.0.254:139). Beta 8 originally hard-fixed port 445; Beta 11 added per-config port selection.",
    "scope": "SMB mode. 445 fixed in Beta 8 (2015/10/23); selectable port Beta 11 (2015/11/11).",
    "conflicts": "Servers exposing only 139 (legacy NetBIOS) need the ':139' override.",
    "provenance": "changelog Beta 8 & Beta 11 (Wayback 20170629142002) + wiki smb-mode/quickstart-smb",
    "confidence": "primary",
    "example": "192.168.0.254:139 My Shared Folder"
  },
  {
    "name": "REFUTED: 'debug build required for SMB'",
    "effect": "FALSE. SMB shares were added as a standard feature in Beta 8 (2015/10/23): 'Added support for ps2host, napLink (yuck) and SMB (NOT password protected, fixed port 445) shares' — no debug gating. The only debug-related caveat (wiki smb-mode 'Additional notes') is that 'Debug infos at startup can NOT be skipped in SMB mode' — i.e. the boot-time debug text is always printed in SMB mode; this is a cosmetic startup behavior, NOT a requirement to use a special debug build.",
    "scope": "SMB mode, Beta 8 onward.",
    "conflicts": "Do not conflate 'startup debug text always shown' with 'must use a debug build'.",
    "provenance": "changelog Beta 8 (Wayback http://web.archive.org/web/20170629142002/.../popstarter-changelog) + wiki smb-mode Additional notes (Wayback 20170629160319)",
    "confidence": "primary",
    "example": "Beta 8 line: 'Added support for ... SMB (NOT password protected, fixed port 445) shares'"
  },
  {
    "name": "HDD layout: __.POPS / __.POPS0..9 + __common/POPS (NEW launch type)",
    "effect": "Internal HDD, modern multi-VCD type. VCDs go in PS2-formatted partition __.POPS (or __.POPS0 .. __.POPS9). Emulator (POPS.ELF + IOPRP252.IMG) goes in a POPS folder inside the __common partition. NO prefix on the launcher ELF (named exactly <game>.elf for <game>.VCD).",
    "scope": "Internal HDD. New launch type introduced POPStarter 13 WIP 01.",
    "conflicts": "Partition must be named __.POPS (with the leading double-underscore-dot) — '+__.POPS' is WRONG (use AKuHAK's uLaunchELF or uLE_kHn build to create a partition without the '+'). Partition names are case-sensitive; .VCD must be uppercase.",
    "provenance": "wiki hdd-mode, Wayback http://web.archive.org/web/20170629165244/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/hdd-mode",
    "confidence": "primary",
    "example": "__common/POPS/IOPRP252.IMG ; __common/POPS/POPS.ELF ; __.POPS/Crash Bandicoot.VCD ; __sysconf/FMCB/Crash Bandicoot.elf"
  },
  {
    "name": "HDD legacy OLD launch type: PP.<game> partition, EXECUTE.KELF/IMAGE0.VCD (HDDOSD-visible)",
    "effect": "One VCD per partition named PP.<game>; the VCD is always IMAGE0.VCD (all uppercase); launcher prefix PP. (KELF EXECUTE.KELF for HDDOSD). This is the only type SHOWN in HDDOSD / PSBBN / PSX XMB. Used in POPStarter 12 and older.",
    "scope": "Internal HDD, legacy (POPStarter 12 and older); still supported.",
    "conflicts": "No whitespace allowed in partition names (old types). 1 partition = 1 game (except multi-disc).",
    "provenance": "wiki hdd-mode 'HDD Launch types (advanced)' (Wayback 20170629165244)",
    "confidence": "primary",
    "example": "PP.Crash_Bandicoot/EXECUTE.KELF ; PP.Crash_Bandicoot/IMAGE0.VCD  (ELF: PP.Crash_Bandicoot.elf)"
  },
  {
    "name": "HDD legacy ALTERNATE old type: __.<game> partition, IMAGE0.VCD (hidden partition)",
    "effect": "One VCD per partition named __.<game>; VCD is IMAGE0.VCD (uppercase); launcher prefix __. ; partition is HIDDEN (not shown in HDDOSD/PSBBN/XMB). Used in POPStarter 12 and older.",
    "scope": "Internal HDD, legacy; not HDDOSD-compatible.",
    "conflicts": "Hidden from Sony browsers by design; no whitespace in partition name.",
    "provenance": "wiki hdd-mode (Wayback 20170629165244)",
    "confidence": "primary",
    "example": "__.Crash_Bandicoot/IMAGE0.VCD ; __sysconf/FMCB/__.Crash Bandicoot.elf"
  },
  {
    "name": "POPSTARTER.KELF / PP. prefix (HDDOSD / Sony Browser 2.00)",
    "effect": "The bundle ships POPSTARTER.KELF (KELF = Krypto-ELF, ELF in a Sony container) for use when SONY Browser 2.00 (HDDOSD) is installed; otherwise useless. Partition prefix is PP. (PP-dot); 1 partition = 1 game (unless multi-disc).",
    "scope": "Internal HDD with HDDOSD/Browser 2.00 only.",
    "conflicts": "Useless without HDDOSD. Do not mix with the prefix-less new launch type on the same game.",
    "provenance": "wiki hdd-mode (Wayback 20170629165244)",
    "confidence": "primary",
    "example": "POPSTARTER.KELF placed per PP.<game> partition"
  },
  {
    "name": "HDD emulator files: POPS.ELF + IOPRP252.IMG (decrypted, in __common/POPS)",
    "effect": "HDD mode uses the DECRYPTED POPS files (not POPS_IOX.PAK). POPS.ELF MD5 355a892a8ce4e4a105469d4ef6f39a42 (the main SLBB-00001 ELF, decrypted). IOPRP252.IMG MD5 1db9c6020a2cd445a7bb176a1a3dd418 (found in some retail discs / $CEI SDKs). Both go in __common/POPS.",
    "scope": "Internal HDD mode.",
    "conflicts": "These are Sony-copyrighted and not redistributed with POPStarter; user must source them. USB/SMB use POPS_IOX.PAK instead.",
    "provenance": "wiki hdd-mode requirements table (Wayback 20170629165244)",
    "confidence": "primary",
    "example": "__common/POPS/POPS.ELF (MD5 355a892a8ce4e4a105469d4ef6f39a42) ; __common/POPS/IOPRP252.IMG (MD5 1db9c6020a2cd445a7bb176a1a3dd418)"
  },
  {
    "name": "Launch method 1: renamed-ELF-per-game",
    "effect": "Classic method: each game has its own copy of POPSTARTER.ELF renamed to '<prefix><VCD name>.elf'. Prefix is XX. (USB), SB. (SMB), or none/PP./__. (HDD per type). Launched via uLaunchELF, FMCB/FHDB, OPL Apps, etc.",
    "scope": "All storage types.",
    "conflicts": "Tedious for big libraries (one ELF per game) — the reason uLE_kHn and POPSLoader exist.",
    "provenance": "wiki usb-mode/smb-mode/hdd-mode (Wayback 20170629123547 / 20170629160319 / 20170629165244)",
    "confidence": "primary",
    "example": "XX.Crash Bandicoot.elf -> launches Crash Bandicoot.VCD"
  },
  {
    "name": "Launch method 2: single un-renamed POPSTARTER.ELF direct-VCD (uLE_kHn / OPL Apps)",
    "effect": "Avoids per-game renaming. Place ONE un-renamed POPSTARTER.ELF in the POPS folder; a special uLaunchELF build (uLE_kHn, e.g. uLE_kHn_20191110) can launch a .VCD file directly like any ELF. Put uLE_kHn's BOOT in mc0:/BOOT. OPL's 'Apps' tab (conf_apps.cfg / APPS/<game>/<game>.elf entries) is the other common direct-launch UI.",
    "scope": "USB (uLE_kHn supports USB; 'SMB not supported ATM' per uLE_kHn page) + OPL Apps for USB/HDD/SMB.",
    "conflicts": "uLE_kHn did NOT support SMB at time of writing. NOTE: base report's 'wLE_kHn' is a TYPO — the correct name is 'uLE_kHn' (u for uLaunchELF).",
    "provenance": "wiki uLE_kHn, Wayback http://web.archive.org/web/20170629140906/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/uLE_kHn ; quickstart-usb (Wayback 20170627200840); ps2-home OPL-Apps tutorials (t=123, t=3216, t=2295)",
    "confidence": "primary",
    "example": "mass:/POPS/POPSTARTER.ELF + mass:/POPS/Crash Bandicoot.VCD + mc0:/BOOT/BOOT.ELF (uLE_kHn) ; run POPSTARTER.ELF, pick the VCD"
  },
  {
    "name": "Launch method 3: modern POPSLoader fork (Lua/Enceladus)",
    "effect": "POPSLoader is a Lua launcher built on the Enceladus runtime that bundles POPSLOADER.ELF + Lua scripts + textures + modules; you drop .VCDs in a POPS folder plus your POPStarter ELF + POPS support files (IOPRP252.IMG, POPS.ELF, POPS.PAK, POPS_IOX.PAK), then run POPSLOADER.ELF (via wLaunchELF/FMCB/etc). Boots from MC/MMCE/MX4SIO/USB(FAT32/exFAT); runs games from MMCE/MX4SIO/USB/APA-HDD. Originally by El_isra; current maintained fork by NathanNeurotic.",
    "scope": "Modern (post-POPStarter) fork; broad device support incl. MMCE & MX4SIO & exFAT not in stock POPStarter.",
    "conflicts": "Separate project from krHACKen's POPStarter; supports exFAT and MMCE/MX4SIO that stock POPStarter does not.",
    "provenance": "GitHub https://github.com/NathanNeurotic/POPSLoader ; PSX-Place fork thread https://www.psx-place.com/threads/fork-popsloader-for-mmce-mx4sio-usb-and-apahdd-stabilization-optimization-updates.49539/",
    "confidence": "primary",
    "example": "POPS/POPSLOADER.ELF + POPS/<game>.VCD + POPS/POPS_IOX.PAK ; run POPSLOADER.ELF"
  },
  {
    "name": "Windows host SMB share setup (modern Windows)",
    "effect": "To serve POPS over SMB from modern Windows: enable 'SMB 1.0/CIFS File Sharing Support' (Control Panel > Programs and Features > Turn Windows features on or off, or PowerShell Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol), turn OFF 'Password protected sharing' (Network and Sharing Center > Advanced sharing settings), and grant the Guest/Everyone account Read/Write on the share. POPStarter's SMB client is legacy (SMB1, guest, port 445).",
    "scope": "Host-side (Windows 10/11) for SMB mode. COMMUNITY guidance — not in the official wiki.",
    "conflicts": "SMB1 is insecure and disabled by default on modern Windows — only enable on a trusted LAN. A NAS exposing SMB2/3-only with mandatory auth may still work via SMBCONFIG.DAT credentials, but guest+SMB1 is the documented path.",
    "provenance": "chipnetics https://chipnetics.com/tutorials/ps2-opl-with-samba/ ; ps2-home SMB tutorial https://www.ps2-home.com/forum/viewtopic.php?t=326 ; GBAtemp https://gbatemp.net/threads/how-to-get-popstarter-via-smb-to-work-in-githubs-opl.613924/",
    "confidence": "community",
    "example": "Windows feature: 'SMB 1.0/CIFS File Sharing Support' ON; 'Password protected sharing' OFF; share POPS folder, Guest = Read/Write"
  },
  {
    "name": "pops-smb-config (on-console SMB editor)",
    "effect": "A PS2 homebrew tool to edit POPStarter's SMBCONFIG.DAT/IPCONFIG.DAT on the console itself (no PC needed). Confirms the 3-line SMBCONFIG.DAT format (IP[:port] + share name, then user, then password; last two may be empty for guest).",
    "scope": "Companion utility for SMB mode.",
    "conflicts": "Third-party tool; not part of POPStarter.",
    "provenance": "GitHub https://github.com/blckbearx/pops-smb-config ; PSX-Place https://www.psx-place.com/resources/popstarter-smb-configuration-tool.1237/",
    "confidence": "near-primary",
    "example": "Edits mc0:/POPSTARTER/SMBCONFIG.DAT in-place on the PS2"
  }
]
```

## New findings

- EXACT per-mode ELF prefixes recovered from primary wiki: USB = 'XX.', SMB = 'SB.', HDD new type = no prefix, HDD legacy = 'PP.' (HDDOSD-visible) or '__.' (hidden). Third char is always a literal dot; prefix and .VCD extension must be UPPERCASE.
- Base report's 'wLE_kHn' is a TYPO — the real tool is 'uLE_kHn' (a special uLaunchELF build; e.g. uLE_kHn_20191110, uLE_kHn_20160723 'last one distributed by kHn'). It can launch .VCD directly and place BOOT in mc0:/BOOT.
- DECISIVE refutation of 'debug required for SMB': changelog Beta 8 (2015/10/23) added SMB as a normal feature ('NOT password protected, fixed port 445'); the wiki's only debug note is 'Debug infos at startup can NOT be skipped in SMB mode' (cosmetic startup print, not a build requirement).
- SMB feature timeline pinned to exact dates: SMB backend Beta 8 (2015/10/23); mc1 module fallback Beta 9 (2015/10/24); POPS#-folder VCD read fix + optional IPCONFIG.DAT + port selection Beta 11 (2015/11/11); SMB user authentication + $FORCEPAL Beta 12 (2015/11/24).
- HDD three-launch-type table recovered verbatim, including that legacy types key off a fixed 'IMAGE0.VCD' (uppercase) one-VCD-per-partition, while the WIP 01 'new' type uses real VCD filenames in __.POPS / __.POPS0..9.
- USB requires the device be not just FAT-formatted but DEFRAGMENTED; PFS_WRAP.BIN became embedded into the ELF as of OBT8 (no longer a separate file).
- POPSLoader (the maintainer's project) is a Lua/Enceladus launcher originally by El_isra, now forked/maintained by NathanNeurotic, extending support to MMCE, MX4SIO, USB FAT32/exFAT, and APA-HDD — beyond stock POPStarter's backends.
- Full Wayback CDX index of the lost wiki is reachable via the CDX API even though direct web.archive.org page fetch is blocked for WebFetch — curl with a timestamped 'id_' raw URL retrieves clean page source for losslessly reconstructing every wiki page (usb/smb/hdd/quickstart/uLE_kHn/changelog/multi-disc/configuration-table all recovered HTTP 200).

## Gaps

- The exact MD5/CRC and contents of POPS_IOX.PAK vs legacy POPS.PAK are stated (a625d0b3036823cdbf04a3c0e1648901) but the internal network-module set bundled inside POPS_IOX.PAK was not independently re-verified beyond the wiki.
- Whether SMB mode supports a POPS#-style multi-folder scan (like USB POPS0..9 and HDD __.POPS0..9) is NOT documented — the wiki only ever shows a single 'POPS' folder for SMB. Treated as 'not supported / undocumented'.
- The precise build where the SB. SMB *launch type* (vs the underlying SMB backend) shipped: wiki smb-mode says 'WIP 06, OBT 08' while the SMB *backend* is changelog Beta 8 (2015/10/23). The OBT vs Public-Beta numbering tracks were not fully cross-walked from a single primary doc.
- ps2host (IP.) and napLink (PL.) launch prefixes were mentioned/removed in the changelog (Beta 8 added, Beta 13 removed ps2host/napLink launchers) but their full path layouts were out of scope and not captured here.
- Modern POPSLoader fork's exact per-device path maps (MMCE mmce0:, MX4SIO mx4sio:/sd:, APA-HDD) were not pulled from the fork's own README in this pass — only the device list and bundle contents were confirmed.

## Sources

- primary — http://web.archive.org/web/20170629123547/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/usb-mode
- primary — http://web.archive.org/web/20170629160319/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/smb-mode
- primary — http://web.archive.org/web/20170629165244/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/hdd-mode
- primary — http://web.archive.org/web/20170627200840/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-usb
- primary — http://web.archive.org/web/20250202192148/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-usb
- primary — http://web.archive.org/web/20180208032618/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-smb
- primary — http://web.archive.org/web/20170822060406/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/quickstart-hdd
- primary — http://web.archive.org/web/20170629140906/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/uLE_kHn
- primary — http://web.archive.org/web/20170629142002/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter-changelog
- primary — http://web.archive.org/web/20170626061653/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/multi-disc
- index — http://web.archive.org/cdx/search/cdx?url=bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki*
- community — https://www.ps2-home.com/forum/viewtopic.php?t=144 (POPStarter Guide and Wiki)
- community — https://ps2-home.com/forum/viewtopic.php?t=3216 (USB + OPL ELF Loader Menu)
- community — https://www.ps2-home.com/forum/viewtopic.php?t=2295 (HDD + OPL ELF Loader Menu)
- community — https://www.ps2-home.com/forum/viewtopic.php?t=123 (list/launch POPStarter games with OPL)
- community — https://www.ps2-home.com/forum/viewtopic.php?t=326 (SMB Network OPL Shared Folder)
- community — https://www.ps2-home.com/forum/viewtopic.php?t=10220 (POPS_IOX.PAK NOT FOUND)
- community — https://chipnetics.com/tutorials/ps2-opl-with-samba/
- community — https://gbatemp.net/threads/how-to-get-popstarter-via-smb-to-work-in-githubs-opl.613924/
- mirror — https://www.psx-place.com/resources/ps1-popstarter-r13-wip-06-beta-20160918.354/
- primary — https://github.com/NathanNeurotic/POPSLoader
- primary — https://www.psx-place.com/threads/fork-popsloader-for-mmce-mx4sio-usb-and-apahdd-stabilization-optimization-updates.49539/
- near-primary — https://github.com/blckbearx/pops-smb-config
- mirror — https://www.psx-place.com/resources/popstarter-smb-configuration-tool.1237/