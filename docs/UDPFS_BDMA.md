# POPS UDPFS / UDPFS Assault

The development version replaces USB-first BDM-UDPFS Assault Alpha with
[Okeanos UDPFS Assault 1.0.0](https://github.com/Okeanos86/BDMAssault/releases/tag/1.0.0).
USB is no longer required. The `UDPFS` settings key and `.udpfs` asset names are
retained for upgrades; they now select the full network read/write driver.
The old USB-first mode is removed. Physical-console status is
**Unknown (verify on hardware)**; see [the QA ledger](../QA_REGRESSION_MATRIX.md).

## Setup

1. Run `udpfsd` without `-ro`, or `udpfs_server.py` without `--read-only`, on
   the same subnet as the PS2. The server must permit writes for VMC saving.
2. Put the complete POPS runtime files under the server's shared root:
   `POPS/POPS_IOX.PAK`, `POPS/<game>.VCD`, the corresponding VMC directories,
   and optional patches, cheats and IGR artwork. Filenames are case sensitive
   on Linux, and the `.VCD` extension must be uppercase. Existing USB saves
   are not automatically migrated; copy backups deliberately before use.
3. Keep `POPSTARTER.ELF` on persistent local storage, such as a memory card.
   Set **POPSTARTER Path** if needed. The temporary menu `udpfs:` mount is
   discarded when POPStarter resets the IOP, so it cannot supply that ELF.
4. In **Settings > SMB / Network**, disable DHCP and set the console's
   static PS2 IP, contiguous netmask and optional gateway. The server must be
   on the same subnet; the runtime does not route through the gateway.
5. Enable the **POPSTARTER Folder** on a memory card. Select
   **Ethernet > UDPFS**, then a game. POPSLoader installs the embedded released
   pair into `mc?:/POPSTARTER/usbd.irx` and `usbhdfsd.irx` before handoff,
   independently of Adaptive BDMA. **BDMA Mode > UDPFS (network R/W)** also
   installs this pair. No USB-first option remains.

Every runtime `mass:` operation goes to the server, including dependency reads
and VMC writes. The `XX.<game>.ELF` mass selector remains correct: `mass:` is the
namespace supplied by the network driver after POPStarter's IOP reset.
The menu filesystem remains read-only and uses its existing transport modules.
Ember retains its existing inherited-network handoff; this POPStarter update
does not replace Ember's backend.

## Configuration and upgrades

The released runtime searches **each file independently**, first
`mc0:/SYS-CONF/`, then `mc1:/SYS-CONF/`:

| File | Content | POPSLoader behavior |
|---|---|---|
| `IPCONFIG.DAT` | `PS2_IP NETMASK [GATEWAY]` | Preserve the effective MC file; create a missing file from the menu's static settings. Cancel launch if an existing address or mask disagrees. |
| `UDPFSCONFIG.DAT` | Server IPv4 address | Preserve any existing MC file. If absent from both cards, copy optional `udpfs:/POPS/UDPFSCONFIG.DAT`; otherwise use upstream broadcast discovery. |

The installation kit ships `UDPFSCONFIG.DAT.example`, which is ignored by the
loader. To pin a server, edit the address and rename it to `UDPFSCONFIG.DAT`
in the server's `POPS/` folder. An unedited kit uses broadcast discovery.
When upgrading a server folder populated from an older kit, remove an unedited
active `UDPFSCONFIG.DAT` example (often `192.168.1.11`) if you want discovery;
existing MC configurations still take precedence.

New files go to `SYS-CONF` on the card selected for the POPSTARTER pack.
Writes are checked by readback. A failed newly created configuration is removed;
if removal fails, further preparation attempts in the same session stay blocked
until it can be removed. Configuration is checked even when the driver
pair is already equipped. Both optional runtime config files must fit within
upstream's 120-byte limit. An empty or oversized server source file is rejected;
remove that optional source file to use discovery.

Old USB `POPS/IPCONFIG.DAT` and `POPS/UDPFSCONFIG.DAT` are no longer read or written
by this integration. Move a custom server address to MC `SYS-CONF` or the server
`POPS/UDPFSCONFIG.DAT` source. Existing MC files take precedence and are never
silently overwritten, including MC1 files when MC0 is also present.

A saved `BDMA=UDPFS` remains valid. The equipped check compares both installed
files with the embedded release bytes, so an old Alpha pair, damaged driver,
or stale marker triggers restaging before launch. Settings apply uses the embedded pair as well, so an old external Alpha override
cannot reinstall the removed backend. Release kits replace the
historical reference bundle's UDPFS files and notices with this same pair.
[Provenance and SHA-256 hashes](third_party/okeanos_udpfs/PROVENANCE.json),
[unmodified upstream instructions](third_party/okeanos_udpfs/UPSTREAM-README.md)
and [configuration details](third_party/okeanos_udpfs/README_CONFIG.txt) accompany it.

## Limits and validation

SMBv1 and the UDPFS menu stack cannot share the network adapter. Restart
POPSLoader before switching protocols after connection. Press **R1** to rescan.
Upstream does not support `rename` or files of 4 GiB or larger.

Keep VMC backups. The upstream driver retries interrupted writes for roughly
10 seconds; a longer interruption can leave a file incomplete. Network writes
are not atomic. Console acceptance must cover cold and repeated no-USB launch,
controller input, real VMC save/reload, missing/read-only server behavior,
reconnection, MC0/MC1 configuration and SMB regression. Host tests and a target
build cannot establish those outcomes.
