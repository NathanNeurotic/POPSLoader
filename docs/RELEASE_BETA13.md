# Releasing BETA-13 — ready-to-run cut runbook

> ⛔ **DO NOT RUN until the §1 hardware gate is green.** BETA-13 is gated on the in-flight
> hardware verification settling. This runbook is *staged* — when the gate clears, work top to bottom.
> Run everything from the **main repo** (`C:/Users/natha/Github/POPSLoader`), **not** a worktree.
>
> The cut is a **tree-adopting merge** (`-s ours` + `read-tree` + verify-empty-diff): `master` and
> the `*-PLAY` branch have diverged, so we record `BETA-13-PLAY` as a merge parent but take its tree
> wholesale. This is the exact pattern that produced BETA-12 (`af983d7`, whose tree is byte-identical
> to its PLAY parent `49ae2c7`) and BETA-11. _Archive this file after BETA-13 ships._

---

## 1. Preconditions — the hardware gate (must be green first)

CI-green ≠ hardware-confirmed (embedded Lua is bin2c'd into the ELF; runtime/load-order bugs are invisible
to `luac`/CI). Do **not** cut until these settle on a real PS2. Tester steps live in **`TESTING.md`**;
canonical status in **`STATE.md` > Reported Hardware Status**.

- [ ] **HDD (exFAT) / BDMA ATA (D-06 / D-06A)** — the flagship new backend, **never run on hardware**. Lists `mass:/POPS`, games launch, and the exFAT drive does **not** mis-classify as USB/MX4SIO. (`TESTING.md` P1)
- [ ] **PAL native 640×512** + **Auto** video default + display-change confirm/revert (U-06) — needs PAL hardware (team has none; recruit a PAL tester).
- [ ] **HDD-resident settings save / `.hide` (L3) / reveal (R3)** via the boot-partition RW take-over — provato confirmed the HDD is RW-writable; the **full save/reboot flow** still wants confirmation.
- [ ] **Eyeball items (believed working):** Overscan on a real CRT (S-14), cover-art `cover_default`+`cover_missing` registration on NTSC + PAL (U-16), description-scroll feel (U-15), HDD Proposal A (scan steered off the boot slot).
- [ ] **Open bug:** "Failed to load HDD" from a non-HDD / via-launcher boot — resolved, **or** explicitly accepted as a documented known-issue (BETA-12 shipped with documented known-broken items; the maintainer makes that call).
- [ ] **Preservation set still PASS** (must not have regressed): **D-10**, **D-14**, **D-15**, DKWDRV-from-MC, BOOT.ELF-from-USB-boot (L-07), **U-10**.
- [ ] **Latest `BETA-13-PLAY` rolling artifact** got a broad hardware pass (à la Nuno6573 2026-06-21).

## 2. Release-prep commits — on `BETA-13-PLAY` first

Mirror the BETA-12 prep commit (`49ae2c7 chore(release): set title.cfg…`). Do these on `BETA-13-PLAY`,
push, and let CI + Rolling go green **before** the cut.

- [ ] **`bin/POPSLDR/title.cfg`** (on-console launcher metadata):
  - `Title=POPSLoader Beta-12` → `Title=POPSLoader Beta-13`
  - `Version=1.0.0 Rev5` → `Version=1.0.0 Rev6` *(optional bump; keep in sync with `etc/boot.lua` below)*
  - `Release=June 18th, 2026` → the actual cut date
  - `Developer=…` → consider adding **saildot4k** (credited this cycle for BDMA-ATA) to the line
- [ ] **`etc/boot.lua`** — `POPSLDR_VER = "v1.0.0 - rev5"` → `"v1.0.0 - rev6"` *(optional; match `title.cfg` Version)*
- [ ] **`bin/changelog`** — add a `[Beta-13]` section: fold the current `[Unreleased]` items in and add this cycle's headline work — **HDD (exFAT)/BDMA-ATA backend**, the µs-as-ms timer sweep, Layer-C lazy-IRX decision (mmceman shipped / ds34-usbd declined), PAL-512 + Auto video, HDD-RW settings-save + `.hide`/R3, MC-folder toggle + BDMA interlock, overscan, layered cover art, nav rework + boot sound, game-list cache, multi-disc collapse, Boot Page, carousel visibility.
- [ ] **Doc version banners** — bump `Released line:` in **`STATE.md`** + **`QA_REGRESSION_MATRIX.md`**, and any version banner in **`README.md`** / **`AGENTS.md`**, from BETA-12 → BETA-13. *(The active dev branch + rolling source stay `BETA-13-PLAY`.)*

Commit, push to `BETA-13-PLAY`, confirm **CI + Rolling green**, and get one more rolling-artifact sanity pass if the prep touched anything runtime.

## 3. The cut — tree-adopting merge to `master`

```bash
# Run from the MAIN repo, NOT a worktree. §1 gate green + §2 prep merged & CI-green first.
set -euo pipefail

# 3.1  TRUE remote tips — local origin/* can be STALE (fetch-refspec trap hit at BETA-12).
git ls-remote origin refs/heads/master refs/heads/BETA-13-PLAY
git fetch origin master BETA-13-PLAY

# 3.2  Start from the REAL remote master, discarding any stale LOCAL merge
#      (e.g. the unpushed 949e670 "BETA-13 candidate" that adopted the pre-session tree).
git checkout master
git reset --hard origin/master

# 3.3  Tree-adopting merge: record BETA-13-PLAY as a 2nd parent, but take its tree wholesale.
git merge --no-commit -s ours origin/BETA-13-PLAY
git read-tree -u --reset origin/BETA-13-PLAY^{tree}    # index + worktree become PLAY's exact tree
git commit -m "Merge BETA-13-PLAY into master for the BETA-13 release"

# 3.4  VERIFY the adopted tree is byte-identical to BETA-13-PLAY. MUST be empty (exit 0). ABORT otherwise.
if git diff --quiet HEAD origin/BETA-13-PLAY; then
  echo "TREE MATCH ✓ — master carries the exact BETA-13-PLAY tree"
else
  echo "‼ TREE MISMATCH — DO NOT TAG OR PUSH. Inspect: git diff HEAD origin/BETA-13-PLAY"
  exit 1
fi
```

## 4. Tag, push, and publish

```bash
# 4.1  Tag + push atomically (only after §3.4 printed TREE MATCH).
git tag -a BETA-13 -m "Merge BETA-13-PLAY into master for the BETA-13 release"
git push origin master --follow-tags

# 4.2  GitHub release. Author notes from ROLLING_NOTES.md ("what's new since BETA-9/BETA-12").
gh release create BETA-13 --title "POPSLoader BETA-13" --notes-file <notes.md>
```

- **Release notes source:** `ROLLING_NOTES.md` is already the user-facing "what's new" list — distill it into the release body (lead with the HDD-exFAT/BDMA-ATA backend; credit kHn/POPStarter, ShaolinAssassin, R3Z3N, saildot4k, the testers).
- **Install zip:** there is **no automated install-zip attached to the release** (BETA-12 mechanics). The formal `PS1_POPSLOADER/*` zip + bare `POPSLOADER.ELF` are built by `compilation.yml` on the tagged commit — download from that CI run and attach to the GitHub release manually. (`POPS` engine binaries are **not** redistributable and are never bundled.)
- **`POPSTARTER.ELF`** (redistributable homebrew) ships in the zips per CI; POPS engine binaries do not.

## 5. Post-cut

- [ ] `BETA-13-PLAY` remains the active dev branch **and** the rolling-release source (`rolling-release.yml` unchanged).
- [ ] Confirm `STATE.md` / `QA_REGRESSION_MATRIX.md` / `README.md` `Released line` now read **BETA-13** (if not done in §2).
- [ ] Record the hardware-pass results that cleared §1 in `QA_REGRESSION_MATRIX.md` (run log) so the cut is auditable.
- [ ] Optionally cut the next safety checkpoint branch (e.g. `checkpoint/beta13-released-<date>`).
- [ ] Archive this runbook (`docs/archive/`) — it's BETA-13-specific.

---

### Why the guards matter (BETA-12/BETA-11 lessons)

- **Stale `origin/master`:** a fetch-refspec quirk left `origin/master` stale; trust `git ls-remote`, then `reset --hard origin/master`. (Right now local `master` even carries an **unpushed** `949e670` "BETA-13 candidate" merge that adopted the *pre-session* tree — §3.2 discards it.)
- **`-s ours` alone keeps the WRONG tree** (master's); the `read-tree` step is what swaps in the PLAY tree. The **verify-empty-diff** (§3.4) is the safety net — never tag/push without `TREE MATCH`.
- **No automated install-zip** on the GitHub release — attach the CI-built artifact by hand.
