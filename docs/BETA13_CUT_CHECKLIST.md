# BETA-13 cut gate — hardware pass checklist

**This is the hardware gate for cutting BETA-13.** Tick items as you confirm them on a real PS2. The staged cut runbook lives in [`RELEASE_BETA13.md`](RELEASE_BETA13.md); the release-prep commits (title.cfg, changelog, version banners) are staged on branch `claude/beta13-release-prep`, ready to merge the moment this gate is green. Canonical status: [`STATE.md` > Reported Hardware Status](../STATE.md).

## The one call that sets the bar

- **Option A** (ship the new backends as "validating on hardware"): clear only **Tier A**. exFAT-ATA / SMB / the 2026-07-09 wave ship documented as not-yet-hardware-confirmed (how they read now). Fastest; cut after one clean session.
- **Option B** (recommended): also clear **Tier B**, so BETA-13 lands with its two brand-new storage backends actually run on a console.

Tier C and the "not blockers" items don't gate either way.

---

## Tier A — Regression core (MUST be clean to cut, either option)

The 2026-07-09 wave inserted code into the launch path and the HDD scan. Adaptive BDMA is **off by default**, so a normal launch should behave exactly as before; this confirms nothing regressed. About 30 min on an NTSC console.

- [ ] **Boot to menu** from each device you have (MC / USB / MMCE / HDD): splash appears instantly, centered, then the carousel. (Also covers the re-encoded boot chime being on the boot path.)
- [ ] **Normal PS1 launch** from each of those devices.
- [ ] **HDD POPSTARTER launches an HDD game** (D-10) still works.
- [ ] **HDD POPSTARTER launches a non-HDD game** (D-14) still works.
- [ ] **Non-HDD POPSTARTER launches an HDD game** (D-15) still works.
- [ ] **DKWDRV from Memory Card** launches.
- [ ] **Exit to BOOT.ELF** from a USB-booted POPSLoader (L-07) works.
- [ ] **Exit to BOOT.ELF** from an HDD-booted POPSLoader (U-10) works.
- [ ] **MX4SIO** still lists and launches (a size optimization re-pointed its embedded USB driver).
- [ ] **Hold START during boot** drops to a safe state.

## Tier B — The two new backends (for Option B; both rigs are available)

- [ ] **HDD (exFAT) via BDMA ATA:** BDMA Mode to ATA, Internal HDD to exFAT, a `POPS/` folder on an exFAT internal drive. It **lists** and **launches**, and the exFAT drive does **not** also show under USB or MX4SIO.
- [ ] **SMB v1** (PS2-Servers setup): install the module pack, connect, browse `smb:/POPS`, **launch a game**, it disconnects cleanly on exit. Also try the blank-Share picker. If a game lists but won't boot, note the exact behavior (that's the argv0-prefix unknown; two fallbacks are ready to swap).

## Tier C — 2026-07-09 wave, quick passes if the setup allows (optional; else ship-as-validating)

- [ ] **Boot chime** sounds normal (not slow/low/crackly). (Or A/B the WAVs in `.research/_audio_preview/` on a PC first.)
- [ ] **Adaptive BDMA** (MMCE + USB): turn it on, launch an MMCE game then a USB game with no settings change between; both boot.
- [ ] **Partition-installed games** (PSBBN/HDDOSD drive): the HDD (PFS) page lists `PP.` games by name and one launches.
- [ ] **HDD-resident settings save + L3 hide / R3 reveal** on an HDD install: save a setting, reboot, it stuck.

## Not blockers (documented pending — accept or delegate)

- **PAL** (native 640x512, Auto video, cover-art registration on PAL): the team has no PAL hardware. Recruit a PAL tester or ship PAL-pending (BETA-12 shipped items this way).
- **#508 "No USB backend detected":** oldman63's specific console; awaiting his retest. Not a broad blocker unless it reproduces.
- **CRT overscan eyeball / DKWDRV exit-to-MC hang:** documented known-issues.

---

When the gate is green: fill the cut date, merge `claude/beta13-release-prep`, and run [`RELEASE_BETA13.md`](RELEASE_BETA13.md) section 3 (the tree-adopting merge to `master` + tag).
