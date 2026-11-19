# POPSLoader extraction

## Verdicts
| ID | Title | Effort | Risk | Verdict |
|---|---|---|---|---|
| RE-POPS-001 | Partition parsers read a full device sector into a fixed 512-byte scratch buffer | S | Low | VERIFIED-DRIFT |
| RE-POPS-002 | USB descriptor walk trusts `bLength`/`bNumEndpoints` from the device in all four copies | M | Med | VERIFIED-DRIFT |
| RE-POPS-003 | `pademu.c` SIO2 parsing reads past the transfer with no size floor, and the multitap slot becomes an unchecked array index | S | Low | VERIFIED-DRIFT |
| RE-POPS-004 | Block cache hard-codes 512-byte sectors in its block geometry | S | Low | VERIFIED |
| RE-POPS-005 | SCSI capacity is off by one and the device-supplied block length is never validated | S | Low | VERIFIED |
| RE-POPS-006 | GPT header fields are trusted unchecked: entry count, entry size, and a possible divide-by-zero | S | Low | VERIFIED |
| RE-POPS-007 | USB mass connect walks endpoint descriptors on device-supplied lengths with no NULL or bounds check | S | Low | VERIFIED |
| RE-POPS-008 | Static-descriptor search takes its first step on an unchecked descriptor length | S | Low | WEAKENED |
| RE-POPS-009 | BT HCI/L2CAP/HID handlers ignore the received byte count and parse stale buffer bytes | M | Low | VERIFIED |
| RE-POPS-010 | DS3 battery byte indexes the 6-entry `power_level[]` unchecked in all four copies | S | Low | VERIFIED |
| RE-POPS-011 | Mount-info lookup accepts the one-past-the-end index (and negative indices) | S | Low | WEAKENED |
| RE-POPS-012 | fs_ioctl2 / fragment-list paths dereference a possibly-NULL mounted block device | S | Low | VERIFIED |
| RE-POPS-013 | Partition read/write pass-through enforces no partition bounds at all | S | Low | VERIFIED |
| RE-POPS-014 | GPT partition size is off by one and an inverted range is accepted | S | Low | VERIFIED |
| RE-POPS-015 | MBR partitions are mounted with no bounds, type, or extended-partition handling | S | Low | VERIFIED |
| RE-POPS-016 | SCSI layer caps every drive at 2 TiB inside an otherwise 64-bit stack | M | Med | VERIFIED |
| RE-POPS-017 | SCSI warmup failure is ignored, sense data is read uninitialised, and TEST UNIT READY can spin forever | M | Low | VERIFIED |
| RE-POPS-018 | Block cache marks a block valid and serves it even when the device read failed | S | Low | VERIFIED |
| RE-POPS-019 | Fragment-list walk can loop forever on a cyclic FAT chain, holding the global FS lock | S | Low | VERIFIED |
| RE-POPS-020 | Isochronous done-queue cleanup clears the wrong LUT slot | S | Low | VERIFIED |
| RE-POPS-021 | Font ids from Lua index the 16-entry fonts[] array with no bounds check in four fntsys entry points | S | Low | VERIFIED-DRIFT |
| RE-POPS-022 | Lua handles are raw pointers cast through integers with no validation: NULL/wild dereference and double-free are one bad integer away | M | Low | WEAKENED |
| RE-POPS-023 | Both ELF-loading stages copy program segments to header-supplied addresses with no bounds validation | M | Med | VERIFIED |
| RE-POPS-024 | `get_data` copies a caller-supplied `size` out of an 18-byte array, and the pademu copies never bounds-check `port` | S | Low | VERIFIED |
| RE-POPS-025 | Pademu BT copy clears the DS4 LED buffer with the DS3 length and sends 29 uninitialised bytes (fix exists in the standalone copy) | S | Low | VERIFIED |
| RE-POPS-026 | Standalone USB copy lost the DS3 null-report guard the other three copies have | S | Low | VERIFIED |
| RE-POPS-027 | Two Lua bindings trust a caller-supplied length over the actual string: loadImageEmbedded and IOP.loadModuleBuffer | S | Low | VERIFIED |
| RE-POPS-028 | Graphics.threadLoadImage passes a Lua-owned string pointer straight to a worker thread, and its second argument is unreachable | S | Low | VERIFIED |
| RE-POPS-029 | bd_cache_create dereferences unchecked allocations | S | Low | VERIFIED |
| RE-POPS-030 | atlas allocation results are never checked: OOM is a NULL dereference, not a failure return | S | Low | VERIFIED-DRIFT |
| RE-POPS-031 | fntsys readFile ignores the read() result, so a short read hands FreeType an uninitialised tail | S | Low | VERIFIED-DRIFT |
| RE-POPS-032 | graphics loadFont branches on an uninitialised magic value when the file cannot be opened | S | Low | VERIFIED |
| RE-POPS-033 | Pads.getPressure reads an uninitialised padButtonStatus when no pad read succeeds | S | Low | VERIFIED |
| RE-POPS-034 | HDD partition index from Lua is turned into a device-name byte with `'0' + index` and no range check | S | Low | VERIFIED |
| RE-POPS-035 | EE ds34 clients copy the RPC buffer to the caller even when the RPC failed | S | Low | VERIFIED |
| RE-POPS-036 | MBR parser leaks its allocation on the read-failure path | S | Low | WEAKENED |
| RE-POPS-037 | FatFs re-entrancy grant ignores its own timeout | S | Med | VERIFIED-DRIFT |
| RE-POPS-038 | fs_devctl dispatches STOP_UNIT to stop-all and STOP_ALL to stop-one | S | Low | VERIFIED |
| RE-POPS-039 | Callback thread reads the request after freeing it (GP-register build only) | S | Low | VERIFIED |
| RE-POPS-040 | The default shipped POPSTARTER.ELF is the DEBUG profile, not MAIN, and the 1–2 patch bytes that define all five profiles are documented nowhere in the repo | S | Low | WEAKENED |
| RE-POPS-041 | 23 of 26 distinct binaries have no in-repo source, and most of them have no hash pin or provenance record either — a silent byte swap would pass CI | M | Low | WEAKENED |
| RE-POPS-042 | opencode workflow runs an unpinned third-party action (`@latest`) with an API-key secret in its environment | S | Low | VERIFIED |
| RE-POPS-043 | The "ABC" on-screen keyboard layout can never be selected: the system normalizer silently converts it to QWERTY | S | Low | VERIFIED |
| RE-POPS-044 | Shipped usbhdfsd.irx cannot be accounted for by the tarball, and the tarball's second driver is absent from the shipped set | S | Low | WEAKENED |
| RE-POPS-045 | The entire merged-driver tree is a second, hand-maintained copy of every component (ffunicode alone is 79% of the tarball) | M | Med | VERIFIED-DRIFT |
| RE-POPS-046 | Every rolling and experimental release zip embeds a full copy of the entire tracked tree, including the 21 MB research archive | S | Low | VERIFIED |
| RE-POPS-047 | Whole `modules/pademu/` tree is built by nothing | S | Med | VERIFIED-DRIFT |
| RE-POPS-048 | 52 of 143 registered Lua bindings have no caller in any Lua that can run | M | Med | VERIFIED-DRIFT |
| RE-POPS-049 | Two embedded IRX blobs are byte-identical duplicates of the usbexfat blobs, embedded a second time instead of aliased (83,008 B) | S | Low | VERIFIED |
| RE-POPS-050 | The same binaries are tracked two to four times in git under different paths | M | Med | VERIFIED |
| RE-POPS-051 | The generated bin2c blob `src/elf_loader/loader.c` (855,821 bytes) is committed and regenerated on every build | M | Med | VERIFIED |
| RE-POPS-052 | The block cache reserves 128 KiB of IOP RAM per whole device | S | Med | VERIFIED |
| RE-POPS-053 | ds34 drivers exist as two hand-synced copies per transport; fixes land in one copy only | L | Med | VERIFIED |
| RE-POPS-054 | Embedded-asset table stores every asset twice: 100 entries for 49 unique blobs | M | Med | WEAKENED |
| RE-POPS-055 | The entire translation database is inlined in system.lua: 2,276 lines / 172,314 bytes parsed on every boot, including for English users | M | Med | VERIFIED-DRIFT |
| RE-POPS-056 | Three iop/embed binaries are dead: nothing builds, embeds or loads them | S | Low | VERIFIED |
| RE-POPS-057 | Vendored `iop/ata_bd_fast/` is kept but explicitly unused; the pinned binary wins | S | Low | VERIFIED |
| RE-POPS-058 | The superseded ps2atad stack is still embedded into every ELF, and two IMPORT_BIN2C externs are unused | S | Low | VERIFIED |
| RE-POPS-059 | SMB defaults that no longer exist (port 1111, preset LAN addresses, DHCP-by-default, guest) still presented as current | S | Low | WEAKENED |
| RE-POPS-060 | i.Link documented as a stub / not implemented / Ember-only; it is implemented for Ember and POPSTARTER | S | Low | VERIFIED |
| RE-POPS-061 | fs_ioctl2's RENAME command is an admitted TODO stub, and the ops table is padded with dummy slots | M | Low | VERIFIED-DRIFT |
| RE-POPS-062 | The `__RTL` renderer in fntsys.cpp is a half-finished second implementation that is never compiled and could not compile | S | Low | VERIFIED |
| RE-POPS-063 | GetMassRootByBackendName defeats the BDM cache and re-binds the RPC on every single call | S | Med | WEAKENED |
| RE-POPS-064 | Settings screen rebuilds its entire item list — and ~100 fresh closures — on every rendered frame | M | Med | VERIFIED-DRIFT |
| RE-POPS-065 | A failing sector is retried 16 times end-to-end with no delay, reset, or backoff | S | Low | VERIFIED |
| RE-POPS-066 | USBD always builds its largest pool configuration; the MINI_DRIVER configuration is unreachable | S | Med | VERIFIED-DRIFT |
| RE-POPS-067 | fs_driver statically reserves 128 FIL and 16 DIR objects regardless of need | S | Med | VERIFIED |
| RE-POPS-068 | HDD.ListPartitions reserves a 512-entry × 33-byte static table (16,896 bytes of BSS) for a transient enumeration | S | Low | VERIFIED |
| RE-POPS-069 | `bdm_query` reports resident success when its only thread failed to start | S | Low | VERIFIED |
| RE-POPS-070 | ART_LOCATION: a removed setting still plumbed through ~10 live sites as inert cargo | M | Low | VERIFIED |
| RE-POPS-071 | The ABNT keyboard layout is a selectable layout whose rows are byte-identical to QWERTY | S | Low | VERIFIED |
| RE-POPS-072 | Game-list scene carries two permanently-empty scaffolding tables and an unreachable "Not implemented yet" branch, evaluated every frame | S | Low | VERIFIED |
| RE-POPS-073 | Adaptive BDMA: tester/rolling docs keep the pre-EXP70 USB rule and the old Off default | S | Low | VERIFIED |
| RE-POPS-074 | TESTING.md SMB setup instructs testers to set two Settings rows that no longer exist (Games path, Link mode) | S | Low | VERIFIED-DRIFT |
| RE-POPS-075 | Two workflows are single-use artifacts: the official-release workflow is hardcoded to 1.4.4, and the retract workflow can only ever fire on its own edit | M | Med | VERIFIED |
| RE-POPS-076 | The IRX load-and-check helper is duplicated verbatim in main.cpp and luasystem.cpp | S | Low | VERIFIED |
| RE-POPS-077 | PNG and BMP decoders repeat the same row-buffer / CLUT / VRAM-upload blocks three times each | M | Med | WEAKENED |
| RE-POPS-078 | ResolveAssetPath and ResolveAssetPathTyped duplicate the same candidate-walk | S | Low | VERIFIED |
| RE-POPS-079 | The PLDRGC1 game-list cache format is implemented twice (parser ×2, builder ×2) | M | Low | VERIFIED-DRIFT |
| RE-POPS-080 | Dead HDD readable-path resolver that is a near-verbatim subset of the live one | S | Low | VERIFIED-DRIFT |
| RE-POPS-081 | Three trailing-slash helpers where one mechanism suffices | M | Med | WEAKENED |
| RE-POPS-082 | DPRINTF is an unconditional no-op, so all EE diagnostic logging is dead in every build, including DEBUG builds | M | Low | VERIFIED-DRIFT |
| RE-POPS-083 | Cache eviction is a fixed-point weight/aging scheme where a trivial policy suffices | S | Med | VERIFIED-DRIFT |
| RE-POPS-084 | Dead C functions and dangling declarations left behind by removed subsystems | S | Low | VERIFIED-DRIFT |
| RE-POPS-085 | GetFreeSize / AllocateLargestFreeBlock: a dead chain whose algorithm repeatedly mallocs the largest block in the heap | S | Low | VERIFIED |
| RE-POPS-086 | The async ATA bring-up worker is dead: KickAtaAsyncBoot / WaitAtaAsyncBootBounded have no callers anywhere | M | Med | VERIFIED-DRIFT |
| RE-POPS-087 | embedded_get's bare-name fallback branch can never execute | S | Low | VERIFIED |
| RE-POPS-088 | images.lua's IMG_FALLBACKS mechanism can never fire | S | Low | VERIFIED |
| RE-POPS-089 | `default.png` is registered in Lua and embedded only conditionally, but the file is not in the repo and the registration is never requested | S | Low | VERIFIED-DRIFT |
| RE-POPS-090 | Four defined-but-never-called functions, including one polluting the global namespace | S | Low | VERIFIED |
| RE-POPS-091 | Dead exported surface: unused PLDR/UI members, a load-time probe whose result nobody reads, and a self-described dead flag | S | Low | WEAKENED |
| RE-POPS-092 | Twenty stale translation entries whose source strings no longer exist in the code | S | Low | VERIFIED |
| RE-POPS-093 | StripVcdExtension is defined independently in both Lua files | S | Low | VERIFIED |
| RE-POPS-094 | The scene-background image cascade is written out twice inside ui.lua | S | Low | VERIFIED |
| RE-POPS-095 | Three clamp implementations, one of them a same-name shadow inside a single function | S | Low | VERIFIED |
| RE-POPS-096 | Dead helpers and dead macros: `GetExportEntry` and the `hci_event_flag_*` family | S | Low | VERIFIED-DRIFT |
| RE-POPS-097 | Dead duplicate files inside __usbd_bd_assault that its Makefile never compiles | S | Low | VERIFIED |
| RE-POPS-098 | A complete second, never-compiled ASYNC implementation of usb_queue_cmd is carried in-line | S | Low | WEAKENED |
| RE-POPS-099 | libbdm ships bd_defrag, which nothing in the package calls | S | Low | VERIFIED-DRIFT |
| RE-POPS-100 | ffsystem.c carries dead sample code for four other operating systems | S | Low | VERIFIED-DRIFT |
| RE-POPS-101 | Tarball CI builds only the merged drivers and libbdm; the five component modules are never compiled | S | Low | VERIFIED-DRIFT |
| RE-POPS-102 | Merged USBD Makefile adds an include directory that does not exist | S | Low | VERIFIED-DRIFT |
| RE-POPS-103 | The build pipeline is triplicated across three workflows; the same gates and the same ~170-line publish script are maintained in three places | M | Med | VERIFIED |
| RE-POPS-104 | The publishing channels run a weaker gate set than CI: docs_verify runs only in compilation.yml, and the experimental channel also skips the PNG decoder harness | S | Low | VERIFIED |
| RE-POPS-105 | test_udpfs_integration.py is named an integration test but is mostly substring-presence assertions on source text | M | Low | VERIFIED |
| RE-POPS-106 | Byte-identical duplicates inside the research archive and the root docs | S | Low | VERIFIED |
| RE-POPS-107 | Release/version headers frozen at 1.1.0 / v1.1.1-dev in five docs | S | Low | WEAKENED |
| RE-POPS-108 | "29 keys" settings lists enumerate only 23 keys (RETROGEM_GAMEID and the five EMBER_* keys missing) | S | Low | VERIFIED |
| RE-POPS-109 | "Cover art reads exactly ONE path per device" — UDPFS reads two | S | Low | VERIFIED |
| RE-POPS-110 | CONTRIBUTING.md packaging contract describes the pre-Ember ZIP (wrong top-level layout, phantom BUILD_INFO.txt, no EMBER/, no PSU) | S | Low | VERIFIED |
| RE-POPS-111 | Pervasive stale path:line anchors and line counts in ARCHITECTURE.md / COMPONENTS.md (and one in LAUNCH_ARGUMENTS.md) | L | Low | VERIFIED |
| RE-POPS-112 | COMPONENTS.md on-card payload lists only three of the six BDMA IRX variants | S | Low | VERIFIED |
| RE-POPS-113 | STATE.md still says Slovak is not in the language picker | S | Low | VERIFIED |
| RE-POPS-114 | STATE.md says the dropped Square binding still toggles cover art | S | Low | VERIFIED |
| RE-POPS-115 | STATE.md says carousel devices are "all shown by default"; i.Link ships hidden | S | Low | VERIFIED |

## Narrowed scopes
- RE-POPS-008: In-block misaligned scan returning a bogus descriptor stands, plus a 1-byte edge read at `staticDeviceDescEndPtr - 1`; the claimed read past the end pointer is defeated by the loops' short-circuit bound check (`descBuf < EndPtr && *descBuf`).
- RE-POPS-011: Latent helper defect only: the guard admits index 10 and negative indices, but FatFs `pdrv` is provably capped at 0–9 in-tree and `fd->unit` reachability depends on external iomanX parsing — no in-tree caller reaches a bad index today.
- RE-POPS-022: Graphics/font handle dereferences, `freeImage` double-free, and Timer's dereference-first magic check stand at filed strength; the ADPCM limb narrows to wild/stale/double-free handles only — handle 0 is NULL-checked in `sound_playadpcm`/`sound_freeadpcm` and is safe.
- RE-POPS-036: The 512 B leak on MBR's read-failure path is real but masked on whole devices by RE-POPS-018's error-swallowing; it is reachable only on uncached probes / crafted offset-0 partitions, and widens back to filed scope if RE-POPS-018 is fixed first.
- RE-POPS-040: Byte matrix and default≡DEBUG stand, but the patch bytes are documented in `.research/build_site.py` ($410 debug-text, $413 USB-delay, $410–$42F table); true scope is undocumented in shipped/packaging locations, with the default=DEBUG intent recorded nowhere.
- RE-POPS-041: 23-of-26 sourceless census and 18/26 with no enforced pin stand; the popsmb SHA-256s are recorded descriptively in a `.research` note and both usbexfat blobs' hashes are on record under their identical twins' names — the surviving gap is enforcement (18/26) and path-level checking of the usbexfat paths.
- RE-POPS-044: Embed `usbhdfsd.irx` is MX4SIO v1.2 with no source in the tarball, but "usbd_bd_assault appears in neither shipped binary" holds only for the embed pair — repo-wide it ships as `bin/POPSLDR/usbhdfsd.irx.udpfs`/`.usbexfat`; README pairing is at lines 11–12, not 13–16.
- RE-POPS-054: Duplication is real (100 rows / 49 unique symbols in source text; 98 rows / 48 compiled in this checkout because the `default.png` rows are `#ifdef`'d out), but `embedded_get` does not normalise bare names — the bare rows cannot be deleted until a bare→canonical mapping is added, or bare lookups such as `"USB.png"` will 404.
- RE-POPS-059: Present-tense wrong defaults stand at STATE:65, TESTING:131/135, ROLLING:130 and README:178 `(guest)`; STATE:237's DHCP clause and ROLLING:177 are past-tense explanations of older builds — from STATE:237 only its closing "Port default 1111 is deliberate" note stands.
- RE-POPS-063: The cache-defeating / RPC re-binding mechanism is verbatim in the C binding, but a repo-wide grep finds no Lua caller at the pin — the cost is latent in a registered-but-uncalled binding, not a live page-entry cost.
- RE-POPS-077: PNG triplication stands (row blocks at calloc lines 172/217/267; CLUT in the 2 palette branches, not 3) plus BMP pixel-conversion-stage triplication; the claimed three separate `loadbmp` VRAM-alloc/upload/free tails is refuted — `loadbmp` (428–849) has one shared VRAM tail.
- RE-POPS-081: The three-helper duplication stands, but consolidation onto the NormRaw variant is not provably behavior-identical: ui.lua:10534 passes raw `System.currentDirectory()` and the `gamelocation` sites (1784, 11463) are only isra-normalized, so NormRaw changes results on nil/backslash/duplicate-slash inputs at those sites.
- RE-POPS-091: Limbs (a), (b), (c) and (e) are dead as filed; limb (d) is refuted — `UI.ResolveSelectedVcdPath` is deliberate test surface consumed by `tools/host_harness.py` T54 (hard-fails at :2334-2335 if missing, called at :2375), so it must be kept or the harness migrated in the same change.
- RE-POPS-098: `ASYNC` is truly never defined, but the genuinely ASYNC-only dead code is ≈48 lines (usb_mass.c:426-442 + 492-522), not ~90; `struct usbmass_cmd` is not ASYNC-exclusive — the live sync path builds CBW/CSW through it (usb_mass.c:447, 459-479), so deleting it would break the live build, and "uncompilable" is unproven.
- RE-POPS-107: The finding lists six docs, not five, and five of the six are explicitly dated snapshots (ARCHITECTURE/COMPONENTS/CONTRIBUTING "Last updated 2026-07-27"; PRESERVATION dated/re-synced 2026-07-27; DECISIONS:1 disclaims being a current-state snapshot); the genuinely present-tense, tester-harming instance is TESTING.md:3 alone.

## Defeating evidence
None.

## Candidates
### CAND-01
- Label: GPT partition-scan counter `int i` compared against `u32 partition_count` — signed-overflow UB for a crafted count ≥ 2³¹
- Mechanism: The GPT scan loop at part_driver_gpt.c:73 iterates with a signed `int i` against the device-supplied `u32 partition_count`. A crafted count ≥ 2³¹ overflows the signed counter, which is undefined behaviour and can derail the scan independently of the unbounded-read issue.
- Locations: part_driver_gpt.c:73
- Proposed class: EXTENSION of RE-POPS-006
- Justification: Same GPT scan and same validation fix site as RE-POPS-006 (unvalidated `partition_count`); an additional overflow consequence of the same unvalidated field.

### CAND-02
- Label: Via-cache GPT entry read goes out of bounds: entries 4..31 are read past the 1,024-byte allocation because bd_cache.c:86 delivers only 512 B per read
- Mechanism: On the cached path the cache delivers only 512 B per read into the GPT entry half-buffer, while `entriesPerSector` is derived from the real sector size (up to 32 entries at 4096 B). The scan then indexes entries 4..31 past the 1,024-byte scratch allocation.
- Locations: part_driver_gpt.c:93-97; bd_cache.c:86
- Proposed class: EXTENSION of RE-POPS-001
- Justification: Same mechanism and fix site as RE-POPS-001 — GPT indexing a 512-sized buffer by the real sector size — manifesting on the via-cache path RE-POPS-001/004 split.

### CAND-03
- Label: `bdm_connect_bd` silently drops a device when all 20 mount slots are full (no error surfaced)
- Mechanism: When every mount slot in `bdm_connect_bd` is occupied, the scan finds no free slot and the function simply returns. The device is never mounted and no error is logged or propagated to the caller.
- Locations: bdm.c:50-66
- Proposed class: NEW
- Justification: No redo finding covers mount-slot exhaustion or silent connect failure in `bdm_connect_bd`; distinct mechanism and site.

### CAND-04
- Label: `usb_mass_connect` also dereferences `config`/`interface` unchecked (extension of RE-POPS-007's site list)
- Mechanism: `usb_mass_connect` additionally dereferences the `config` and `interface` descriptors without NULL checks, beyond the first-endpoint dereference RE-POPS-007 filed. A device yielding no config/interface descriptor is a NULL dereference on the same connect path.
- Locations: usb_mass.c:648-656
- Proposed class: EXTENSION of RE-POPS-007
- Justification: Explicitly an extension of RE-POPS-007's site list: same function, same unchecked-descriptor mechanism, additional pointers.

### CAND-05
- Label: 1-byte over-read at `staticDeviceDescEndPtr − 1` in the hcd scan (the surviving edge of RE-POPS-008)
- Mechanism: When the descriptor walk lands exactly on `EndPtr - 1`, the bound test passes and the predicate reads that last in-block byte. This is the surviving edge case already incorporated into RE-POPS-008's narrowed true scope in the verify report §4.
- Locations: hcd.c:200-202
- Proposed class: REJECTED
- Justification: Full duplicate of RE-POPS-008's surviving narrowed scope — same site, same mechanism, no additional location or instance.

### CAND-06
- Label: `USBMASS_IOCTL_GET_FRAGLIST` never validates `rdata` — NULL pointer + non-zero length = NULL-pointer write in `get_frag_list` (a fourth unchecked site for RE-POPS-012's fix)
- Mechanism: The GET_FRAGLIST ioctl passes `rdata` into `get_frag_list` without validating it. A NULL `rdata` with a non-zero length makes the fragment walk write through a NULL pointer, a fourth unchecked site alongside the three RE-POPS-012 filed.
- Locations: fs_driver.c:707-709
- Proposed class: EXTENSION of RE-POPS-012
- Justification: Explicitly a fourth unchecked site for RE-POPS-012's fix: same `get_frag_list`/ioctl mechanism, additional caller site.

### CAND-07
- Label: `get_fat`'s error sentinel 1 is a fixed point of the frag-list loop (strengthens RE-POPS-019's non-termination case)
- Mechanism: `get_fat` returns sentinel 1 on error, and cluster 1 fed back into the frag-list walk returns 1 again, so the loop never progresses and never reaches a value ≥ `n_fatent`. A chain reaching cluster 0/1 therefore hangs with no crafted FAT cycle required.
- Locations: fs_driver.c (get_fat)
- Proposed class: EXTENSION of RE-POPS-019
- Justification: Same non-termination mechanism and bound-the-walk fix as RE-POPS-019; an additional, non-crafted trigger for the same loop.

### CAND-08
- Label: USB `readReport`/`usb_data_cb` ignore the transfer byte count in both USB copies, exactly as RE-POPS-009 documents for BT
- Mechanism: The USB copies' report callbacks receive the transfer byte count but never bound-check it before parsing the report buffer. Short or truncated transfers are therefore parsed from stale buffer bytes, exactly the mechanism RE-POPS-009 documented for the BT copies.
- Locations: ds34usb copies
- Proposed class: EXTENSION of RE-POPS-009
- Justification: Same ignored-byte-count mechanism as RE-POPS-009, in the two USB copies RE-POPS-009 did not cover.

### CAND-09
- Label: `chrg_connect` dereferences `config->bConfigurationValue` unchecked in both BT copies
- Mechanism: In both BT copies, `chrg_connect` obtains the config descriptor via `UsbGetDeviceStaticDescriptor` and immediately reads `config->bConfigurationValue` to set the device configuration. No NULL check intervenes, so a device with no config descriptor is a NULL dereference in a connect path no redo finding covers.
- Locations: ds34bt copies
- Proposed class: NEW
- Justification: Distinct function and driver (`chrg_connect`, the DS34 charge driver) not mentioned anywhere in the redo corpus; not a site of RE-POPS-002's endpoint walk.

### CAND-10
- Label: USB EE `ds34usb_get_bdaddr`'s unconditional copy also fires on outright RPC failure (scoping note inside RE-POPS-035's mechanism)
- Mechanism: `ds34usb_get_bdaddr` copies the address bytes out of the static RPC buffer unconditionally, and that copy also fires when `SifCallRpc` itself fails outright — not only when the IOP returns a failure byte. The caller receives a stale Bluetooth address presented as a fresh result.
- Locations: EE ds34usb
- Proposed class: EXTENSION of RE-POPS-035
- Justification: Same function, same unconditional-copy mechanism and same fix as RE-POPS-035; an additional failure trigger (outright RPC failure) at the filed site.

### CAND-11
- Label: `fntNewAtlas` (fntsys.cpp:428-437) + `atlasPlace` NULL-dereference chain — the caller-side half RE-POPS-030's fix omits
- Mechanism: If `atlasNew` were made to return NULL on allocation failure as RE-POPS-030 proposes, `fntNewAtlas` immediately dereferences the result and `atlasPlace` dereferences `atlas->allocation`. Without caller-side NULL guards, RE-POPS-030's fix trades one NULL dereference for another.
- Locations: fntsys.cpp:428-437; atlas.cpp (atlasPlace)
- Proposed class: EXTENSION of RE-POPS-030
- Justification: Caller-side half of RE-POPS-030's own mechanism and fix, at additional locations the filed fix omits.

### CAND-12
- Label: `System.getMassRootByBackendName` (luasystem.cpp:2581) is itself a zero-caller RE-POPS-048-family binding — decide RE-POPS-063's fix jointly with keep-or-delete
- Mechanism: The candidate notes that the binding behind RE-POPS-063 has no Lua caller and belongs to the dead-binding family, so RE-POPS-063's fix should be decided jointly with keep-or-delete. The binding is, however, already enumerated by name in RE-POPS-048's dead-binding list in the redo report.
- Locations: luasystem.cpp:2581
- Proposed class: REJECTED
- Justification: Full duplicate: `System.getMassRootByBackendName` is already counted in RE-POPS-048's census; the candidate is a decision cross-reference for RE-POPS-063, not a distinct defect.

### CAND-13
- Label: A third inline VCD-strip copy exists at system.lua:9585 (`PLDR.HDD.GameEntryDisplayKey`) — extends RE-POPS-093's consolidation
- Mechanism: A third inline copy of the VCD-extension strip operation exists inside `PLDR.HDD.GameEntryDisplayKey`, beyond the two definitions RE-POPS-093 filed in system.lua and ui.lua. Consolidating only the two filed copies would leave this inline instance behind.
- Locations: system.lua:9585
- Proposed class: EXTENSION of RE-POPS-093
- Justification: Explicitly extends RE-POPS-093's consolidation: same duplicated operation, an additional third instance.

### CAND-14
- Label: DECISIONS.md:300, STATE.md:128, docs/archive/LAUNCH_HYGIENE.md:150 describe `PLDR.GetBootKind` as a consumed public API (doc residue of RE-POPS-090)
- Mechanism: Three documents describe `PLDR.GetBootKind` as a consumed public API, while RE-POPS-090 proved the function has exactly one occurrence in code — its definition. The docs present dead code as a live interface other code depends on.
- Locations: DECISIONS.md:300; STATE.md:128; docs/archive/LAUNCH_HYGIENE.md:150
- Proposed class: NEW
- Justification: Distinct doc-vs-code defect at doc locations no redo finding covers; RE-POPS-090 owns the dead code, not these false consumption claims.

### CAND-15
- Label: `print_uart` (luasystem.cpp:2660, registered via `lua_register` as a global) has zero Lua callers — a dead registration outside RE-POPS-048's `luaL_Reg` census scope
- Mechanism: `print_uart` is registered as a Lua global via `lua_register`, a registration route RE-POPS-048's `luaL_Reg`-table census could not see. It has zero Lua callers, so it is dead Lua surface of exactly RE-POPS-048's kind, reached by a different registration mechanism.
- Locations: luasystem.cpp:2660
- Proposed class: EXTENSION of RE-POPS-048
- Justification: Same dead-binding mechanism as RE-POPS-048 with an additional instance its census scope (luaL_Reg tables only) missed.

### CAND-16
- Label: Stale comment at ui.lua:2050 inside RE-POPS-094's duplicate cascade ("all other scenes use BKG.png") contradicts the cascade directly below it
- Mechanism: The comment at ui.lua:2050 claims all other scenes use BKG.png, but the scene-background cascade directly below it — the code RE-POPS-094 duplicates — does not do that. The comment misdescribes the live behaviour it annotates.
- Locations: ui.lua:2050
- Proposed class: NEW
- Justification: A stale-comment defect at a location no redo finding covers; RE-POPS-094 owns the cascade's duplication, not this contradictory comment.

### CAND-17
- Label: RE-POPS-071 fix-completeness: ui.lua:2614's fallback `_NormalizeLayout` also accepts `"ABNT"` (and divergently `"ABC"`) — unreachable in shipped load order but absent from 071's removal list
- Mechanism: The PathEditor fallback `_NormalizeLayout` at ui.lua:2614 also accepts `"ABNT"` (and, divergently, `"ABC"`). It is unreachable in shipped load order, but RE-POPS-071's removal list omits it, so the filed fix would leave an ABNT-accepting remnant.
- Locations: ui.lua:2614
- Proposed class: EXTENSION of RE-POPS-071
- Justification: Explicitly RE-POPS-071 fix-completeness: same ABNT-removal fix, an additional accepting site the filed fix misses.

### CAND-18
- Label: Subject-report scope-census drift: "639 tracked files" vs `git ls-files` = **609** (639 is the on-disk count including 30 ignored `__pycache__/*.pyc`; the byte total matches the tracked set); Markdown count 163 vs the report's claimed 162
- Mechanism: The candidate corrects the subject report's own header census: `git ls-files` gives 609 tracked files, not 639, and 163 Markdown files, not 162. It identifies no defect in the repository itself.
- Locations: report header vs `git ls-files`
- Proposed class: REJECTED
- Justification: Census correction of the subject report itself, not a code defect in the repo.

### CAND-19
- Label: COMPONENTS.md:400-405 presents the three dead RE-POPS-056 binaries as bin2c'd/live and the active mx4sio_bd as pinned from `iop/embed/PS2SDK_MX4SIO` — contradicted by Makefile:346-352 (a distinct limb from RE-POPS-112)
- Mechanism: COMPONENTS.md:400-405 presents the three binaries RE-POPS-056 proved dead as bin2c'd/live, and describes the active mx4sio_bd as pinned from `iop/embed/PS2SDK_MX4SIO`. Makefile:346-352 contradicts both statements.
- Locations: COMPONENTS.md:400-405
- Proposed class: NEW
- Justification: Distinct doc-vs-code defect at COMPONENTS.md:400-405, expressly a different limb from RE-POPS-112; RE-POPS-056 owns the dead binaries, not this live presentation of them.

### CAND-20
- Label: Byte-accounting caution: the `5ea4818b`/`70a369e4` duplicate bytes are counted in both RE-POPS-049 and RE-POPS-050, and the 167,700 B default≡DEBUG copy in both RE-POPS-040 and RE-POPS-050(c) — report-level savings roll-ups would double-count (see §2)
- Mechanism: The same duplicate bytes are counted in two findings each, so a report-level roll-up summing finding-level byte savings would double-count them. This is an accounting caution about the reports, not a defect in the repository.
- Locations: —
- Proposed class: REJECTED
- Justification: Pure accounting caution with no defect, as the verify report's own §2 frames it.

### CAND-21
- Label: The "Ember only" claim from RE-POPS-060 survives in two code comments: ui.lua:1067 (the `GILINK = 11` line) and system.lua:9161 (`InitILINKRoot` header)
- Mechanism: The false "Ember only" framing RE-POPS-060 documented in seven doc passages also survives in two code comments: the `GILINK = 11` line comment and the `InitILINKRoot` header comment. i.Link is in fact implemented for Ember and POPSTARTER, per RE-POPS-060.
- Locations: ui.lua:1067; system.lua:9161
- Proposed class: EXTENSION of RE-POPS-060
- Justification: Same false claim as RE-POPS-060, at additional locations (code comments) beyond the seven doc passages filed.
