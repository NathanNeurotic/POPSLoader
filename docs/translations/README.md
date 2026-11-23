# Translating POPSLoader

Community translations live in this folder. English is the source language. The
runtime dictionaries are embedded in `bin/POPSLDR/system.lua` under `PLDR.I18N`.
Unlisted strings fall back to English.

## Slovak contribution (#605)

[SVKghost](https://github.com/SVKghost) translated POPSLoader into Slovak. The
returned workbook (November 12, 2026) covered all 409 strings; it now ships as
`PLDR.I18N.SK` and appears in the language picker as **Slovenčina**.
[slovak.tsv](slovak.tsv) keeps the contributed text.

Two maintainer edits were made on import, pending SVKghost's confirmation:

- The credits block in the returned file stopped after "uyjulian, fjtrujy,". The
  last five lines were completed in Slovak, and two stray `n` letters after line
  breaks were removed.
- One extra line break in the Games-path hint was removed so it keeps the same
  line count as English.

The empty template for new languages is still [slovak.xlsx](slovak.xlsx?raw=true)
(the **Slovak** sheet name is what the importer reads). Excel can trim a leading
space from a cell; the importer restores it for keys that start with one.

## Translation rules

1. Leave the English column unchanged. Translate only the target column. Leave
   unknown translations blank; blank cells are omitted on import and retain the
   English fallback. Do not fill them with English merely to mark them complete.
2. Keep every format placeholder (`%s`, `%d`, `%%`) exactly and in the same order.
   `%s` inserts text such as a path or error; `%d` inserts a number. Lua's formatter
   does not support positional forms such as `%1$s`.
3. Keep literal `\n` line-break markers and any leading space. Do not use Alt+Enter
   inside a cell. TSV records occupy one physical line each.
4. Keep names, handles, URLs, paths, filenames and technical names unchanged:
   `POPSLoader`, `POPStarter`, `POPSTARTER`, `Ember`, `DKWDRV`, `OSDSYS`, `BDMA`,
   `SMB`, `UDPFS`, `MX4SIO`, `MMCE`, `APA`, `PFS`, `exFAT`, `FAT32`, device names
   such as `mc0:`, and extensions such as `.VCD`. Keep network speed/duplex labels
   such as `100M Full`. Translate the surrounding explanation.
5. Use natural spelling and accents, including Slovak diacritics. Keep text concise
   enough for the PS2 interface. Row notes explain ambiguous meanings: **Resolved:**
   describes a resolved file path; **multi-disc collapsed** describes extra disc
   entries combined under the first disc.
6. Ember's **Unchanged** preserves a native setting. **Default** removes an override.
   **Default (global)** inherits the global setting. Native values such as `auto`,
   `ntsc`, `pal`, `on`, `off` and `d2a` stay unchanged.

## Existing language corrections

- [hungarian.tsv](hungarian.tsv) retains the contributed Hungarian translations.
- [brazilian-portuguese.tsv](brazilian-portuguese.tsv) retains the prior Portuguese
  handoff, including its existing regional edits. Its base is the current `PT`
  dictionary; Brazilian wording corrections remain welcome. The ABNT keyboard
  layout is available separately from UI language.

Both handoffs use the same current English inventory as the Slovak template.
Existing target text is preserved; new untranslated rows are blank. Obsolete rows
have been removed. The French, German, Portuguese, Spanish and Italian runtime
translations were machine-assisted and also welcome native-speaker corrections.

## Maintainer validation and integration

Run the checks from the repository root (Python standard library only):

```sh
python tools/translation_handoff.py
python -m unittest discover -s tools -p test_translation_handoff.py
python tools/docs_verify.py
```

The checker compares live source keys with the handoffs, detects runtime duplicate
keys, and validates placeholders, line breaks, duplicate/edited English keys and
the Excel/TSV key sets. It is called by the existing CI documentation gate.
When source text changes, review new UI literals as well as dictionary keys and
explicit `PLDR.L` / `PLDR.LFmt` calls; static string scanning cannot prove every
indirect display path is translated.

Convert a returned workbook or TSV to a **reviewable Lua table**, without editing
the application automatically:

```sh
python tools/translation_handoff.py --import-file returned.xlsx --language SK --output slovak.lua
```

The importer reads text cells only, rejects formulas and non-text target cells,
and omits blank translations. Review wording and retain the contributor's credit.
Then integrate `PLDR.I18N.SK`, add `SK` / `Slovenčina` to `PLDR.LANGUAGE_ORDER` and
`PLDR.LANGUAGE_NAMES`, check normalization and settings persistence, and exercise
all new strings at their actual display sites. New composite messages must
translate their parts before concatenation or use `PLDR.LFmt` before substituting
paths and numbers. Handoff files are not build inputs.

Run the host harness and canonical GitHub Actions build. Finally check Slovak
diacritics, menu/dialog fit, credits and saved language selection on PS2, recording
results in `QA_REGRESSION_MATRIX.md`. Host checks do not establish console rendering.
