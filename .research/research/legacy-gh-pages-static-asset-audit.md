# Pages-only sidecars and the competing archive writer — integrity review (2026-10-11)

**Scope:** audit of POPSLoader `master`/`dev` generator and published `gh-pages` after the [orb-regression fix PR #583](https://github.com/NathanNeurotic/POPSLoader/pull/583). This is preservation and publishing policy, not approval of binary safety, original provenance, or game compatibility.

## Two source owners

- The generated site had a SHA-256 manifest for **254** site files, including current JS/CSS, the page HTML, and generated **`popstarter-docs-archive.zip`**. The docs workflow rebuilds and overlays them.
- A separate, **20-file `gh-pages`-only set** was outside the generator. See the [exact filename, size and Git blob ID inventory](legacy-gh-pages-inventory.tsv). Git blob SHA-1 pins **today's served bytes** but does not prove historical authorship or malware safety.
- Because the deployment overlays and never previously deleted files, some old files survived as orphaned direct URLs even when the generator's Downloads page said a file was **Withheld** or did not mention it. The generated ZIP does **not automatically** include all Pages-only orphaned files.

## Three source-confirmed retirements

| Previous `gh-pages` path | Why it must not remain a standalone publisher |
|---|---|
| `downloads/DISCS_POOPER.BAT.7z` | Generator `EXCLUDE_DL` and catalog classify DISCS_POOPER files as **Withheld**. Despite that policy, the old direct-only archive still existed, making the file reachable by a guessed URL. This change retires the direct copy without denying that the historical file existed. |
| `.github/workflows/rebuild-popstarter-offline.yml` | The old, Pages-only workflow independently **rewrote the generator-owned offline ZIP** following certain `gh-pages` pushes, conflicting with the new source-of-truth manifest. It also explicitly added `DISCS_POOPER.BAT.7z` to the ZIP's required input set. Retire this competing publisher. |
| `.github/scripts/rebuild_offline_archive.py` | Standalone helper only for the retired workflow; source remains retrievable in earlier Git history. No other workflow depends on this file in this audit. |

No `Disc_Combining_Kits.7z` or Sony `POPS` executable file was imported.

The **17 remaining Pages-only files are preserved exactly**: historical `.7z` sidecars, checksum and security notice texts, and the root favicon. They are **not** automatically added to the generated official Downloads page or offline ZIP; some lack sufficient provenance or are categorically excluded. Their current identities are tracked in the manifest and must be reconciled through source review before mutation.

## New publish-time invariants

1. On each Pages publish, **check the preexisting 254-file generated manifest**, then independently check all 20 inventoried historical sidecars. No missing/modified preserved file and no *unknown* untracked Pages-only file are accepted.
2. Remove **only** the three explicitly source-authorized retired paths, after verifying they match the previously recorded exact Git blob identity. If any retired file has changed since inventory, fail instead of blindly deleting it.
3. Newly deleted source-generated pages are now explicitly pruned **only if owned by the old generated manifest**; no orphaned stale generated page can silently survive a source deletion.
4. Overlay the newly generated site, update the generated manifest, and recheck all 17 preserved legacy file hashes and absence of the three retired paths.
5. CI tests the sidecar guard against deletion, tampering, untracked new files and policy retirement; it also **decompresses the generated offline ZIP** and checks that no withheld filenames entered its archive-member list. Existing orb tests and source/build JS/CSS equality are retained.

**Review boundary:** This is a targeted structural preservation fix. The historic sidecar identities are explicitly protected, while importing all their bytes into `.research/downloads/` or reissuing them in the generated ZIP requires a separate safe-content and rights review. The standalone offline ZIP is described as the complete **generated** documentation bundle, not as a container for every older direct-only `gh-pages` asset.

CI results and live deployment should be checked after merge/sync to `dev`; this document alone does not claim successful publication.
