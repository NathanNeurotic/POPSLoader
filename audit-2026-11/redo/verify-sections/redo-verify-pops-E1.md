# Redo Verification — POPSLoader chunk E1 (EE graphics/font core)

- Subject: `~/workspace/Sable-audit-redo/Redo-POPSLoader.md`
- Clone (read-only): `~/workspace/audit-clones-2026-11-13/POPSLoader`
- Pin verified: `git rev-parse HEAD` = `29272cddbf0122f14e76bc3bdd75e3b46aa870be`, worktree clean.
- Method: refute-first. Every cited file/line opened with surrounding context; every numeric claim re-derived by shell; defeating evidence hunted first (caller validation, callee NULL checks, FreeType/gsKit/libpng behaviour, build-file redefinitions).
- Assigned: RE-POPS-021, 022, 027, 028, 030, 031, 032, 062, 077, 082.

---

### RE-POPS-021 — VERIFIED-DRIFT

Font ids from Lua index the 16-entry `fonts[]` array with no bounds check in four fntsys entry points.

Evidence (all re-read at pin):

- `src/fntsys.cpp:91` `#define FNT_MAX_COUNT (16)`; `:94` `static font_t fonts[FNT_MAX_COUNT];`; `src/include/fntsys.h:7` `#define FNT_DEFAULT (0)`.
- `src/fntsys.cpp:279-283` `fntRelease` is exactly as claimed: `if (id > FNT_DEFAULT && id < FNT_MAX_COUNT) fntDeleteSlot(&fonts[id]);` — the only one of the five id-taking entry points with a guard.
- `fntSetPixelSize` (`:550-555`): `fntCacheFlush(&fonts[fontid]); FT_Set_Pixel_Sizes(fonts[fontid].face, …)` — no check. `fntCacheFlush` (`:168-…`) loops `font->glyphCache[i]` and `free()`s through the pointer, so a wild slot is indeed a write/free through out-of-bounds memory, as claimed.
- `fntSetCharSize` (`:557-562`): identical pattern.
- Live `fntRenderString` (`:602`, `#ifndef __RTL` branch): `font_t *font = &fonts[id];` (`:606`) — no check; it also re-enters `fntCalcDimensions(id, …)`.
- `fntCalcDimensions` (`:907-912`): `font_t *font = &fonts[id];` then `FT_HAS_KERNING(font->face)` — no check.
- Lua side (`src/luagraphics.cpp:379-420`): `lua_ftSetPixelSize`, `lua_ftSetCharSize`, `lua_ftprint`, `lua_ftwidth` all take the id via `luaL_checkinteger` and pass it straight through; the only validation is argument *count*. No Lua-side range check exists in `bin/POPSLDR/*.lua` either (ids there are the `LFONT`/`BFONT`/`SFONT` variables returned by the loaders).
- Defeating-evidence hunt: no other caller validates. The only non-Lua callers are internal (`fntRenderString`→`fntCalcDimensions`, same unchecked id). `fntFitString` (`:851`) reaches `fonts[]` only via `fntCalcDimensions`, so it is covered transitively by fixing that function and is not a missed fifth site. Negative ids are reachable in practice, not just in theory: `fntLoadFile`/`fntLoadbuff` return `FNT_ERROR` = `-1` (`fntsys.h:9`) on failure, and a Lua caller that ignores a failed load hands `-1` to these bindings.

Corrected figure (the DRIFT — the proposed fix, taken literally, is wrong):

- The report says "add the same range check `fntRelease` already uses." Copied verbatim, that check is `id > FNT_DEFAULT`, i.e. **1..15 — it excludes id 0**. But id 0 is a legitimate, heavily used font everywhere except in `fntRelease`: `fntLoadFile` returns slot 0 for the first loaded font, `fntLoadDefault` installs into `fonts[FNT_DEFAULT]` and returns 0, and the default font is precisely the one the setters/renderer must accept. `fntRelease` excludes 0 deliberately (protect the default font from release); the other four functions must not.
- Correct guard for the four functions: reject `id < FNT_DEFAULT || id >= FNT_MAX_COUNT` (equivalently `id < 0 || id >= 16`), return / return 0. With that correction the fix is sane, minimal, and LESS-NOT-MORE compliant (one guard, four sites, no abstraction).

Overlap note: the dead `__RTL` copy of `fntRenderString` (`:737`, `&fonts[id]`) is a fifth unchecked site, but it is the code RE-POPS-062 deletes, so it needs no separate guard — see RE-POPS-062.

### RE-POPS-022 — WEAKENED

Lua handles are raw pointers cast through integers with no validation.

What holds in full (verified at pin):

- Graphics texture handles: `src/luagraphics.cpp:529-653` — `lua_drawimg`, `lua_drawimg_rotate`, `lua_drawimg_scale`, `lua_drawimg_part`, `lua_drawimg_full` cast `(GSTEXTURE*)luaL_checkinteger(L,1)` and immediately read `source->Width`/`source->Height` in the binding itself (before `drawImage`, which also dereferences `source->Delayed` at `src/graphics.cpp:1040-…` with no check). `lua_width`/`lua_height` (`:631-…`) push `source->Width`/`source->Height`; `lua_filters` writes `source->Filter`. No NULL check at any of these sites; handle 0 or any stale/wild integer dereferences immediately. The GSFONT bindings at `:287-315` are the same pattern (`printFontText`/`unloadFont` receive the raw cast; `unloadFont` dereferences `font->Texture` at `src/graphics.cpp:~958`).
- `Graphics.freeImage` (`lua_free`, `:761-786`): no liveness record exists anywhere in the file (no registry/set of live textures — confirmed by reading the whole handle surface). It calls `UnloadTexture(source)`, then dereferences `source->Mem`, `free()`s Mem/Clut/struct and only NULLs its *local* variable; the Lua integer is unchanged, so a second call on the same integer is a use-after-free read of `Mem`/`Clut` followed by a double `free()`. The Lua side does call it from many cleanup paths, as claimed (`bin/POPSLDR/images.lua:82-87`; `bin/POPSLDR/ui.lua:389-418, 451-452, 651-652, 706-707, 782-783, 826-827, 850`, mostly via `pcall` — which cannot catch a C crash).
- Timer (`src/luatimer.cpp:33-122`): the report's sharpest claim is exactly right. All seven handle-taking functions (`lua_time` :33, `lua_pause`, `lua_resume`, `lua_reset`, `lua_set`, `lua_wisPlaying`, `lua_destroy` :112) do `(Timer*)luaL_checkinteger(...)` and then test `src->magic != TIMER_MAGIC` — i.e. **the magic check's first act is dereferencing the unchecked pointer** (`src->magic` at :38 and siblings). There is no preceding NULL check, and `SKIP_ERROR_HANDLING` is never defined (grep: only `#ifndef` uses, no `-D` in any Makefile), so the check is compiled in and still cannot catch 0/wild handles. `lua_destroy` additionally double-frees: after `free(timer)` the Lua integer still decodes to a block whose `magic` field typically still reads `TIMER_MAGIC` in unreused heap, so a second `destroy` passes the check and `free()`s again.

True scope (the WEAKENING — one limb is overstated):

- Sound ADPCM NULL is **not** an unchecked dereference. The bindings (`src/luasound.cpp:38-50`) pass the cast straight through, but the callees check: `sound_playadpcm` (`src/sound.cpp:129-138`) begins `if (sample == NULL) { DPRINTF(...); return; }`, and `sound_freeadpcm` (`src/sound.cpp:140-147`) begins `if (sample == NULL) return;`. So ADPCM handle **0 is safe**, unlike texture/font/timer handle 0. What survives for sound is the narrower claim: a *non-NULL wild/stale* ADPCM integer is dereferenced inside `audsrv_ch_play_adpcm` / `audsrv_free_adpcm` + `free(sample)`, and a second `freeADPCM` on the same integer is still a double-free path. The finding's headline mechanism (raw-pointer handles, no validation, double-free) stands for all three files; its "a 0 … handle is a NULL dereference" framing applies to graphics/font/timer, not to sound.
- Fix assessment: rejecting 0 in every handle-taking binding + NULL checks at the dereference sites is sane and LESS-NOT-MORE (explicitly no registry framework). Note the fix's `freeADPCM` clear-and-check limb is partly redundant for the NULL case given the `sound.cpp` checks above; the double-free limb is the real sound-side value.

### RE-POPS-027 — VERIFIED

Two Lua bindings trust a caller-supplied length over the actual string.

Evidence:

- (a) `src/luagraphics.cpp:810-826` `lua_load_embedded_png`: `uint8_t* ptr = (uint8_t*)luaL_checkstring(L,1); size_t siz = luaL_checkinteger(L,2); loadEmbeddedPNG(ptr, siz, true);` — the length never comes from the string. `loadEmbeddedPNG` (`src/graphics.cpp:1361-1364`) → `DecodePngFromMemory` (`:361`) → `PngMemReader{data, size, 0}` + `PngReadFromMemory` (`:51-60`), whose overflow check is `byteCountToRead > (reader->size - reader->off)` — bounded against the **supplied** size, exactly as claimed; an overstated size makes libpng `memcpy` past the end of the Lua string into heap. A negative size is worse than the report states: `siz` is `size_t`, so a negative `luaL_checkinteger` wraps to a huge bound. The one real caller is correct, as claimed: `bin/POPSLDR/images.lua:59` `Graphics.loadImageEmbedded(blob, string.len(blob))`.
- (b) `src/luasystem.cpp:2608-2627` `lua_sifloadmodulebuffer`: `const char* ptr = luaL_checkstring(L,1); int size = luaL_checkinteger(L,2); … arg_len = luaL_checkinteger(L,3); args = luaL_checkstring(L,4); SifExecModuleBuffer((void*)ptr, size, arg_len, args, &RET);` — no comparison of `size` against the string's true length, no `size < 0` rejection, no `arg_len` vs args-length check. Registered as `IOP.loadModuleBuffer` (`Sif_functions` at :2628, installed as global `IOP` at :2667-2668) — the report's name is correct. No Lua caller exists (grep over all `*.lua` in the tree: zero hits), consistent with the RE-POPS-048 cross-reference and with deletion being the cheapest fix.
- One framing nuance (does not change the verdict): for (b) the hazard is the *size trust*, not NUL truncation — `SifExecModuleBuffer` consumes `ptr`+`size`, not `strlen(ptr)`, so embedded NULs in the buffer are not themselves lost; what `luaL_checkstring` fails to provide is the length that would let the binding validate `size`/`arg_len`. The report's operative claims (unchecked size, negative passes through, unchecked `arg_len`) are all literally in the code.
- Fix assessment: (a) `luaL_checklstring` + drop/clamp the second argument, (b) delete with the RE-POPS-048 pass — both sane, minimal, LESS-NOT-MORE compliant.

### RE-POPS-028 — VERIFIED

`Graphics.threadLoadImage` passes a Lua-owned string pointer to a worker thread; its second argument is unreachable.

Evidence:

- `src/luagraphics.cpp:489-512` `lua_loadimgasync`: `char* text = (char*)(luaL_checkstring(L,1)); … StartThread(thread, (void*)text);` — the pointer itself is the thread argument; nothing copies it. After the binding returns, the string is unreferenced on the Lua side and collectable while `imgThread` (`:265-285`) is still calling `load_image(text, delayed)` on it — use-after-free as claimed.
- The file convicts itself, as claimed: the EXP49 cover-loader comment (`:33-44`) states of `Graphics.threadLoadImage` that "it passes the Lua-owned string straight to the thread (it can be collected mid-load), has one global slot with no association to WHICH request finished, and on decode failure leaves `imgThreadData` holding a stale pointer" — and the cover loader was built to copy its path for exactly this reason.
- Result channel (`:265-285`, `:788-808`): `imgThread` does `char* buffer = (char*)malloc(16); sprintf(buffer, "%i", (int)image); imgThreadData = (unsigned char*)buffer; imgThreadSize = strlen(buffer);` — one global slot (`imgThreadData`/`imgThreadSize`/`imgThreadResult`, declared `:20-26`), no request association; `lua_getloaddata` later `lua_pushlstring`s and `free()`s it. All as claimed. (16 bytes is sufficient for a 32-bit `%i`, so this is an archaic channel, not an overflow — the report does not claim overflow.)
- Arity limb — exactly as claimed, verified character-for-character: `:491` `if (argc != 1) return luaL_error(L, "wrong number of arguments");` makes `:494` `if (argc == 2) asyncDelayed = lua_toboolean(L, 2);` **unreachable in both directions** (argc==2 already errored; argc==1 fails the inner test). `asyncDelayed` (global, `:20`, initialised `true`) can therefore never be set from Lua.
- No Lua caller: grep for `threadLoadImage`/`getLoadState`/`getLoadData` over all `*.lua` — zero hits; registrations at `:838, 852-853` are the only references besides the definitions. The cover loader (`coverLoadBegin`/`coverLoadPoll`) is the live async path.
- Fix assessment: delete `threadLoadImage`, `getLoadState`, `getLoadData`, `imgThread` and their globals/stack — sane, pure deletion, LESS-NOT-MORE ideal.

### RE-POPS-030 — VERIFIED-DRIFT

Atlas allocation results are never checked: OOM is a NULL dereference.

Evidence (mechanism fully verified):

- `src/atlas.cpp:12-25` `allocNew`: `al = malloc(...); al->x = x; …` — writes through the result unconditionally.
- `allocPlace` (actual lines **49-82**): `alloc->leaf1 = allocNew(...); alloc->leaf2 = allocNew(...);` at :62-66, stored unchecked (in practice `allocNew` crashes first on OOM, before a NULL can even be stored).
- `src/atlas.cpp:84-110` `atlasNew`: `atlas = malloc(...); atlas->allocation = allocNew(...); … atlas->surface.Mem = memalign(128, txtsize); … memset(atlas->surface.Mem, 0x0, txtsize);` at :107 — two unchecked allocations plus a `memset` through the `memalign` result.
- The caller-side contrast the report draws is real: `fntGlyphAtlasPlace` (`src/fntsys.cpp:439-…`) does handle a placement failure (`atlasPlace` returning NULL → return 0 → glyph skipped), so graceful degradation exists one level up for the *space* failure but not for the *allocation* failure.

Corrected figures / fix scope (the DRIFT — two citation/fix defects):

1. Citation drift: the report cites `src/atlas.cpp:165-183` for the third site. Those lines are `atlasPlace` (the wrapper), not `allocPlace`. The `allocPlace` leaf-allocation site is at **:49-82** (allocNew calls at :62-66) and is not in the cited ranges. The defect is real; one anchor points at the wrong function.
2. Fix incompleteness: the report says `atlasNew` should free-and-return-NULL "matching the failure handling the caller already has." The caller does **not** have such handling for a NULL atlas. `fntNewAtlas` (`src/fntsys.cpp:428-437`) immediately dereferences the result (`atl->surface.ClutPSM = …`), and `fntGlyphAtlasPlace` then calls `atlasPlace(*atl, …)`, which dereferences `atlas->allocation` — with `*atl == NULL` both crash. A correct fix therefore needs, in addition to the three NULL checks in `atlas.cpp`, a NULL guard in `fntNewAtlas` or in `fntGlyphAtlasPlace`/`atlasPlace`. Still small and LESS-NOT-MORE compliant, but the fix as written would trade one NULL dereference for another.

### RE-POPS-031 — VERIFIED-DRIFT

`fntsys` `readFile` ignores the `read()` result; a short read hands FreeType an uninitialised tail.

Evidence (core mechanism verified):

- `src/fntsys.cpp:123-152` `readFile`: sizes from `lseek(fd, 0, SEEK_END)`, `malloc`/`memalign(64, realSize)`, then `:148` `read(fd, buffer, realSize);` — return value discarded — then `*size = realSize;` unconditionally. The buffer is `malloc` (not `calloc`), so any short-read tail is uninitialised heap.
- Sole caller (grep: only one call site): `fntLoadSlot` (`:286-312`) passes `bufferSize` initialised to -1, then `FT_New_Memory_Face(font_library, buffer, bufferSize, 0, &font->face)` at :302 with the full claimed size. Caller treats NULL as a clean load failure (`FNT_ERROR`), exactly as the fix assumes. Fix (capture read result; short/failed/`realSize <= 0` → free, close, return NULL) is sane and minimal.

Corrected figure (the DRIFT — the secondary `lseek` limb is overstated):

- The report says the function "casts a failed `lseek` (-1) through the allocation size path instead of rejecting it up front," implying the -1 flows onward dangerously. Traced: with the sole caller's `*size == -1`, the expected-size check `(*size > 0) && (*size != realSize)` is skipped, but `malloc((size_t)-1)` / `memalign(64, -1)` then **fails**, the existing `if (!buffer)` branch sets `*size = 0` and the function returns NULL — a clean load failure, not an uninitialised buffer reaching FreeType. (For a hypothetical caller passing an expected size > 0, the mismatch check returns NULL before allocation.) So the -1 path is ugly and worth the explicit `realSize <= 0` rejection the fix proposes, but its current consequence is benign-by-accident; the live hazard in this finding is the short read alone.

### RE-POPS-032 — VERIFIED

Graphics `loadFont` branches on an uninitialised magic value when the file cannot be opened.

Evidence:

- `src/graphics.cpp:932-950` `loadFont`, verbatim mechanism: `int file = open(path, O_RDONLY, 0777); uint16_t magic; read(file, &magic, 2); close(file);` — no check on any of the three calls. On open failure `file == -1`, `read` fails, and `magic` — an uninitialised stack `uint16_t` — selects among the `0x4D42` / `0x4246` / `0x5089` `gsKit_init_font` branches (or none).
- Stronger than stated in one respect: inside `loadFont` itself the branch result is **not** NULL-checked before use — `font = gsKit_init_font(...); gsKit_font_upload(gsGlobal, font);` — so a garbage-magic match on a nonexistent path feeds a possibly-NULL `font` straight to the upload.
- Caller pattern as claimed: `lua_fontload` (`src/luagraphics.cpp:287-293`) does check `font == NULL` and raises a Lua error, but `lua_print`/`lua_fontunload` (`:295-315`) pass the raw cast handle to `printFontText`/`unloadFont`, which dereference it (`unloadFont`: `font->Texture`, `src/graphics.cpp:~958`). Locations `:287-315` verified.
- Deletion premise verified: the gsFontM trio is at `src/graphics.cpp:908-930` (`loadFontM` :908, `printFontMText`, `unloadFontM`), and grep over all shipped Lua finds **no caller** of `Font.load` / `Font.print` / `Font.unload` / `fmLoad` / `fmPrint` / `fmUnload` — the live Lua font surface is exclusively the FreeType `ft*` bindings. (This independently corroborates the RE-POPS-048 cross-reference for these bindings.)
- Fix assessment: deletion with the RE-POPS-048 pass is the right LESS-NOT-MORE call; the fallback (check open/read, initialise `magic`) is correctly stated.

### RE-POPS-062 — VERIFIED

The `__RTL` renderer in `fntsys.cpp` is a half-finished second implementation that is never compiled and could not compile.

Evidence (all numbers re-derived):

- Structure: `#ifndef __RTL` at `src/fntsys.cpp:601`, live `fntRenderString` :602-692, `#else` at **:693**, `#endif` at **:849**. Dead block = lines 693-849 = **157 lines** (`awk 'NR>=693 && NR<=849' | wc -l` = 157), containing `isRTL`, `isWeak`, `fntRenderSubRTL` and the second `fntRenderString` — exactly as claimed, anchors exact.
- Never compiled: `grep -rn "__RTL"` over the entire tree (sources, headers, Makefiles, workflows) returns hits **only** inside `fntsys.cpp` itself (the `#ifndef`, the `#else` block, and the explanatory comment at :17). Nothing defines it — no Makefile flag, no header, no build option.
- Could not compile: the dead branch calls `rmScaleX` (:741, :743), `rmScaleY` (:742, :744, :766, :768, :810) and `rmUnScaleX` (:847). `grep -rn "rmScaleX|rmScaleY|rmUnScale"` over `src/` returns **only those call sites** — the three functions are defined nowhere in the tree. (The other globals the branch uses — `state`, `codepoint`, `glyph`, `use_kerning` at :97-101 — do exist file-scope, so the report correctly names only the `rm*` trio as missing.) Flipping the define is an immediate link/compile break, not a feature toggle.
- Fix assessment: delete the `#else` branch and its three helpers — pure deletion, LESS-NOT-MORE ideal.
- Minor prose correction (not affecting the verdict): the benefit line says fntsys "loses a quarter of its bulk"; 157 lines of the 946-line file is ≈17%. The deletion is still the largest single dead block in the file.

### RE-POPS-077 — WEAKENED

PNG and BMP decoders repeat the same row-buffer / CLUT / VRAM-upload blocks three times each.

What holds in full (PNG limb, verified):

- `decode_png_stream` (`src/graphics.cpp:82-359`): the allocate-row-pointers → `png_read_image` → free-row-pointers sequence appears **three times**, at the exact anchors cited — `calloc` at :172 (CT32 branch), :217 (T4 branch), :267 (T8 branch), each with its own per-row `malloc` loop, NULL→`longjmp` guards, and matching free/reset block. The budget-check (`cover_size_ok`) → `memalign` sequence also appears in all three branches. The CLUT-build block appears in the two palette branches (T4: :226-… with the 8×2 CLUT; T8: :276-… with the 16×16 CLUT and the CSM1 nibble-swap loop) — CT32 has no CLUT, so "CLUT … three times" is really two for PNG.
- `loadbmp` (`src/graphics.cpp:428-849`; report says 428-840, end anchor off by 9): per-bit-depth triplication is real for the *conversion* stage — three `memalign` pixel-buffer + `fread` + conversion blocks (24-bit :641-…, 16-bit :680-…, 8/4-bit :722-…) plus two CLUT preamble blocks (4-bit :484-…, 8-bit :526-…).

True scope (the WEAKENING — the BMP VRAM-tail limb is refuted):

- The report claims `loadbmp` contains "three separate copies of the VRAM-alloc/upload/free tail that `decode_png_stream` also has." It does not. In `loadbmp` the VRAM tail — `gsKit_vram_alloc` for texture (+ CLUT), `gsKit_texture_upload`, `free(tex->Mem)`, conditional `free(tex->Clut)` — appears **once**, as a single shared tail after all per-depth branches converge (:795-849 region), structurally the same single tail `decode_png_stream` has once at its end. What is triplicated in `loadbmp` is the pixel-buffer/conversion stage (and duplicated in the CLUT preambles and the many per-branch error-cleanup blocks), not the upload tail.
- Fix assessment: factoring the PNG row-pointer lifecycle into a file-local helper is sane and clearly net-negative code. The "texture VRAM upload tail" half of the proposed factoring has much less to factor than claimed — one tail per decoder, shared by construction — so the realistic saving is the PNG row lifecycle plus the BMP conversion-stage error-cleanup repetition. Still LESS-NOT-MORE compliant (file-local helpers only), but scoped smaller than stated.

### RE-POPS-082 — VERIFIED-DRIFT

`DPRINTF` is an unconditional no-op, so all EE diagnostic logging is dead in every build, including DEBUG builds.

Evidence (mechanism fully verified):

- `src/include/dprintf.h` is five lines; `:4` is `#define DPRINTF(x...)` — empty, with **no** `#ifdef DEBUG` or any other condition. Verified by reading the whole file.
- No build file redefines it: the top-level `Makefile` sets `DEBUG = 0` and, at :66-68, `ifeq ($(DEBUG),1) EE_CXXFLAGS += -DDEBUG` — `-DDEBUG` is passed but `dprintf.h` never tests it, and grep for `DPRINTF` over the Makefile/workflows finds no `-DDPRINTF` or alternate definition for the EE core. So DEBUG builds get exactly the same nothing, as claimed.
- The contrast is exact: `dbgprintf` in `src/include/luaplayer.h:36-40` is `#ifdef DEBUG → scr_printf(args) / #else → ;` — DEBUG-gated, as claimed.
- The misleading-comments limb is real and abundant: `src/main.cpp:628-631` ("LOAD_IRX_NARG feeds id/ret to DPRINTF, which is a no-op in a release build… Deliberately no DPRINTF on failure: DPRINTF IS the bug"), `src/main.cpp:322`, `src/luasystem.cpp:118` and `:1477` all describe DPRINTF as a release-only-off channel. The cited representative consumer `src/main.cpp:459-478` is `LoadIrxChecked` (macro definition at :455-457) — anchor correct.
- One additional unconditional definition the report does not mention: the child loader has its **own** `DPRINTF` at `src/elf_loader/src/loader/src/loader.c:32,35` — `do {} while (0)` in **both** branches of `#ifdef LOADER_ENABLE_DEBUG_COLORS`, with an in-code comment (:25-31) explaining it is deliberately kept a no-op for link cleanliness. It does not weaken the finding (it is also dead in every build), but it means gating `dprintf.h` on `DEBUG` would not revive the loader's 4 DPRINTF calls.

Corrected figure (the DRIFT — the count is right, the file list is incomplete):

- My re-derivation: `grep -rn "DPRINTF" src/ --include="*.cpp" --include="*.c" | wc -l` = **163 lines** — the report's number is exact for *all* EE sources.
- But the nine files the report lists sum to **150**, not 163: fntsys.cpp 16, graphics.cpp 30, luasystem.cpp 21, luaHDD.cpp 11, pad.cpp 20, sound.cpp 10, system.cpp 3, elf_loader/src/elf.c 15, main.cpp 24. The missing 13 lines are `src/luaplayer.cpp` (6 call sites) and `src/elf_loader/src/loader/src/loader.c` (7 lines: 1 comment, 2 defines, 4 call sites), neither of which appears in the finding's Locations. Corrected statement: 163 matching lines across **eleven** EE source files (150 in the nine listed + 13 in the two unlisted).
- Fix assessment: gate the macro on `DEBUG` like `dbgprintf`, or delete macro + call sites — both sane; no new logging framework proposed. LESS-NOT-MORE compliant either way.

---

## Tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 4 | RE-POPS-027, 028, 032, 062 |
| VERIFIED-DRIFT | 4 | RE-POPS-021, 030, 031, 082 |
| WEAKENED | 2 | RE-POPS-022, 077 |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |
| **Total** | **10** | |

No finding was refuted outright: every headline mechanism in this chunk re-derives from the pinned code. All corrections are to fix wording, one citation anchor, one count's file list, and two overstated sub-limbs.

## Suspected mechanism-level duplicates

- None among the ten as independent findings. One overlap flagged: the dead `__RTL` `fntRenderString` (`fntsys.cpp:737`) is a fifth unchecked-`fonts[id]` site belonging to RE-POPS-021's mechanism, but it lives entirely inside the block RE-POPS-062 deletes — fixing 062 removes it; it should not be counted as a separate 021 site or a separate finding.
- RE-POPS-022 / 027 / 028 share `src/luagraphics.cpp` and a "Lua boundary trusts its input" theme but are three distinct mechanisms (handle dereference, length trust, thread UAF + dead arity branch) — not duplicates.

## Candidates (new defects noticed while verifying — not verdicts)

- CANDIDATE-E1-1 (related to RE-POPS-030's fix gap, arguably part of it): `fntNewAtlas` (`src/fntsys.cpp:428-437`) dereferences `atlasNew`'s result with no NULL check, and `atlasPlace` (`src/atlas.cpp:165-…`) dereferences `atlas->allocation` with no NULL-atlas check — an independent NULL-deref chain in the same glyph path that exists *today* for the `allocNew`-inside-`atlasNew` failure mode (where `atlas->allocation` is written through NULL inside `atlasNew` itself). Recorded here because any fix for RE-POPS-030 must touch these sites; if the parent treats them as outside 030's scope, they stand as a separate candidate.
- No other new defects were found in the assigned files within this chunk's scope. (`fntFitString` was specifically checked as a possible extra unchecked-id site for RE-POPS-021 and cleared: it reaches `fonts[]` only through `fntCalcDimensions`.)
