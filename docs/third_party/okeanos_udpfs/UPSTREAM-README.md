# BDM-UDPFS Assault

PS2 homebrew project that adds UDPFS support to the BDM Assault USB driver used by POPStarter, so VCD files can be read from a UDPFS server as if it were a USB device.

Original BDM Assault description: *PS2 homebrew project to bring support for EXFAT USB devices to closed source old homebrew which loads external USB Drivers.*

## What it does

`bdm_udp_fs_assault.irx` is a drop-in replacement for `bdm_assault.irx`. It keeps everything BDM Assault does (USB mass storage through BDM + FatFs, exFAT/FAT32, read and write) and adds a read-only network fallback:

- POPStarter opens a `POPS/` or `POPS0/` ... `POPS9/` `*.VCD` file: the USB drive is tried first.
- If the file is not on the USB drive, the same path is requested from a UDPFS server over Ethernet and read with BREAD requests.
- If neither has the file, the open fails exactly as with the original driver.
- Any other file, and any write, never touches the network.

The `.VCD` extension must be uppercase (POPStarter is case-sensitive on this), on the USB drive and on the server.

Servers it has been tested with: [udpfsd](https://github.com/pcm720/udpfsd) (Go) and the original Python server (`udpfs_server.py`).

## Usage

Place the IRX binaries from the releases section of this repository into the path that POPStarter looks for.

### POPStarter

- `bdm_udp_fs_assault.irx` must be pasted into `mc?:/POPSTARTER/usbd.irx`
- `usbd_bd_assault.irx` (the USB mass storage driver, from the [BDM Assault releases](https://github.com/israpps/BDMAssault/releases)) must be pasted into `mc?:/POPSTARTER/usbhdfsd.irx`

### What goes where

- **UDPFS server:** only the `.VCD` files, in the folder POPStarter looks in, relative to the server's shared root: `/POPS/` or `/POPS0/` ... `/POPS9/` (for example `/POPS/SLUS_011.56.VCD`). The extension must be uppercase.
- **USB drive:** everything else POPStarter needs (`POPS_IOX.PAK` and any other file) stays on the USB drive and is read from there. No additional file is needed on the server, and this module does not read any other file from the network.

### Any other homebrew

- This is built specifically for POPStarter, other homebrew are out of scope.

## Network configuration

Both files are optional and live on the USB drive, in the `POPS` folder. Full details in [docs/README_CONFIG.txt](docs/README_CONFIG.txt).

- `mass:/POPS/IPCONFIG.DAT`: the PS2's address, one line: `IP NETMASK [GATEWAY]`, for example `192.168.1.10 255.255.255.0 192.168.1.1`. If it is missing or invalid, the PS2 falls back to `192.168.1.10` / `255.255.255.0` (same default as UDPBD and Neutrino).
- `mass:/POPS/UDPFSCONFIG.DAT`: the server's address, one line: `192.168.1.11`. If present and in the same network as the PS2, it takes priority over the discovery and the server is contacted directly. If it is missing, or its address belongs to another network, it is ignored and the server is found with a broadcast discovery.

The files are read once the USB drive is mounted.

## Building

You need the [PS2SDK](https://github.com/ps2dev/ps2sdk). Build `libbdm` first, then the module:

```
cd libbdm && make
cd ../__bdm_udp_fs_assault && make
```

Options (run `make clean` after changing one):

- `make DEBUG=1` builds `bdm_udp_fs_assault_debug.irx`, which sends the log over UDP tty (broadcast, port 18194): `nc -u -l 18194`. It also prints the start-up timings of each phase.
- `make UDPFS_STATS=1` adds live statistics (one line per second in the server log in verbose mode).

## License

This project is distributed under the terms of the [LICENSE](../LICENSE) file of the repository (Academic Free License 2.0). It includes or derives from third-party works that keep their own licenses (PS2SDK, Neutrino/UDPBD/UDPFS, FatFs, udpfsd): the full list, with copyright notices and license texts, is in [docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md) and [licenses/](licenses/).

## CREDITS

the softwares found here were taken and modified from [__PS2SDK__](https://github.com/ps2dev/ps2sdk)

- israpps: for BDM Assault, the project this one is based on
- krHACKen: for POPStarter
- rickgaiser ([Neutrino](https://github.com/ps2max32/neutrino)): UDPFS/UDPRDMA protocol and the original UDPBD network code
- PCM720 ([udpfsd](https://github.com/pcm720/udpfsd)): UDPFS server in Go, used as the reference to write the client
- everyone that collaborated to PS2SDK
