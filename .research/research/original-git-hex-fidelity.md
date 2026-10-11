# Hexadecimal-notation source-fidelity audit

**Research only — do not mass-replace files in draft PR #578.** Compared all 63 recovered `.research/wiki/*.md` pages at base commit `15ffb1c7` with original wiki Git **HEAD** (`960d675d278296a3a62143410b38aa8882d21a79`), using the case-insensitive literal pattern `0×[0-9A-F]` (U+00D7 multiplication sign as a hexadecimal prefix). The correct hexadecimal prefix is ASCII `0x`. The scan counts **occurrences**, not distinct commands or lines.

| Recovered page | Invalid hex-prefix occurrences | At original source HEAD: invalid `0×` | At original source HEAD: ASCII `0x` |
|---|---:|---:|---:|
| `automated.md` | **630** | 0 | 323 |
| `compatibility.md` | **16** | 3 | 11 |
| `configuration-table.md` | **72** | 0 | 75 |
| `Game-Compatibility.md` | **19** | n/a (extra recovery page, no source HEAD counterpart) | n/a |
| `help.md` | **13** | 0 | 13 |
| `known-bugs.md` | **1** | 0 | 1 |
| `poc2-pops-00001-era.md` | **2** | 0 | 2 |
| `special-cheats.md` | **2** | 0 | 2 |
| `troubleshooting-games.md` | **73** | **72** | 1 |
| `version.md` | **26** | 0 | 34 |
| **TOTAL** | **854** | **75** (from two original HEAD files) | — |

The other **53 recovered wiki pages** contain no matches. All 61 original HEAD Textile pages together contain **75 malformed prefixes**: three in `compatibility.textile`, 72 in `troubleshooting-games.textile`. Thus the problem is **mixed provenance**:

- **Likely reconstruction/conversion defects:** the major expansions in `automated.md`, `configuration-table.md`, `help.md`, `known-bugs.md`, `poc2-pops-00001-era.md`, `special-cheats.md` and `version.md`. In these, the corresponding original HEAD sources use ASCII `0x` and do not contain the invalid prefix.
- **Historically inherited source defects:** at least some of `compatibility.md` and almost all of `troubleshooting-games.md` were already malformed in original source. Do **not** claim these were introduced exclusively by the Wayback conversion.
- **Unmatched recovery provenance:** `Game-Compatibility.md` has no source HEAD file of the same name; its 19 occurrences require tracing the particular archived snapshot or page version.
- **Snapshot merging and title differences:** occurrences must not be mathematically subtracted as if identical document revisions. For example `automated.md` merges several snapshots and therefore has many more mode mentions than the one original source HEAD.

### Reproduction

Run these standard Python snippets against an unchanged original wiki working tree and a checked-out POPSLoader base:

`python -c "import pathlib,re; a=list(pathlib.Path('.research/wiki').glob('*.md')); print([(p.name,len(re.findall('0×[0-9A-F]',p.read_text(errors='replace'),re.I))) for p in a if re.search('0×[0-9A-F]',p.read_text(errors='replace'),re.I)])"`

`python -c "import pathlib,re; a=list(pathlib.Path('/path/to/original/wiki').glob('*.textile')); print([(p.name,len(re.findall('0×[0-9A-F]',p.read_text(errors='replace'),re.I))) for p in a if re.search('0×[0-9A-F]',p.read_text(errors='replace'),re.I)])"`

Note: other Unicode substitutions (e.g. typographic multiplication in `3×16:9`) are legitimate and **must not** be blindly rewritten. A later remediation should target **hex prefixes only**, compare against the exact archival source revision, and distinguish faithful preservation from a corrected, clearly marked current-use representation. No changes to wiki text are made here.


**2026-10-10 verification update:** The generator **already normalizes** every `0×[hex digit]` to `0x[hex digit]` in `.research/build_site.py` (`render_md`, line 211). The published site therefore does **not** display the 854 literal raw-Markdown malformed prefixes; they remain a fidelity concern for the raw repository source, offline conversion and independent consumers. Do not conflate raw-count audit with rendered-site defects.
