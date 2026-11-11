POPSLoader editorial note: the installation wording below clarifies the two
module destinations; driver binaries are the unmodified upstream 1.0.1 release.

UDP FS ASSAULT: CONFIGURATION AND BEHAVIOR
==========================================

The module reads its settings from optional files on the MEMORY CARD. There is
no USB drive: "mass:" is served entirely by the UDPFS server.

    IPCONFIG.DAT      the PS2's own address
    UDPFSCONFIG.DAT   the server address

Each file is looked up in this order, the first one found is used:

    mc0:/SYS-CONF/   then   mc1:/SYS-CONF/

    PATHMAP.INI          options (see below), looked up in
                      mc0:/POPSTARTER/   then   mc1:/POPSTARTER/

The files are independent. Without a file, the defaults below apply.


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


PATHMAP.INI - options
---------------------
Lines of the form KEY=VALUE. Empty lines and lines starting with # or ; are
ignored, keys are not case sensitive, spaces around = are ignored. A # or ; after
the value starts a comment (GAMEID_DIR=1 ; note is on). If a key is repeated the
last line counts. Unknown keys are ignored.

Three options, each one on only with the value 1 (anything else is off):

    GAMEID_DIR=1   Per-game folder named after the game ID
    DISCS_DIR=1    Per-game folders from POPS/DISCS_DIR.TXT (see below)
    CHEATS_WS=1    CHEATS_WS.TXT is read in place of CHEATS.TXT

Example:

    GAMEID_DIR=1
    DISCS_DIR=1

How the folder of a game is chosen
----------------------------------
POPStarter keeps the files of a game (SLOT0.VMC, SLOT1.VMC, CHEATS.TXT,
PATCH_*.BIN, TROJAN_*.BIN, BIOS.BIN, DISCS.TXT, VMCDIR.TXT, OSD.BIN, ...) in a
folder named after the VCD: POPS/<VCD name>/. The module can use another folder:
POPStarter does not know, it still asks for POPS/<VCD name>/..., the module
changes the path on its way to the server (POPS0..POPS9 work the same way). The
VCD file itself does not move. The folder is:

    DISCS_DIR  GAMEID_DIR  game in the list  game not in the list (or no list)
    ---------  ----------  ----------------  --------------------------------
        0          0       the VCD name      the VCD name       (POPStarter's own)
        0          1       the ID            the ID
        1          0       the list's value  the VCD name
        1          1       the list's value  the ID

If the ID is not found, the VCD name is used. A server that does not answer when
the list is asked for is treated like a missing list (the last column: the ID
with GAMEID_DIR=1, else the VCD name). Both GAMEID_DIR and DISCS_DIR make the
module read the ID.

GAMEID_DIR=1: the folder is POPS/<ID>/, e.g. POPS/SLUS_123.45/, whatever the VCD is
called.

- The ID is read from the disc image inside the VCD when POPStarter opens the
  first VCD (a VCD, or a .cue + .bin set; about 3 sector reads): the executable
  named on the BOOT line of SYSTEM.CNF, written as XXXX_NNN.NN (upper case, a
  hyphen becomes an underscore). A disc without a usable SYSTEM.CNF (or booting
  PSX.EXE) is recognised by the creation date of its volume, with a table of
  about 100 titles, mostly early Japanese ones. If no ID is found nothing is renamed and
  POPStarter's folder name is used.
- It is decided once per start of the module: the VCDs opened later (a disc
  change in a multi-disc game) do not change the folder.
- Each disc of a multi-disc game has its own ID, so each disc has its own folder
  (and its own VMC files).
- Without the file, or with GAMEID_DIR=0, nothing changes.
- To give the discs of a game one folder, see DISCS_DIR.TXT below.
- Adding a game to DISCS_DIR.TXT (or turning an option on or off) after it was
  played changes its folder: the memory cards in the old folder stay there and
  the game starts with new ones. Move the files to the new folder.
- Files you add yourself (cheats, patches, ...) go in POPS/<ID>/ on the server;
  POPStarter creates the folder, and the VMC files, when they are missing.
- The file is read like the others, at most 512 bytes; a larger file is ignored.

DISCS_DIR.TXT - one folder for the discs of a game
--------------------------------------------------
Optional, used only with DISCS_DIR=1. It is a file on the server, in the same folder as
the VCD (POPS/DISCS_DIR.TXT; for a VCD in POPS3, POPS3/DISCS_DIR.TXT). Lines of the
form ID=Folder, or ID1,ID2,...=Folder for several IDs at once:

    # Gran Turismo 2 (EU)
    SCES_023.80,SCES_123.80=Gran Turismo 2 (EU)

    # Grandia (USA), one line per ID works too
    SCUS_944.57=Grandia
    SCUS_944.65=Grandia

The game ID of the disc that was started is looked up and the folder is the
value of its line, so the discs of a game share one folder whichever disc is
started: POPS/Gran Turismo 2 (EU)/ here. Everything POPStarter keeps in the
game folder is shared by those discs: SLOT0.VMC, SLOT1.VMC, DISCS.TXT, CHEATS.TXT,
BIOS.BIN, TROJAN_n.BIN, PATCH_n.BIN, VMCDIR.TXT, OSD.BIN. Put in one folder only
the discs of the same game: these files are meant for one game.

- The ID is compared without upper/lower case and without punctuation:
  SCES_023.80, SCES-02380 and SCES02380 are the same ID. A list written for another
  tool (key=value, [sections]) can be used as it is.
- Empty lines and lines starting with #, ; or [ are ignored. Spaces around = and
  at the end of the line are ignored. The first line of an ID that is usable wins.
- With several IDs the line counts for each of them. An empty ID between commas
  ("A,,B", "A,", ",A") makes the whole line invalid: it is ignored, also for
  the other IDs of the line. Spaces around the commas are ignored. Each ID is at
  most 15 letters and digits (punctuation does not count).
- The folder is the name written after =, exactly as it is on the server: only
  the IDs are normalised, not the folder.
- The folder is a single name of at most 95 characters, without / \ or : and not
  "." or "..". A line with a value that is not usable is ignored (as if the ID
  was not listed). Lines longer than 511 characters are ignored
  (a line with 20 IDs and a title is about 250).
- An ID that is not listed, or no DISCS_DIR.TXT, gets the folder of the table
  above: the ID with GAMEID_DIR=1, else the VCD name. A server that does not answer
  when the list is asked for is treated like a missing list (the module tries a
  few times first).
- The list is read when the first VCD is opened, in pieces of 8 KB, up to its
  first 512 KB; a big list is fine (reading a 350 KB list to its end takes less
  than a second on the hardware tested), but keep the lines you use near the top.
- Several GAMES in one folder (to share the memory cards, e.g. a series) work too,
  but they would share the same two 128 KB cards and every file above, so for that
  POPStarter's own VMCDIR.TXT is better: it moves only the memory cards to
  another folder of POPS and the other files stay in each game's folder.
- DEBUG log: "UDPFS: discs_dir <folder>" when the line of the ID was found.

CHEATS_WS.TXT - cheats for widescreen
-------------------------------------
With CHEATS_WS=1, when POPStarter reads POPS/<game folder>/CHEATS.TXT the module
gives it POPS/<game folder>/CHEATS_WS.TXT instead, if that file exists; else the
normal CHEATS.TXT. It works with any of the folder choices above (CHEATS_WS.TXT is
looked for in the folder that is used).

- Both files present: CHEATS_WS.TXT is read and CHEATS.TXT is ignored. The two are
  not merged: put in CHEATS_WS.TXT all the cheats you want.
- Only the game folder is concerned: POPS/CHEATS.TXT, the one for all the games,
  is read as it is, and POPStarter loads it together with the file of the game.
- Only reading is changed. File names must be upper case, like POPStarter's.
- A game without CHEATS_WS.TXT keeps its CHEATS.TXT, so the option can stay on.
- DEBUG log: "UDPFS: cheats_ws /POPS/<folder>/CHEATS_WS.TXT" when it is used.

Server side
-----------
- The server must allow writing (udpfsd without -ro, or udpfs_server.py
  without --read-only).
- File and folder names are case sensitive on a Linux server: they must be
  exactly what the program asks for (for example POPS/<game>.VCD, or
  EMBER/games/<folder>/<name>.cue).
- A POPStarter game can be a `.cue` + `.bin` instead of a `.VCD`: put
  POPS/<game>.cue (or .CUE) and the .bin file(s) it names in the same folder.
  The module opens every .bin once at game start to learn its size (about
  10 ms per file).
- Every file the program used to find on the USB drive must be on the server.
  Missing optional files (TROJAN_*.BIN, PATCH_*.BIN, IGR_*.TM2, ...) are
  answered "not found" and the program goes on without them.


Which programs, and how the memory card is read
-----------------------------------------------
POPStarter needs the file mc?:/POPSTARTER/usbhdfsd.irx on the memory card to
start: use usbd_bd_assault.irx of the BDM Assault project, renamed to
usbhdfsd.irx. Copy it to mc?:/POPSTARTER/usbhdfsd.irx.
The UDPFS module (udp_fs_assault.irx) goes into mc?:/POPSTARTER/usbd.irx.

POPStarter loads this module twice: once before and once after an IOP reset.
In the first load the memory card is readable; after the reset the memory card
driver ("mc0:") is gone (opening it returns -19, ENODEV). The IOP reset does not
clear the IOP RAM, so the files are carried across it:

- First load (the memory card answers): the files are read and copied, with
  a signature and a checksum, into three windows of IOP RAM (0x1D0000, 0x1E0000
  and 0x1F0000, 256 bytes each) taken with AllocSysMemory at a fixed address, so
  nothing in use is overwritten. The copies are written also when the files do
  not exist, so an old copy is never reused.
- Second load (mc0: gives ENODEV): the first copy that passes the signature and
  checksum check is used and every valid copy is wiped. A damaged copy (another
  module wrote over it) is neither used nor touched.
- Three copies because the reset may overwrite one of them (in a test on
  hardware, 19 of 20 windows survived; the lost one was at 0x100000).
- IPCONFIG.DAT and UDPFSCONFIG.DAT may be at most 120 bytes each, PATHMAP.INI 512;
  a larger or empty file is ignored. Of PATHMAP.INI only the option bits are kept.

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

All reads use BREAD. Unaligned reads (Ember's .bin, the files after the first
one of a multi-file cue) read the head and tail through a one-sector cache
per open file. The header of a VCD built from a cue is served from RAM.


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

    UDPFS: cfg src: mc ip N srv M opt O, stash K    first load: bytes read from the
                                                    memory card, option bits (1 =
                                                    GAMEID_DIR, 2 = DISCS_DIR, 4 =
                                                    CHEATS_WS), copies written
    UDPFS: cfg src: stash K copies ip N srv M opt O second load: valid copies found,
                                                    bytes of each file, option bits
    UDPFS: PS2 IP a.b.c.d (IPCONFIG.DAT | default)
    UDPFS: server: a.b.c.d (UDPFSCONFIG.DAT)
    UDPFS: server: broadcast
    UDPFS: server: outside subnet, broadcast

Discovery messages:

    UDPFS: INFORM from <ip> port <p>, server <ip>, MAC <mac> (unicast | Ethernet broadcast)
    UDPFS: no INFORM accepted after 3 DISCOVERY packets (INFORMs seen: N)
    UDPFS: no reply to unicast, falling back to Ethernet broadcast
    UDPFS: server restarted (data port X -> Y), new session

Game ID folder (GAMEID_DIR=1 or DISCS_DIR=1), DEBUG build:

    UDPFS: gameid SLUS_123.45 (cnf | table)     found when the first VCD was opened
    UDPFS: gameid: not found                    no ID: the folder is not renamed
    UDPFS: discs_dir <folder>                   folder taken from POPS/DISCS_DIR.TXT
    UDPFS: discs_dir: -2                        no DISCS_DIR.TXT (or the error of the open)
    UDPFS: cheats_ws /POPS/<folder>/CHEATS_WS.TXT CHEATS_WS=1: that file is read
    UDPFS: map /POPS/<name>/X -> /POPS/<ID>/X   a path sent to the server renamed

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
