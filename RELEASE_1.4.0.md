# POPSLoader 1.4.0

This release replaces the old USB-first UDPFS fallback with Okeanos's UDPFS Assault 1.0.0 full network read/write driver. USB is no longer required for POPStarter UDPFS games. It also includes the localization fixes and updated translator handoffs merged since 1.3.1.

## Changes

- **Network-only UDPFS:** POPS dependencies, VCD reads and VMC writes use the UDPFS server. The old USB-first mode is removed; the existing `UDPFS` setting migrates in place. Stale Alpha or damaged driver pairs are detected and replaced with the bundled release bytes.
- **Memory-card configuration:** runtime network DAT files use independent MC0 then MC1 `SYS-CONF` precedence. Existing settings are preserved. Missing console IP configuration comes from the menu's static network settings; conflicting addresses block launch.
- **Discovery by default:** the server-address sample ships as `UDPFSCONFIG.DAT.example`. Edit and rename it only to explicitly pin a server. An optional server DAT is copied from the network POPS folder only when absent from both cards.
- **Failure recovery:** new config writes are verified and journaled before the final file is created. Pending cleanup survives a restart, and malformed journals block launch instead of authorizing deletion. Size guards reject oversized installed drivers and IP configs before reading them.
- **Localization:** fix Ember per-game labels and formatted error messages, language-name accents, resolved-path labels and the Hungarian collapsed-disc count. Refresh the Portuguese/Hungarian handoffs and provide the 409-string Slovak TSV/Excel handoff; Slovak wording still awaits the contributor.
- **Packaging:** the ZIP carries matching UDPFS drivers, corrected installation and license documentation, AFL license texts, unchanged upstream Ember Beta-2, and the eight-file flat PSU.

## Installation and migration

Use `PS1_POPSLOADER.zip` for the complete installation kit. `PS1_POPSLOADER.psu` contains the application only; install the separate POPS/EMBER support folders from the ZIP. `POPSLOADER.ELF` is also available separately.

For UDPFS, keep POPSTARTER.ELF on persistent local storage (for example, a memory card). Put the POPS runtime files and games under the server's shared `POPS/` folder and use a server that permits writes. Keep VMC backups: prolonged interruption during a save can leave a file incomplete. Existing USB saves are not automatically migrated. When upgrading a server folder from an older kit, remove an unedited active `UDPFSCONFIG.DAT` sample if you want discovery; installing the new ZIP does not delete files already on your server or memory cards.

[UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.0/docs/UDPFS_BDMA.md)

## Validation and limits

The official assets are taken from the exact passing master CI run. Automated checks cover 60 Lua boot/runtime cases, UDPFS configuration and production-launch mocks, oversized-file guards, MC0/MC1 restart recovery, controller initialization, disc artwork layout, PNG decoding, translator handoffs, driver hashes, ZIP contents and independent PSU readers. `BUILD-MANIFEST.txt` identifies the source and CI run; `SHA256SUMS.txt` covers the published assets.

**Physical-console UDPFS launch and VMC save/reload acceptance remain unverified.** Ember launch, controller behavior after handoff and VMC persistence also require recorded PS2 testing. These remain experimental options within this official launcher release. Issues #603 and #568 stay open for reporter confirmation; this release does not claim new hardware results. Ember i.Link remains deferred.

Ember is Gageformer's unmodified **Beta-2**, not a new emulator version. Supply your own BIOS, games and proprietary Sony POPS components; none are included. The packaged ExampleGame.bin is an empty placement example.
