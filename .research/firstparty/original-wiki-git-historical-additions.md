## Historical additions recovered from the original wiki Git history

These dated notes supplement the 63 Wayback-recovered wiki pages without overwriting their source text. **AstroSnail** provided the original ShaolinAssassin Bitbucket Git archive: 2,140 commits across 2016–2024, including deleted pages. Original documentation authors retain their credits. **Historical reports below are not current hardware-testing results.**

### The 15 original news bulletins (April–July 2016)

Original deleted `News.textile` at Git revision `1ee0214f63ba` listed these items:

| Date, 2016 | Bulletin |
|---|---|
| July 27 | POPStarter r13 WIP06 OBT14 release announcement |
| June 19 | POPStarter BATCHER v0.2 |
| May 6 | Batch-create/rename/update POPStarter ELF tutorial |
| May 3 | Game Fixes archive description published |
| April 30 | HDD/USB/SMB tools and guide links corrected |
| April 30 | New `SMOOTH` screenshots page |
| April 29 | Toolbox/CUE2POPS changelog moved into its own page |
| April 29 | General note about external files added |
| April 29 | POPS history material added |
| April 28 | Widescreen codes moved to Related Stuff |
| April 28 | Wiki contents/navigation rearranged |
| April 28 | VCD conversion guide revised |
| April 27 | IGR texture-making tutorial consolidated |
| April 27 | Game troubleshooting tutorial created |
| April 27 | Wiki News section introduced |

### Old-release corrections: keep the versions separate

**WIP05 USB Quickstarter erratum (2016-10-29 / 2016-11-03).** The wiki author reported accidentally mixing stable and beta setup instructions. A prior USB pack omitted the needed `PFS_WRAP.BIN`; a corrected pack followed. The WIP05 setup required `POPS.PAK` and `PFS_WRAP.BIN`. In a [contemporary developer discussion](https://www.assemblergames-archive.com/printthread.php?page=191&tid=38642), **krHACKen** explained that the beta used `POPS_IOX.PAK` instead and renaming the PAK does not make files interchangeable. Some earlier pages misleadingly referred to `POPS_IOP.PAK`, changed to `POPS_IOX.PAK` in February 2017. Do not apply these **2016-specific** packaging rules to the final 2019 launcher.

**OBT14 USB caution (July–September 2016).** The original homepage repeated community reports of black screens or corrupted POPS-folder files with that beta, and discouraged IRX modules in USB mode. The notice was removed with the OBT15 release. Source Git commits `ca88fcf1bb62`, `95e41b9093b3`. This is **historical community feedback**, not established as a present-day POPStarter/POPSLoader bug.

**WIP05 PAL clock / XA stuttering.** A removed 2016 known-bugs note said PAL emulator clock timing might make A/V resynchronization stutter XA audio; deleted by October 2017 (`18b64829c634`, `9fdfafd3d241`). Later release status unverified.

**Configuration byte `$412`.** Initially a never-completed "skip most functions" setting (April 2016), later marked unused, it was redefined for the **SetGsCrt** hack in November 2016. The current table's SetGsCrt meaning is correct; the experimental description is only version history (original commits `fa60511de312`, `34755b05e46`, `7211f94519a`).

### Tools, CUE sheets and input devices

**Linux CUE2POPS source and credit.** Original `51abeb7d6e:vcd.textile` named a Linux-modified source archive (`cue2pops_src_linux.7z`, with an earlier .zip variant), mentioned GCC compilation, and credited **SovietStriker**. The actual historical sources are **unverified/unavailable**, not a currently tested build.

**Missing CUE instructions.** An earlier VCD guide (`058f6fc`, removed by `a114f3a`) pointed to Redump's PS1 CUE listing and emphasized matching filenames and actual tracks. A different disc revision's CUE is not necessarily valid for a particular BIN dump; this is historical guidance rather than an unchecked repair method.

**Light-gun module example correction.** The preserved Wayback page `ps1-special-devices.md` repeats `USBD.IRX` as both example modules. The original wiki corrected the second entry to **USBGUN.IRX** on 2017-10-17 (`f4210efed748`). The underlying tutorial credits **AKuHAK**; its module order is experimental and no hardware compatibility guarantee is implied.

**Old ELF batcher warning.** Deleted `Batcher_outdated.textile` (`e85288316021`) warned that older versions deleted existing launcher ELFs in the working folder before regenerating them, and periods in VCD filenames could truncate generated ELF names. Do not generalize this to later versions.

### Superseded multi-disc methods and missing screenshots

Before native disc swapping, the source wiki listed **52 region-specific disc-combining kit entries**, a manual emulator/retail-console save-transfer workaround, and a caution about a possibly unsafe Chrono Cross kit. The original author explicitly marked that method obsolete. Preserve the [historical inventory](https://github.com/NathanNeurotic/POPSLoader/blob/master/.research/research/original-git-obsolete-multidisc-kits.md) as **metadata only**, not a recommended download.

Both the original 2017 automated game/fix record (**497 entries**) and the final Git wiki record (**641 entries**) are preserved in full. Across 38 historical revisions of that page, all **545 distinct disc IDs** remain represented; this is a **textual** comparison, not a verified game-performance result.

The current site has working files for all **98 image references in its own gallery cache**, but the original wiki final revision references **19 additional missing image IDs**. Twelve are widescreen comparison images. The [image-priority ledger](https://github.com/NathanNeurotic/POPSLoader/blob/master/.research/research/original-git-image-priorities.md) identifies each; no unverified replacement is presented as the original.

### Source integrity and distribution

The original wiki Git ZIP contributed by AstroSnail must remain **byte-identical**, with SHA-256 `d0c243d91e417988825ed92b440224ed46cbbf448d0b67528e0957c15c0d029a`. It also includes original historical Git author names/emails. If the exact ZIP is not yet hosted, the Downloads page labels it **not yet available** instead of generating a dead link. Historical download names, including uncertain and withheld packages, remain documented with explicit verification labels.
