# POPSLoader BETA-8 Regression Matrix

Last updated: 2026-03-06
Target branch: `codex/beta8-hardening`

## Scope
This checklist covers:
- settings boot/load/save/apply correctness,
- USB/MX4SIO/MMCE/HDD launch surfaces,
- `mc0:/` / `mc1:/` / `mc?:/` path resolution,
- sidecar cover-art behavior,
- missing dependency and backend-unavailable error feedback.

## Test Matrix
| ID | Area | Setup | Action | Pass Criteria |
|---|---|---|---|---|
| S-01 | Settings boot defaults | Remove `mc0:/POPSTARTER/.pldrs` and reboot | Open Settings | BDMA, profile, POPStarter path, DKWDRV path show defaults; no crash |
| S-02 | Settings boot persisted FAT32 | Save BDMA as FAT32, reboot | Open Settings | BDMA row shows FAT32 and matches active runtime behavior |
| S-03 | Settings boot persisted EXFAT | Save BDMA as EXFAT, reboot | Open Settings | BDMA row shows EXFAT and matches effective runtime state |
| S-04 | Settings boot persisted MX4SIO | Save BDMA as MX4SIO, reboot | Open Settings | BDMA row shows MX4SIO and matches effective runtime state |
| S-05 | Settings boot persisted MMCE | Save BDMA as MMCE, reboot | Open Settings | BDMA row shows MMCE and matches effective runtime state |
| S-06 | Settings staging | Enter Settings and change rows without leaving | Hard reboot app before leaving | Changes are not persisted; old settings remain |
| S-07 | Settings commit | Change BDMA/profile/paths then confirm/leave | Reopen Settings | Changes persist only after leave/confirm |
| S-08 | Settings save failure | Make `mc0:/POPSTARTER` unwritable/unavailable | Leave Settings with changes | User sees save/apply error; dirty state is not falsely cleared |
| S-09 | Save/apply UX | Change BDMA and leave Settings | Observe UI during commit | Saving/applying overlay is visible and clears on success/failure |
| L-01 | POPStarter path missing | Set POPStarter path to nonexistent ELF | Launch any game | Launch is blocked with explicit "Cant find POPSTARTER ELF" notice |
| L-02 | DKWDRV path missing | Set DKWDRV path to nonexistent ELF | Open Disc (DKWDRV) and confirm | Launch is blocked with explicit "Cant find DKWDRV ELF" notice |
| L-03 | `mc?:/` POPStarter alias (`mc0`) | Put POPSTARTER only on `mc0:/` and set `mc?:/` path | Launch game | Launch succeeds by resolving `mc0:/` |
| L-04 | `mc?:/` POPStarter alias (`mc1`) | Put POPSTARTER only on `mc1:/` and set `mc?:/` path | Launch game | Launch succeeds by resolving `mc1:/` |
| L-05 | `mc?:/` DKWDRV alias | Put DKWDRV only on `mc1:/` and set `mc?:/` path | Launch DKWDRV | DKWDRV launch resolves `mc1:/` and succeeds |
| L-06 | `mc?:/` alias missing both cards | Set POPStarter/DKWDRV to `mc?:/` with no target file | Launch game / DKWDRV | Explicit missing-path notification is shown; no silent fail |
| D-01 | USB backend unavailable | Boot with no USB mass backend present | Enter USB page | User gets explicit "No USB backend found" notification |
| D-02 | MX4SIO first entry | MX4SIO inserted | Enter MX4SIO page once | No manual second entry needed; game list/root probe succeeds or clear failure message appears |
| D-03 | MX4SIO absent | No MX4SIO inserted | Enter MX4SIO page | User gets explicit "No MX4SIO device found" notification |
| D-04 | MMCE absent | No MMCE in slot 0/1 | Enter MMCE page | User gets explicit MMCE-not-found notification |
| D-05 | HDD unavailable | No usable HDD | Enter HDD page | User sees explicit HDD error notification |
| C-01 | Cover sidecar present | Place `Game.png` beside `Game.VCD` on active root | Highlight that game | Cover preview shows sidecar image |
| C-02 | Cover sidecar missing | Remove sidecar PNG | Highlight game and move selection repeatedly | No repeated spam; UI remains responsive; fallback preview behavior is stable |
| C-03 | Multi-root sidecar derivation | Build entries on `mass:/`, `mass1:/`, `mmce0:/`, `pfs0:/` | Highlight each game | Cover lookup derives from selected resolved VCD path (`.VCD -> .png`) with no backend-specific art rules |
| U-01 | Hide text toggle | Any allowed browsing scene | Press Select twice | Auxiliary text hides/shows; icons and controls remain functional |
| U-02 | Hide text exclusions | Splash, Credits, Settings, game list text | Press Select where applicable | Excluded scenes remain unaffected; game list text remains visible |

## Run Notes Template
Use this template for each hardware run:

| Date | Console | Storage setup | Matrix IDs run | Result |
|---|---|---|---|---|
| YYYY-MM-DD | SCPH-xxxxx | USB/MMCE/MX4SIO/HDD details | e.g. S-01,S-02,D-02,C-01 | PASS/FAIL + short notes |

