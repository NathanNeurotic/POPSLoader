# Pins — fresh clones 2026-11-13, github.com/NathanNeurotic, checked 10:03 PST

Clone root: ~/workspace/audit-clones-2026-11-13/

| Repo | Default branch | HEAD | HEAD date/subject | Tracked files | Remote branches | Tags |
|---|---|---|---|---|---|---|
| RiptOPL | rebuild/main | 677812185ac5aab96bf697f21919a5729307ec4a | 2026-11-13 09:30:03 -0800 "Check for Updates: stop keeping a .BAK backup of the old ELF" | 2380 | 273 | 5: rolling-incebtion, rolling-korium, rolling-lite, rolling-llvm, rolling-ra |
| Launchstation | master | 8cd3329a98c09a570bfbf60137717edd42324990 | 2026-11-13 09:19:42 -0800 "Updater: stop making a .BAK of the old ELF" | 1065 | 104 | 140 |
| POPSLoader | master | 29272cddbf0122f14e76bc3bdd75e3b46aa870be | 2026-11-12 16:55:47 -0800 "Docs: credit Ember and the translators on the site; RiptOPL links (#639)" | 609 | 37 | 37 |
| Simple-Media-System | master | b9a5c882d6d632914faa4ff8dc080f1ecd51bfd7 | 2026-11-13 05:56:38 -0800 "Docs site: softer dark-gray colour scheme (#67)" | 1012 | 50 | 13 |
| PS2-Servers | main | 5179b4bb1f488ef2eb91956c8792e2194dda2fca | 2026-11-13 09:04:41 -0800 "Docs site: softer dark-gray colour scheme (#314)" | 596 | 159 | 118 |

Full remote branch/tag lists: recorded in audit working notes via `git branch -r` / `git tag` at clone time (see repo .git). Notable patterns already visible (Category 7, to verify in per-repo pass):
- RiptOPL: ~200+ claude/project-thread-* branches.
- Launchstation: 140 tags incl. ~70 sequential build-10xx/build-11xx tags, many preview-* tags.
- PS2-Servers: 159 branches incl. many backup/* branches, 118 tags incl. ~70 main-<n>-<hash> tags.
- POPSLoader: tags incl. backup/*, checkpoint/* style names; branches incl. BETA-*, CHECKPOINT2, checkpoint-*.
- Simple-Media-System: 50 branches incl. checkpoint-2026-07-*, pre-*-checkpoint.

Extension counts (tracked, top): RiptOPL 688 h / 388 c / 318 py (mostly .github/scripts tests) / 133 cpp / 54 irx / 13 ELF; Launchstation 241 c / 234 py / 208 h; POPSLoader 162 md / 123 png / 38 jpg+38 JPG / 21 irx / 13 zip / 9 7z / 5 ELF; SMS 188 h / 171 c / 146 png / 94 py / 24 xz / 19 irx / 5 .o tracked; PS2-Servers 242 py / 86 go / 58 c / 51 h / 6 chd.
