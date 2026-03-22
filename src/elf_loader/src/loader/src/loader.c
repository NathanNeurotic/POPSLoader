/*
# _____     ___ ____     ___ ____
#  ____|   |    ____|   |        | |____|
# |     ___|   |____ ___|    ____| |    \    PS2DEV Open Source Project.
#-----------------------------------------------------------------------
# (c) 2020 Francisco Javier Trujillo Mata <fjtrujy@gmail.com>
# Licenced under Academic Free License version 2.0
# Review ps2sdk README & LICENSE files for further details.
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <kernel.h>
#include <loadfile.h>
#include <iopcontrol.h>
#include <sifrpc.h>
#include <errno.h>
#include <ps2sdkapi.h>
#include <fcntl.h>
/* NEWLIB_PORT_AWARE must precede fileXio_rpc.h so fileXioOpen/etc. accept
 * POSIX-style flags (O_RDONLY = 0) rather than raw PS2 FIO flags. */
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>

#define DPRINTF(x...) printf(x)

#ifdef LOADER_ENABLE_DEBUG_COLORS
#define SET_GS_BGCOLOUR(colour) {*((volatile unsigned long int *)0x120000E0) = colour;}
#else
#define SET_GS_BGCOLOUR(colour)
#endif

/* GS background colour values (BGR format) used for progress tracing */
#define WHITE_BG   0xFFFFFF /* start of main()                          */
#define CYAN_BG    0xFFFF00 /* argv parsed OK                           */
#define RED_BG     0x0000FF /* bad argc                                 */
#define GREEN_BG   0x00FF00 /* before ELF load                          */
#define BLUE_BG    0xFF0000 /* after ELF load attempt                   */
#define YELLOW_BG  0x00FFFF /* ELF loaded OK                            */
#define MAGENTA_BG 0xFF00FF /* ELF load failed                          */
#define ORANGE_BG  0x00A5FF /* after IOP reset (non-pfs path only)      */
#define BROWN_BG   0x2A2AA5 /* before FlushCache                        */
#define PURPBLE_BG 0x800080 /* before ExecPS2                           */


//--------------------------------------------------------------
// Redefinition of init/deinit libc:
//--------------------------------------------------------------
// DON'T REMOVE — reduces binary size.
// These functions are defined as weak in /libc/src/init.c
//--------------------------------------------------------------
   void _libcglue_init() {}
   void _libcglue_deinit() {}

   DISABLE_PATCHED_FUNCTIONS();
   DISABLE_EXTRA_TIMERS_FUNCTIONS();
   PS2_DISABLE_AUTOSTART_PTHREAD();

//--------------------------------------------------------------
// ELF structures (redefined here; loader cannot include elf.h)
//--------------------------------------------------------------
#define LOADER_ELF_MAGIC        0x464c457fU
#define LOADER_PT_LOAD          1
#define LOADER_PT_MIPS_REGINFO  0x70000000U
#define LOADER_ELF_MAX_PHDRS    16

typedef struct {
	unsigned char  ident[16];
	unsigned short type, machine;
	unsigned int   version, entry, phoff, shoff, flags;
	unsigned short ehsize, phentsize, phnum, shentsize, shnum, shstrndx;
} loader_elf_hdr_t;

typedef struct {
	unsigned int type, offset;
	void        *vaddr;
	unsigned int paddr, filesz, memsz, flags, align;
} loader_elf_phdr_t;

//--------------------------------------------------------------
// Clear user memory (0x100000 .. RAM end).
// The embedded loader lives in BRAM (0x84000) and is unaffected.
// PS2Link (C) 2003 Tord Lindstrom / adresd
//--------------------------------------------------------------
static void wipeUserMem(void)
{
	int i;
	for (i = 0x100000; i < GetMemorySize(); i += 64) {
		asm volatile(
			"\tsq $0, 0(%0) \n"
			"\tsq $0, 16(%0) \n"
			"\tsq $0, 32(%0) \n"
			"\tsq $0, 48(%0) \n" ::"r"(i));
	}
}

//--------------------------------------------------------------
// load_elf_via_filexio
//
// Load a PS2 ELF directly into EE RAM using the fileXio RPC
// (iomanX-aware).  Used for pfs: paths; SifLoadElf uses IOMAN
// and cannot access iomanX pfs: mounts.
//
// fileXioInit() must have been called before entering this function.
// On success *entry_out and *gp_out are set.  Returns 0 on success,
// negative on error.
//--------------------------------------------------------------
static int load_elf_via_filexio(const char *path,
                                unsigned int *entry_out,
                                unsigned int *gp_out)
{
	int fd, i, n;
	static loader_elf_hdr_t  hdr;
	static loader_elf_phdr_t phdrs[LOADER_ELF_MAX_PHDRS];
	unsigned int gp = 0;

	*entry_out = 0;
	*gp_out    = 0;

	fd = fileXioOpen(path, O_RDONLY, 0);
	if (fd < 0) {
		DPRINTF("loader: fileXioOpen(%s) failed rc=%d\n", path, fd);
		return -1;
	}

	n = fileXioRead(fd, &hdr, sizeof(hdr));
	if (n != (int)sizeof(hdr) ||
	    *(unsigned int *)hdr.ident != LOADER_ELF_MAGIC) {
		DPRINTF("loader: ELF header invalid (n=%d)\n", n);
		fileXioClose(fd);
		return -2;
	}
	if (hdr.phnum == 0 || hdr.phnum > LOADER_ELF_MAX_PHDRS) {
		DPRINTF("loader: phnum=%d out of range\n", (int)hdr.phnum);
		fileXioClose(fd);
		return -3;
	}

	fileXioLseek(fd, hdr.phoff, SEEK_SET);
	n = fileXioRead(fd, phdrs, sizeof(loader_elf_phdr_t) * hdr.phnum);
	if (n != (int)(sizeof(loader_elf_phdr_t) * hdr.phnum)) {
		DPRINTF("loader: phdrs read failed\n");
		fileXioClose(fd);
		return -4;
	}

	for (i = 0; i < hdr.phnum; i++) {
		/* Extract GP from MIPS reginfo segment (offset +20 within the
		 * 24-byte reginfo struct holds the GP register value). */
		if (phdrs[i].type == LOADER_PT_MIPS_REGINFO) {
			unsigned int tmp_gp = 0;
			fileXioLseek(fd, phdrs[i].offset + 20, SEEK_SET);
			if (fileXioRead(fd, &tmp_gp, sizeof(tmp_gp)) == (int)sizeof(tmp_gp))
				gp = tmp_gp;
		}
		if (phdrs[i].type != LOADER_PT_LOAD || phdrs[i].filesz == 0)
			continue;
		fileXioLseek(fd, phdrs[i].offset, SEEK_SET);
		n = fileXioRead(fd, phdrs[i].vaddr, phdrs[i].filesz);
		if (n != (int)phdrs[i].filesz) {
			DPRINTF("loader: segment %d read failed (got %d want %d)\n",
			        i, n, (int)phdrs[i].filesz);
			fileXioClose(fd);
			return -5;
		}
		if (phdrs[i].memsz > phdrs[i].filesz)
			memset((void *)((unsigned int)phdrs[i].vaddr + phdrs[i].filesz),
			       0, phdrs[i].memsz - phdrs[i].filesz);
	}

	fileXioClose(fd);
	*entry_out = hdr.entry;
	*gp_out    = gp;
	return 0;
}

//--------------------------------------------------------------
// main
//
// Protocol (set by ExecuteViaEmbeddedLoader in elf.c):
//   argv[0]    = full path of ELF to load
//   argv[1..]  = arguments passed directly to the loaded ELF
//   target_argc = argc - 1
//   target_argv[0..] = argv[1..]
//
// For pfs: paths the ELF is loaded via fileXio (iomanX).
// For all other paths the original SifLoadElf + IOP-reset path is used.
//--------------------------------------------------------------
int main(int argc, char *argv[])
{
	SET_GS_BGCOLOUR(WHITE_BG);
	static t_ExecData    elfdata;
	static char          elf_path[1024];
	static char          target_arg_storage[1024];
	static char         *target_argv[33];
	size_t               target_arg_offset = 0;
	int                  target_argc = 0;
	int                  ret, i;

	elfdata.epc = 0;

	if (argc < 1 || argv[0] == NULL) {
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}

	snprintf(elf_path, sizeof(elf_path), "%s", argv[0]);
	target_argc = argc - 1;
	if (target_argc > 32) {
		SET_GS_BGCOLOUR(RED_BG);
		return -E2BIG;
	}
	for (i = 0; i < target_argc; i++) {
		size_t arg_len;
		if (argv[i + 1] == NULL) {
			target_argv[i] = NULL;
			continue;
		}
		arg_len = strlen(argv[i + 1]) + 1;
		if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
			SET_GS_BGCOLOUR(RED_BG);
			return -E2BIG;
		}
		memcpy(&target_arg_storage[target_arg_offset], argv[i + 1], arg_len);
		target_argv[i] = &target_arg_storage[target_arg_offset];
		target_arg_offset += arg_len;
	}
	target_argv[target_argc] = NULL;

	DPRINTF("> elf_path = %s\n", elf_path);
	for (i = 0; i < target_argc; i++)
		DPRINTF("> target_argv[%d] = %s\n", i,
		        target_argv[i] ? target_argv[i] : "(null)");

	SET_GS_BGCOLOUR(CYAN_BG);

	/* Reinitialise SIF in the embedded loader's own context, then wipe the
	 * user RAM region (0x100000+) that POPSLoader occupied. */
	SifInitRpc(0);
	wipeUserMem();
	FlushCache(0);

	if (strncmp(elf_path, "pfs", 3) == 0) {
		/*
		 * pfs: paths: load via fileXio (iomanX-aware).
		 * SifLoadElf uses IOMAN and cannot open iomanX pfs: mounts.
		 * Do NOT reset the IOP — the HDD modules loaded by POPSLoader
		 * must remain alive for fileXio to work; POPSTARTER will
		 * perform its own IOP reset when it starts.
		 */
		unsigned int entry = 0, gp = 0;
		SET_GS_BGCOLOUR(GREEN_BG);
		fileXioInit();
		ret = load_elf_via_filexio(elf_path, &entry, &gp);
		fileXioExit();
		SET_GS_BGCOLOUR(BLUE_BG);
		if (ret == 0 && entry != 0) {
			SET_GS_BGCOLOUR(YELLOW_BG);
			FlushCache(0);
			FlushCache(2);
			SET_GS_BGCOLOUR(PURPBLE_BG);
			DPRINTF("POPS EXEC (pfs): argc=%d\n", target_argc);
			for (i = 0; i < target_argc; i++)
				DPRINTF("POPS EXEC: argv[%d] = %s\n", i,
				        target_argv[i] ? target_argv[i] : "(null)");
			return ExecPS2((void *)entry, (void *)gp,
			               target_argc, target_argv);
		} else {
			SET_GS_BGCOLOUR(MAGENTA_BG);
			return -ENOENT;
		}
	}

	/* Non-pfs: use SifLoadElf and reset the IOP afterwards. */
	SET_GS_BGCOLOUR(GREEN_BG);
	SifLoadFileInit();
	ret = SifLoadElf(elf_path, &elfdata);
	SifLoadFileExit();
	SET_GS_BGCOLOUR(BLUE_BG);
	if (ret == 0 && elfdata.epc != 0) {
		SET_GS_BGCOLOUR(YELLOW_BG);

		while (!SifIopReset(NULL, 0)) {}
		while (!SifIopSync()) {}

		SET_GS_BGCOLOUR(ORANGE_BG);
		SifInitRpc(0);
		SifLoadFileInit();
		SifLoadModule("rom0:SIO2MAN", 0, NULL);
		SifLoadModule("rom0:MCMAN",   0, NULL);
		SifLoadModule("rom0:MCSERV",  0, NULL);
		SifLoadFileExit();
		SifExitRpc();

		SET_GS_BGCOLOUR(BROWN_BG);
		FlushCache(0);
		FlushCache(2);

		SET_GS_BGCOLOUR(PURPBLE_BG);
		DPRINTF("POPS EXEC: argc=%d\n", target_argc);
		for (i = 0; i < target_argc; i++)
			DPRINTF("POPS EXEC: argv[%d] = %s\n", i,
			        target_argv[i] ? target_argv[i] : "(null)");
		return ExecPS2((void *)elfdata.epc, (void *)elfdata.gp,
		               target_argc, target_argv);
	} else {
		SET_GS_BGCOLOUR(MAGENTA_BG);
		SifExitRpc();
		return -ENOENT;
	}
}
