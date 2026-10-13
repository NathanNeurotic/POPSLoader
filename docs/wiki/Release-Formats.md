# POPSLoader Release Formats and Verification

## Development all-in-one ZIP

`PS1_POPSLOADER.zip` contains these three device-root trees: `APPS/`, `POPS/`, and `EMBER/`, plus a standalone `PS1_POPSLOADER.psu` inside the ZIP. `POPS/` copies the complete pinned RiptOPL support-file set, and `EMBER/` copies the independently pinned **unmodified** Ember release plus licence and a non-playable example game-folder layout. All other scripts, drivers and legacy assets must retain their upstream attribution. A missing source component is a packaging failure, not a reason to silently omit it.

`APPS/PS1_POPSLOADER/` contains **exactly**:

| Direct file | Purpose |
| --- | --- |
| `POPSLOADER.ELF` | Launcher executable |
| `POPSTARTER.ELF` | Companion launcher |
| `icon.sys` | PS2 save/browser metadata |
| `list.icn` | Main icon |
| `copy.icn` | Copy icon |
| `del.icn` | Delete icon |
| `title.cfg` | Launcher metadata |
| `APPINFO.PBT` | Application information |

No other files are put into that eight-file application directory.

## Flat memory-card PSU

`PS1_POPSLOADER.psu` uses the PS2 save-directory header **PS1_POPSLOADER**, plus the eight direct files above. There is **no nested `PS1_POPSLOADER/` folder** in the PSU. The PSU contains neither `POPS/` nor `EMBER/`; those are installed separately on your storage device. The package writer preserves RiptOPL-compatible PSU entry layout, timestamps and padding, and rejects data that would exceed an 8 MiB memory-card image.

CI verifies the PSU files against `APPS/PS1_POPSLOADER/` **byte-for-byte**, using both the Python parser and RiptOPL's preserved PSUManager C++ reader. It also checks the full ZIP, required Ember licence, pinned POPS/Ember source files, and accidental BIOS inclusion. Passing those checks does not prove the games launch or saves work on hardware.

## Channels and compatibility

- **Stable 1.2.3:** existing official package remains unchanged. New eight-file directory / PSU expectations must **not** be retroactively applied to that release.
- **Rolling development:** after PR #600 merges into `dev`, use the rolling tag's separate `.zip` and `.psu` assets, or the traditional combined source bundle.
- **Experimental:** isolated prerelease channel, built independently from `experimental`. The PR alone does not add these features to that branch; they must be explicitly integrated before advertising the experimental packages.
- **Official future release:** publish only from a separately reviewed, version-stamped source after compatibility disclosures and release gates are satisfied.

[View GitHub releases](https://github.com/NathanNeurotic/POPSLoader/releases) · [QA matrix](../../QA_REGRESSION_MATRIX.md)
