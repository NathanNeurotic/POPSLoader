# UDPFS Assault

A PS2 IOP module that makes a **UDPFS server** look like the `mass:` device,
with **read and write** support. Programs that expect a USB drive on `mass:`
(POPStarter, Ember) run with their files served over the network.

It is a fork-side project of [BDM Assault](https://github.com/israpps/BDMAssault)
(folder `__udp_fs_assault`, next to `__bdm_udp_fs_assault`); the network layer
and the UDPFS client come from that work, which in turn derives from UDPBD and
UDPFS in the Neutrino repository.

Tested on hardware with:

- **POPStarter** (`.VCD` + `SLOT0.VMC` / `SLOT1.VMC`)
- **Ember** (`.cue` / `.bin` + `MC1.vmc` / `MC2.vmc`)
- servers: `udpfsd` (Go) and `udpfs_server.py` (Python)

## What the module does

- Registers the `mass` device (`mass:` and `mass0:`) and sends every request
  to the UDPFS server: `open`, `read`, `write`, `lseek`, `close`, `getstat`,
  `mkdir`, `remove`, `rmdir`, `dopen` / `dread` / `dclose`.
- Reads use BREAD; unaligned reads go through a one-sector cache.
- Errors are translated into the negated FatFs codes the USB driver returned
  (`-4` file not found, `-5` path not found, ...), because the programs rely on them.
- Exports an empty `bdm` library, so a USB block-device driver loaded after
  this module is accepted and changes nothing (`mass:` is always the server).

## Installation (POPStarter)

- `udp_fs_assault.irx` replaces the BDM module: paste it into
  `mc?:/POPSTARTER/usbd.irx` (where `bdm_assault.irx` goes in BDM Assault).
- POPStarter also needs `mc?:/POPSTARTER/usbhdfsd.irx` at start-up and does not
  run without it. Use `usbd_bd_assault.irx` from the BDM Assault project, renamed
  to `usbhdfsd.irx`.
- Optional: `IPCONFIG.DAT` and `UDPFSCONFIG.DAT` in `mc?:/SYS-CONF/` (see below).
- Ember: use a launcher to load this module, load the memory card modules
  before it (see docs/README_CONFIG.txt).

Not supported: `rename` (neither POPStarter nor Ember use it, and the UDPFS
protocol has no such request), `ioctl2`, files of 4 GiB or more (the position
kept by the driver is 32 bit).

## Server requirements

- A UDPFS server that **allows writing** (`udpfsd` without `-ro`, or
  `udpfs_server.py` without `--read-only`), and the files exactly as the program
  asks for them, including the case of file and folder names:
  - POPStarter: `POPS/POPS_IOX.PAK`, `POPS/<game>.VCD`, optional files such as
    `POPS/IGR_*.TM2`; the VMC files are created by POPStarter.
  - Ember: `EMBER/ember.elf`, `EMBER/bios.bin`, `EMBER/games/<folder>/...`.
- Everything the program used to find on the USB drive has to be on the server.
- Same network segment as the PS2 (no routing).

## Configuration

Two optional files on the memory card: `IPCONFIG.DAT` (PS2 IP) and
`UDPFSCONFIG.DAT` (server IP), in `mc0:/SYS-CONF/` then `mc1:/SYS-CONF/`.
See [docs/README_CONFIG.txt](docs/README_CONFIG.txt). Without them the PS2 uses
192.168.1.10 and the server is found by broadcast.

## Building

Inside the fork repository (it needs `../global.make` and `../libbdm/include`):

    make                 release build  ->  ../udp_fs_assault.irx
    make DEBUG=1         log over UDP tty (port 18194) -> ../udp_fs_assault_debug.irx

After changing DEBUG run `make clean`.

## WARNING: writing and network failures

Everything the programs write (virtual memory cards, saves) goes over the
network. Read this before trusting it with data you care about.

- **Keep a copy of your VMC files.** A VMC that was being written when the
  connection or the server failed can be left incomplete or damaged.
- If the network drops or the server restarts **in the middle of a write**, the
  module does not fail at once: the call waits and repeats what did not get
  through, for about 10 seconds, a little more counting the attempts themselves (writes and closes of files open for writing;
  opening a file for writing also waits). The game or emulator stays blocked
  during that time. If the server does not come back in time, the write fails
  with an error and **the file may be left incomplete**. The server
  writes a group of up to 32 KiB only when it is complete, but a longer write, or a file written in many
  calls (POPStarter rewrites the whole 128 KiB card in 8 calls), can stop
  between two of them.
- If the server is unreachable for longer, a program may react in its own way.
  Ember, for example, falls back to creating the file when it cannot open it
  (flags `0x602`), which **truncates** it before rewriting it from its copy in
  memory; if the network fails again during that rewrite, the file is left
  empty or partial. The module avoids this for short outages by waiting on
  opens for writing, but cannot for long ones.
- Reads are not affected the same way: a failed read returns an error and the
  program decides what to do; after the connection returns, reading resumes by
  itself (the file is reopened by path if the server restarted).
- Do not unplug the network, put the PS2 to sleep or stop the server while a
  save is in progress.

## Credits and licenses

See [docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md). The project is
under the Academic Free License 2.0 (`licenses/`).
