# Okeanos DISCS_DIR Lists Design

## Intent

Issue #615 tracks current Okeanos Assault assets. POPSLoader already embeds UDPFS Assault 1.0.1, so this change supplies the separate current directory lists needed by its optional `DISCS_DIR` feature.

## Approved scope

- Ship both Okeanos lists: multi-disc-only and all-games.
- Package them as `POPS/DISCS_DIR.MULTI.TXT.example` and `POPS/DISCS_DIR.ALL.TXT.example`.
- The user copies exactly one to `POPS/DISCS_DIR.TXT` and enables `DISCS_DIR=1` in `PATHMAP.INI`.
- Do not ship an active `DISCS_DIR.TXT`, change folder behavior by default, or change the Assault modules.
- Include immutable source revision, hashes, upstream instructions, and the CC BY-SA 4.0 license.

## Source

`Okeanos86/popstarter-dir-lists` commit `b8256b0ac1311c7dd8acb6f4e8f93e8429fc2bf3` (2026-11-08).

## Approaches considered

- Multi-disc-only: smallest, but the user chose both lists.
- All-games-only: covers more rows, but loses the focused multi-disc choice.
- Both as opt-in examples: approved; slightly larger kit, no runtime behavior change unless explicitly enabled.

## Verification

Verify pinned bytes and hashes, both example files in the release ZIP, accompanying notices, and absence of an active `DISCS_DIR.TXT`. Hardware behavior remains unverified.
