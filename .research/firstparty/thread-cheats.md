## From the official thread — cheat clarifications

> Sourced from the [official psx-place POPStarter thread](https://www.psx-place.com/threads/popstarter.19139/);
> items marked **krHACKen** are from POPStarter's author and are authoritative.

- **`CHEATS.TXT` must be UPPERCASE.** A `CHEATS.txt` is silently ignored on internal HDD/PFS (case-sensitive),
  even though SMB is tolerant — this is the real root cause behind many "my cheat / `$HDTVFIX` does nothing on
  HDD" reports. In uLaunchELF press **R1** to rename `CHEATS.txt` → `CHEATS.TXT`. *(krHACKen / jolek)*
- **`$SAFEMODE` is ONLY for raw hexadecimal (GameShark/Action-Replay) codes** — the built-in named `$`
  commands (`$IGR#`, `$NOPAL`, `$NOIGR`, `$WIDESCREEN`, …) do **not** need it. Leading every file with
  `$SAFEMODE` is harmless but unnecessary for named commands. *(krHACKen)*
- **`$IGR5` is the OPL-style In-Game-Reset** — combo **Select + Start + L1 + L2 + R1 + R2**, with **no
  YES/NO exit popup**. This is the variant most people actually want for a clean, OPL-like instant exit.
  *(krHACKen)*
- **Raw codes:** put them in `CHEATS.TXT` in the game's VMC folder, prefix **every** code line with `$`, and
  lead the file with `$SAFEMODE`. Some unusual code types simply won't work or will crash the emulation.
  *(krHACKen, hand-correcting a user's syntax)*
