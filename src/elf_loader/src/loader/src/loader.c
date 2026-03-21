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
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fcntl.h>
#define DPRINTF(x...) printf(x)

#ifdef LOADER_ENABLE_DEBUG_COLORS
#define SET_GS_BGCOLOUR(colour) {*((volatile unsigned long int *)0x120000E0) = colour;}
#else
#define SET_GS_BGCOLOUR(colour)
#endif

// Color status helper in BGR format
#define WHITE_BG 0xFFFFFF // start main
#define CYAN_BG 0xFFFF00 // proper argc count
#define RED_BG  0x0000FF // wrong argc count
#define GREEN_BG 0x00FF00 // before SifLoadELF
#define BLUE_BG 0xFF0000 // after SifLoadELF
#define YELLOW_BG 0x00FFFF // good SifLoadELF return
#define MAGENTA_BG 0xFF00FF // wrong SifLoadELF return
#define ORANGE_BG 0x00A5FF  // after reset IOP
#define BROWN_BG 0x2A2AA5  // before FlushCache
#define PURPBLE_BG 0x800080  // before ExecPS2


//--------------------------------------------------------------
// Redefinition of init/deinit libc:
//--------------------------------------------------------------
// DON'T REMOVE is for reducing binary size. 
// These funtios are defined as weak in /libc/src/init.c
//--------------------------------------------------------------
   void _libcglue_init() {}
   void _libcglue_deinit() {}

   DISABLE_PATCHED_FUNCTIONS();
   DISABLE_EXTRA_TIMERS_FUNCTIONS();
   PS2_DISABLE_AUTOSTART_PTHREAD();

//--------------------------------------------------------------
//Start of function code:
//--------------------------------------------------------------
// Clear user memory
// PS2Link (C) 2003 Tord Lindstrom (pukko@home.se)
//         (C) 2003 adresd (adresd_ps2dev@yahoo.com)
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

#define ELF_MAGIC         0x464c457f
#define ELF_PT_LOAD       1
#define PT_MIPS_REGINFO   0x70000000

typedef struct {
	unsigned char ident[16];
	unsigned short type;
	unsigned short machine;
	unsigned int   version;
	unsigned int   entry;
	unsigned int   phoff;
	unsigned int   shoff;
	unsigned int   flags;
	unsigned short ehsize;
	unsigned short phentsize;
	unsigned short phnum;
	unsigned short shentsize;
	unsigned short shnum;
	unsigned short shstrndx;
} ldr_elf_ehdr;

typedef struct {
	unsigned int type;
	unsigned int offset;
	unsigned int vaddr;
	unsigned int paddr;
	unsigned int filesz;
	unsigned int memsz;
	unsigned int flags;
	unsigned int align;
} ldr_elf_phdr;

static int load_elf_via_filexio(const char *path, unsigned int *out_entry, unsigned int *out_gp)
{
	int fd, i;
	ldr_elf_ehdr ehdr;
	ldr_elf_phdr phdr;
	unsigned char reginfo[24];

	fd = fileXioOpen(path, O_RDONLY);
	if (fd < 0)
		return -1;

	if (fileXioRead(fd, &ehdr, sizeof(ehdr)) != (int)sizeof(ehdr)) {
		fileXioClose(fd);
		return -2;
	}
	if (*(unsigned int *)ehdr.ident != ELF_MAGIC) {
		fileXioClose(fd);
		return -3;
	}

	*out_entry = ehdr.entry;
	*out_gp = 0;

	for (i = 0; i < ehdr.phnum; i++) {
		fileXioLseek(fd, ehdr.phoff + i * sizeof(ldr_elf_phdr), SEEK_SET);
		if (fileXioRead(fd, &phdr, sizeof(phdr)) != (int)sizeof(phdr))
			continue;

		if (phdr.type == PT_MIPS_REGINFO && phdr.filesz >= 24) {
			fileXioLseek(fd, phdr.offset, SEEK_SET);
			if (fileXioRead(fd, reginfo, 24) == 24)
				*out_gp = *(unsigned int *)(reginfo + 20);
		}

		if (phdr.type != ELF_PT_LOAD || phdr.filesz == 0)
			continue;

		fileXioLseek(fd, phdr.offset, SEEK_SET);
		if (fileXioRead(fd, (void *)phdr.vaddr, phdr.filesz) != (int)phdr.filesz) {
			fileXioClose(fd);
			return -4;
		}
		if (phdr.memsz > phdr.filesz)
			memset((void *)(phdr.vaddr + phdr.filesz), 0, phdr.memsz - phdr.filesz);
	}

	fileXioClose(fd);
	return 0;
}

//--------------------------------------------------------------
//End of func:  void wipeUserMem(void)
//--------------------------------------------------------------
// *** MAIN ***
// 
//--------------------------------------------------------------
int main(int argc, char *argv[])
{
	SET_GS_BGCOLOUR(WHITE_BG);
	static t_ExecData elfdata;
	static char target_path[1024];
	static char target_arg_storage[1024];
	static char *target_argv[33];
	size_t target_arg_offset = 0;
	int target_argc = 0;
	int ret, i;

	elfdata.epc = 0;

	// argv[0]=path to ELF, argv[1..]=arguments
	if (argc < 2) {  
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	snprintf(target_path, sizeof(target_path), "%s", argv[0] ? argv[0] : "");
	target_argc = argc - 1;
	if (target_argc > 32) {
		return -E2BIG;
	}
	for (i = 1; i < argc; i++) {
		size_t arg_len = strlen(argv[i]) + 1;
		if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
			return -E2BIG;
		}
		memcpy(&target_arg_storage[target_arg_offset], argv[i], arg_len);
		target_argv[i - 1] = &target_arg_storage[target_arg_offset];
		target_arg_offset += arg_len;
	}
	target_argv[target_argc] = NULL;

	DPRINTF("> argv[0] = %s\n", argv[0]);
	for (i = 1; i < argc; i++) {
		DPRINTF("> argv[%d] = %s\n", i, argv[i]);
	}
	
	// new_argv[0] = argv[0];
	// new_argv[1] = argv[1];
	//new_argv[3] = argv[3];

	SET_GS_BGCOLOUR(CYAN_BG);

	// Initialize
	SifInitRpc(0);
	wipeUserMem();

	//Writeback data cache before loading ELF.
	FlushCache(0);

	// pfs: paths require fileXio (iomanX) - SifLoadElf (IOMAN) cannot access them.
	// Also skip IOP reset to preserve HDD modules already loaded by POPSLoader.
	if (strncmp(target_path, "pfs", 3) == 0) {
		unsigned int entry = 0, gp = 0;
		SET_GS_BGCOLOUR(GREEN_BG);
		fileXioInit();
		ret = load_elf_via_filexio(target_path, &entry, &gp);
		fileXioExit();
		SET_GS_BGCOLOUR(BLUE_BG);
		if (ret < 0 || entry == 0) {
			SET_GS_BGCOLOUR(MAGENTA_BG);
			SifExitRpc();
			return -ENOENT;
		}
		SET_GS_BGCOLOUR(PURPBLE_BG);
		DPRINTF("POPS EXEC (pfs): argc=%d\n", target_argc);
		for (i = 0; i < target_argc; i++) {
			DPRINTF("POPS EXEC (pfs): argv[%d] = %s\n", i, target_argv[i]);
		}
		FlushCache(0);
		FlushCache(2);
		return ExecPS2((void *)entry, (void *)gp, target_argc, target_argv);
	}

	SET_GS_BGCOLOUR(GREEN_BG);
	SifLoadFileInit();
	ret = SifLoadElf(target_path, &elfdata);
	SifLoadFileExit();
	SET_GS_BGCOLOUR(BLUE_BG);
	if (ret == 0 && elfdata.epc != 0) {
		SET_GS_BGCOLOUR(YELLOW_BG);

		// Let's reset IOP because ELF was already loaded in memory
		while(!SifIopReset(NULL, 0)){};
		while (!SifIopSync()) {};

		SET_GS_BGCOLOUR(ORANGE_BG);

        SifInitRpc(0);
        // Load modules.
        SifLoadFileInit();
        SifLoadModule("rom0:SIO2MAN", 0, NULL);
        SifLoadModule("rom0:MCMAN", 0, NULL);
        SifLoadModule("rom0:MCSERV", 0, NULL);
        SifLoadFileExit();
        SifExitRpc();

		SET_GS_BGCOLOUR(BROWN_BG);

		FlushCache(0);
		FlushCache(2);

		SET_GS_BGCOLOUR(PURPBLE_BG);
		
		DPRINTF("POPS EXEC: argc=%d\n", target_argc);
		for (i = 0; i < target_argc; i++) {
			DPRINTF("POPS EXEC: argv[%d] = %s\n", i, target_argv[i]);
		}
		return ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, target_argc, target_argv);
	} else {
		SET_GS_BGCOLOUR(MAGENTA_BG);
		SifExitRpc();
		return -ENOENT;
	}
}

//--------------------------------------------------------------
//End of func:  int main(int argc, char *argv[])
//--------------------------------------------------------------
//End of file:  loader.c
//--------------------------------------------------------------
