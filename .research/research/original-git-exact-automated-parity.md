# Exact original automated-fix row parity (original final Git revision versus recovered wiki)

**Source:** AstroSnail-supplied original Bitbucket Git wiki `automated.textile` at HEAD `960d675d278296a3a62143410b38aa8882d21a79` (2024-07-31). **Comparator:** POPSLoader `.research/wiki/automated.md` from `master` at `15ffb1c7c46e1643ab2869baf1b26718cf53a604`. This is a **read-only 2026-10-10 analysis** under draft PR #578; no pages or binaries imported.

## Result: all 641 original final-revision entries preserved, plus four attributed 2017-only entries

| Original original HEAD section | Source items | Recovered matching items | Recovered additional dated items | Canonical SHA-256 |
|---|---:|---:|---:|---|
| Automatic compatibility modes | **309** | **309** | **4** (2017-only, labelled) | `fc8f86bed695f79eba2de31225eb85284df7578bc49d8236228d9ebcc4ffa3cf` |
| Auto-applied LibCrypt fixes | **223** | **223** | 0 | `03f8b3d4e3ba7eef2a49cd9106b6cda77eab9ff9574aa5e3b3c7fcac691acfcb` |
| Miscellaneous fixes, auto-applied | **109** | **109** | 0 | `be702918ea096d36bb5644baebe13d6cd70a1f12e1cb6d853b6083fe27e9a638` |
| **Total** | **641** | **641** | **4** | Each of the three source/recovered SHA-256 pairs matched. |

The SHA-256 digests were independently calculated on the original extracted Git source with Python `hashlib` and on the exact recovered GitHub file using a SHA-256 implementation checked against the standard `abc` test vector. The comparison uses **complete list-entry text**, not merely a disc ID or a fix category. **All duplicate rows count separately** (e.g. the repeated Akumajou Dracula v1.2 entry).

### Four additional 2017-era mode-0x06 entries (preserved by recovery, no counterpart in final Git HEAD)

- `Dance Dance Revolution: Disney's Rave (SLPM-86667) : $COMPATIBILITY_0x06`
- `Dance Dance Revolution: Disney's Rave (SLPM-86667, R18) : $COMPATIBILITY_0x06`
- `DonPachi (SLPS-00548) : $COMPATIBILITY_0x06`
- `Tobal 2 v1.1 (SLPM-86033) : $COMPATIBILITY_0x06`

Each is explicitly suffixed with `*(from 2017 snapshot)*` in recovered Markdown. They are **historical observations**, not necessarily current performance guidance.

## Exact normalization and comparison

1. Select the three original `h3.` sections in `automated.textile` from the original source HEAD. Retain the text of every original `* ` list item without paraphrasing.
2. Select the equivalent three `### *...*` sections in recovered `automated.md` and retain every `- ` list item.
3. For recovered text, normalize only the typographic multiplication sign to ASCII `x` (so commands such as `0×04` compare as `0x04`). Trim outer whitespace.
4. Separate only **four explicit 2017-snapshot-labelled items** from the compatibility-mode section. Do not silently omit any other differing items.
5. Sort the complete rows lexically, preserving duplicates, join with LF newline, encode UTF-8, compute SHA-256 and **also** compare `Counter` multiplicities. Each source and recovered digest is identical.

To reproduce after extracting the original ZIP:

`python3 .research/tools/audit_original_automated_parity.py /path/to/original/wiki/automated.textile .research/wiki/automated.md`

The script is read-only and fails when any source row is missing, altered, duplicated unexpectedly, or when any unexpected extra row is present.

## Scope and limitations

**This closes exact final-revision game-entry equivalence for the entire 641-row automated reference.** It includes every game's title, version, disc number/ID, and complete named automatic modes/fixes as a row. It does **not** prove runtime/hardware correctness, describe which algorithm implements the fixes, confirm every earlier **historical revision** is fully preserved, or establish semantic equivalence of prose and changelog paragraphs outside the three lists. The manually installed TROJAN/fix table is a **separate** page/class already inventoried elsewhere in the ledger. It would be a mistake to replace this merged reconstruction with the original 2024 HEAD; doing so would lose the four extra historically attributed mode-0x06 entries.

### Website rendering already mitigates two source defects

The source `.research/wiki/automated.md` contains typographic `0×` literals; `build_site.py:211` normalizes such prefixes to ASCII `0x` **at render time**. The builder's `rewrite_and_clean` function (`build_site.py:170–172`) **also strips pseudo Git-commit anchors, retaining the literal linked value**. Live `wiki/automated.html` shows `COMPATIBILITY_0x04` and live `wiki/cheat-engine.html` shows `add $01000000` with no spurious commit link. Thus the **raw Markdown remains less portable/faithful than the generated website**, but these two defects are **not confirmed present in rendered public pages**. Avoid describing 854 raw `0×` instances and 30 pseudo-commit links as 884 live website failures.

**PR policy:** research only; no actual wiki-content overwrites, license-sensitive redistribution, runtime edits, or merge.


## Historical 2017 WIP06 OBT17 — full row-level preservation proof

Original source commit `a005d6274eb845b6307fcdb1bad4a20b2a5f9d57` (2017-07-15), page `automated.textile`. Its first `h2.` section is titled **Fixes integrated into POPStarter Revision 13 WIP 06, OBT 17**. It contains **497** complete `* ` game/fix rows covering **460 distinct disc IDs**. The separate `## Changelog / version history (from the 2017-06-29 snapshot)` section in our current `.research/wiki/automated.md` contains **497** historical `- ` rows, with **the exact same normalized full row multiset and all 460 distinct disc IDs**.

Applied **only** Unicode NFKC normalization, multiplication sign `×` → ASCII `x`, typographic en/em dash → hyphen, curly apostrophe → straight apostrophe, and whitespace collapsing. Retained full titles, disc/region identifiers, release-version labels, fix descriptions, row multiplicity and variants. Sorting normalized rows and SHA-256 hashing LF-delimited UTF-8 text returned the *same digest on both sides*:

`d2449e7d75be69e25464ad159a06b0763c718299413d425c82aa5c2db39e2754`

The source data was read directly from the unmodified original Git clone via `git show`, and the recovered file was read directly from GitHub. The digest was verified by Python `hashlib.sha256` and an independently tested JS SHA-256 implementation. The new [`audit_original_wip06_2017.py`](../tools/audit_original_wip06_2017.py) is a read-only local comparator using Python `Counter` and SHA-256, and was syntax-checked and positive/negative-tested: deliberately removing one record caused `DIFF` and a nonzero exit status.

This **closes exact entry preservation for the 2017 WIP06 OBT17 497-row list**, in addition to the previously proven 641 rows in the original **2024 Git HEAD**. It does **not** prove that all intermediate revisions, changelog prose or real game compatibility are preserved, and should not be added to 641 as a count of unique games: the two lists overlap extensively.
