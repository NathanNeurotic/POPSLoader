# Hosted legacy patch-package forensic comparison — PATCH_9 naming collision

**Draft follow-up research only.** This report inspects **existing hosted archive bytes**, not the historical Bitbucket originals. It does not execute any patch, assess patch safety on a PS2, or replace, delete or redistribute existing packages.

## Why this matters

The original final `special-cheats.textile` (and recovered `.research/wiki/special-cheats.md`) explicitly links `$NOPAL`'s disable-auto-PAL-patcher instruction to the Bitbucket download **`NOPAL_PATCH.7z`**. The POPSLoader research site has a **same-named 188-byte archive** under `.research/downloads/` which the site normally relinks for recovered download names. The historical Bitbucket listing, however, describes an original **226-byte** archive dated **2017-10-26**. The distinct sizes establish that **the two full archives cannot be byte-identical**, but do not reveal the original 2017 member filenames or semantics.

## Read-only inspection of the *currently hosted* files

Both existing tracked archives were retrieved as base64 with the repository connector, decoded to a temporary audit directory, identified as 7-Zip containers, and read **without executing members** using `libarchive`. The table contains byte-accurate hashes from the actual tracked blobs.

| Existing repository archive | Hosted bytes | Hosted archive SHA-256 | Contained file(s) | Member bytes | Contained file SHA-256 | Embedded readable label |
|---|---:|---|---|---:|---|---|
| `.research/downloads/NOPAL_PATCH.7z` | **188** | `e07446f307cee99be54795d83bc1cf645def4c4aeba384aea474343ca0015d5d` | `PATCH_9.BIN` | **67** | `bdbf309adbb8a28a8af66f085a3a0f430efd2e9679668a7efd07c093b11b3fca` | **Unhook IGR's ELF LDR** |
| `.research/downloads/FORCEPAL_PATCH.7z` | **234** | `91f606681e071ccef3df66143a93573a578a811ce176de498eab96ea09130dab` | `$FORCEPAL_PATCH/PATCH_8.BIN` (plus an empty parent directory) | **64** | `1ebf6f579e7ba4f184fd1d10176e19b49820c2e36a405d79b7ef05e26767622a` | **Force PAL Patching** |

GitHub Git blob SHA values are `ac5f0043b8064302898cc8ab041deab3db5310b4` (NOPAL) and `3bd8797f56e20f7c8967a23780f6a1e43fe5208c` (FORCEPAL). Git blob hashes are not interchangeable with SHA-256 archive digests. Neither package contains a Sony emulator executable. This inspection is a **container/member metadata and string audit**, not a disassembly or console-functionality proof.

The original indexed Bitbucket listing shows:
- `NOPAL_PATCH.7z`: **226 B** uploaded **2017-10-26**; our hosted `NOPAL_PATCH.7z` is **188 B**. The difference is real beyond size-display rounding; exact original bytes are unavailable.
- `FORCEPAL_PATCH.7z`: **234 B** uploaded **2017-10-26**, same displayed size as the current hosted 234 B. **Equal size alone does not prove byte equality.**

## Version-scoped collision: PATCH_9.BIN has two documented meanings

1. An original **2014 krHACKen discussion** at [Metagames](https://www.metagames-eu.com/forums/playstation-2/popstarter-revision-13-a-134569.html) describes an *earlier* `PATCH_9.BIN` as disabling automatic PAL patching for PAL games previously patched to NTSC. It calls `PATCH_8.BIN` the reverse: forcing PAL patching. This is consistent with the original wiki's `NOPAL_PATCH.7z` / `FORCEPAL_PATCH.7z` links but **does not authenticate either present-day hosted package**.
2. On **2020-03-21**, [krHACKen explicitly supplied a `PATCH_9.7z` attachment](https://www.psx-place.com/threads/popstarter.19139/page-4) (listed size **188 B**) to disable POPStarter's buggy ELF loader and avoid IGR black screens. That **188-byte** attachment size matches the hosted `NOPAL_PATCH.7z` exactly; its described effect matches the hosted member's embedded **Unhook IGR's ELF LDR** label. The [existing POPSLoader thread-patches notes](../firstparty/thread-patches.md) already describe this loader-disabling use. **This is strong circumstantial evidence of a later PATCH_9 archive being stored under an older NOPAL archive name, but it is not SHA-256 proof that the forum attachment and the hosted bytes are identical.**

### Maintainer decision required before any publication change

- **Treat the current hosted `NOPAL_PATCH.7z` as NOT VERIFIED to implement `$NOPAL`.** Its member label and dated developer record strongly indicate the **2020 ELF-loader/IGR function**, whereas the 2017 original archive is *different in size* and unavailable.
- Avoid silently changing the patch file's basename or replacing it with another archive. Recover the authenticated **2017 226-byte** source, if allowed, and compare member lists, sizes and SHA-256.
- If approved separately, clarify the public `$NOPAL` instruction or redirect it to confirmed `$NOPAL` / config-byte `$42A` equivalents. Do **not** recommend the current hosted `NOPAL_PATCH.7z` as a verified PAL-mode disabling patch until this discrepancy is resolved.
- Keep the `PATCH_9.BIN` semantics **version-scoped**. A same-numbered patch is not proof of matching behavior across 2014–2020 releases; do not rely on filenames alone.

**Research-boundary reminder:** the draft PR deliberately **does not modify** `special-cheats.md`, `thread-patches.md`, `build_site.py`, the downloadable archives, or the published website. The underlying original Git clone does not embed either binary package.
