## From the official thread — PATCH / TROJAN details

> Sourced from the [official psx-place POPStarter thread](https://www.psx-place.com/threads/popstarter.19139/).

- **`TROJAN_7.BIN` is krHACKen's final cumulative "goodbye" fix-pack** — it patches POPStarter **globally**
  (applied to all games), not per-game. Revision history runs **r6 → r7 (2020-05-20, "unhook code just fixed")**,
  *after* the final r13 / 2019-06-05 ELF, and is **not** merged into that ELF. Drop it at
  `hdd0:/__common/POPS/TROJAN_7.BIN` (or the POPS folder on USB). *(krHACKen / hugopocked)*
- **Do not stack `TROJAN_7` with HugoPocked's per-game fixes** — using both on a game HugoPocked already covers
  **adds** crashes. Use TROJAN_7 only on titles HugoPocked doesn't fix. *(hugopocked)*
- **The digit in a PATCH_#/TROJAN_# filename is a SLOT (0–9), not a version**, and POPStarter validates the
  number embedded in the file header against the filename — it **refuses to load on a mismatch**. So you can't
  just rename `TROJAN_7.BIN` → `TROJAN_0.BIN`; the header number must be hex-edited too. *(ShaolinAssassin)*
- **`PATCH_9.BIN`** has a specific documented use beyond the "disable PAL patcher" meaning: it **disables
  POPStarter's bugged internal ELF loader** to restore IGR on setups where exit black-screens
  (see [Troubleshooting](troubleshooting.html)). *(krHACKen)*
- **HugoPocked's per-game fixes install differently** from global TROJAN/PATCH BINs — you drop the fix files
  **into that game's VMC folder**. Thread:
  [HugoPocked fixes for POPStarter](https://www.psx-place.com/threads/hugopocked-fixes-for-popstarter.39750/).
