# POPSLoader — EE C++ Core — Independent Blind Redo Audit

- Repo: NathanNeurotic/POPSLoader, clone `~/workspace/audit-clones-2026-11-13/POPSLoader`, pin `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (master, verified with `git rev-parse HEAD`).
- Scope: `src/*.cpp`, `src/*.c`, `src/include/*.h`, `src/elf_loader/` in full, root `Makefile` EE wiring, `src/embed_assets.cpp` asset table vs `bin/` + `EMBED/` on disk.
- Method: every in-scope source file opened and read; all counts below are script-produced (grep/python censuses over the clone), never estimated. Lua files under `bin/POPSLDR/` and `etc/boot.lua` were used only as the consumer census for bindings/assets (they are the only Lua that can run: `luaplayer.cpp` disables filesystem script loaders, see RE-POPS-EE-07).
- Rule applied: LESS, NOT MORE — remove / simplify / consolidate / fix only.

---

### RE-POPS-EE-01 — Two embedded IRX blobs are byte-identical duplicates of the usbexfat blobs and are embedded a second time instead of aliased
- Category: 4
- Locations: Makefile:115-119, Makefile:220-241, src/embed_assets.cpp:80-87, src/embed_assets.cpp:160-165, src/embed_assets.cpp:214-219, bin/POPSLDR/usbd.irx.ilink (48,500 B), bin/POPSLDR/usbhdfsd.irx.udpfs (34,508 B)
- Problem: Scripted MD5 comparison of the on-disk blobs: `usbd.irx.ilink` is byte-identical to `usbd.irx.usbexfat` (both 48,500 B, same MD5) and `usbhdfsd.irx.udpfs` is byte-identical to `usbhdfsd.irx.usbexfat` (both 34,508 B, same MD5), yet each gets its own bin2c object in `EMBEDDED_RSC`, its own extern pair, and its own table entries — 83,008 bytes of payload carried twice in the ELF. The codebase already knows the correct pattern: `usbd.irx.mx4sio` is aliased to `asset_usbd_irx_usbexfat` with an explanatory comment (src/embed_assets.cpp:149-153) precisely because it is byte-identical; the ilink and udpfs pairs were simply never given the same treatment. (`usbd.irx.udpfs`, 61,949 B, and `usbhdfsd.irx.ilink`, 27,769 B, are distinct blobs and are not part of this finding.)
- Fix: Alias the two duplicate keys to the usbexfat symbols in `g_embedded_assets[]` exactly like the mx4sio alias, and drop `asset_usbd_irx_ilink.o` and `asset_usbhdfsd_irx_udpfs.o` (plus their bin2c rules and externs). Keep the on-disk files — only the second embedded copy goes.
- Benefit: ~83 KB off the unpacked embedded payload (before packing) with zero behaviour change; one less pair of blobs that can silently diverge on a future driver update.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-02 — Embedded-asset table stores every asset twice: 100 entries for 49 unique blobs
- Category: 2
- Locations: src/embed_assets.cpp:114-243
- Problem: Scripted count: `g_embedded_assets[]` holds exactly 100 `ASSET_ENTRY` rows (50 bare keys + 50 `POPSLDR/`-prefixed keys) over only 49 unique symbols/blobs. Every asset addition or removal must be typed twice in this file, on top of the Makefile rule and the `images.lua` registration — and the lookup side already normalises bare names, `IMG/` prefixes and `POPSLDR/` prefixes into one canonical key in `embedded_get` (src/embed_assets.cpp:243-293), so the duplicated half of the table exists only to serve callers that pass the prefixed form verbatim.
- Fix: Keep only the canonical (prefixed) half of the table and let `embedded_get`'s existing normalisation map every caller form onto it; delete the 50 duplicated bare rows (the one mx4sio alias row collapses with them).
- Benefit: Halves the table, removes one of the three hand-coordinated places an asset edit can go wrong, and makes a missed duplicate entry (bare works, prefixed 404s, or vice versa) impossible.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-EE-03 — embedded_get's bare-name fallback branch can never execute
- Category: 1
- Locations: src/embed_assets.cpp:282-285
- Problem: The fallback `if (asset == NULL && lookup_key != input && strchr(input, '/') == NULL) asset = embedded_find(input);` is unsatisfiable. `lookup_key` is reassigned away from `input` only in the three branches that all require a `/` in `input` (`POPSLDR/`, `IMG/`, or any string containing `/`); when `input` contains no `/`, `lookup_key` still equals `input`, so the second conjunct is false. In every reachable state at least one conjunct fails, and the second `embedded_find` is dead code that misleads readers into thinking a bare-name rescue exists.
- Fix: Delete the dead fallback (the first lookup already covers the bare-name case, because a slash-free input is looked up unchanged).
- Benefit: Removes a false safety net from the one function every embedded-asset consumer funnels through; the real lookup contract becomes readable at a glance.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-04 — `default.png` is registered unconditionally in Lua but embedded only conditionally, so the registration is dead in a normal checkout
- Category: 8
- Locations: Makefile:88-95 (OPTIONAL_EMBEDDED_RSC wiring, line range INFERRED from the full Makefile read), src/embed_assets.cpp:56-58, src/embed_assets.cpp:140, src/embed_assets.cpp:201, bin/POPSLDR/images.lua:34, bin/POPSLDR/IMG/ (directory listing)
- Problem: `bin/POPSLDR/IMG/default.png` does not exist in this checkout (scripted listing of all 67 IMG files), so `HAVE_ASSET_DEFAULT_PNG` is undefined and no `default.png` blob is embedded — yet `images.lua` unconditionally registers `{"default", "default.png"}` in `IMG_REGISTRATIONS`. `IMG["default"]` therefore always resolves through `System.getEmbeddedAsset` to failure and is memoised in `IMG_FAILED`. The optional-embed machinery (Makefile conditional, `#ifdef` externs, `#ifdef` table rows) exists solely to support a file that is not in the repo.
- Fix: Drop the `default` row from `IMG_REGISTRATIONS`; if a legacy cover override is ever reintroduced, add the registration and the file together. The conditional embed wiring can go with it, or stay only if the file is committed.
- Benefit: Removes a permanently-failing lookup from the cover path and a three-place conditional that no shipped build exercises.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-05 — The generated bin2c blob `src/elf_loader/loader.c` (855,821 bytes) is committed and regenerated on every build
- Category: 7
- Locations: src/elf_loader/loader.c:1-5, src/elf_loader/Makefile:28-31
- Problem: The two files named `loader.c` are not two loaders. `src/elf_loader/src/loader/src/loader.c` (442 lines) is the child-loader source; `src/elf_loader/loader.c` (8,740 lines, 855,821 bytes, script-measured) is a generated hex dump of the compiled, stripped child (`size_loader_elf = 139700`). The elf_loader Makefile regenerates it under `FORCE` from `src/loader/bin/loader.elf` on every build, and its own comment says CI validates parity by re-running bin2c and `cmp`-ing against this file — i.e. the repo carries an 856 KB generated artifact purely as a checksum fixture, and every child-loader change produces an 8,740-line diff in it.
- Fix: Stop tracking the generated file (generate it into the build tree like the other bin2c outputs in the root Makefile's `asm/` directory) and have CI compare the freshly generated blob against the freshly built `loader.elf` instead of against a committed copy.
- Benefit: Removes 856 KB and one whole class of mega-diffs from the repo; eliminates the recurring trap of reading the hex dump as if it were the loader source.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-EE-06 — The async ATA bring-up worker is dead: KickAtaAsyncBoot / WaitAtaAsyncBootBounded have no callers anywhere
- Category: 1
- Locations: src/luasystem.cpp:1864-1965 (state, stack, semaphores, `ata_async_thread`, `KickAtaAsyncBoot`, `WaitAtaAsyncBootBounded`), src/luasystem.cpp:1955-1965, src/main.cpp (boot sequence, full read: no call to either function), bin/POPSLDR/system.lua:6330
- Problem: Scripted caller census over `src/` and the shipped Lua: `KickAtaAsyncBoot` and `WaitAtaAsyncBootBounded` are defined and never called; no `initATAAsync` binding exists in any registration table, yet `system.lua` still probes for one (`type(System.initATAAsync) == "function"` — always false) and the comments in this block describe a boot-time kick and a bounded join in `main.cpp` that do not happen (main.cpp's own comment concedes the worker "stays dormant (no callers)"). The live ATA path is the synchronous `initATAModules`. The dead block costs an 8,192-byte static stack, two semaphores, a worker thread function and ~100 lines of misleading concurrency commentary around the most failure-sensitive launch path in the app.
- Fix: Delete the worker, its stack, its module semaphore and both entry points, keeping `lua_ata_init_status` reading a state that the synchronous path sets (or delete the status binding with it if nothing then writes the state). Remove the stale `initATAAsync` probe from the Lua boot path at the same time (Lua file, outside this section's edit scope — flagged for the parent).
- Benefit: One ATA bring-up mechanism instead of two, and no future maintainer can "fix" a hang by wiring up a worker whose race history (documented in the same comments) is exactly why it was abandoned.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-EE-07 — 52 of 143 registered Lua bindings have no caller in any Lua that can run
- Category: 1
- Locations: src/luaScreen.cpp:157-232, src/luacontrols.cpp:277-282, src/luagraphics.cpp:468-484, src/luagraphics.cpp:830-853, src/luasystem.cpp:2522-2582, src/luasystem.cpp:2630, src/luatimer.cpp:127-132, src/luaplayer.cpp:158-190
- Problem: Scripted census: 143 active (non-commented) `luaL_Reg` entries across all binding files; 91 are referenced from the shipped Lua (`bin/POPSLDR/system.lua`, `ui.lua`, `images.lua`, `etc/boot.lua`) and 52 are not referenced anywhere in it — including `Screen.getFPS`; `Color.getR/getG/getB/getA`; `Pads.getType/getPressure/rumble/setLED/check`; `Font.ftLoad/ftSetPixelSize/ftUnload/ftEnd/print/unload/fmUnload`; `Graphics.drawPixel/drawLine/drawCircle/drawTriangle/drawQuad/threadLoadImage/drawRotateImage/drawPartialImage/drawImageExtended/getLoadState/getLoadData`; `System.seekFile/getFreeMemory/getMCInfo/loadELFRebootIOP/checkValidDisc/getDiscType/checkDiscTray/getAppDir/ensureBDM/ensureBDMFatFs/ensureDev9/ataReady/getSio2Owner/getMassBackendInfo/getMassRootByBackendName/findBDMByDriver`; `IOP.loadModuleBuffer`; `Timer.setTime/destroy/pause/resume/isPlaying`. These are not a public scripting API: `runScript` only ever executes the embedded `boot.lua`, and `DisableLuaFilesystemScriptLoaders` nils `dofile`/`loadfile` and empties `package.path`/`cpath`, so no user script can reach them. Each dead binding keeps its C implementation (and, for the Font/Graphics ones, whole subsystems — see RE-POPS-EE-08, RE-POPS-EE-17) linked into the ELF. Two judgement calls are noted, not hidden: `Pads.getType` and `System.getSio2Owner` are documented in repo docs as diagnostic/do-not-use-for-gating surfaces — they still have no runtime caller.
- Fix: Delete the 52 unreferenced registrations and the implementations that become unreachable with them, in one pass, keeping any binding the parent confirms is a deliberate external contract.
- Benefit: The largest single dead-code cut in the EE core; shrinks the Lua attack/bug surface (several of these bindings are the unsafe ones in RE-POPS-EE-11/12/13) and the ELF.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-EE-08 — Dead C functions and dangling declarations left behind by removed subsystems
- Category: 1
- Locations: src/fntsys.cpp:390-412 (`fntLoadDefault`), src/fntsys.cpp:851-905 (`fntFitString`), src/graphics.cpp:890-900 (`gsKit_clear_screens`), src/graphics.cpp:1020-1045 (`drawImageCentered`, line range from full read), src/graphics.cpp:1093-1098 (`drawRectCentered`, line range from full read), src/include/system.h:19-20, src/include/luaplayer.h:51, src/include/luaplayer.h:61, src/main.cpp:532-534
- Problem: Scripted reference census over `src/` + shipped Lua: `fntLoadDefault` and `fntFitString` are defined and declared but called from nowhere (the Lua default-font path calls `fntLoadbuff` directly); `gsKit_clear_screens`, `drawImageCentered` and `drawRectCentered` have no caller and the two `*Centered` helpers are not even declared in `graphics.h`. The headers still promise things that do not exist: `system.h` declares `load_elf()` and the `load_elf_NoIOPReset` macro even though `system.cpp`'s own comment (src/system.cpp:168-181) records that `load_elf` was removed — any future caller compiles and fails only at link; `luaplayer.h` declares `stackDump()` and `luaC_collectgarbage()`, neither defined anywhere. `main.cpp`'s `#ifdef POWERPC_UART` block loads a `ppctty_irx` symbol that no IOP module list provides, so defining the flag breaks the link.
- Fix: Delete the five dead functions, the two dangling header declarations, the dead `load_elf` declaration + macro, and the `POWERPC_UART` block.
- Benefit: Headers become a truthful map of the link; removes ~150 lines including a font-slot copy/delete routine (`fntLoadDefault`) whose semaphore-free slot swap is a hazard if ever revived blind.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-09 — GetFreeSize / AllocateLargestFreeBlock: a dead chain whose algorithm repeatedly mallocs the largest block in the heap
- Category: 1
- Locations: src/system.cpp:183-254, src/luasystem.cpp:887-895, src/luasystem.cpp:2532, src/include/system.h:21, src/include/luaplayer.h:47
- Problem: `GetFreeSize()`'s only caller is the `System.getFreeMemory` binding, which the RE-POPS-EE-07 census shows has no Lua caller — the chain is unreachable. The algorithm itself is the other reason to delete rather than keep it: `AllocateLargestFreeBlock` binary-searches by actually `malloc`-ing ever-larger blocks (starting from a half-address-space probe) and `GetFreeSize` repeats that in a loop, linking every largest block into a list before freeing them — maximum heap churn and fragmentation pressure on a 32 MB EE, in exchange for a number nothing displays.
- Fix: Delete `GetFreeSize`, `AllocateLargestFreeBlock`, the binding, and both header declarations.
- Benefit: Removes ~70 lines and the most heap-hostile utility in the EE core; if a free-memory readout is ever wanted, it should come back as a mallinfo-style query, not this probe.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-10 — The `__RTL` renderer in fntsys.cpp is a half-finished second implementation that is never compiled and could not compile
- Category: 8
- Locations: src/fntsys.cpp:693-849
- Problem: `fntRenderString` exists twice: the live `#ifndef __RTL` version (src/fntsys.cpp:601-692) and an `#else` RTL version with `isRTL` / `isWeak` / `fntRenderSubRTL` (lines 693-849, ~157 lines). Nothing defines `__RTL` — no Makefile flag, no header, no build option (scripted grep over the repo build files) — and the dead branch calls `rmScaleX` / `rmScaleY` / `rmUnScaleX`, which are defined nowhere in the tree, so flipping the define on is an immediate compile break, not a feature toggle.
- Fix: Delete the `#else` branch and its three helper functions; keep the single live renderer. If RTL support is ever scheduled, it should be re-derived against the current renderer, not resurrected from this snapshot.
- Benefit: fntsys loses a quarter of its bulk and the next font bug gets fixed in exactly one place.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-11 — Lua handles are raw pointers cast through integers with no validation: NULL/wild dereference and double-free are one bad integer away
- Category: 6
- Locations: src/luagraphics.cpp:529-545, src/luagraphics.cpp:549-630, src/luagraphics.cpp:631-653, src/luagraphics.cpp:761-786, src/luagraphics.cpp:287-315, src/luasound.cpp:26-50, src/luatimer.cpp:33-122
- Problem: One mechanism across three files: C objects are handed to Lua as `(uint32_t)pointer` integers and taken back with `(GSTEXTURE*)luaL_checkinteger(...)` / `(GSFONT*)...` / `(audsrv_adpcm_t*)...` / `(Timer*)...`, then dereferenced immediately. Concretely: every `Graphics.draw*`/`getImageWidth`/`getImageHeight`/`setImageFilters` binding reads `source->Width`/`->Height`/`->Filter` with no NULL check, so a 0 or stale handle is a NULL/wild dereference; `Graphics.freeImage` frees Mem/Clut/struct with no liveness record, so a second call on the same integer is a double-free (the Lua side does call it from several cleanup paths); `Sound.playADPCM`/`freeADPCM` do the same for ADPCM handles. The Timer file looks like the exception but is not: its `TIMER_MAGIC` check itself dereferences the unchecked pointer first (`src->magic` at src/luatimer.cpp:38 and siblings), so a wild integer crashes inside the check that was meant to catch it.
- Fix: Validate before dereferencing with the cheapest mechanism that fits the existing style: reject 0 in every handle-taking binding, and for `freeImage`/`freeADPCM`/`Timer.destroy` clear-and-check via the one place that owns the handle (at minimum, NULL checks on every dereference site listed). No new handle-registry framework is proposed — the Lua is first-party, so this is crash-hardening, not a security boundary.
- Benefit: Turns a class of hard EE crashes (black screen, no error path) into Lua errors the existing error screen can show.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-12 — Two Lua bindings trust a caller-supplied length over the actual string: loadImageEmbedded and IOP.loadModuleBuffer
- Category: 6
- Locations: src/luagraphics.cpp:810-826, src/luasystem.cpp:2608-2627
- Problem: Buffer/length handling where Lua values cross into C. (a) `Graphics.loadImageEmbedded(blob, size)` takes the data via `luaL_checkstring` and the length from a *separate* integer argument, never comparing it with the string's true length; a size larger than the blob makes the PNG reader walk past the Lua string into heap memory (the reader bounds against the supplied size, not the real one). The one real caller passes `string.len(blob)` correctly, so the hazard is the binding's contract, not current data. (b) `IOP.loadModuleBuffer(ptr, size, ...)` takes an IRX image via `luaL_checkstring` — a C-string API applied to binary data containing NUL bytes — plus an unchecked `int size` (negative values pass straight through) and an `arg_len` that is never checked against the args string's length, all fed to `SifExecModuleBuffer`. This binding also has no Lua caller (RE-POPS-EE-07), so the cheapest correct fix is removal.
- Fix: For (a), take the length from `luaL_checklstring` and drop (or clamp to) the second argument. For (b), delete the binding with the RE-POPS-EE-07 pass; if it is ever restored, it needs `luaL_checklstring` + a size equality check.
- Benefit: Closes the only two places in the EE core where a Lua integer, rather than the data itself, decides how many bytes C reads.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-13 — Graphics.threadLoadImage passes a Lua-owned string pointer straight to a worker thread, and its second argument is unreachable
- Category: 6
- Locations: src/luagraphics.cpp:20-26, src/luagraphics.cpp:265-285, src/luagraphics.cpp:489-512, src/luagraphics.cpp:788-808, src/luagraphics.cpp:838, src/luagraphics.cpp:852-853
- Problem: `lua_loadimgasync` stores the `luaL_checkstring` pointer itself as the thread argument; the string belongs to the Lua heap and can be collected or moved while `imgThread` is still reading it — a use-after-free the file's own cover-worker comment (src/luagraphics.cpp:36-44) already documents as the reason the newer cover loader copies its path. The result channel is the same vintage: the thread `sprintf`s the texture pointer into a 16-byte heap buffer returned later by `getLoadData`, with one global slot and no request association. Additionally the arity check `if (argc != 1) return luaL_error(...)` makes the following `if (argc == 2) asyncDelayed = ...` branch unreachable, so the delayed flag can never be set from Lua. The binding and both result bindings have no Lua caller (RE-POPS-EE-07); the cover loader supersedes them.
- Fix: Delete `threadLoadImage`, `getLoadState`, `getLoadData`, `imgThread` and their globals/stack; the cover-load worker is the single async image path.
- Benefit: Removes a documented use-after-free and a whole superseded async mechanism (~90 lines) instead of leaving it armed for the next caller.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-14 — Font ids from Lua index the 16-entry fonts[] array with no bounds check in four fntsys entry points
- Category: 6
- Locations: src/fntsys.cpp:550-562, src/fntsys.cpp:602-606, src/fntsys.cpp:907-912, src/luagraphics.cpp:379-420
- Problem: `fntSetPixelSize`, `fntSetCharSize`, `fntRenderString` and `fntCalcDimensions` all do `&fonts[id]` / `fonts[fontid]` directly on the integer that `Font.ftSetPixelSize` / `ftSetCharSize` / `ftPrint` / `ftWidth` took from Lua via `luaL_checkinteger`, with no range validation. `fntRelease` (src/fntsys.cpp:281-283) does check `id > FNT_DEFAULT && id < FNT_MAX_COUNT`, proving the bound is known — the other four entry points just never got it. An out-of-range id is an out-of-bounds read in the render path and an out-of-bounds write in the two setters (both call `fntCacheFlush(&fonts[fontid])` first, which frees pointers through the wild slot).
- Fix: Add the same range check `fntRelease` already uses at the top of the four functions (return / return 0 on a bad id). No new abstraction — one guard, four sites.
- Benefit: Closes an out-of-bounds write reachable from the text-rendering bindings that every screen uses.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-15 — Pads.getPressure reads an uninitialised padButtonStatus when no pad read succeeds
- Category: 6
- Locations: src/luacontrols.cpp:148-213
- Problem: `lua_getpressure` declares `padButtonStatus pad;` uninitialised, calls `padRead` / `ds34bt_get_data` / `ds34usb_get_data` without checking any return value, and then switches over `pad.right_p` / `pad.left_p` / … — so with no controller in a stable state (or all three reads failing) the returned pressure is stack garbage. Its sibling bindings in the same file were already hardened for exactly this failure (zero-init + neutral 127 defaults + return-value gating in `lua_getleft`/`lua_getright`, src/luacontrols.cpp:82-146); this one function was missed.
- Fix: Give `lua_getpressure` the same treatment as its siblings: zero-initialise the struct, track whether any read succeeded, and return 0 pressure when none did.
- Benefit: Deterministic pressure values and parity inside one file; removes the last uninitialised-read in the pad bindings.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-16 — atlas allocation results are never checked: OOM is a NULL dereference, not a failure return
- Category: 6
- Locations: src/atlas.cpp:12-25, src/atlas.cpp:84-110, src/atlas.cpp:165-183
- Problem: `allocNew` writes through its `malloc` result unconditionally; `allocPlace` creates two leaf allocations per placement and stores them unchecked; `atlasNew` writes through two unchecked allocations (`malloc` for the atlas, `memalign` for the surface) and then `memset`s the surface pointer. Any allocation failure in the glyph-atlas path — the path every rendered character takes — is an immediate NULL dereference instead of the graceful "no atlas free" return that `fntGlyphAtlasPlace` already implements for the placement-failure case.
- Fix: NULL-check the three allocation sites and propagate failure (`allocPlace` returns NULL, `atlasNew` frees and returns NULL), matching the failure handling the caller already has.
- Benefit: Font rendering degrades (missing glyphs) instead of crashing the EE when the heap is exhausted.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-17 — graphics loadFont branches on an uninitialised magic value when the file cannot be opened
- Category: 6
- Locations: src/graphics.cpp:932-950, src/luagraphics.cpp:287-315
- Problem: `loadFont` does `int file = open(path, O_RDONLY, 0777); read(file, &magic, 2); close(file);` with no check on any of the three calls. If `open` fails, `file` is -1, `read` fails, and `magic` — an uninitialised stack `uint16_t` — decides which `gsKit_init_font` branch (if any) runs on a nonexistent path; the result is then uploaded without a NULL check in the caller pattern (`lua_fontload` checks for NULL, but `printFontText`/`unloadFont` dereference `font`/`font->Texture` unchecked). This is the legacy gsKit-font subsystem whose Lua bindings (`Font.load/print/unload`) have no caller (RE-POPS-EE-07) — the FreeType path is the live one.
- Fix: Prefer deletion with the RE-POPS-EE-07/08 pass (bindings + `loadFont`/`printFontText`/`unloadFont` + the gsFontM trio `loadFontM`/`printFontMText`/`unloadFontM` at src/graphics.cpp:908-930, whose bindings are likewise uncalled). If any part is kept, `open`/`read` results must be checked and `magic` initialised before use.
- Benefit: Removes an uninitialised-read bug and a whole parallel font subsystem (three file formats, its own upload path) that duplicates what fntsys already does.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-18 — fntsys readFile ignores the read() result, so a short read hands FreeType an uninitialised tail
- Category: 6
- Locations: src/fntsys.cpp:123-152, src/fntsys.cpp:286-312
- Problem: `readFile` sizes the buffer from `lseek(SEEK_END)`, allocates it, then calls `read(fd, buffer, realSize)` and discards the return value, reporting `*size = realSize` regardless of how many bytes actually arrived. A short read (or a file that shrinks between the seek and the read) leaves the tail of the buffer uninitialised, and `fntLoadSlot` passes that buffer and the full claimed size to `FT_New_Memory_Face`. The same function casts a failed `lseek` (-1) through the allocation size path instead of rejecting it up front.
- Fix: Capture the `read` result; on a short or failed read (or `realSize <= 0`), free, close and return NULL — the caller already treats NULL as a clean load failure.
- Benefit: Font loading fails cleanly on I/O trouble instead of feeding heap garbage to the FreeType parser.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-19 — The IRX load-and-check helper is duplicated verbatim in main.cpp and luasystem.cpp
- Category: 2
- Locations: src/main.cpp:459-478, src/luasystem.cpp:362-380
- Problem: `LoadIrxChecked` (main.cpp) and `LoadIrxCheckedBuffer` (luasystem.cpp) are the same function — same `SifExecModuleBuffer` call, same out-parameter handling, same `id < 0 || ret < 0` failure rule — differing only in the DPRINTF lines main.cpp adds. Every IRX-load policy change (return-code interpretation, logging, retry policy if one is ever justified) must currently be made twice, in the two files that between them load every module in the system.
- Fix: Keep one implementation (luasystem's, declared for main.cpp's use the way `EnsureUsbMass`/`EnsureDev9` already cross the same boundary) and delete the other.
- Benefit: One definition of "did this IRX load" for the whole EE core.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-20 — PNG and BMP decoders repeat the same row-buffer / CLUT / VRAM-upload blocks three times each
- Category: 2
- Locations: src/graphics.cpp:82-360 (decode_png_stream: CT32 branch from line 159, T4 branch from line 195, T8 branch within the same palette arm; row-pointer calloc/free blocks at lines 172, 217, 267), src/graphics.cpp:428-840 (loadbmp: per-depth CLUT, pixel-conversion and upload blocks)
- Problem: Inside `decode_png_stream`, the allocate-row-pointers → `png_read_image` → free-row-pointers sequence and the budget-check → memalign → CLUT-build sequence are copied per colour branch with only the PSM and CLUT size changing; inside `loadbmp` the same pattern repeats per bit depth, including three separate copies of the VRAM-alloc/upload/free tail that `decode_png_stream` also has. This is the file where the audit-sensitive fixes live (budget checks, longjmp cleanup, CLUT clamps are all documented inline as prior bug fixes) — triplication is how one branch ends up with a fix the others lack.
- Fix: Factor only the identical sequences (row-pointer lifecycle; texture VRAM upload tail) into file-local helpers used by all branches; leave the genuinely format-specific pixel conversion in place. No new abstraction leaves this file.
- Benefit: One place for the allocation/cleanup contract in the cover-art path; the next decoder fix applies to every format at once.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-EE-21 — ResolveAssetPath and ResolveAssetPathTyped duplicate the same candidate-walk
- Category: 2
- Locations: src/system.cpp:80-168
- Problem: `ResolveAssetPath` hand-rolls the absolute-path shortcut and the `app_dir` / `app_dir + "POPSLDR/"` candidate walk; `ResolveAssetPathTyped` then re-implements the same shortcut and walk pattern twice more (IMG and IRX arms) around a small `ResolveAssetCandidate` helper that the generic function does not use, before falling back to `ResolveAssetPath` for the generic kind anyway. Three copies of "try candidate, stat it, copy it out" in 90 lines.
- Fix: Rewrite `ResolveAssetPath` as the typed function with `ASSET_GENERIC` (the fallback already exists) and delete the duplicate body, keeping both public names/signatures so the two Lua bindings are untouched.
- Benefit: One candidate-order definition for asset resolution; a future search-path change cannot land in only two of the three copies.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-22 — DPRINTF is an unconditional no-op, so all EE diagnostic logging is dead in every build, including DEBUG builds
- Category: 3
- Locations: src/include/dprintf.h:4, src/main.cpp:459-478 (representative consumer whose comments describe DPRINTF as the DEBUG-gated channel), src/fntsys.cpp, src/graphics.cpp, src/luasystem.cpp, src/luaHDD.cpp, src/pad.cpp, src/sound.cpp, src/system.cpp, src/elf_loader/src/elf.c (163 lines matching `DPRINTF` across these EE sources by scripted grep)
- Problem: `#define DPRINTF(x...)` in `dprintf.h` is empty with no `#ifdef DEBUG` or any other condition — unlike `dbgprintf` in `luaplayer.h`, which is DEBUG-gated. Every DPRINTF call site in the EE core therefore compiles to nothing in release *and* debug builds, while comments throughout the tree (and the boot-profile design in main.cpp) describe DPRINTF as a live diagnostic channel that was deliberately bypassed in specific places because it "compiles to nothing in a release build". The mechanism misleads: effort keeps being spent routing around a logging system that is off everywhere, and the call sites themselves (string formatting arguments included) are pure dead weight in the source.
- Fix: Pick one truth and encode it: either gate the macro on `DEBUG` like `dbgprintf` so debug builds actually get the channel the comments promise, or delete the macro and its call sites. Do not add a new logging framework — the finding is that the existing switch is wired to nothing.
- Benefit: Either ~163 dead call sites go, or the diagnostic channel the codebase already writes to starts existing; the current state has the costs of both and the benefits of neither.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-23 — GetMassRootByBackendName defeats the BDM cache and re-binds the RPC on every single call
- Category: 5
- Locations: src/luasystem.cpp:321-360, src/luasystem.cpp:343-344, src/luasystem.cpp:521-526, src/luasystem.cpp:560-578
- Problem: Structural, not micro: a BDM device cache exists (`mass_backend_cache` + `EnsureMassBackendCache`), but `GetMassRootByBackendNameInternal` — the implementation behind `System.getMassRootByBackendName` — begins by forcing `mass_backend_cache_valid = false` and `bdm_rpc_bound = false`, then calls `FetchBdmList`, which re-runs `SifBindRpc` and a full RPC round-trip for the whole device list, on every lookup. `lua_refresh_mass_backends` also clears the bind flag without any unbind, so repeated refresh/lookup cycles accumulate bind attempts against the fixed-slot bdm_query server. Page-entry code that resolves several backends by name pays one full enumeration per name.
- Fix: Let the by-name lookup use the existing cache like `lua_get_mass_backend_info` does (invalidate only in `RefreshMassBackendCache`), and stop clearing `bdm_rpc_bound` outside an actual RPC failure.
- Benefit: Backend resolution becomes O(1) cached reads after the first enumeration instead of an IOP RPC + bind per call, on the storage-page paths that already have documented scan-latency history.
- Effort: S · Risk: Med · Confidence: High (READ)

### RE-POPS-EE-24 — HDD partition index from Lua is turned into a device-name byte with `'0' + index` and no range check
- Category: 6
- Locations: src/luaHDD.cpp:42-50, src/luaHDD.cpp:56-64
- Problem: `UmountPart` does `PFS[3] = '0' + luaL_checkinteger(L, 1)` and `mnt()` does `PFS[3] = '0' + index` (guarded only by `index > 0`) on the fixed `"pfs0:"` template. Any Lua integer outside 0-9 writes an arbitrary byte into the device name (index 17 produces `pfsA:`, index -1 in `UmountPart` produces `pfs/:`), and the resulting malformed name is passed to `fileXioUmount` / `fileXioMount`. The valid domain is a single digit — the callers only ever address pfs0:-pfs3: (the exec path in elf.c caps slots at 3).
- Fix: Range-check the index (0-9, or 0-3 to match the rest of the tree) in both bindings and return a Lua error / failure for anything outside it.
- Benefit: A bad Lua argument becomes an error instead of a malformed device operation against an arbitrary driver name.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-25 — Both ELF-loading stages copy program segments to header-supplied addresses with no bounds validation
- Category: 6
- Locations: src/elf_loader/src/elf.c:460-468, src/elf_loader/src/loader/src/loader.c:195-270
- Problem: The parent stage (`ExecuteViaEmbeddedLoader`) checks only the 4-byte ELF magic, then iterates `boot_header->phnum` program headers and `memcpy`s each `filesz` to `vaddr` with no check on phnum/phentsize sanity, on `offset + filesz` against the blob size, or on the destination range — acceptable only because the blob is the project's own child loader, but the check that exists (magic) implies a validation that is not performed. The child stage (`load_elf_via_filexio`) does cap `phnum` at 16, but then reads each PT_LOAD's `filesz` bytes directly to the header-supplied `vaddr` from a file on pfs/hdd/mass storage, with no check that the segment does not overwrite the child loader itself in BRAM, the metadata page at 0x83C00, or lie outside RAM, and no check that `hdr.entry` is inside a loaded segment. A crafted or corrupted target ELF is arbitrary memory write by design of the format — the finding is that neither stage performs even the cheap structural checks (file-bounds, BRAM exclusion, entry-in-segment) that would catch corruption rather than malice. INFERRED severity: the target ELFs are user-supplied game launchers, so the realistic trigger is a truncated/corrupt file, not an attacker.
- Fix: Add the three structural checks in each stage (segment file-range within the blob/file size; destination outside the loader's own BRAM span and the metadata page; entry inside a PT_LOAD) and fail with the existing negative-code convention. No format or loader redesign.
- Benefit: A corrupt POPSTARTER.ELF fails with a diagnosable code instead of silently overwriting the loader and hanging the console.
- Effort: M · Risk: Med · Confidence: Med (INFERRED)

### RE-POPS-EE-26 — Makefile still embeds the superseded ps2atad stack and keeps a build rule its own comment calls unused
- Category: 7
- Locations: Makefile:98, Makefile:338-341, src/luaHDD.cpp:166-174
- Problem: `IOP_MODULES` still bin2c-embeds `ps2atad.o`, but the only reference to the `ps2atad_irx` symbol in the EE sources is the unused `IMPORT_BIN2C(ps2atad_irx)` extern in luaHDD.cpp — `Load_HDD_IRX` deliberately no longer loads it, because ata_bd (the BDM-enabled atad) replaced it and loading both was the documented APA-boot freeze. The blob is therefore linked into every ELF and never executed. The same file declares `IMPORT_BIN2C(poweroff_irx)`, also never referenced in the file. Separately, the Makefile retains the `iop/ata_bd_fast/ata_bd.irx` build rule under a comment stating the vendored source and its rule "are kept but unused" — dead build wiring for a driver that is pinned from `iop/embed/` instead.
- Fix: Remove `ps2atad.o` from `IOP_MODULES`, delete the two unused `IMPORT_BIN2C` lines, and delete the unused ata_bd_fast build rule (the vendored source directory itself is outside this section's scope — flagged for the parent).
- Benefit: One atad in the ELF — the one that actually loads — and no build rule that invites someone to wire the fast variant back in by accident.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-EE-27 — HDD.ListPartitions reserves a 512-entry × 33-byte static table (16,896 bytes of BSS) for a transient enumeration
- Category: 4
- Locations: src/luaHDD.cpp:124-165
- Problem: `ListPartitions` snapshots partition names into `static char lp_names[512][33]` — 16,896 bytes of permanent BSS — to hold at most 512 APA partition names across a single call. The static is there for a real reason (the comment explains snapshotting before touching the Lua heap so a longjmp cannot strand a directory slot), but the cap is two orders of magnitude past any real drive's PFS partition count, and the memory is paid for the life of the process for a listing operation.
- Fix: Keep the snapshot design; cut the cap to a defensible bound (e.g. 64 entries, still far beyond real APA tables) or allocate the snapshot per call and free it after the table is built. Either keeps the longjmp-safety property.
- Benefit: ~14-16 KB of EE BSS returned permanently, in the memory space where the cover loader and font atlases compete.
- Effort: S · Risk: Low · Confidence: High (READ)

---

## FILES READ

In scope, read in full unless noted:

- Makefile (root, 448 lines, full)
- src/atlas.cpp, src/embed_assets.cpp, src/fntsys.cpp, src/ftmin.c, src/graphics.cpp, src/luaHDD.cpp, src/luaScreen.cpp, src/luacontrols.cpp, src/luagraphics.cpp, src/luaplayer.cpp, src/luasound.cpp, src/luasystem.cpp (2,718 lines, full), src/luatimer.cpp, src/main.cpp, src/pad.cpp, src/retrogem.cpp, src/sound.cpp, src/system.cpp
- src/include/atlas.h, src/include/dprintf.h, src/include/embed_assets.h, src/include/fntsys.h, src/include/graphics.h, src/include/luaplayer.h, src/include/pad.h, src/include/sound.h, src/include/system.h, src/include/utf8.h
- src/elf_loader/Makefile, src/elf_loader/include/elf-loader.h, src/elf_loader/src/elf.c, src/elf_loader/src/elf.h, src/elf_loader/src/loader/Makefile, src/elf_loader/src/loader/linkfile, src/elf_loader/src/loader/src/loader.c
- src/elf_loader/loader.c — header + metadata only (first 80 lines): this file is the generated bin2c hex dump analysed in RE-POPS-EE-05; its size (855,821 B), line count (8,740), embedded size field (139,700) and MD5 were taken by script, and it was diffed against the child source by identity (different files, different hashes — it is generated output, not a second source copy)
- AGENTS.md (repo root, house rules)

Out-of-scope files used only as census inputs (grep/script counts, not line-audited): bin/POPSLDR/system.lua, bin/POPSLDR/ui.lua, bin/POPSLDR/images.lua (read in full — 93 lines — for the asset-registration census), etc/boot.lua, and scripted directory listings / sizes / MD5s for everything under bin/POPSLDR/ and EMBED/.

## FILES NOT READ

- src/elf_loader/loader.c, lines 81-8740 — the generated hex payload itself (see above; no human-readable code exists in this range to audit).
- All binary payloads under bin/POPSLDR/ and EMBED/ (POPSTARTER.ELF copies, *.irx.*, *.png, *.icn, *.adp, PATCH_5.BIN, builtin_font.ttf) — inventoried by name/size/MD5 only; their contents are data, not EE code.
- bin/POPSLDR/system.lua and bin/POPSLDR/ui.lua beyond the binding/asset-usage census greps — Lua application logic is outside this section's EE C++ scope.
- Everything outside the assigned scope: iop/, modules/, POPSTARTER/, tools/, docs/, .github/, and the remaining root *.md files — not opened.
- Nothing under ~/workspace/Sable-audit/ was read, listed, or opened (hard blind rule).
