# Original POPStarter wiki Git clone: archival provenance

**Recovered and contributed by [AstroSnail](https://github.com/AstroSnail)** in the
PS2 Scene community, 2026-10-10. The original wiki and commit history were authored
by ShaolinAssassin and the original wiki contributors; provision of a copy is not
a claim to authorship.

## Identifiers (original ZIP, bytes unchanged)

| Field | Value |
|---|---|
| Original supplied file | `wiki.zip` |
| Published filename when supplied | `popstarter-documentation-stuff-wiki-git-20240731.zip` |
| ZIP size | 2,102,657 bytes |
| ZIP SHA-256 | `d0c243d91e417988825ed92b440224ed46cbbf448d0b67528e0957c15c0d029a` |
| Git HEAD | `960d675d278296a3a62143410b38aa8882d21a79` |
| Original remote | `https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff.git/wiki` |
| First / last commit (UTC) | 2016-04-11 / 2024-07-31 |
| Reachable commits | 2,140 |
| Current source pages | 61 Textile |
| Integrity | `git fsck --full --no-reflogs --strict` and ZIP CRC checks passed |

All **61** upstream current page basenames are represented in the existing **63**
Wayback-recovered Markdown pages. Name coverage does **not** imply historical
version or content parity. The Wayback recovery contains merged snapshot variants
that must not be overwritten indiscriminately.

This Git repository additionally preserves intermediate revisions, attribution,
renames, and historical deletions. Examples of material deleted by the original
project include `News.textile`, `Guides.textile`, `Batcher_outdated.textile`,
`11c. Threads (POPStarter around the web).textile`, `sample.md` and
`poop.textile` (a compatibility-fix list). Some were superseded or renamed;
they should be studied in their historical context, not silently reinstated
as current instructions.

## Distribution contract

Keep original bytes and original Git authorship intact; distribute the whole
repository as a separate source ZIP. To add it to the site's Downloads page,
place the unchanged archive under
`.research/downloads/popstarter-documentation-stuff-wiki-git-20240731.zip`.
The docs generator refuses a mismatched SHA-256 and does not render a card
if the archive is absent. With the file present, the full offline site archive
includes it automatically.

The ZIP includes historical Git author names and emails. A scan of 1,982 Git
blobs detected a single AWS-access-key-ID-shaped value in a **2016-expired
Bitbucket image URL**, not a private access key. Do not reproduce that value.
This historical source should not be merged into POPSLoader's Git commit graph
because of provenance integrity and possible secret-scanning false positives.
No Sony POPS emulator binaries were found in the source ZIP. This is not a
professional malware scan or a license grant.
