UDPFS CLIENT CONFIGURATION (from the USB drive)
===============================================

The PS2 UDPFS client reads its network settings from two optional files in the
POPS folder of the USB drive: IPCONFIG.DAT (the PS2's own address) and
UDPFSCONFIG.DAT (the server address).


IPCONFIG.DAT - PS2 IP address
-----------------------------
A single line of text:  IP_ADDRESS NETMASK [GATEWAY]

e.g.:

    192.168.1.10 255.255.255.0 192.168.1.1

File:

    mass:/POPS/IPCONFIG.DAT

- An unreadable or invalid file is treated as if it were missing. Invalid means:
  IP 0.0.0.0, 127.x or multicast; an invalid netmask; or an IP equal to the
  network address or the broadcast address.
- Empty lines and comments (# or ;) at the start of the file are allowed, as
  are CRLF line endings and a BOM. Extra fields after the gateway are ignored.
- The gateway is not used: the ministack does not route, so the server must be
  on the same network as the PS2.
- Without a valid file, the default IP 192.168.1.10 with netmask 255.255.255.0
  is used (the same as UDPBD and Neutrino), which keeps compatibility.


UDPFSCONFIG.DAT - UDPFS server IP address
-----------------------------------------
A single line of text:  IP_ADDRESS

e.g.:

    192.168.1.11

File:

    mass:/POPS/UDPFSCONFIG.DAT

- If present (and in the same subnet as the PS2), it takes precedence: the
  DISCOVERY goes directly to that IP and an INFORM is accepted only from it.
- If it is missing, the server is looked up with a broadcast DISCOVERY (3
  attempts) and the first one that answers is used.
- If the address in the file is outside the PS2's subnet, it is ignored and
  broadcast is used instead.


Transport behavior
------------------
After the discovery, packets go to the server as Ethernet unicast (the MAC
address is taken from the INFORM). If the server does not answer two requests
in a row, the data port is forgotten and the next request performs the
discovery again.


Why the USB drive (and not the memory card)
-------------------------------------------
POPStarter loads this module twice: once before and once after an IOP reset.
After the reset the memory card driver ("mc0:") does not exist. Restoring it
from this module (loading rom0:XSIO2MAN and rom0:XMCMAN) made the game
controller stop working, because it interferes with the modules POPStarter
loads itself. So the module never touches the memory card and loads no system
module.

The USB drive is always there (POPStarter needs it for the POPS files) and is
mounted by this very module. The network thread starts first (hardware init and
Ethernet link negotiation), waits for the drive to be mounted (at most 10 s),
reads the two files and then starts the discovery. Without a drive, or without
the files, the defaults apply: default IP and broadcast discovery.

- The Ethernet link comes up seconds after smap_init() returns. The client
  waits for it (up to 4 s) before the first DISCOVERY; without a link (cable
  unplugged) no discovery window is spent. fs_open waits up to 14 s for the
  client to be ready.


Diagnostics
-----------
Build with "make DEBUG=1" to enable the IRX log. It is sent over UDP tty on
port 18194:

    nc -u -l 18194

Configuration messages (printed together with the INFORM line):

    UDPFS: PS2 IP a.b.c.d (IPCONFIG.DAT | default)
    UDPFS: server: a.b.c.d (UDPFSCONFIG.DAT)
    UDPFS: server: broadcast
    UDPFS: server: outside subnet, broadcast

Discovery messages:

    UDPFS: INFORM from <ip> port <p>, server <ip>, MAC <mac> (unicast | Ethernet broadcast)
    UDPFS: no INFORM accepted after 3 DISCOVERY packets (INFORMs seen: N)
    UDPFS: no reply to unicast, falling back to Ethernet broadcast
    UDPFS: server restarted (data port X -> Y), new session

Start-up timing (DEBUG=1): once the client is ready, lines of the form

    UDPFS: t(ms) dev9 700 smap 900 usb 3000 ip 3050
    UDPFS: t(ms) cfg 3100 link 3200 disc 3500 ready 3500

show the milliseconds since the start of the module instance at each phase
(usb = USB drive mounted, cfg = config read, dev9/smap = hardware init,
ip = PS2 IP set, link = Ethernet link up, disc = discovery done). dev9/smap
init and the Ethernet link negotiation (about 3 s) run in parallel with the
USB mount; the discovery starts after the config files have been read.

Live statistics: build with "make UDPFS_STATS=1". The statistics travel as fake
GETSTAT requests whose path is the statistics text, so the server logs them as
errors / not found. This is expected. The server must run in verbose mode to
show them.

All reads use BREAD (also verified against udpfs.py). Unaligned reads (the VCD
header at open time) read the head and tail through a bounce sector; the client
no longer sends READ or LSEEK.

After changing a build knob (DEBUG, UDPFS_STATS) run "make clean".


Changelog
---------
- Configuration: IPCONFIG.DAT (PS2 IP) and UDPFSCONFIG.DAT (fixed server IP)
  from mass:/POPS/ on the USB drive; default IP 192.168.1.10.
- The memory card is never touched and no system module is loaded (restoring
  the card after the IOP reset broke the game controller).
- Discovery: real-time clock for the INFORM wait (3 s window, 6 packets),
  wait for the Ethernet link, late INFORM accepted while no session exists.
- Server restart during a game: probe DISCOVERY after 2 unanswered attempts,
  session restart, reopen by path if the handle is no longer valid.
- Reads: BREAD only, with bounce sector for unaligned head/tail.
- net_ministack.c: arp_add_entry() free-slot check fixed (no behavior change,
  the function is unused).
- Start-up time: the network thread starts first (hardware init and link
  negotiation overlap with the USB mount).
  net_smap.c: the stock driver slept a fixed 3 s waiting for auto negotiation;
  it now polls every 50 ms and continues as soon as it completes (limit
  unchanged).
- Boot discovery sends DISCOVERY at short intervals first (6 packets over the
  3 s window, spaced 150, 150, 300, 600, 900, 900 ms): the first packet is
  often lost right after the link comes up, and waiting 1.7 s for the next
  one cost more than the time saved elsewhere.