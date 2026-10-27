UDP FS ASSAULT: CONFIGURATION AND BEHAVIOR
==========================================

The module reads its network settings from two optional files on the MEMORY
CARD. There is no USB drive: "mass:" is served entirely by the UDPFS server.

    IPCONFIG.DAT      the PS2's own address
    UDPFSCONFIG.DAT   the server address

Each file is looked up in this order, the first one found is used:

    mc0:/SYS-CONF/   then   mc1:/SYS-CONF/

The two files are independent. Without a file, the defaults below apply.


IPCONFIG.DAT - PS2 IP address
-----------------------------
A single line of text:  IP_ADDRESS NETMASK [GATEWAY]

e.g.:

    192.168.1.10 255.255.255.0 192.168.1.1

- An unreadable or invalid file is treated as if it were missing. Invalid means:
  IP 0.0.0.0, 127.x or multicast; an invalid netmask; or an IP equal to the
  network address or the broadcast address.
- The gateway is not used: the ministack does not route, so the server must be
  on the same network as the PS2.
- Without a valid file, the default IP 192.168.1.10 with netmask 255.255.255.0
  is used (the same as UDPBD and Neutrino).


UDPFSCONFIG.DAT - UDPFS server IP address
-----------------------------------------
A single line of text:  IP_ADDRESS

e.g.:

    192.168.1.11

- If present (and in the same subnet as the PS2), it takes precedence: the
  DISCOVERY goes directly to that IP and an INFORM is accepted only from it.
- If it is missing, the server is looked up with a broadcast DISCOVERY (3
  attempts) and the first one that answers is used.
- If the address in the file is outside the PS2's subnet, it is ignored and
  broadcast is used instead.


Server side
-----------
- The server must allow writing (udpfsd without -ro, or udpfs_server.py
  without --read-only).
- File and folder names are case sensitive on a Linux server: they must be
  exactly what the program asks for (for example POPS/<game>.VCD, or
  EMBER/games/<folder>/<name>.cue).
- Every file the program used to find on the USB drive must be on the server.
  Missing optional files (TROJAN_*.BIN, PATCH_*.BIN, IGR_*.TM2, ...) are
  answered "not found" and the program goes on without them.


Which programs, and how the memory card is read
-----------------------------------------------
POPStarter needs the file mc?:/POPSTARTER/usbhdfsd.irx on the memory card to
start: use usbd_bd_assault.irx of the BDM Assault project, renamed to
usbhdfsd.irx. This module goes into mc?:/POPSTARTER/usbd.irx.

POPStarter loads this module twice: once before and once after an IOP reset.
In the first load the memory card is readable; after the reset the memory card
driver ("mc0:") is gone (opening it returns -19, ENODEV). The IOP reset does not
clear the IOP RAM, so the files are carried across it:

- First load (the memory card answers): the two files are read and copied, with
  a signature and a checksum, into three windows of IOP RAM (0x1D0000, 0x1E0000
  and 0x1F0000, 256 bytes each) taken with AllocSysMemory at a fixed address, so
  nothing in use is overwritten. The copies are written also when the files do
  not exist, so an old copy is never reused.
- Second load (mc0: gives ENODEV): the first copy that passes the signature and
  checksum check is used and every valid copy is wiped. A damaged copy (another
  module wrote over it) is neither used nor touched.
- Three copies because the reset may overwrite one of them (in a test on
  hardware, 19 of 20 windows survived; the lost one was at 0x100000).
- Each file may be at most 120 bytes; a larger or empty file is ignored.

Ember loads the module once and never resets the IOP, so the copy in IOP RAM is
harmless there: the files are read from the card once, at start. For this to
work the program that starts the module (the Ember launcher) has to load the
memory card modules (rom0:XSIO2MAN, rom0:XMCMAN) BEFORE this module. Otherwise
mc0: answers "no device" and the defaults are used: the PS2 gets 192.168.1.10
and the server is looked up by broadcast, which fails on a LAN with another
address.


Transport behavior
------------------
After the discovery, packets go to the server as Ethernet unicast (the MAC
address is taken from the INFORM). The Ethernet link comes up seconds after
smap_init() returns; the client waits for it (up to 4 s) before the first
DISCOVERY, so no discovery window is spent without a link (cable unplugged).
Boot discovery sends DISCOVERY at short intervals first (6 packets over a 3 s
window, spaced 150, 150, 300, 600, 900, 900 ms).

All reads use BREAD. Unaligned reads (the VCD header, Ember's .bin) read the
head and tail through a one-sector cache per open file.


Behavior when the network or the server fails
---------------------------------------------
Each request is retried up to 4 times, the timeout doubling every time (about
1.5 s in total for open / getstat / close, 100-800 ms steps for BREAD). A NACK
from the server resynchronizes the sequence numbers. If the server does not
answer two requests in a row, a probe DISCOVERY runs: if the server restarted
(new data port) a new session starts, and a file whose server handle is no
longer valid is reopened by path.

Reads: a read that cannot be completed returns an error; after the connection
returns reading resumes by itself. Opening a file for reading while the server
is down fails at once, so a scan of many optional files does not stall.

Writes (WARNING, see README.MD):
- A write is sent in groups of at most 32 KiB, as chunks of up to 1400 bytes,
  each confirmed by an ACK; the server writes a group only when all its chunks
  arrived. The server cursor is moved with LSEEK before the group, so the same
  group can safely be sent again.
- If the network fails, the write waits and repeats: every 250 ms, up to 40
  times (about 10 s of waiting, a few seconds more counting the attempts). If the server lost the file handle (restart) the file
  is reopened by path (never created or truncated again) and the write goes on.
- Opening a file for writing, and closing it, also wait up to about 8 s
  (open) and 5 s (close) for the server. A read-only open does not wait.
- If the retries run out, the write returns an error (or, if part of it had
  gone through, a short count) and the file can be left incomplete.


Diagnostics
-----------
Build with "make DEBUG=1" to enable the IRX log. It is sent over UDP tty on
port 18194:

    nc -u -l 18194

Every operation of the "mass" device is logged with its result (open, close,
dopen, getstat, ..., "write -> N (retry n)" when a write is repeated).

Configuration messages (printed together with the INFORM line):

    UDPFS: cfg src: mc ip N srv M, stash K          first load: bytes read from the
                                                    memory card, copies written
    UDPFS: cfg src: stash K copies ip N srv M       second load: valid copies found
                                                    and bytes of each file
    UDPFS: PS2 IP a.b.c.d (IPCONFIG.DAT | default)
    UDPFS: server: a.b.c.d (UDPFSCONFIG.DAT)
    UDPFS: server: broadcast
    UDPFS: server: outside subnet, broadcast

Discovery messages:

    UDPFS: INFORM from <ip> port <p>, server <ip>, MAC <mac> (unicast | Ethernet broadcast)
    UDPFS: no INFORM accepted after 3 DISCOVERY packets (INFORMs seen: N)
    UDPFS: no reply to unicast, falling back to Ethernet broadcast
    UDPFS: server restarted (data port X -> Y), new session

Request failures:

    UDPFS: req seq N failed: rx A dseq B dport C port D mac E
                                       a request got no valid reply after all
                                       attempts (cable unplugged, server down);
                                       A = data packets received, B / C = packets
                                       dropped for wrong seq / wrong port, D =
                                       current data port, E = server MAC known

Start-up timing: once the client is ready, lines of the form

    UDPFS: t(ms) mc 3000 ip 3050 cfg 3100 dev9 700
    UDPFS: t(ms) smap 900 link 3200 disc 3500 ready 3500

show the milliseconds since the start of the module instance at each phase
(mc = memory card configuration read, cfg = config applied, dev9/smap =
hardware init, ip = PS2 IP set, link = Ethernet link up, disc = discovery
done).

Boot information (DEBUG=1): "UDPFS: args argc=N / UDPFS: argK [text]" lists
the arguments given to the module. POPStarter passes only argv[0] ("LBbyEE").

After changing the DEBUG build knob run "make clean".
