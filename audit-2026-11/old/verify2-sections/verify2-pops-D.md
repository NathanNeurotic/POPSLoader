# FULL-VERIFICATION — POPSLoader, worker D (adversarial)

- **Clone:** `~/workspace/audit-clones-2026-11-13/POPSLoader`, read-only, unedited.
- **Pin verified:** `git rev-parse HEAD` = `29272cddbf0122f14e76bc3bdd75e3b46aa870be` — matches the assigned pin. All checks below were run at that HEAD.
- **Scope:** POPSLOADER-049…052 (ROUND3), -053…059 (ROUND4), -060…065 and -067…070 (ROUND7). 21 findings.
- **Stance:** adversarial — each finding was re-derived from the code/docs at the pin; it survives only where the cited evidence proves it.

## 1. Verdict table

| ID | Verdict | Evidence (one line) |
|---|---|---|
| POPSLOADER-049 | VERIFIED | Diff sizes re-derived exactly (BT 513, USB 399 diff lines; 1719/1521 and 806/634 lines); standalone guards `port >= MAX_PADS` + BT authorized-check present at `modules/ds34bt/iop/ds34bt.c:1451-1524`, `modules/ds34usb/iop/ds34usb.c:516-661`, absent in pademu bodies `modules/pademu/ds34bt.c:1419-1470`, `modules/pademu/ds34usb.c:515-590` which index `ds34pad[port]` directly; `analog_btn` 15/16 hits pademu-only, `enable_fake`/`options & 1` at `modules/pademu/ds34bt.c:351,1478` vs `disable_fake` standalone `:359`, MAX_PADS 2→4, `rrum * 255` at `modules/pademu/ds34bt.c:1188` |
| POPSLOADER-050 | VERIFIED | Caller sweep over `src/`, `bin/POPSLDR/`, `etc/`: all 12 named dead functions return 0 callers; the 10 used ones hit (e.g. `ds34bt_init`/`ds34usb_init` at `src/main.cpp:687-688`); libs are 173+148=321 lines, single-object `EE_OBJS = libds34bt.o`/`libds34usb.o`, linked via `Makefile` EE_LIBS (`-lds34bt -lds34usb`) and `EXT_LIBS` at `Makefile:82` |
| POPSLOADER-051 | VERIFIED | Stale toast key present in exactly 6 languages directly under the live key (FR `system.lua:2772`, DE `:3079`, PT `:3387`, ES `:3695`, IT `:4002`, HU `:4358`); SK carries only the live key (`:4751`); 8 HU-only keys at `:4155,4214,4306,4315,4331,4332,4377,4378` have zero occurrences in `ui.lua`/`images.lua`/`src/`; live hints composed via `UI.PadHintPair("Keep","Revert")` `ui.lua:7320` and `("Select","Cancel")` `ui.lua:7062` |
| POPSLOADER-052 | VERIFIED | `.research/audit_site.py:99-100` catalogue floor `len(history_rows) < 80`, `:124-126` `tracked_size.get('NOPAL_PATCH.7z', 226) != 226`, verbatim-phrase gates `'The 15 original news bulletins'`, `'1094748012'`, `'3844714277'`, `'34 original screenshot/image references not recovered'` in the `:124-160` block; gate is live at `.github/workflows/docs-site.yml:80` |
| POPSLOADER-053 | VERIFIED | `src/fntsys.cpp` is 946 lines; `#else` at `:693`, `isRTL` `:694`, `fntRenderSubRTL` `:704`, second `fntRenderString` `:733`, block ends `:848` (156 lines); `__RTL` defined nowhere tree-wide and header comment `:17-18` records the undefined `MENU_ITEM_HEIGHT`; `fntLoadDefault` `:390-410` and `fntFitString` `:851-905` (ends `:905`) have zero callers outside `fntsys.cpp`; 156+21+55 = ~232 dead lines |
| POPSLOADER-054 | VERIFIED-DRIFT | Four 7z `-slt` parsers confirmed, but definition lines are `compare_recovered_archive_candidates.py:47`, `audit_hosted_patch_members.py:20`, `audit_legacy_archive_payloads.py:81`, `audit_legacy_tool_overlap.py:39` (not 18/76/33 for the last three); finder/blob secondary lines also shifted (see §2) |
| POPSLOADER-055 | VERIFIED-DRIFT | Wiring-assert pattern confirmed, but the cited range/count and the "no message anywhere in the file" sub-claim are wrong: 35 assert statements in `:29-73`, exactly 45 in `:29-90`, and blob/provenance asserts elsewhere in the same file do carry messages (see §2) |
| POPSLOADER-056 | VERIFIED-DRIFT | Primary claim exact — `audit_published_provenance.py` (31 lines) is 7 required phrases incl. `"188-byte"`, `"226 bytes"`, `"93,934-byte"`, 3 disproven phrases, 1 compatibility sentence, 4 filenames — but the secondary wiki-zip citations are wrong: exact checks are at `audit_original_wiki_zip.py:20-22,28-33,79-80`, not `:29-33` and `:86-89` (see §2) |
| POPSLOADER-057 | VERIFIED-DRIFT | Both comment-string extractions confirmed, but the PNG harness extraction is at `tools/png_decoder_harness.py:116`, not `:122`; the orbs extraction is exactly at `.research/tools/test_cursor_orbs.cjs:17-18`; contrast anchor `tools/test_udpfs_config_runtime.py:8-10` uses the function name (see §2) |
| POPSLOADER-058 | VERIFIED | `grep -n matches_by_hash .research/tools/audit_legacy_tool_overlap.py` returns exactly one hit, `:148` (`matches_by_hash = {d: f for f, (_, d, _) in originals.items()}`); the matching loop below works from `originals` directly |
| POPSLOADER-059 | VERIFIED | Files exist at exactly the claimed sizes — `fetch_fail.tsv` 204 B, `stubborn_done.tsv` 2,484 B, `agent6-FAILED.md` 36 B (sum 2,724 B, content `# agent 6 — FAILED (rate limited)`); repo-wide grep for all three filenames returns zero references; siblings are load-bearing (`build_site.py:552` reads `_state/galleries.json`, `:1076` reads `_state/assets_done.tsv`); per-agent series 00–05, 07 present, 06 only the stub |
| POPSLOADER-060 | VERIFIED | Docs: `ARCHITECTURE.md:253` "\| 6 \| i.Link \| **stub** (`ui.lua:4318`) \|", `COMPONENTS.md:474` "`i.Link` (OPT6): NOT implemented", `README.md:84` "(Ember only…)", `:139` "(experimental: Ember games only…)", `:263` "POPSTARTER titles over i.Link are not implemented". Code (annex paths, `bin/POPSLDR/`): `ui.lua:6425` `UI.MainMenu.OPT == 6` handler, `ui.lua:1067` `GILINK = 11`, `system.lua:9166` `PLDR.InitILINKRoot`, `system.lua:10702` `BuildLaunchPolicy("ILINK", "mass", "ilink0", TranslateIlinkPathForPopStarter)` |
| POPSLOADER-061 | VERIFIED | Doc `ARCHITECTURE.md:640`: "`BDMA_ADAPTIVE` (per-launch BDMA variant staging, default off; see STATE.md)". Code `bin/POPSLDR/system.lua:6236`: `PLDR.BDMA_ADAPTIVE = true   -- per-launch BDMA variant staging (issue #509)`, with the maintainer rationale comment directly above |
| POPSLOADER-062 | VERIFIED | Doc `STATE.md:5-7`: "Slovak wording awaits the contributor; `SK` is not yet in the picker", directly under the 1.4.4 header (`STATE.md:1`). Code `bin/POPSLDR/system.lua:2559` `PLDR.LANGUAGE_ORDER = {"EN", "FR", "DE", "PT", "ES", "IT", "HU", "SK"}`, `:2560` `SK = "Slovenčina"`, SK dictionary at `:4431-4432`; `STATE.md:1` itself and `bin/changelog` [1.4.3]/[1.4.4] record SK as shipped |
| POPSLOADER-063 | VERIFIED | Docs: `ARCHITECTURE.md:1` and `COMPONENTS.md:1` "Release 1.1.0; rolling `v1.1.1-dev` / experimental `v1.1.1-dev-EXP73`", `docs/PRESERVATION_CONTRACTS.md:3` "Public release is **1.1.0** (2026-07-21); rolling is `1.1.1-dev`". Code: `etc/boot.lua:1` `POPSLDR_VER = "v1.4.4"`, `bin/POPSLDR/title.cfg:7` `Version=1.4.4`, `STATE.md:1` "Official release: 1.4.4"; all three doc headers defer to STATE.md, as the finding states |
| POPSLOADER-064 | VERIFIED | Doc `README.md:149`: Retro GEM Game ID row, Options cell "**On**" only (neighbouring rows list full sets, e.g. Cover art "**On** (default) · Off"). Code `bin/POPSLDR/ui.lua:5250-5256`: `AddCycle("Retro GEM Game ID", function() return UI.RetroGemGameId and "On" or "Off" end, …toggle…)`; default on at `system.lua:6258` `PLDR.RETROGEM_GAMEID = true` |
| POPSLOADER-065 | VERIFIED | Doc `ARCHITECTURE.md:329`: "`UI.CoverCache` (`ui.lua:257`, `max = 3`) is a 3-entry LRU of loaded box-art images". Code `bin/POPSLDR/ui.lua:372-373`: `local CoverCache = {` / `max = 4, -- bounded recent cover/icon textures` |
| POPSLOADER-067 | VERIFIED | `src/elf_loader/Makefile:15-16`: target `src/loader/bin/loader.elf:` with recipe `$(MAKE) src/loader` (no `-C`). Stub-PS2SDK execution in `/tmp` (copy of the folder, clone untouched): `make src/loader/bin/loader.elf` ran the recipe, sub-make reported "Nothing to be done for 'src/loader'", exited 0, and created no `src/loader/bin/` at all; `make -n loader.c` then proceeds to bin2c on the nonexistent ELF. Top-level driver does it correctly first at `Makefile:358` (`$(MAKE) -C src/elf_loader/src/loader/ … clean all`). The original INFERRED label is upgraded by this stub execution; a full PS2SDK build was not run |
| POPSLOADER-068 | VERIFIED | Doc `COMPONENTS.md:387-388`: "`src/elf_loader/loader.c` — committed ~6.5 MB bin2c blob of the built `loader.elf`". Measured at the pin: `stat` = 855,821 B, `wc -l` = 8,740 lines — exactly the finding's figures; the doc overstates by ~7.6× |
| POPSLOADER-069 | VERIFIED | Binary exists: `iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx`, 14,993 B, md5 `48677ae01b05c84b6f299773baa7dea0`, strings self-identify `MX4SIO: MX4SIO v1.2` / `sio2man`; it is byte-identical to the shipped `bin/POPSLDR/usbhdfsd.irx.mx4sio` (same md5). Tarball beside it (md5 `09ff4b911ba131468a25d0ec9a4e2f27`, 119 files in the `/tmp/bdma7v2` extraction): zero files with `mx4sio`/`sio2`/`sio2man` content (`grep -rli` = 0) and zero such paths in the tar listing (only bdm/libbdm/usbd/usbmass_bd/bdmfs trees). Whole clone tree: the only MX4SIO artifacts are binaries (`mx4sio_bd.irx` 15,089 B md5 `d63df3c91829a982fe6e6bf0f290881e` — a different binary — and `mx4sio_bd_mini.irx`), no source. The folder's pin claim (`COMPONENTS.md:401` "source pins"; tarball README install mapping `usbd_bd_assault.irx` → `usbhdfsd.irx`) covers the USB BDMAssault build, not this SIO2/MX4SIO binary |
| POPSLOADER-070 | VERIFIED | Tree-wide grep for `hci_event_flag`: only the 6 macro definitions (`modules/ds34bt/iop/ds34bt.h:81-83`, `modules/pademu/ds34bt.h:67-69`, each expanding to operations on `hci_event_flag`) plus the two enum comments (`ds34bt.h:140`, pademu `ds34bt.h:122`); no declaration of `hci_event_flag` and zero call sites anywhere. Companion `HCI_FLAG_*` enums likewise occur only at their definitions and have diverged: standalone `:141-149` has 9 values (`0x0001…0x0100`, incl. `READ_VERSION`/`READ_FEATURES`), pademu `:123-129` has 7 (`0x01…0x40`) |

**Counts: 17 VERIFIED / 4 VERIFIED-DRIFT / 0 WEAKENED / 0 REFUTED (21 total).**

## 2. Full reasoning for non-VERIFIED verdicts

### POPSLOADER-054 — VERIFIED-DRIFT (duplication of the 7z listing parser stands; several cited lines are off)

The core claim re-derives cleanly. All four gates implement the same parser — run `7z l -slt`, split on `----------`, build a `fields` dict from ` = ` lines, drop `Folder == '+'` entries, and apply the "0-byte, no-CRC entry that is a parent of a real member is a directory marker" filter:

- `compare_recovered_archive_candidates.py:47` `def seven_entries(exe, path):` — `p.stdout.split('----------', 1)[1].split('\n\n')`, `fields = dict(line.split(' = ', 1) …)`. Cited `:47-65` — correct.
- `audit_hosted_patch_members.py:20` `def list_7z_members(exe, archive):` — same split/fields shape, with the directory-marker comment verbatim in spirit: "Some p7zip/7zip builds omit the Folder field in -slt output for 7z directory entries. The archive may show a 0-byte path with no CRC that is a parent of a real member. Do not count it as a file." Cited as `:18-42`; the function actually starts at `:20`.
- `audit_legacy_archive_payloads.py:81` `def archive_members(archive: Path, executable: str) -> tuple[int, int, int]:` — same shape plus the path-safety rejection and size checks the finding describes as drift. Cited as `:76-116`; the function actually starts at `:81`.
- `audit_legacy_tool_overlap.py:39` `def seven_list(path, exe):` — same shape, raising on oversized members inside the lister (`length < 0 or length > EXTERNAL_MAX_BYTES`). Cited as `:33-57`; the function actually starts at `:39`.

Secondary sites, corrected: the 7z-executable discovery sits at `verify_network_driver_payloads.py:119` (cited 120), `compare_recovered_archive_candidates.py:41` (cited 39–44, in range), `audit_hosted_patch_members.py:52` (cited 53), `audit_legacy_archive_payloads.py:146` (cited 156–158 — wrong), `audit_legacy_tool_overlap.py:103` (cited 97 — wrong). The git-blob OID sites are exact: `audit_legacy_archive_payloads.py:44` `def git_blob`, `audit_legacy_pages.py:14` `def oid`, `tools/test_udpfs_integration.py:23` inline `sha1(b"blob " …)`. The sharing precedent is exact: `verify_network_driver_payloads.py:19` `from inspect_network_modules_header import manifest`. Nothing here weakens the finding; only the line citations drifted.

### POPSLOADER-055 — VERIFIED-DRIFT (text-assertion wiring half stands; count/range and the bare-assert parenthetical are wrong)

The pattern is real: `tools/test_udpfs_integration.py` reads `ui.lua`, `system.lua`, `src/luasystem.cpp`, `src/embed_assets.cpp` and the `Makefile` as text (`:29-33`) and asserts exact strings, including the whitespace-exact C++ at `:68`:

```python
assert 'snprintf(iparg,sizeof(iparg),"ip=%s",ip);' in cpp
```

and the slice-and-exclude check at `:46-47` built from two `ui.index("function …")` anchors. The blob-pin half (`:12-27`) and PROVENANCE.json half (`:77-117` in the original's numbering; provenance block actually runs to the end of the 117-line file) are byte checks, as the finding says.

Two sub-claims do not survive as written:

1. **Count/range.** An AST count of the file gives 35 assert *statements* with line numbers in the cited `:29-73` range (lines 35–47, 49–62, 64–71, 73), not ~45. The "~45" figure is exactly right for the wider wiring region `:29-90` (45 statements, adding the asset/make loop asserts at `:74-77` and the file-existence asserts at `:78,79,84,85,90`). Corrected citation: `tools/test_udpfs_integration.py:29-90`, 45 assert statements.
2. **"No message argument anywhere in the file."** False for the file as a whole. The blob asserts carry messages — `:22` `assert len(binary) == length, (path, len(binary), length)`, `:25` `assert binary[:4] == b"\x7fELF", f"not a valid ELF: {path}"` — as do `:97`, `:105` and `:116`. What is true, and what the finding's argument actually needs, is the narrower claim: **the wiring asserts in `:35-90` themselves are all bare** (no `msg` on any of them, AST-verified). The surviving claim is therefore: ~45 bare source-text assertions in the wiring half `:29-90`, whose failures are unadorned `AssertionError`s — while the file's other halves do use messages.

### POPSLOADER-056 — VERIFIED-DRIFT (primary file exact; secondary wiki-zip lines wrong, one attribution name wrong)

The primary claim is exact, whole-file. `.research/tools/audit_published_provenance.py` is 31 lines and nothing else: seven required phrases — `"Historical NOPAL patch name conflict"`, `"188-byte"`, `"226 bytes"`, `"IGR ELF-loader"`, `"archival copy"`, `"not a verified"`, `"93,934-byte"` — each failing with `Missing public provenance warning: {term}`; three disproven phrases that must not appear; one exact compatibility sentence, `"Do not apply the hosted file as a verified PAL workaround"`; the `href="downloads/NOPAL_PATCH.7z"` link check; and four required filenames (`POPStarter_USB_Quickstarter_Pack_20171027.7z`, `POPStarter_SMB_Quickstarter_Pack_20171027.7z`, `DISCS_POOPER.EXE`, `uLE_kHn_20160723.7z`).

The secondary citation does not survive. In `.research/tools/audit_original_wiki_zip.py` the exact-text gates are:

- `:20-22` — `EXPECTED_MODULE_LINE = ("For light gun, first .IRX might be USBD.IRX and second .IRX USBGUN.IRX;")`
- `:28-33` — the module-line presence check, the `"second .IRX USBD.IRX;"` regression check, and the attribution check — but the attribution string is `"AKuHAK"` (`:32`: `if "AKuHAK" not in source or "AKuHAK" not in rendered:`), not `"AstroSnail"` as the finding states.
- `:79-80` — `"AstroSnail"` does exist in the file, but as a downloads-page attribution check in the staged-archive branch (`if "AstroSnail" not in downloads: raise ValueError("Archive contributor attribution disappeared")`), not at the cited `:86-89` — lines 86–89 are the `except`/`SystemExit` tail of the `__main__` guard and contain no gates at all.

Corrected secondary citation: `.research/tools/audit_original_wiki_zip.py:20-22, 28-33, 79-80`. The pattern claim (exact prose as a hard gate, in a second file) stands.

### POPSLOADER-057 — VERIFIED-DRIFT (both comment-anchored extractions stand; PNG harness line is 116, not 122)

Both harnesses are genuine execution tests that locate the code under test by comment text:

- `tools/png_decoder_harness.py:116` (cited `:122` — line 122 is an unrelated `rgb = lambda …` inside the test-case builder):
  ```python
  decoder = source[source.index('//2D drawing functions'):source.index('GSTEXTURE* loadbmp(')]
  ```
  under the comment at `:115` "Compile production functions verbatim. No copied decoder implementation."
- `.research/tools/test_cursor_orbs.cjs:17-18` — exactly as cited:
  ```js
  const start = js.indexOf('/* Site-wide cursor orb preference.');
  const end = js.indexOf('/* ---- PS2 OSDSYS Cursor Orbs Canvas ---- */', start);
  ```

The contrast case also checks out: `tools/test_udpfs_config_runtime.py:8-10` anchors on the function name (`source.index("local function ParseUdpfsIPv4(value)")`). Only the PNG line number drifted; the brittleness claim is untouched.

## 3. Incidental new defects

None filed. Every anomaly encountered during re-derivation was either already covered by an existing POPSLoader finding (checked against the headings of `Sable-POPSLoader.md`, `Sable-POPSLoader-ROUND2.md`, `Sable-POPSLoader-ROUND3.md`, `Sable-POPSLoader-ROUND4.md` and `Sable-POPSLoader-ROUND7.md`) or was an inaccuracy in a finding's own citation/count, recorded above as VERIFIED-DRIFT rather than as a new code defect. Reserved range POPSLOADER-121…124 unused.
