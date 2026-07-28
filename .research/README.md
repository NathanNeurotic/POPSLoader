# POPStarter docs site — source

This directory builds <https://nathanneurotic.github.io/POPSLoader/>, published from the
`gh-pages` branch. It is the recovered POPStarter documentation archive (the Bitbucket
wiki, rescued via the Wayback Machine) plus mirrors of this repo's own markdown.

## Rebuild

```
cd .research
python build_site.py     # clean-rebuilds .research/site/ (~246 files)
python audit_site.py     # must print TOTAL ISSUES: 0
```

`build_site.py` reads this repo's markdown for the `popsloader/*.html` mirrors, taking
the checkout it lives in by default. To build the mirrors from a different working tree
(a worktree, another branch) point it there:

```
POPSLOADER_REPO=/path/to/a/POPSLoader/checkout python build_site.py
```

Requires `python-markdown`. No other dependency.

## Deploy

Copy `site/*` **over** a `gh-pages` worktree and push. Overlay, never delete-then-copy.

```
git worktree add ../ghp origin/gh-pages
cp -r site/* ../ghp/          # .nojekyll is emitted by build_site.py; keep it
cd ../ghp && git add -A && git commit && git push origin HEAD:gh-pages
```

## What is tracked, and why

The generator and the corpus it reads are tracked; the research scratch is not. See the
`.research/` block in `.gitignore` for the exact list. A clean-room rebuild from only the
tracked files was verified to reproduce all 246 published files byte-for-byte (the
archive `.zip` differs only because zips embed timestamps).

`_html/` (the raw Wayback snapshots) is deliberately NOT tracked. 186 of its 526 files
carry an AWS-key-shaped token, two apiece, which is archive.org wrapper boilerplate
rather than any POPStarter secret, but GitHub push protection refuses credential-shaped
data in a public repo and bypassing that is not the answer. The only thing the build
took from those files was the per-page image galleries, which are now pre-extracted to
`_state/galleries.json`. Building WITH `_html/` present refreshes that cache; building
without it serves the cache. Both produce the same site, verified byte-for-byte.

Do not add a new input directory without either tracking it or confirming the build
still reproduces the site without it. `page_gallery()` is the cautionary tale: it
returns an empty string when its input is missing, so an untracked input degrades the
site silently instead of failing loudly.

## Two halves, different rules

- `popsloader/*.html` **mirror this repo's markdown** and are regenerated. Never hand-edit
  them; fix the markdown and rebuild.
- The top-level pages (`storage.html`, `known-issues.html`, `config.html`, …) are
  **authored inside `build_site.py`**. Fixing a fact on those means editing the generator.
- `wiki/*.html` is an **archival record of someone else's project**. Its historical content
  is not ours to correct. Only link and asset integrity are our problem.

## Known traps

- `audit_site.py` validates relative links only; it returns true for every `http(s)` href.
  A hardcoded GitHub branch that no longer exists will sail straight past it — that is how
  15 dead `blob/BETA-13-PLAY/` links shipped.
- `dl_note()` matches download descriptions by **substring** and is shared with
  `build_dl_manifest()`. Card copy uses the exact-filename `DL_CARD_NOTES` map instead;
  do not fold new card text back into `DL_NOTES`.
- Any hosted download missing from `DL_GROUPS` renders under a visible "Uncategorised"
  heading and prints a build warning. It is never silently dropped.
