# POPSLoader BETA-13 Candidate Deep Audit - Codex - 2026-06-20

Read-only audit report for the BETA-13 candidate tree. The only repository write
made by this audit is this file.

## Coverage Summary

Checkout / diff scope verified:

- Current branch was `BETA-12-PLAY`; `git status --short --branch` reported `## BETA-12-PLAY...origin/BETA-12-PLAY`.
- Current HEAD was `8d1e67a0fdfc88694658a490a94facfff66c1bc7`.
- The requested post-BETA-12 range was `af983d7..HEAD`; `git log --oneline af983d7..HEAD` listed 42 commits, ending at `8d1e67a fix(hdd): re-validate boot RW mount so settings save after a scan (Nuno)`.
- The diff touched 36 files, with the highest-risk source changes in `.github/workflows/rolling-release.yml`, `Makefile`, `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`, `etc/boot.lua`, `src/elf_loader/src/elf.c`, `src/embed_assets.cpp`, `src/fntsys.cpp`, `src/graphics.cpp`, and `src/luagraphics.cpp`.

Read in depth:

- Canonical docs: `STATE.md`, `docs/PRESERVATION_CONTRACTS.md`, `ARCHITECTURE.md`, `COMPONENTS.md`, and `README.md`.
- Priority-1 code paths: HDD PFS slot tracking and RW takeover in `system.lua`, R3 reveal/hide in `ui.lua`, settings encode/decode/commit flow, game-list cache, `System.writeFile` callers, boot ordering, graphics decoder hardening, `usbd.irx` aliasing, CI/rolling packaging, and launch-contract paths in `elf.c` / BRAM `loader.c`.
- Priority-2 spot checks: Lua/C boundary return contracts, pfs mount lifecycle, cache parsing, cover-art loading, BDMA marker write helpers, carousel/settings dirty detection, and release package contents.

Not reached / not performed:

- No build, emulator run, or hardware run was performed. All runtime-dependent statements below are source-trace findings and need the listed on-hardware tests.
- I did not disassemble binary assets, exhaustively audit every vendored IRX, or line-read every unchanged UI drawing branch. I focused the remaining budget on the changed high-risk code and the launch/storage/decoder surfaces that can brick or corrupt data.

## Top Findings

### 1. `PromoteTmpToDest` ignores a failed backup before truncating the live destination

Area: Lua file persistence, settings/cache/marker atomic writes

Severity: High

Confidence: CONFIRMED source bug

Evidence:

- `bin/POPSLDR/system.lua:2604` records `local had_dest = doesFileExist(dest)`.
- `bin/POPSLDR/system.lua:2607` calls `pcall(System.rename, dest, bak)` but discards the result.
- `bin/POPSLDR/system.lua:2609` then calls `local ok = pcall(System.rename, tmp, dest)`.
- `bin/POPSLDR/system.lua:2612` only restores if `had_dest and doesFileExist(bak)`.
- `src/luasystem.cpp:721` opens the rename destination with `O_WRONLY | O_CREAT | O_TRUNC`.
- `src/luasystem.cpp:729` treats short copy as failure: `if (wrote < size)`.
- `src/luasystem.cpp:760-761` turns copy failure into a Lua error: `return luaL_error(L, "System.rename: copy failed")`.

Why it matters:

The current C binding is better than the old silent-return shape: `pcall(System.rename, tmp, dest)` now does see copy failure. The remaining bug is the ignored first rename. If `dest -> bak` fails on a full/flaky/RO-ish device, `PromoteTmpToDest` continues and lets `tmp -> dest` open the original file with `O_TRUNC`. If the second copy then fails, the function returns `false`, but the original `.pldrs` / cache / marker can be gone or partial because no `.bak` exists to restore. This hits every `WriteAtomic` caller, including `PLDR.SaveSettingsAtomic`.

Suggested fix:

Capture and require the backup result before touching `dest`:

- If `had_dest`, remove stale `.bak`, then require `pcall(System.rename, dest, bak)` and `doesFileExist(bak)` before attempting `tmp -> dest`.
- If backup creation fails, remove `tmp` and return `false` while leaving `dest` untouched.
- Keep the current `System.rename` error-on-copy-failure behavior.

Hardware test:

On a storage target with an existing `.pldrs`, force a backup-copy failure or near-full-device condition, then save settings. Expected: UI reports save failure and the old `.pldrs` remains byte-identical. Repeat for HDD boot settings and MC/USB sidecar settings.

### 2. BMP decode still trusts declared dimensions without validating required pixel bytes / stride

Area: Cover-art decoder hardening, `src/graphics.cpp`

Severity: High for malformed local assets; normal covers unaffected

Confidence: CONFIRMED source bug

Evidence:

- `src/graphics.cpp:438-439` assigns `tex->Width = Bitmap.InfoHeader.Width` and `tex->Height = Bitmap.InfoHeader.Height`.
- `src/graphics.cpp:572-573` sets `FTexSize` to file length minus pixel offset.
- `src/graphics.cpp:577-579` allocates the output texture from `tex->Width`, `tex->Height`, and `tex->PSM`.
- `src/graphics.cpp:590` allocates the source pixel buffer using only `FTexSize`.
- `src/graphics.cpp:606` reads exactly `FTexSize` bytes.
- `src/graphics.cpp:617-621` loops `tex->Height * tex->Width` and indexes `image[(cy * tex->Width + x) * 3 + ...]` for 24-bit BMP.
- `src/graphics.cpp:657-663` does the same dimension-derived indexing for 16-bit BMP.
- `src/graphics.cpp:705-710` copies dimension-derived rows for 8/4-bit BMP.

Why it matters:

The recent BMP hardening fixed unsupported bit depths, CLUT null checks, allocation checks, and some file-offset issues. It still does not verify that the file contains enough pixel data for the declared dimensions and BMP row padding. A truncated or crafted BMP can pass the `fread(image, FTexSize, 1, File)` check for the shorter file and then be read past `image` by the conversion loops. Cover art is user-controlled input, so this is a real crash/corruption surface even though normal covers are fine.

Suggested fix:

Before allocating/looping, reject impossible dimensions and compute the BMP source stride:

- Require positive, sane width/height.
- Compute `row_stride = ((width * bitcount + 31) / 32) * 4`.
- Require `FTexSize >= row_stride * abs(height)`.
- Use `row_stride` in all source indexes instead of `tex->Width * bytes_per_pixel`.

Hardware test:

Place a deliberately truncated 24-bit BMP cover and enter a game list with cover preview enabled. Expected after fix: no crash/black screen, cover load fails cleanly, and the missing-cover path is used. Repeat for 16-bit, 8-bit, and 4-bit BMPs.

### 3. PNG decoder still lacks the JPEG-style dimension cap and mixes `png_uint_32` with `int` row counters

Area: Cover-art decoder hardening, `src/graphics.cpp`

Severity: Medium

Confidence: LIKELY source bug / confirmed missing guard

Evidence:

- `src/graphics.cpp:101` reads PNG IHDR into `png_uint_32 width, height`.
- `src/graphics.cpp:110-111` assigns those values directly to `tex->Width` and `tex->Height`.
- `src/graphics.cpp:120` allocates `tex->Mem` from `tex->Width` and `tex->Height` without a prior cap.
- `src/graphics.cpp:123` allocates row pointers with `calloc(height, sizeof(png_bytep))`.
- `src/graphics.cpp:125-126` casts height to `int`: `row_count = (int)height` and `row < (int)height`.
- `src/graphics.cpp:134-137` loops over `tex->Height` and `tex->Width`.
- JPEG has an explicit cap by contrast: `src/graphics.cpp:848-850` rejects zero or `> 8192u` dimensions before multiplying.

Why it matters:

PNG now handles corrupt/truncated decode failures much better, but unlike JPEG it still accepts arbitrary 32-bit dimensions before allocation and loop setup. On constrained EE memory most huge images will fail allocation, but the `png_uint_32` to `int` casts and unbounded row-pointer allocation leave malformed PNGs in a sharper failure mode than JPEG.

Suggested fix:

Apply the same policy as JPEG before `png_read_update_info` consumers allocate:

- Reject zero dimensions.
- Reject width/height above a sane cover-art cap.
- Reject dimensions that would overflow `gsKit_texture_size_ee`, row byte calculations, or `int` loop counters.

Hardware test:

Use crafted PNG covers with huge IHDR dimensions and truncated data. Expected after fix: cover load returns nil and UI continues; no crash, hang, or leaked cover handle.

### 4. HDD write-probe comments and success/failure toasts still describe obsolete `mc0:` behavior

Area: Tester-facing diagnostics / documentation drift in runtime UI

Severity: Medium

Confidence: CONFIRMED source bug

Evidence:

- `bin/POPSLDR/system.lua:939-944` says the boot partition is "known-unwritable" and "HDD settings save to mc0:".
- `bin/POPSLDR/ui.lua:3193-3196` says "Settings already saved (to mc0: on HDD)" after a settings save.
- `bin/POPSLDR/ui.lua:3200` toasts "settings can live on HDD".
- `bin/POPSLDR/ui.lua:3202` toasts "settings stay on the memory card" on probe failure.
- Canonical save code says the opposite: `bin/POPSLDR/system.lua:3214-3218` states HDD settings are written through the boot partition and "NEVER mc0:".

Why it matters:

The canonical behavior has changed: HDD boot settings, `.hide`, and cache use the HDD boot partition through `PLDR.HDD.EnsureBootPartitionWritable`. The old probe text can produce false tester conclusions, especially during BETA-13 validation where HDD RW behavior is the center of attention.

Suggested fix:

Retire the probe toast or rewrite it as a separate `__.POPS game partition write diagnostic`. Do not describe settings as already saved to `mc0:` on HDD. Update the comments at the same time so future audits do not re-learn the obsolete model.

Hardware test:

On HDD boot, save settings and confirm the notification text matches the canonical HDD-sidecar behavior. If the game-partition probe fails, the warning must not imply settings moved to `mc0:`.

### 5. Two raw `System.writeFile` callers still do not validate the returned byte count

Area: Lua/C file IO contract

Severity: Low-Medium

Confidence: CONFIRMED source bug; immediate `.hide` impact is low

Evidence:

- `src/luasystem.cpp:881-885` implements `System.writeFile` as raw `write()` and returns the integer byte count.
- `bin/POPSLDR/system.lua:966` calls `pcall(System.writeFile, fd, "ok", 2)` in `PLDR.ProbeHddSettingsWrite` and only checks file existence.
- `bin/POPSLDR/system.lua:2105` calls `pcall(System.writeFile, fd, content, #content)` in `PLDR.HDD.WriteGamePartitionFile` and only checks file existence.
- `bin/POPSLDR/system.lua:2637-2638` shows the intended pattern: require `wrote == chunk_len`.
- `bin/POPSLDR/system.lua:4848-4851` also checks the raw HDD cache write count and deletes a partial cache.

Why it matters:

The current HDD `.hide` call passes an empty string at `bin/POPSLDR/system.lua:4445`, so the active marker use is not losing non-empty content today. The helper contract at `bin/POPSLDR/system.lua:2080` says `string = create+write`, and the probe writes `"ok"`. Those paths can report success on a short write because file existence alone is not a write-completeness proof.

Suggested fix:

Count-check these two calls. For zero-byte marker creation, keep the existence check. For non-empty content/probe data, require `type(wrote) == "number" and wrote == #content`.

Hardware test:

Force a short write in the HDD probe and confirm it reports failure. Add a temporary non-empty `WriteGamePartitionFile` caller or unit-style harness and verify short writes do not return success.

### 6. R3 reveal/hide always shows a success toast even if persistence fails

Area: R3 hidden-games flow / settings persistence

Severity: Low-Medium

Confidence: CONFIRMED source behavior; runtime impact needs hardware/storage failure test

Evidence:

- `bin/POPSLDR/ui.lua:2817` flips `PLDR.GLOBAL_HIDE`.
- `bin/POPSLDR/ui.lua:2818` calls `pcall(PLDR.SaveSettingsAtomic)` and ignores both `pcall` status and returned save status.
- `bin/POPSLDR/ui.lua:2820` raises `UI.Pad.Events.R1 = true` for the refresh path.
- `bin/POPSLDR/ui.lua:2945-2949` always shows either "Hidden games are now hidden" or "Showing hidden games (dimmed) -- press L3 to unhide".

Why it matters:

The in-session reveal/hide flow works by source trace, including the intentional R1 reuse. The persisted setting can silently fail on read-only/full storage while the UI still tells the user the mode changed. On reboot, the visible state may revert.

Suggested fix:

Capture `SaveSettingsAtomic()`'s boolean result. If it fails, either revert `PLDR.GLOBAL_HIDE` before the rebuild or keep the in-session change but toast that it was not saved.

Hardware test:

Use a read-only/full settings target, press R3 on each device page, then reboot. Expected after fix: user sees an explicit "not saved" warning and reboot behavior matches the warning.

## Priority-1 New-Work Review

### HDD pfs-slot management and `EnsureBootPartitionWritable`

Status: No new source-level blocker found beyond the residual slot-borrowing root already described in the request.

Clean evidence:

- `etc/boot.lua:48-50` mounts HDD boot to `pfs1:` and sets `BOOT_HDD_MOUNT_SLOT = 1`.
- `etc/boot.lua:63-64` normalizes the cwd to `pfs1:` before `System.currentDirectory`.
- `bin/POPSLDR/system.lua:750-758` still allows game scans to try slot 3 and slot 1.
- `bin/POPSLDR/system.lua:783-794` records successful PFS mounts and unmounts untrackable mounts.
- `bin/POPSLDR/system.lua:803-807` forgets recorded state only after `HDD.UMountPartition` reports success.
- `bin/POPSLDR/system.lua:2125-2135` liveness-validates `PLDR.HDD.BOOT_PARTITION_RW` by probing `APP_DIR_LOCAL`.
- `bin/POPSLDR/system.lua:2150-2153` explicitly unmounts and remounts the boot partition RW at the same slot.

Residual risk / hardware-needed:

- `bin/POPSLDR/system.lua:4991-4997` cleans up a failed `BuildGameList`, but deliberately does not unmount `gslot` if it equals `boot_slot`. That protects the boot mount, but if a failing scan borrowed slot 1 for a game partition, source inspection alone cannot prove every subsequent cover/cache/read path behaves before the next save calls `EnsureBootPartitionWritable`.
- Hardware test: HDD boot, force a scan error after a slot-1 game mount, then immediately exercise cover reads, `.hide`, cache write, settings save, BOOT.ELF launch, and POPSTARTER launch. Expected: no dead `pfs1:` cwd, no leaked game partition on the boot slot, and settings save recovers the boot mount.

### R3 reveal/hide hidden games

Status: Functionally plausible by source trace; persistence-status gap is finding 6.

Clean evidence:

- `bin/POPSLDR/ui.lua:2813-2816` limits R3 handling to device list scenes.
- `bin/POPSLDR/ui.lua:2820` intentionally reuses the R1 refresh path.
- `bin/POPSLDR/ui.lua:2837-2843` suppresses the ordinary HDD R1 toast when R3 drove the rebuild.
- `bin/POPSLDR/ui.lua:2897-2903` does the same for SMB/MMCE/MX4SIO/USB refresh.
- `bin/POPSLDR/ui.lua:2905-2915` keeps L3 hide/unhide gated by the current `ammount > 0` selection.

Hardware-needed:

- Exercise R3 on an all-hidden list. Source trace shows input is read before the `ammount > 0` action gate, but the stale `ammount` local at `bin/POPSLDR/ui.lua:2952-2964` can make the footer one frame behind after rebuild.

### Game-list cache and settings round-trip

Status: Mostly clean; persistence helpers inherit finding 1.

Clean evidence:

- `bin/POPSLDR/system.lua:2637-2638` checks `System.writeFile` byte counts in `WriteAtomic`.
- `bin/POPSLDR/system.lua:4747-4761` makes per-device cache opt-in and writes through `WriteAtomic`.
- `bin/POPSLDR/system.lua:4767-4771` makes cache loading opt-in and rejects files over 4 MiB.
- `bin/POPSLDR/system.lua:4812` makes HDD disk cache opt-in.
- `bin/POPSLDR/system.lua:4863` bounds HDD cache reads at 4 MiB.
- `bin/POPSLDR/system.lua:4743-4744` signs caches with `GLOBAL_HIDE` and `COLLAPSE_MULTIDISC`.
- `bin/POPSLDR/system.lua:3541` wipes the HDD cache when scan-affecting settings change.
- `bin/POPSLDR/ui.lua:3638-3643` includes the new value-cycle settings in the unsaved-changes prompt.

Hardware-needed:

- Toggle each new persisted setting, save, reboot, and verify round-trip: `SHOW_DETAILS`, `DETAILS_ALIGN`, `GAMELIST_CACHE`, `DESC_SCROLL_SPEED`, `HIDDEN_DEVICES`, `BOOT_PAGE`, `COLLAPSE_MULTIDISC`, and `GLOBAL_HIDE`.

### Boot rework

Status: No source-level regression found in the START-recovery / splash ordering path.

Clean evidence:

- `bin/POPSLDR/system.lua:6200-6201` suppresses `PLDR.AutoLaunchFromLaunchArgs()` while START is held.
- `bin/POPSLDR/system.lua:6212-6215` only applies persisted Boot Page when no explicit `-page` launch arg is present.
- `bin/POPSLDR/system.lua:6264` loads settings before the final START-held override.
- `bin/POPSLDR/system.lua:6265-6279` resets video to Auto and Boot Page to Carousel when START is held.
- `bin/POPSLDR/system.lua:6285` runs `UI.WelcomeDraw.Play(initial_scene, show_boot_credits, do_boot_init)`.

Hardware-needed:

- START-held boot with persisted PAL / HDD Boot Page / `-page` / `-game` launch args. Expected: visible recovery UI, Auto video, Carousel, and no auto-launch.

### Graphics / decoder hardening

Status: Recent fixes are real, but findings 2 and 3 remain.

Clean evidence:

- `src/graphics.cpp:65-69` now NULL-checks PNG texture allocation and initializes `Mem` / `Clut`.
- `src/graphics.cpp:82-90` centralizes PNG longjmp cleanup.
- `src/graphics.cpp:848-850` caps JPEG dimensions before multiply.
- `src/graphics.cpp:855-857` checks JPEG pixel-buffer allocation.
- `src/graphics.cpp:446-451` rejects unsupported BMP bit depths.
- `src/graphics.cpp:457-458` and `src/graphics.cpp:499-500` check BMP CLUT allocation.
- `src/luagraphics.cpp:583-590` now pushes `nil` when embedded PNG decode fails, matching the Lua nil guards in `bin/POPSLDR/images.lua:64-73`.

### `usbd.irx` MX4SIO dedup

Status: Clean by source trace.

Evidence:

- `Makefile:102-103` embeds `asset_usbd_irx_usbexfat.o`, `asset_usbhdfsd_irx_usbexfat.o`, `asset_usbhdfsd_irx_mx4sio.o`, `asset_usbd_irx_mmce.o`, and `asset_usbhdfsd_irx_mmce.o`; there is no dangling `asset_usbd_irx_mx4sio.o`.
- `src/embed_assets.cpp:70-77` declares the same available symbols.
- `src/embed_assets.cpp:124-128` documents and registers `usbd.irx.mx4sio` as an alias of `asset_usbd_irx_usbexfat`.
- `src/embed_assets.cpp:168-171` also aliases the `POPSLDR/usbd.irx.mx4sio` key to `asset_usbd_irx_usbexfat`.

## Priority-2 Whole-Repo Review

### Launch preservation contracts

Status: No source-level regression found in the key contract routes. Hardware claims still need QA matrix evidence.

Evidence:

- `bin/POPSLDR/system.lua:1053-1071` preserves boot PFS slots for non-HDD external loads.
- `bin/POPSLDR/system.lua:1107-1115` sets the exec keep mask and unmounts slots not in the keep set.
- `bin/POPSLDR/system.lua:1120-1129` cold external launch clears the keep mask and unmounts all PFS slots.
- `src/elf_loader/src/elf.c:628-648` routes HDD-backed POPSTARTER and HDD-backed DKWDRV through `ExecuteHddBackedViaEmbeddedLoader`.
- `src/elf_loader/src/loader/src/loader.c:381-397` uses the HDD partition-context branch with dynamic PFS unmount plus `SifExitRpc()` and `SifExitCmd()`.
- `src/elf_loader/src/loader/src/loader.c:405-410` explicitly avoids `SifExitCmd()` in the non-HDD branch.
- `src/elf_loader/src/elf.c:668-686` unmounts live PFS slots before `SifIopReset` for non-HDD direct-launch paths.

Hardware-needed:

- D-10, D-15, U-10, DKWDRV-from-MC, DKWDRV-from-HDD, BOOT.ELF from USB-booted, and BOOT.ELF from HDD-booted should all be retested against this exact tree before BETA-13 release claims.

### CI / rolling release

Status: Clean by source trace; not executed locally.

Evidence:

- `.github/workflows/rolling-release.yml:33` installs `lua5.4`.
- `.github/workflows/rolling-release.yml:72-78` probes `luac5.4` / `luac` / `luac5.3` and hard-fails syntax errors.
- `.github/workflows/rolling-release.yml:117-127` checks generated loader blob parity when timestamps are not newer.
- `.github/workflows/rolling-release.yml:177-182` ships `POPS/PATCH_5.BIN` at the zip root.
- `.github/workflows/rolling-release.yml:232-234` uploads both the zip and bare `bin/POPSLOADER.ELF`.
- `.github/workflows/compilation.yml:139-177` builds the release package with `PS1_POPSLOADER/` and `POPS/PATCH_5.BIN`.
- `.github/workflows/compilation.yml:186-236` verifies exact package contents and forbids old POPS TM2 files.

### Settings UI and game-list UI

Status: No source-level drop of the new value-cycle settings found; hardware/UI pass needed for layout.

Evidence:

- `bin/POPSLDR/ui.lua:2273-2305` initializes Boot Page, hidden devices, multi-disc collapse, global hide, game details, description speed, and game-list cache UI state from `PLDR`.
- `bin/POPSLDR/ui.lua:3152-3165` commits the corresponding draft values into `PLDR` before save.
- `bin/POPSLDR/ui.lua:3638-3643` includes the value-cycle settings in dirty detection.
- `bin/POPSLDR/ui.lua:600-602` explicitly notes the widened list is past CRT action-safe and wants a hardware eyeball.

Hardware-needed:

- Check PAL and NTSC CRT-safe layout for widened game list, right-aligned details, scrolling details, footer labels, and all settings rows.

## Improvements & Things To Know

- `PLDR.HDD.CreateCache` uses a direct write to `hdd_gamecache.txt` at `bin/POPSLDR/system.lua:4845-4851` rather than `WriteAtomic`. It deletes partial files on short writes, so this is not a data-corruption finding, but using the shared atomic helper would make cache behavior more uniform after finding 1 is fixed.
- The stale comments at `bin/POPSLDR/system.lua:4406-4408` say HDD games are gated out before `.hide` writes. Current code has an HDD counterpart at `bin/POPSLDR/system.lua:4430-4457`, so the comment should be modernized with finding 4.
- The codebase now has good breadcrumbs for Lua load-order traps: `bin/POPSLDR/system.lua:981-986` documents why `PLDR.HDD` methods must be defined after `PLDR.HDD` exists. Keep that style for future embedded-Lua changes.
- The rolling release workflow intentionally publishes from push and PR events to the floating `rolling-release` tag. That matches `AGENTS.md`, but the operational risk remains last-write-wins assets; testers should always record the commit hash from `BUILD_INFO.txt`.

## What I Am Unsure About

- The exact runtime effect of transient `pfs1:` loss during HDD scans cannot be proven without PS2/PCSX2. Source trace shows the settings save path revalidates and remounts, but cover reads, `.hide`, and cache behavior immediately after a faulting scan need hardware/emulator proof.
- The malformed PNG/BMP findings are source-level memory-safety risks. The exact user-visible symptom on PS2 depends on allocator behavior, gsKit texture sizing, and the asset path exercised.
- I did not prove full PAL native 640x512 behavior. The boot and UI source paths are coherent, but the requested display-mode claims need the QA matrix / real display validation.
- I did not execute CI locally, so workflow observations are source-only.
