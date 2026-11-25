# Round 5 — Section 04: `iop/usbd-ra` (USB host driver) + `iop/pccf` (PC Card/CF)

Repo: NathanNeurotic/Launchstation, pin `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified, no fetch).
Scope note: no finding below repeats LAUNCHSTATION-001…096. The only prior touch of either
directory was LAUNCHSTATION-018 citing `iop/usbd-ra/src/usbd.c:200` as one of thirteen `#if 0`
sites; that block is not re-filed here. READ = line-read at the pin in this pass;
INFERRED = reasoned from READ code, not executed. No build or hardware claims.

---

## A) `iop/usbd-ra` — vendored USB host-controller driver (OHCI)

### (a) Provenance + built-or-not verdict

- **Provenance (READ):** No `VENDORED.md`/`ORIGIN.md` in the directory. Every source/header
  carries the ps2dev 2001–2004 AFL-2.0 header. `git log -- iop/usbd-ra/` shows exactly two
  commits: `959c271` "vendor RiptOPL usbd-ra to eliminate post-2024 USBD hardware controller
  loss and IOP hangs" (single-commit import of all 21 files) and `59411fa`, which only deleted
  its `Makefile`. No `.c`/`.h` file has been edited since the import. The pin identity is
  stated in-tree at `ps2.yaml` (wLaunchELF target comment): "RiptOPL vendored USBD (usbd-ra):
  ps2sdk pre-rewrite (314d87e7) with MINI_DRIVER and USE_GP_REGISTER=0. Avoids the
  post-2024-09-04 USBD rewrite…". So: **pristine upstream code; the entire local delta is
  build configuration** — `ps2.yaml:46-63` target `usbd_ra` with defines `MINI_DRIVER`,
  `USE_GP_REGISTER=0`. (That the import is byte-identical to ps2sdk@314d87e7 itself is
  INFERRED from the single-commit import + comment; no upstream fetch was made.)
- **Built/linked (READ): YES, twice over.** Target `usbd_ra` at `ps2.yaml:46-63` builds
  exactly the seven `.c` files in scope. It is embedded as `usbd_ra:usbd` in **both** EE
  targets: `wle_igr` (`ps2.yaml:473`) and `wLaunchELF` (`ps2.yaml`, embed list, comment at
  the usbd entry). Runtime load is with **zero module arguments**: `src/init.c:1566`
  `SifExecModuleBuffer(usbd_irx, size_usbd_irx, 0, NULL, &ret)` and the Ember path
  `src/init.c:2092,2096`. This matters for T4-F5: the unvalidated `_start` argument surface
  is not reachable from Launchstation's own loader.

### (b) Coverage ledger — usbd-ra (all READ end-to-end)

| File | Lines | Status |
|---|---|---|
| `src/driver.c` | 283 | READ |
| `src/hcd.c` | 544 | READ |
| `src/hub.c` | 737 | READ |
| `src/interface.c` | 452 | READ |
| `src/mem.c` | 259 | READ |
| `src/usbd.c` | 410 | READ |
| `src/usbio.c` | 319 | READ |
| `src/driver.h` / `hcd.h` / `hub.h` / `mem.h` / `usbio.h` | 31/28/19/45/28 | READ |
| `src/usbdpriv.h` | 328 | READ |
| `include/usbd.h` | 361 | READ |
| `include/usbd_macro.h` | 154 | READ |
| `src/exports.tab` / `src/imports.lst` / `src/irx_imports.h` | 23/48/30 | READ |

### (c) Findings — usbd-ra

### T4-F1 / Isochronous halted-ED cleanup clears the wrong LUT slot, leaving a dangling request / Category 6
- Locations: `iop/usbd-ra/src/usbd.c:137-139` (`processDoneQueue_IsoTd`); contrast the correct twin at `iop/usbd-ra/src/usbd.c` in `processDoneQueue_GenTd` (clears `hcTdToIoReqLUT[tdListPos - memPool.hcTdBuf]` for the TD actually being retired)
- Problem: In the halted-endpoint walk, the code fetches `req = hcIsoTdToIoReqLUT[curTd - hcIsoTdBuf]` but then clears `hcIsoTdToIoReqLUT[arg - hcIsoTdBuf]` — `arg`'s slot, already cleared at `usbd.c:109`. `curTd`'s slot keeps pointing at an `IoRequest` that is simultaneously queued for completion (result `USB_RC_ABORTED`) and will be freed/callbacked below. A later done-queue pass for that TD index can complete the same request a second time (double callback / use-after-free of the request slot). The generic-TD path in the same file does the identical walk correctly, so this is a copy-drift bug inside one file, not a design choice. READ.
- Fix: Change the clear to `memPool.hcIsoTdToIoReqLUT[curTd - memPool.hcIsoTdBuf] = NULL;` (one line, mirrors GenTd).
- Benefit: Removes a double-completion path on isochronous endpoints (audio/webcam-class devices) after a halt — the rarest exercised path in the driver, hence the one most likely to still carry it.
- Effort: S (one line)
- Risk: Low — the change makes IsoTd match the already-shipping GenTd behaviour.
- Confidence: READ

### T4-F2 / Config-descriptor fetch trusts device-supplied `wTotalLength` and never checks `transferedBytes`; short transfers parse stale bytes, oversize devices wedge silently / Category 6
- Locations: `iop/usbd-ra/src/hub.c:402-440` (`fetchConfigDescriptors`); feeder `iop/usbd-ra/src/hub.c:444-475` (`requestDevDescrptCb`/`requestDeviceDescriptor`); consumer walk `iop/usbd-ra/src/hcd.c:185-206` (`doGetDeviceStaticDescriptor`)
- Problem: Three linked gaps in one state machine, all fed by device-supplied data. (1) The advance/fetch length is `READ_UINT16(&desc->wTotalLength)` taken from the 4-byte header fetch; no check that `wTotalLength >= sizeof(UsbConfigDescriptor)` (9) or that it matches the bytes actually delivered — `req->transferedBytes` is never consulted in `fetchConfigDescriptors`. A device that ACKs the full-length request but delivers fewer bytes leaves the tail of its 512-byte static slot holding the **previous device's descriptors** (slots are per-device-id, zeroed only once at pool allocation in `initHcdStructs`), and `doGetDeviceStaticDescriptor` plus every LDD `probe`/`connect` then parse that mixture as the new device's own descriptors. (2) `bNumConfigurations` (device byte, up to 255) is trusted as the loop bound. (3) When the cumulative size exceeds `maxStaticDescSize` the function just `return`s (`hub.c:427-429`, comment "silently ignore the device") — no `killDevice`, no completion: the device stays neither connected nor flushed, its control request consumed, until unplug. READ for the mechanism; which real devices short-transfer is INFERRED.
- Fix: In `fetchConfigDescriptors`, require `req->transferedBytes == readLen` (and on the header pass, `wTotalLength >= 9`) before advancing `staticDeviceDescEndPtr`; on any mismatch or on the too-large branch, call the existing `killDevice(dev, ep)` instead of returning bare.
- Justification (if ADD): No addition — two comparisons and reuse of the existing teardown path; net code is the deletion of the silent-wedge outcome.
- Benefit: Descriptor parsing stops consuming cross-device stale data, and a non-conforming device is rejected deterministically instead of occupying a slot in limbo.
- Effort: S
- Risk: Low–Medium — a device that today "works" only because its short transfer happens to be followed by zero/stale bytes would now be rejected; that is the intended fail-closed direction.
- Confidence: READ (mechanism) / INFERRED (field prevalence)

### T4-F3 / Device-descriptor short read retries forever with no counter / Category 5
- Locations: `iop/usbd-ra/src/hub.c:451-454` (`requestDevDescrptCb`); re-arm at `iop/usbd-ra/src/hub.c:465-475`
- Problem: If the device answers `USB_RC_OK` but with `transferedBytes < sizeof(UsbDeviceDescriptor)`, the callback unconditionally re-issues the identical full-descriptor request. A device that persistently short-reads (e.g. always returns its 8-byte first packet) loops control transfers indefinitely: it is never killed, never connected, and generates bus traffic for as long as it is plugged in. Every other retry in this driver is bounded (`hubSetFuncAddressCB` doubles `functionDelay` and gives up past `0x500`; CIS/ATA in pccf are counted); this one has no bound at all. READ.
- Fix: Count retries on the `Device` (e.g. reuse/`fetchDescriptorCounter`-style field or a new u8) and `killDevice(dev, ep)` after a small fixed number (3 matches the pccf CIS retry convention in-tree).
- Justification (if ADD): One counter increment + comparison is the smallest change that terminates the loop; no new mechanism.
- Benefit: A stuck/broken device stops consuming the control endpoint and bus bandwidth forever.
- Effort: S
- Risk: Low
- Confidence: READ

### T4-F4 / Recycled hub buffer keeps the previous hub's `bNbrPorts` when the new hub descriptor is short / Category 6
- Locations: `iop/usbd-ra/src/hub.c:71-81` (`allocHubBuffer`); `iop/usbd-ra/src/hub.c:714-720` (`hubDrvConnect` descriptor copy); use at `iop/usbd-ra/src/hub.c:606-625` (`hubSetupPorts`) gated only by `iop/usbd-ra/src/hub.c:632` (`bNbrPorts <= maxPortsPerHub`, = 4 under MINI_DRIVER)
- Problem: `allocHubBuffer` resets only `desc.bDescriptorType` and the two `busyFlag`s — the rest of `UsbHub.desc` survives from the previous hub that used the slot (the pool is allocated and zeroed once in `initHubDriver`). `hubDrvConnect` copies the device-supplied hub descriptor with `len = hubDesc->bLength` clamped **above** to `sizeof(UsbHubDescriptor)` but never clamped **below**: a hub descriptor with `bLength < 3` copies the type byte but not `bNbrPorts`, so the stale previous-hub value flows into `hubSetupPorts`, which attaches that many child devices. The ≤4 cap in `hubCheckPorts` bounds the damage to phantom ports of a previous, larger hub — wrong topology, spurious child slots consumed from a 16-device MINI pool. READ.
- Fix: `memset(&res->desc, 0, sizeof(res->desc))` in `allocHubBuffer` (one line), and/or reject `len < 3` in `hubDrvConnect`. The memset alone closes it for every field, not just `bNbrPorts`.
- Benefit: Hub topology derives only from the attached hub's own descriptor; recycled slots stop leaking state across devices (same stale-slot class as T4-F2, local instance).
- Effort: S
- Risk: Low
- Confidence: READ

### T4-F5 / `_start` config arguments are parsed without range checks and feed unchecked allocation arithmetic; `AllocSysMemory` result is memset before any NULL check / Category 6
- Locations: `iop/usbd-ra/src/usbd.c:295-333` (`ParseOptionInput`); `iop/usbd-ra/src/usbd.c:335-390` (`_start` option table); `iop/usbd-ra/src/hcd.c:378-381` (`memSize` computation + `AllocSysMemory` + `memset`); layout consumers `iop/usbd-ra/src/hcd.c` `initHcdStructs` passim
- Problem: A chain of three. (1) `ParseOptionInput` accepts any char where `*p - '0' <= 9` — characters **below** `'0'` yield a negative digit and are accumulated, and the `value*10+digit` accumulation has no overflow guard. (2) The parsed ints overwrite `usbConfig` fields (`maxDevices`, `maxEndpoints`, TD counts, `maxStaticDescSize`, thread priorities) with no clamping against the compiled MINI maxima. (3) `initHcdStructs` computes `memSize = (u32)devDescBuf + maxDevices * maxStaticDescSize` in wrapping u32 arithmetic, calls `AllocSysMemory`, and immediately `memset(memBuf, 0, memSize)` — `memBuf` is never checked for NULL (its sibling `initHubDriver` in `hub.c` does check). Crafted or merely large arguments therefore produce a NULL dereference or a pool whose internal offsets overrun the allocation during initialisation. Mitigation, READ: Launchstation itself loads the module with `argc=0` (`src/init.c:1566,2092,2096`), so today this is reachable only by another loader/homebrew passing arguments — a latent trap in a module whose whole purpose is to be loaded by other software. READ.
- Fix: Clamp each parsed value to `[1, compiled-in maximum]` in `_start` after parsing (the non-MINI table in `usbd.c` already documents sane maxima), reject negative parse results in `ParseOptionInput` (`NewValue < 0 || NewValue > 9`), and return an error from `initHcdStructs` if `memBuf == NULL`, mirroring `initHubDriver`.
- Benefit: Module initialisation fails closed instead of corrupting IOP memory when handed bad arguments; costs a few comparisons at load time only.
- Effort: S
- Risk: Low — Launchstation's own zero-argument load path is untouched.
- Confidence: READ

### T4-F6 / The local MINI_DRIVER choice caps total descriptors at 512 bytes/device and the overflow path drops the device with no diagnostics in release builds / Category 6 / 8
- Locations: Local delta `ps2.yaml:58-62` (`MINI_DRIVER`); `iop/usbd-ra/src/usbd.c` MINI `usbConfig` (`maxStaticDescSize = 0x200`, `maxDevices = 0x10`, `maxHubDevices = 4`, `maxPortsPerHub = 4`); drop site `iop/usbd-ra/src/hub.c:427-429`
- Problem: `MINI_DRIVER` is Launchstation's own selection (see provenance). Any device whose device+config descriptor set exceeds 512 bytes total — routine for multi-interface composite devices — hits the T4-F2 too-large branch and is ignored; `dbg_printf` compiles to nothing without `DEBUG` (`usbdpriv.h`), so on release builds the device simply never appears, with no log and no user-visible reason. This is a shipped-behaviour consequence of the local configuration, distinct from T4-F2's parsing bug: even a perfectly conforming large-descriptor device is dropped. Whether any target device class for Launchstation actually exceeds 512 bytes is INFERRED (not measured); the cap and the silence are READ.
- Fix: No code growth required to surface it: keep the cap, but make the drop observable (one unconditional `printf` on that branch, as other fatal paths in `hcd.c` already use `printf`). Raising `maxStaticDescSize` is a separate, RAM-costing decision (16 devices × each +512 B = +8 KiB IOP) for the maintainer, not recommended here by default.
- Benefit: An invisible compatibility cliff becomes diagnosable; support reports can distinguish "not recognised" from "descriptors too large for the mini driver".
- Effort: S
- Risk: Low
- Confidence: READ (cap + silence) / INFERRED (real-world hit rate)

### T4-F7 / Four imports are declared and never called (`strtol`, `DeleteSema`, `DeleteThread`, `DelayThread`) / Category 1
- Locations: `iop/usbd-ra/src/imports.lst:17` (`I_strtol`), `:32` (`I_DeleteSema`), `:45-46` (`I_DeleteThread`, `I_DelayThread`); zero callers in all seven `.c` files (grep-verified this pass). `src/irx_imports.h` also includes `thmsgbx.h` and `vblank.h`, which no source uses.
- Problem: Dead import stubs are linked into the IRX for functions the module hand-rolls instead (decimal parsing in T4-F5 is hand-written while `strtol` sits imported and unused). Pure residue, multiplied across every embedded copy (the module ships in both EE targets).
- Fix: Delete the four `imports.lst` lines and the two unused `irx_imports.h` includes.
- Benefit: Smaller IRX stub table in both embeddings; removes the false signal that `strtol` validates the `_start` arguments.
- Effort: S
- Risk: Low — no caller exists to break.
- Confidence: READ

### (d) Checked-and-clean — usbd-ra

- `interface.c` export surface: every `sceUsbd*` entry takes `usbdLock`, validates device/endpoint via `fetchDeviceById`/`fetchEndpointById` (both range- and liveness-checked, `mem.c`), and `sceUsbdTransferPipe` correctly short-circuits on `BADPIPE` before dereferencing `ep`, checks the OHCI two-page span limit and isochronous packet size. READ, no finding.
- `mem.c` free-list functions (`freeTd`, `freeIsoTd`, `freeIoRequest`, `freeDevice`) all scan for double-free and `freeDevice` range-checks the pointer against the pool. READ.
- `hub.c` `addTimerCallback`'s `HcInterruptEnable = OHCI_INT_SF` is **not** a lost-update bug: OHCI enable/disable are write-to-set/write-to-clear registers, so the assignment sets exactly SF. Same for `handleTimerList`'s disable write in `usbd.c`. READ, deliberately not flagged.
- `driver.c` callback thread: copies the request before freeing it, then invokes the copy's callback. The post-free `req->gpSeg` read exists only under `USE_GP_REGISTER`, which the local build defines to `0` (`ps2.yaml`) — compiled out in the shipped module. READ for the shipped configuration.
- `exports.tab` exports exactly the 14 implemented functions; the two header-declared unimplemented functions (`sceUsbdGetReportDescriptor`, `sceUsbdMultiIsochronousTransfer`, `include/usbd.h` — self-labelled "these aren't implemented") are not exported. READ.
- `fetchPortElemByNumber` NULL result is checked by its hub caller; root-hub port indexing in `handleRhsc` matches the exactly-two root children created in `initHcdStructs`. READ.

---

## B) `iop/pccf` — PC Card / CompactFlash block driver

### (a) Provenance + built-or-not verdict

- **Provenance (READ):** `iop/pccf/VENDORED.md` pins upstream **mihhru/PS2CF @
  `9b6ed3702b59a87512426952e003125a5b4f0e3c`**, imported from `src/wlaunchelf/iop/pccf`;
  power/reset sequence derives from PS2SDK DEV9 (AFL-2.0, `PS2SDK_LICENSE.txt` in-tree).
  Git history: `5aefb4d` port, `f285f02` semaphore fail-closed fix, `bdfdc04` embed +
  ownership lifecycle, `fc11a92` toolchain move, `59411fa` Makefile removal.
  **Local delta (READ, per VENDORED.md + in-source markers):** (i) module entry no longer
  force-reclaims a powered controller and rejects a resident DEV9 library before any
  semaphore/MMIO (`main.c:67-90`, comment "Launchstation shares the PC CARD bus with DEV9");
  (ii) `uintptr_t` alignment in the PIO bulk path (Windows LLP64 host-harness portability);
  (iii) **`pccf_control.inc` is entirely Launchstation-authored** (its header: "Launchstation-
  specific lifecycle control"), plus `include/pccf_control.h`; (iv) 1000 µs PIO settle kept
  from upstream. The ATA/CIS/CF-diagnostic cores (`pccf_ata.c`, `pcdiag_cis.c`, `pcdiag_cf.c`,
  most of `pccf_hw.c`) are upstream material.
- **Built/linked (READ): YES — but embed-limited and feature-gated.** Target `pccf` at
  `ps2.yaml:37-44` builds the five `.c` files; embedded in `wLaunchELF` only
  (`ps2.yaml:665`) — **not** in `wle_igr`'s embed list. Runtime loading is on-demand and
  ownership-gated (`src/init.c:2486-2497`). VENDORED.md itself states the EE service exists
  but "No boot probe or Files/Devices entry calls the service yet. Filesystem mount/rescan/
  handle invalidation remains unfinished" — i.e. the IRX ships in every release ELF while
  its user-facing feature is not yet wired in. Recorded as a build fact; the gating is
  documented and deliberate, so it is not filed as a finding.

### (b) Coverage ledger — pccf (all READ end-to-end)

| File | Lines | Status |
|---|---|---|
| `main.c` | 106 | READ |
| `pccf_ata.c` | 229 | READ |
| `pccf_hw.c` | 252 | READ |
| `pcdiag_cf.c` | 71 | READ |
| `pcdiag_cis.c` | 186 | READ |
| `pccf_control.inc` | 54 | READ |
| `pccf_pio_bulk.inc` | 31 | READ |
| `pccf_pio_profile.inc` | 28 | READ |
| `pccf_ata.h` / `pcdiag_ata.h` / `pcdiag_cf.h` / `pcdiag_cis.h` / `pcclog.h` | 32/21/18/31/4 | READ |
| `VENDORED.md` / `imports.lst` / `irx_imports.h` / `ps2.yaml` (local) | —/26/9/10 | READ |

### (c) Findings — pccf

### T4-F8 / `pcdiag_cf_probe`'s sampling phase is diagnostic dead work in the production driver: results go to a no-op trace, the return is unconditional, and it costs ~700 ms on every start / Category 1 / 5
- Locations: `iop/pccf/pcdiag_cf.c:40-70` (3 samples × 2 selector spaces × read8/read16 sweeps, `wait_ms(500)` + 2× `wait_ms(100)`); production caller `iop/pccf/pccf_hw.c` (`pccf_hw_start`) passes `quiet_trace`, the variadic sink defined in the same file that discards every argument; only the candidate/COR gates at `pcdiag_cf.c` top (through the COR check) influence the outcome
- Problem: The function's own header calls it "DIAG 4 … interpretation awaits hardware comparison". In the shipped module every sampled byte/word is formatted for a trace callback that is a no-op in production (`quiet_trace` in `pccf_hw.c`), nothing compares or acts on the samples, and the function returns 0 unconditionally once the COR gate passes. What production actually needs from this file is only the gate: `pcdiag_cis_cf_candidate(info)` + COR index/soft-reset check. The remaining ~30 lines are an in-vivo diagnostic that also inserts a fixed 500 ms + 200 ms of `wait_ms` delay into every `pccf_hw_start` — and again into the T4-F10 fallback restart. READ.
- Fix: Reduce `pcdiag_cf_probe` to its two gates (candidate + COR) and delete the sampling loops/waits from the production path; the full diagnostic already lives in the upstream repo's DIAG branches per the file header's own provenance note.
- Benefit: −~700 ms from every CF start (twice on a profile-fallback start), and removal of ~30 lines whose only output is discarded.
- Effort: S
- Risk: Low — no return value or register write depends on the deleted phase (verified: it performs reads only, "no card writes, no ATA commands" per its own trace string).
- Confidence: READ

### T4-F9 / PIO tuning profile reserves 8 KiB of static IOP memory for a one-shot, two-model check / Category 4
- Locations: `iop/pccf/pccf_pio_profile.inc:3` (`static union { u32 words[1024]; unsigned char bytes[4096]; } profile_ref, profile_check;` = 2 × 4096 B = 8192 B `.bss`, included into `pccf_hw.c:172`)
- Problem: Two 4 KiB scratch buffers live in the resident IRX for the module's entire lifetime to serve a start-up-only comparison that runs only when the card's IDENTIFY model string exactly matches one of two strings (`TS16GCF133`, `INIC-2051 CompactFlash Card`, `pccf_pio_profile.inc:7-8`); for every other card the buffers are never touched at all. 8 KiB is a large permanent resident cost on the IOP for a transient boot-time need (for scale: the whole usbd-ra static descriptor pool for 16 devices is the same 8 KiB). READ.
- Fix: Shrink the validation window (e.g. profile against 8 sectors read into one 4 KiB buffer compared sector-wise on a second pass, halving it to 4 KiB), or move the pair into a start-up-only allocation freed after `pio_profile` returns. Either halves or eliminates the resident cost; the one-buffer variant is LESS.
- Benefit: −4 to −8 KiB permanent IOP `.bss` from a module whose feature is not yet user-facing (see provenance).
- Effort: S
- Risk: Low — buffers are touched only inside `pio_profile`, under the module's own start-up serialisation.
- Confidence: READ

### T4-F10 / `pio_profile` does up to 18 validation reads at start, and any failure — including "known model, card smaller than 4096 sectors" — triggers a full power-cycle restart of the whole driver / Category 5
- Locations: `iop/pccf/pccf_pio_profile.inc:12-24` (`if (ata->sectors<4096) return -1;` after the model match; 3 samples × (2 baseline + 1 tuned) reads of 8 sectors); restart machinery `iop/pccf/pccf_hw.c:238-244` (`pio_fallback_restart`, `pccf_hw_stop()` + 100 ms delay + recursive `pccf_hw_start`)
- Problem: For the two recognised models, start-up performs 9 separate 4 KiB validation reads across three LBAs before the card can serve its first real request. Worse, the failure path is indiscriminate: a recognised-model card with < 4096 sectors (< 2 MiB) returns −1 at the size check — before any timing conclusion — and `pccf_hw_start` treats every `pio_profile` failure identically: full stop, power-cycle, and a complete second start (power sequencing ≈522 ms of delays, CIS parse with up to 5 s of retries, CF probe, IDENTIFY), at the end of which the recursive call skips profiling anyway via `pio_fallback_restart`. The small-card case therefore always pays two full starts to arrive at the conservative profile it could have taken directly. READ.
- Fix: Return 0 (keep conservative PIO) instead of −1 for the `sectors < 4096` case — a small card is not a tuning failure — and reserve the restart path for an actual tuned-vs-baseline data mismatch.
- Benefit: Eliminates a guaranteed double-start (seconds of delay) for small recognised cards; start-up failure handling distinguishes "cannot tune" from "tuning is unsafe".
- Effort: S
- Risk: Low — conservative timing is already the documented fallback for unknown models.
- Confidence: READ

### T4-F11 / The same `pccf` IOP target is defined twice — root `ps2.yaml` and `iop/pccf/ps2.yaml` — with identical sources, defines, flags and headers / Category 2 / 7
- Locations: `ps2.yaml:37-44`; `iop/pccf/ps2.yaml:1-10` (project `launchstation_pccf`)
- Problem: Both definitions currently agree exactly (same 5 sources, `PCCF_SETTLE_US=1000`, `-Wall -fno-strict-aliasing`, same header set) — READ, verified by direct comparison this pass. Two authoritative copies of one target definition is a drift trap: the first silent divergence (a define, a source, a flag) makes the standalone/host build test different code from the shipped IRX, in a module whose VENDORED.md leans on host tests as its evidence base. No divergence exists today; the finding is the duplication itself.
- Fix: Make one definition the source of truth — e.g. the standalone file documents that it mirrors the root target and is generated/checked, or the root target references the directory's file if ps2build supports it. If the build system cannot share it, a comment cross-pointing both files is the minimum.
- Benefit: Host-test evidence stays applicable to the shipped module; one less silent-drift surface.
- Effort: S
- Risk: Low
- Confidence: READ

### T4-F12 / One dead import: `I_memcpy` is declared but `memcpy` is never called in the module / Category 1
- Locations: `iop/pccf/imports.lst:11` (`I_memcpy`); zero call sites across `main.c`, `pccf_ata.c`, `pccf_hw.c`, `pcdiag_*.c` and the three `.inc` files (grep-verified; the module uses `memset`/`memcmp`/`strcmp`, all imported and used)
- Problem: Single dead import stub linked into the IRX. Trivial alone; filed because the same sweep (T4-F7) shows the pattern is tree-wide in these vendored modules and the fix is one line.
- Fix: Delete `imports.lst:11`.
- Benefit: One less stub; import list again documents the module's real dependencies.
- Effort: S
- Risk: Low
- Confidence: READ

### (d) Checked-and-clean — pccf

- **CIS parser is the model citizen of the two modules** (`pcdiag_cis.c`): bus walk is bounded by `PCDIAG_CIS_BUS_LIMIT` and `PCDIAG_CIS_TUPLE_LIMIT`; payload length is checked against the remaining bus bound before copying; `length == 0xff` is handled as terminator **before** the copy, so the 254-byte `data[]` can never be overrun by the maximum remaining length of 254; CONFIG/CFTABLE decoders validate their sub-lengths and set `malformed` instead of trusting; links are recorded, never followed (`linked` disqualifies the candidate in `pcdiag_cis_cf_candidate`). READ, deliberately not flagged.
- **ATA layer validation** (`pccf_ata.c`): IDENTIFY is gated on reset/zero signature agreement across byte and word reads, word-0/word-49 capability bits, non-zero/non-`0xffffffff` sector count, integrity byte/checksum, and 512-byte-sector enforcement via word 106; LBA48 count is bounded to 2 TiB−1; all `wait_status` polls are bounded (`PCDIAG_ATA_POLL_LIMIT_MS`) and latch `ready = 0` on failure; writes require a flush command when write cache is on, flush, then read back **every** sector and `memcmp` it. This checked-write path is slow by design (VENDORED.md: "Keep … the upstream checked write/flush/read-back path") — recorded as a deliberate safety trade-off, not a performance finding. READ.
- **BDM entry points** (`main.c`): `cf_read`/`cf_write` reject NULL buffer, zero count and any range touching `sector >= ata.sectors` before taking `io_lock`, fail closed on `WaitSema` failure (the `f285f02` local fix), chunk at 64 sectors matching the ATA layer's own cap, and return `-EIO` — not a partial count — on any mid-loop failure. `cf_stop` takes the same lock. READ.
- **Local devctl** (`pccf_control.inc`, Launchstation-authored): validates `file`/unit, rejects any `args`/`arglen`, requires exact `buflen == sizeof(pccf_control_status_t)` for STATUS, requires empty buffer for OFF, and OFF goes through `cf_stop`'s own lock acquisition (no double-lock). This is the correct pattern several Round-2/3 drivers lacked. READ, deliberately not flagged.
- **Entry-point bus safety** (`main.c` `_start`): the DEV9 resident-library scan is capped (256 libraries, fail-closed), runs before semaphore creation or any MMIO, and every post-`CreateSema` failure path deletes the semaphore and stops the hardware; a failed `iomanX_AddDrv` unwinds in reverse order. READ.
- **`pccf_hw.c` taskfile issue paths**: `issue_read_count` re-reads all five taskfile registers and refuses to send the command on any mismatch; `issue_rw` bounds count/LBA28 range, writes LBA48 high bytes in the correct order, and both refuse when the card is absent or the selector/timing state is wrong. Saved host registers are restored in stop in the documented order (the 7th save16 entry restored last, separately). READ.

### (e) Still unread / not verified

- Nothing in the assigned file list is unread: both modules were read end-to-end including headers, `.inc`, `exports.tab`/`imports.lst`/`irx_imports.h`, `VENDORED.md` and the local `ps2.yaml`.
- Not verified (explicit): byte-identity against the two upstreams (ps2sdk@314d87e7 for usbd-ra; PS2CF@9b6ed37 for pccf) — no fetch was performed per task rules; provenance rests on in-tree docs, headers and git history (READ) plus the inference noted in A(a). Host test suites under `tests/` that exercise pccf were out of section scope and not read. No build, no hardware, no execution of any path described above.
