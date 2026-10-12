# POPS UDPFS / BDM-UDPFS Assault — Release candidate (Coming soon)

**POPSLoader integration: Coming soon.** This page documents the intended user workflow so it will be ready when implemented. No currently published POPSLoader release provides UDPFS VCD browsing, automatic driver staging, or the settings described below. Do not treat this guide as a release announcement.

## Implementation branch (not yet released)

The POPSLoader feature branch implements the planned Ethernet protocol picker:
select **SMBv1** to use the existing SMB browsing and network-streaming modules,
or **USB + UDPFS** to use a read-only `udpfs:/POPS/` game list and Okeanos's
POPSTARTER runtime fallback. This is **not yet a published or hardware-verified
POPSLoader feature**; the public Pages website must continue to say *Coming soon*
until the feature is merged, packaged, and verified.

### USB + UDPFS configuration

1. Start `udpfsd` or `udpfs_server.py` on the same LAN with `POPS/<title>.VCD`
   in the server's exported folder. The extension must be uppercase `.VCD` for
   the upstream POPSTARTER driver.
2. In **Settings → SMB / Network**, disable DHCP and enter the console's static
   **PS2 IP** and **Netmask**, and optionally its gateway. The in-game Okeanos
   driver and the menu-side UDPFS filesystem must use the same console IP.
   The gateway is ignored by the driver; the server must be on the same subnet.
3. Put a USB drive with a `POPS/` directory in the console. On launch,
   POPSLoader checks existing `POPS/IPCONFIG.DAT` on every detected USB volume:
   if addresses disagree, it cancels without overwriting the user's file; if
   missing, it generates one using the configured static address.
   `POPS/UDPFSCONFIG.DAT` is optional and is **not** automatically modified;
   create one containing the server IPv4 address to bypass discovery.
4. Select **Ethernet → USB + UDPFS**. The network game page can list VCDs
   without an SMB login. Press **R1** to rescan after starting/restarting the
   server.
5. Choose a game. POPSLoader resolves **POPSTARTER.ELF from a local device**
   (never from the network filesystem), prepares the USB settings, and equips
   the embedded `usbd.irx.udpfs` / `usbhdfsd.irx.udpfs` pair on the memory
   card as `POPSTARTER/usbd.irx` and `POPSTARTER/usbhdfsd.irx`.
   The `XX.<title>.ELF` mass selector starts the USB-first / UDPFS-fallback
   read path after POPSTARTER's IOP reset. **Do not expect the in-menu
   `udpfs:` filesystem to survive that reset.**

SMB and the UDPFS ministack cannot share the PS2's network adapter at once.
To change from one protocol to the other after a connection, **restart
POPSLoader / reset the IOP**. There is intentionally no attempt to reflash
any adapter firmware, change the UDPFS server implementation, or forcibly
unload the resident network IRX modules.

The binary pair is pinned from the RiptOPL copy of Okeanos's Alpha release;
the menu filesystem modules are pinned from its Neutrino bundle. The upstream
license notices and configuration reference are mirrored under
[`docs/third_party/okeanos_udpfs/`](third_party/okeanos_udpfs/).
**Build success is not hardware compatibility proof.** Verify physical PS2
USB enumeration, UDPFS directory scanning, launch, return/restart behavior,
and SMBv1 regression before a public release.

---

## About this support — Coming soon

POPSLoader is preparing support for PlayStation 1 `.VCD` titles served by UDPFS, using [Okeanos's BDM-UDPFS Assault (Alpha)](https://github.com/Okeanos86/BDMAssault/releases/tag/Alpha). This is a **read-only fallback** in the POPSTARTER USB driver: POPSTARTER checks USB for the VCD first; when the requested VCD is not present there, it tries the same path on a UDPFS server *after* POPSTARTER resets the IOP. It is **not** the Neutrino/UDPFS PS2-game transport, and it does **not** make UDPBD or UDPFS image mode a POPSTARTER backend.

The [upstream Alpha release](https://github.com/Okeanos86/BDMAssault/releases/tag/Alpha) is already public, but POPSLoader's discovery, settings, BDMA staging and launch handoff are **Coming soon**. Upstream driver availability is not proof that any POPSLoader release integrates it.

## Planned POPSLoader workflow — Coming soon

1. Place your PS1 `.VCD` files under `POPS/` in the folder exported by a UDPFS server (for example, `POPS/Example.VCD`). The upstream driver also recognizes `POPS0/` through `POPS9/`; use uppercase `.VCD`.
2. Configure the PS2 and the UDPFS server on the same LAN/subnet. The planned **POPS UDPFS Network Settings** editor will manage the POPSTARTER-specific USB configuration files, separately from POPSLoader's SMB and launcher network settings (**Coming soon**).
3. Open POPSLoader's proposed **UDPFS Files** PS1 page, choose the title, and launch. POPSLoader will enumerate network `.VCD` entries and prepare the matching driver pair for POPSTARTER (**Coming soon**). Enumeration in the menu and reading in POPSTARTER are separate responsibilities.
4. With **Adaptive BDMA** enabled, POPSLoader will stage the UDPFS variant for network VCD launches. With automatic staging disabled, **BDMA Mode → UDPFS** will be the manual option (**Coming soon**). None of those new selectors exist in current releases.

The planned behavior prefers a matching USB VCD over the server's copy. Missing or invalid network configuration, unavailable server, missing drivers, and driver staging failures must produce an actionable error rather than silently report a successful launch (**Coming soon**).

## Driver and configuration reference — Coming soon in POPSLoader

The upstream Alpha release contains drivers named:

| Upstream file | POPSTARTER destination |
| --- | --- |
| `bdm_udp_fs_assault.irx` | `mc0:/POPSTARTER/usbd.irx` or `mc1:/POPSTARTER/usbd.irx` |
| `usbd_bd_assault.irx` | matching card's `POPSTARTER/usbhdfsd.irx` |

The POPSLoader integration will be prepared to stage them as a pair, preserving the current installation if a staged copy is incomplete (**Coming soon**). Driver names above describe **upstream manual installation**, not filenames already shipped in POPSLoader.

The Alpha driver reads optional `mass:/POPS/IPCONFIG.DAT` (PS2 address and subnet) and `mass:/POPS/UDPFSCONFIG.DAT` (server address / discovery) from **USB**, not from `mc?:/POPSTARTER/`. Upstream permits both to be absent and uses its defaults/discovery, but explicit matching LAN settings are advisable. The planned POPSLoader editor will save those USB-side files and explain conflicts across multiple USB volumes (**Coming soon**). POPSLoader's SMB settings do **not** configure the UDPFS driver.

Keep the necessary POPSTARTER executable and user-supplied POPS runtime files in their normal locations. The original upstream project supports `udpfsd` and `udpfs_server.py` servers; PS2-only UDPFS/Neutrino setup documentation does not replace these POPSTARTER requirements.

## Scope and current availability

- **Upstream BDM-UDPFS Assault Alpha:** available now, separately from POPSLoader. [Project and release](https://github.com/Okeanos86/BDMAssault/releases/tag/Alpha).
- **POPSLoader UDPFS VCD page / Favorites integration:** **Coming soon**.
- **POPSLoader automatic/manual UDPFS BDMA staging:** **Coming soon**.
- **POPSLoader POPS UDPFS network settings editor:** **Coming soon**.
- **Real-console validation of the POPSLoader integration:** pending implementation. No compatibility or performance guarantee is being claimed.

## Credits

**[Okeanos](https://github.com/Okeanos86)** developed [BDM-UDPFS Assault](https://github.com/Okeanos86/BDMAssault/releases/tag/Alpha), the POPSTARTER-specific read-only UDPFS fallback. It builds on **[israpps / El_isra's BDM Assault](https://github.com/israpps/BDMAssault)** and the wider **[PS2SDK](https://github.com/ps2dev/ps2sdk)** ecosystem. POPSTARTER itself is by **krHACKen**; the `udpfsd` server is by **[pcm720](https://github.com/pcm720/udpfsd)**. All retain their own project and licensing credits.

POPSLoader integration is **Coming soon**. This documentation is not a claim that any of these authors supplied an integrated POPSLoader build.

When integration is released, removing the explicit **Coming soon** markers must be accompanied by working binaries, documented supported settings, real test results, and updated packaging/license notices.
