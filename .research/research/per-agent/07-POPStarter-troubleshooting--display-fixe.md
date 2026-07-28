# Research agent 7: POPStarter troubleshooting, display fixes, game codes, edge cases

## Summary
krHACKen full r13 changelog (RIP06-WIP01) survives verbatim on the Dekazeta mirror and is the primary command/offset/game-fix reference the base called lost. ps2-home tutorials recovered via the Wayback id_ raw endpoint + curl. Corrections and broader command list in entries and new_findings.

## Entries (3)

```json
[
  {
    "name": "$HDTVFIX / $480p (HDTV no-signal)",
    "effect": "HDTVFIX SetGsCrt interlace hack for HDTV/HDMI green-screen (CHEATS.TXT or ELF offset 412h=0x01). 480p offset 42Ah=0x02 incomplete.",
    "scope": "r13",
    "conflicts": "HDTVFIX breaks some CRTs",
    "provenance": "PRIMARY Dekazeta r13 changelog",
    "confidence": "primary",
    "example": "$HDTVFIX"
  },
  {
    "name": "USB-not-seen offset 413h (not USBDELAY)",
    "effect": "USB HDD not detected: patch POPSTARTER.ELF offset 413h 0x02 to 0x05; USBDELAY patches POPS not POPSTARTER. Debug via POPS_DEBUG_AND_HALT.zip or offset 410h=04.",
    "scope": "r13 RIP06 (older 417h)",
    "conflicts": "also check FAT32, POPS folder at root",
    "provenance": "NEAR-PRIMARY DEBUG tutorial t=5311",
    "confidence": "near-primary",
    "example": "413h 0x02 to 0x05"
  },
  {
    "name": "Modes/IGR/conf_elm/game-fixes/TROJAN",
    "effect": "Modes: 0x02 Colony Wars, 0x04 GPU fix, 0x05 RE Director Cut, 0x06 disable BIOS OSD; never combine 0x01/0x02/0x03/0x05, 0x04+0x06 OK (Tekken 3). IGR5 terminate; 2020 PATCH_9.BIN restores IGR-to-OPL. Delete conf_elm.cfg+conf_elms.cfg, conf_elmz.cfg safe. Crash Bash PAL best; Jackie Chan SCES-01444 LibCrypt crack. TROJAN per-game binary patch in game VMC, v3 build-ID Ah version Ch 0x03.",
    "scope": "r13; CHEATS.TXT/TROJAN in game VMC",
    "conflicts": "2020 PATCH_9.BIN differs from PAL-patcher PATCH_9.BIN",
    "provenance": "PRIMARY Dekazeta + Wiki t=144, exit t=127, Tekken3 t=8744",
    "confidence": "primary",
    "example": "$COMPATIBILITY_0x02"
  }
]
```

## New findings

- offset 412h is HDTVFIX not function-skipper
- USB-delay offset 413h RIP06, 417h earlier
- new offset 42Fh test mode; new commands SET_TIMINGS/LOAD_TIMINGS, LOAD_PADMAN/KILL_PADMAN
- smooth hotkeys enable L1+R2 disable L2+R1
- conf_elm.cfg and conf_elms.cfg deleted, conf_elmz.cfg safe
- TROJAN build-ID offset Ah version offset Ch 0x03 auto-skip when stale
- Jackie Chan SCES-01444 built-in LibCrypt crack
- Tomb Raider 1/2 CDDA desync is an emulation limitation
- Tekken 3 fix shows 0x06+0x04 combine
- corpora ps2-home f=117 and HugoPocked PSX-Place pack; keep CHEATS.TXT/TROJAN in game VMC not POPS path
- provenance curl Wayback CDX then id_ endpoint with compressed flag

## Gaps

- XPOS/DWSTRETCH/DWCROP defaults only in Scribd mirror; DWSTRETCH/DWCROP absent from primary changelog
- C1 master-code support unverified
- PATCH_7.BIN absent from r13 changelog
- f=117 corpus and Crash Bash t=8707 Cloudflare-walled
- 5-AUTOMATED.TXT per-serial list not retrieved

## Sources

- https://www.dekazeta.net/foro/files/file/1652-popstarter/
- https://web.archive.org/web/20190808161830/http://www.ps2-home.com/forum/viewtopic.php?t=5311
- https://web.archive.org/web/20240407083519/https://www.ps2-home.com/forum/viewtopic.php?t=144
- https://web.archive.org/web/20230619145423/https://www.ps2-home.com/forum/viewtopic.php?t=127
- https://web.archive.org/web/20230723000350/https://www.ps2-home.com/forum/viewtopic.php?t=8744
- https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/
- https://www.elotrolado.net/hilo_ho-pops-emulador-de-psx-para-ps2_1874054_s3250