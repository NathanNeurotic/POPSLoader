# Flagged ambiguities / conflicting claims (resolve before publishing)

> Each carries a recommended UI treatment (RED = unverified/warn, AMBER = collision, INFO = nuance).


## 1.
PATCH_7.BIN (existence unconfirmed) - Present it in a RED warning box. State plainly: no primary file or definition survives; it is absent from the wiki, the r13 CHANGES.TXT, the IGR download table, and the community manual (which skips from PATCH_6 to PATCH_8). The '2014 krHACKen forced mode 0x06' vs 'obsolete Mode 7' framings are community lore only. Explicitly distinguish it from the VERIFIED TROJAN_7.BIN game-fix bundle, which is a different file. Confidence: unverified.


## 2.
PATCH_9.BIN filename collision - Present as TWO separate site records that cross-warn each other in an AMBER box. (A) STOCK PATCH_9.BIN == $NOPAL, disables the auto PAL patcher so a PAL VCD runs in POPS native NTSC (wiki already calls it 'obsolete (still working tho)'). (B) The 2020-03-21 krHACKen file that REUSES the name PATCH_9.BIN to disable the bugged ELF loader and restore IGR-to-OPL; PATCH_9.7z MD5 9db1e18bae92c4991e3de7e2a752558c (188 B), distributed via the IGR 'Trojans and Patches' thread. Same filename, different binary - never mix them. NOT byte-diffed in this pass; flag that the 188 B/MD5 in the IGR table is not explicitly tied to one of the two roles.


## 3.
'classic 00 vs debug FF' build label - Present in an INFO (grey) box, not a warning. The LABEL is community shorthand, not a verbatim krHACKen string, BUT it is accurate and grounded: it is literally the state of config byte $410 (00 = off = shipped/'classic', FF = realtime = old POPStarter-12). Nuance to state: any value 0x01-0xFE gives PACED (not just 00/FF) debug, and DEBUG_AND_HALT.PPF also flips $411. Confidence: near-primary.


## 4.
Lost config-table 'Default values' graphic and the official all-in-one sample CHEATS.TXT - Present in an INFO box. The wiki's default-values IMAGE was not OCR'd; the defaults on the site come instead from a direct hexdump of the shipped r13 ELF (more authoritative). The official all-in-one sample CHEATS.TXT download is NOT recoverable (every Wayback snapshot 302s to an expired Bitbucket S3 URL). Mark both as documented-but-asset-unrecovered.


## 5.
Default IGR combo (L1+Select+Start) - Present with a 'community-reported' tag. The default-skin-enabled fact is primary (CHANGES.TXT), but the specific default button combo is from a PS2-HOME tutorial, not the CHANGES.TXT; confidence near-primary.


## 6.
'Root CHEATS.TXT blocks per-game CHEATS.TXT' (base claim) - Present a clarifying note: the recovered wiki only documents one blocking case - the general-note priority rule's single exception where two CHEATS.TXT load at once and one changes the video mode. A general 'root blocks per-game' is otherwise NOT confirmed; the override rule is that the VMC-folder copy WINS. Confidence: community/unverified for the broad claim.


## 7.
$480p reliability ('NOT reliable ATM') - Present a caveat: the wiki flags $480p as unreliable and the geometry-incompatibility is firm, but whether it was fixed by the 2019 r13 build is unverified. Mark status uncertain.


## 8.
$415 / $429 exact byte enumeration - Note that $429 values 00/01/02 (both/none/first-only) are confirmed, but the precise byte values of a few peripheral offsets ($415 ASCII range, $417 residual 0x01 meaning, $42C purpose) are documented qualitatively only - flag as low-importance gaps.


## 9.
VCD filename limit (89 vs ~73) - Present both numbers: the wiki states 89 chars max; POPSLoader's own empirical testing (#503) shows ~73 usable because it is a full-PATH buffer, not a bare-name buffer. Use ~73 as the practical guidance and 89 as the documented figure.


## 10.
TROJAN_6 / TROJAN_8 - Note they are absent from the recovered IGR download table (only 0-5, 7, 9 exist there); whether they ever existed is unknown. Low-importance gap.
