# POPS UDPFS / BDM-UDPFS Assault — Experimental development feature

**Experimental development build, not an official compatibility release.**
The Ethernet mode selector, UDPFS VCD browser, and embedded POPSTARTER driver
staging are implemented. Cross-compilation and automated regression checks have
passed, but physical PS2 launch compatibility is **Unknown (verify on hardware)**.
The stable 1.2.2 release does not provide these features.

## Experimental implementation

The POPSLoader feature branch implements the planned Ethernet protocol picker:
select **SMBv1** to use the existing SMB browsing and network-streaming modules,
or **USB + UDPFS** to use a read-only `udpfs:/POPS/` game list and Okeanos's
POPSTARTER runtime fallback. This implementation is available to development builds; it is **not a
hardware-verified or official stable feature**. Do not advertise stable support
until the release matrix records hardware validation.

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

## How USB + UDPFS works

The [upstream BDM-UDPFS Assault Alpha](https://github.com/Okeanos86/BDMAssault/releases/tag/Alpha)
is a POPSTARTER-specific, read-only network fallback. POPSTARTER first checks
for the VCD on USB and then, if absent, looks for the same file under `POPS/`
(or upstream-supported `POPS0/` … `POPS9/`) on a UDPFS server. It is not
the Neutrino PS2 game transport and does not add UDPBD image mode to POPSTARTER.

The feature branch implements this through the existing **Ethernet** tile:
choose **SMBv1** or **USB + UDPFS**. To configure the UDPFS choice, use
**Settings → SMB / Network**, turn DHCP off, and enter a valid static PS2 IP
and contiguous subnet mask. Those settings supply the menu-side UDPFS
ministack and the USB `POPS/IPCONFIG.DAT` used by Okeanos's POPSTARTER driver.
An existing file must agree with the settings; POPSLoader does not overwrite
conflicting user files. `POPS/UDPFSCONFIG.DAT` is optional and stays under
the user's control, with broadcast discovery used when appropriate.

When a UDPFS title launches, POPSLoader stages the matching Okeanos driver
pair on the memory card **regardless of the global Adaptive BDMA setting**.
It resolves POPSTARTER.ELF from persistent local storage, never `udpfs:/`,
because the temporary browsing filesystem disappears on the IOP reset.
SMBv1 keeps its existing module, share, and POPSTARTER launch workflow.

### Upstream driver names (manual-install reference)

| Upstream file | POPSTARTER destination |
| --- | --- |
| `bdm_udp_fs_assault.irx` | `mc?:/POPSTARTER/usbd.irx` |
| `usbd_bd_assault.irx` | `mc?:/POPSTARTER/usbhdfsd.irx` |

These are the upstream names; the feature branch embeds the corresponding
renamed driver images. See the [mirrored upstream configuration reference](third_party/okeanos_udpfs/README_CONFIG.txt)
and [license notices](third_party/okeanos_udpfs/THIRD_PARTY_NOTICES.md).

## Scope and current availability

- **Upstream Okeanos Alpha:** publicly available as a standalone driver.
- **POPSLoader SMBv1 / USB+UDPFS picker, VCD browsing and automatic staging:**
  implemented for experimental development builds; not in stable 1.2.2.
- **Dedicated POPS UDPFS settings editor:** not implemented or required; the
  feature branch uses the existing SMB / Network static address fields.
- **Hardware compatibility:** **Unknown (verify on hardware)**. A passing
  build and host test are not PS2 hardware confirmation.

## Credits

**[Okeanos](https://github.com/Okeanos86)** developed [BDM-UDPFS Assault](https://github.com/Okeanos86/BDMAssault/releases/tag/Alpha), the POPSTARTER-specific read-only UDPFS fallback. It builds on **[israpps / El_isra's BDM Assault](https://github.com/israpps/BDMAssault)** and the wider **[PS2SDK](https://github.com/ps2dev/ps2sdk)** ecosystem. POPSTARTER itself is by **krHACKen**; the `udpfsd` server is by **[pcm720](https://github.com/pcm720/udpfsd)**. All retain their own project and licensing credits.

POPSLoader's **official stable integration remains pending hardware validation**. This documentation is not a claim that any of these authors supplied or verified the integrated POPSLoader build.

An official release requires documented PS2 hardware test results, regression checks for existing SMB/USB modes, working binaries, and complete packaging/license notices.
