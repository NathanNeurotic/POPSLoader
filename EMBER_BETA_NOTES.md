# POPSLoader 1.3.0 Ember Beta 1 — opt-in prerelease

This is the **first versioned, Ember-enabled POPSLoader beta**. It is built from the `dev` branch, not the official stable `master` branch. The preceding **official stable release is 1.2.3** and remains available separately. The versioned beta archive is immutable; the floating [Rolling Release](https://github.com/NathanNeurotic/POPSLoader/releases/tag/rolling-release) can change on future commits.

## What is included

- POPStarter/VCD game browsing and the existing features from the stable line.
- A **separate Ember PS1 core** for `EMBER/games/<folder>/` CUE/BIN titles (alongside VCD game rows), using the original unmodified Gageformer `ember.elf` and its beta licence.
- Ember **Settings → Ember PS1 Core** global options and **L2** per-game settings for timing, dither, shading and controller.
- Storage-aware Ember scanning for USB (including dual USB), MX4SIO, MMCE, internal exFAT/ATA, APA/PFS `__.EMBER*`, SMB and UDPFS where their mounts are available. These are **host-level integration results, not verified PS2 launch results**.
- Experimental, opt-in **USB + UDPFS** PS1 VCD browsing and Okeanos BDM-UDPFS Assault fallback, with SMBv1 as a separate Ethernet choice. Restart when switching network stacks.
- Release ZIP including `APPS/PS1_POPSLOADER/` (eight application files), the complete pinned RiptOPL-compatible `POPS/` support folder, `EMBER/ember.elf` and licence, and `EMBER/games/ExampleGame/ExampleGame.cue` plus a **zero-byte non-playable** `ExampleGame.bin` placeholder.
- **PS1_POPSLOADER.psu**: a flat PS2 save with header `PS1_POPSLOADER` and only those eight application files immediately below it. **No nested folder; no POPS or EMBER directories inside the PSU.**

## Downloads and install

- `PS1_POPSLOADER.zip` — complete application + support-file directory layout.
- `PS1_POPSLOADER.psu` — the application-only memory-card save.
- `POPSLOADER.ELF` — standalone launcher.
- `BUILD-MANIFEST.txt` and `SHA256SUMS.txt` — source identity, tested CI run and checksums.

Follow the [installation guide](https://github.com/NathanNeurotic/POPSLoader/blob/dev/docs/wiki/Installation-Guide.md) or the [GitHub-native Wiki](https://github.com/NathanNeurotic/POPSLoader/wiki). Install `POPS/` and `EMBER/` at a supported device root; the PSU contains the application only. You must supply your **own legally obtained Sony POPS emulator components, a 512 KiB PS1 BIOS for Ember, and your own game images**. None are included.

## Read before testing

**Ember game boot on physical PS2 hardware, controller input after keep-IOP handoff, writable VMC saves, APA/PFS write-through, and network launch behavior have not been certified.** Automated host-harness, compilation, file checks, independent PSUManager C++ validation and ZIP-integrity tests do not substitute for hardware verification.

**i.Link is deliberately not implemented** in this Ember beta. It will be revisited only after RiptOPL demonstrates reliable i.Link operation on physical hardware. It does not block this prerelease.

Report the exact beta version, PS2 model, storage backend, number of USB drives, whether game launch and pad input worked, and whether VMC saves persisted. See [STATE](https://github.com/NathanNeurotic/POPSLoader/blob/dev/STATE.md) and the [QA regression matrix](https://github.com/NathanNeurotic/POPSLoader/blob/dev/QA_REGRESSION_MATRIX.md).

Credits: Gageformer (Ember), krHACKen (POPStarter), israpps (POPSLoader), Okeanos (BDM-UDPFS Assault), the RiptOPL/PS2SDK/driver contributors and POPSLoader testers. Ember's unmodified upstream core and beta licence are included; upstream rights remain with their authors.

**This is a versioned development beta, not an official stable hardware compatibility release.**
