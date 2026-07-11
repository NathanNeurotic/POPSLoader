# Translating POPSLoader

Thanks for helping translate POPSLoader. This folder is the home for community language work.

## How the localization works

Every piece of on-screen text is translated at draw time. The app keeps a table of
`English -> your language` strings; anything not in the table simply stays English. That means
a partial translation is completely safe: whatever you translate shows up, and anything you skip
falls back to English. Paths, filenames, and numbers pass through untouched.

The strings themselves live compiled into the program (in `bin/POPSLDR/system.lua`, the `PLDR.I18N`
table). You do **not** need to edit that file. Instead you fill in a simple two-column list, and the
maintainer wires it into the build for you (adding your language to the picker under
`Settings > Startup > Language` and handling all the code plumbing).

## To add or fix a language

1. Open the `.tsv` for your language in a spreadsheet program (Excel, LibreOffice, Google Sheets) or
   any plain-text editor. If your language does not have a file yet, ask and one will be generated, or
   copy `hungarian.tsv` as a starting point.
2. The **left column is the English text** (leave it alone; it is the reference). Replace the **right
   column** with your translation for each row. The right column starts pre-filled with the English so
   you can see the context and overwrite it.
3. Leave these **as-is** (do not translate them):
   - Technical and filesystem names: `exFAT`, `FAT32`, `APA`, `PFS`, `BDMA`, `SMB`, `MX4SIO`, `MMCE`,
     `DKWDRV`, `POPStarter`, `OSDSYS`, `BOOT.ELF`, device names, and similar.
   - Numbers, sizes, and speed labels (`100M Full`, `10M Half`, and the like).
   - Anything that looks like a path or a filename.
4. Keep any `\n` exactly where it is. It means "line break" in a two-line message; just leave the two
   characters `\n` in place and translate the words around them.
5. Send the finished file back to the maintainer (reply with it on Discord, or open a pull request that
   adds/updates the file in this folder). The maintainer injects it and it ships in the next build.

## Notes

- The existing French, German, Portuguese, Spanish, and Italian translations were machine-assisted, so
  corrections from native speakers are very welcome too. Same process: edit the right column.
- You do not have to translate everything at once. A partial file is fine and still helps.
