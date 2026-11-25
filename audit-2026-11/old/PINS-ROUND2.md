# Round 2 pins — checked live 2026-11-14 09:05-09:10 PST

Clones updated in place (fetch + checkout of default branch origin head, in OUR clones only; repos on GitHub untouched, clones verified clean before checkout).

| Repo | Round-1 pin | Round-2 HEAD | Commits between | Delta summary |
|---|---|---|---|---|
| RiptOPL | 677812185ac5 | 2e347d5ac885cd0ff73e9ad4143781946396f492 (rebuild/main) | 3 | #420 smb1 VMC share fix; #419 IGR interrupt hold; #417 "Update ELF in place and fix file manager card rename" (src/ui/selfupdate.cpp −196/+~ lines reworked, src/core/filemgr.cpp +37); 17 files, +331/−209 |
| Launchstation | 8cd3329a98c0 | 9fb0598a79f09b4ff06fdc3078ab26c38d7f4790 (master) | 3 | #384 "Check for Updates: write the verified ELF straight over the running one" (14 files, +424/−526, self-update tests reworked); #385/#386 docs palette only |
| POPSLoader | 29272cddbf01 | 29272cddbf01 (master) | 0 | unchanged |
| Simple-Media-System | b9a5c882d6d6 | e65ced39a27eee8d996e9257e21594d1cac1c93d (master) | 2 | docs palette only (6 files, CSS) — no code delta |
| PS2-Servers | 5179b4bb1f48 | c5f021c4d38698860f56b03498adc261dbb8d8dd (main) | 2 | docs palette only (2 files) — no code delta |

Revalidation duties created by the delta:
- LAUNCHSTATION-017 (self-update holds a whole second ELF in RAM): MUST be re-read at the new head — #384's in-place write may have fixed or changed it.
- RiptOPL findings touching src/ui/selfupdate.cpp, src/core/filemgr.cpp, smb1/VMC, IGR: MUST be re-read at the new head.
- All other pass-1 findings: code trees unchanged in SMS/PS2-Servers/POPSLoader (docs CSS only / no commits), and spot-revalidation suffices in RiptOPL/Launchstation outside the delta files.
- Meta-observation for SUMMARY: all four moved repos received style/docs-palette commits, two of them the *same* docs change fanned out per repo — the docs-site duplication (X-02) is not static, it is actively consuming commits in every repo.
