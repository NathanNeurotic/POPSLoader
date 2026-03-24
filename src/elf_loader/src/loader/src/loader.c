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
#include <iopheap.h>
#include <iopcontrol.h>
#include <sifrpc.h>
#include <errno.h>
#include <ps2sdkapi.h>
#include <fcntl.h>
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
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

static int load_elf_via_filexio(const char *path,
                                unsigned int *entry_out,
                                unsigned int *gp_out)
{
	int fd;
	int i;
	int n;
	static loader_elf_hdr_t hdr;
	static loader_elf_phdr_t phdrs[LOADER_ELF_MAX_PHDRS];
	unsigned int gp = 0;

	*entry_out = 0;
	*gp_out = 0;

	fd = fileXioOpen(path, O_RDONLY, 0);
	if (fd < 0 && (strncmp(path, "hdd", 3) == 0 || strncmp(path, "HDD", 3) == 0)) {
		const char *first_colon = strchr(path, ':');
		const char *second_colon = first_colon ? strchr(first_colon + 1, ':') : NULL;
		if (second_colon != NULL &&
		    (strncmp(second_colon + 1, "pfs", 3) == 0 ||
		     strncmp(second_colon + 1, "PFS", 3) == 0)) {
			fd = fileXioOpen(second_colon + 1, O_RDONLY, 0);
		}
	}
	if (fd < 0) {
		return -1;
	}

	n = fileXioRead(fd, &hdr, sizeof(hdr));
	if (n != (int)sizeof(hdr) || *(unsigned int *)hdr.ident != LOADER_ELF_MAGIC) {
		fileXioClose(fd);
		return -2;
	}
	if (hdr.phnum == 0 || hdr.phnum > LOADER_ELF_MAX_PHDRS) {
		fileXioClose(fd);
		return -3;
	}

	fileXioLseek(fd, hdr.phoff, SEEK_SET);
	n = fileXioRead(fd, phdrs, sizeof(loader_elf_phdr_t) * hdr.phnum);
	if (n != (int)(sizeof(loader_elf_phdr_t) * hdr.phnum)) {
		fileXioClose(fd);
		return -4;
	}

	for (i = 0; i < hdr.phnum; i++) {
		if (phdrs[i].type == LOADER_PT_MIPS_REGINFO) {
			unsigned int tmp_gp = 0;
			fileXioLseek(fd, phdrs[i].offset + 20, SEEK_SET);
			if (fileXioRead(fd, &tmp_gp, sizeof(tmp_gp)) == (int)sizeof(tmp_gp)) {
				gp = tmp_gp;
			}
		}
		if (phdrs[i].type != LOADER_PT_LOAD || phdrs[i].filesz == 0) {
			continue;
		}
		fileXioLseek(fd, phdrs[i].offset, SEEK_SET);
		n = fileXioRead(fd, phdrs[i].vaddr, phdrs[i].filesz);
		if (n != (int)phdrs[i].filesz) {
			fileXioClose(fd);
			return -5;
		}
		if (phdrs[i].memsz > phdrs[i].filesz) {
			memset((void *)((unsigned int)phdrs[i].vaddr + phdrs[i].filesz),
			       0, phdrs[i].memsz - phdrs[i].filesz);
		}
	}

	fileXioClose(fd);
	*entry_out = hdr.entry;
	*gp_out = gp;
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
	static char partition_prefix[1024];
	static char target_path[1024];
	static char full_path[1024];
	static char target_arg_storage[1024];
	static char *target_argv[33];
	size_t target_arg_offset = 0;
	int target_argc = 0;
	int ret, i;

	elfdata.epc = 0;

	// argv[0]=partition prefix, argv[1]=path to ELF, argv[2..]=arguments
	if (argc < 2) {  
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	snprintf(partition_prefix, sizeof(partition_prefix), "%s", argv[0] ? argv[0] : "");
	snprintf(target_path, sizeof(target_path), "%s", argv[1] ? argv[1] : "");
	snprintf(full_path, sizeof(full_path), "%s%s", partition_prefix, target_path);
	target_argc = argc - 1;
	if (target_argc > 32) {
		return -E2BIG;
	}
	target_argv[0] = &target_arg_storage[0];
	snprintf(target_argv[0], sizeof(target_arg_storage), "%s", full_path);
	target_arg_offset = strlen(target_argv[0]) + 1;
	for (i = 2; i < argc; i++) {
		const char *arg = argv[i] ? argv[i] : "";
		size_t arg_len = strlen(arg) + 1;
		if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
			return -E2BIG;
		}
		memcpy(&target_arg_storage[target_arg_offset], arg, arg_len);
		target_argv[i - 1] = &target_arg_storage[target_arg_offset];
		target_arg_offset += arg_len;
	}
	target_argv[target_argc] = NULL;

	DPRINTF("> argv[0] = %s\n", argv[0]);
	for (i = 1; i < argc; i++) {
		DPRINTF("> argv[%d] = %s\n", i, argv[i]);
	}
	
	SET_GS_BGCOLOUR(CYAN_BG);

	// Initialize
	SifInitRpc(0);
	wipeUserMem();

	//Writeback data cache before loading ELF.
	FlushCache(0);
	SET_GS_BGCOLOUR(GREEN_BG);
	SifLoadFileInit();
	ret = SifLoadElf(target_path, &elfdata);
	SifLoadFileExit();
	SET_GS_BGCOLOUR(BLUE_BG);
	if (ret != 0 || elfdata.epc == 0) {
		/* SifLoadElf failed — expected for pfs: paths since rom0:LOADFILE
		   uses ioman which cannot access PFS (registered with iomanX only).
		   Fall back to loading the ELF directly via fileXio. */
		unsigned int fio_entry = 0, fio_gp = 0;
		DPRINTF("SifLoadElf failed (ret=%d epc=%u), trying fileXio\n", ret, elfdata.epc);
		fileXioInit();
		if (load_elf_via_filexio(target_path, &fio_entry, &fio_gp) == 0 && fio_entry != 0) {
			elfdata.epc = fio_entry;
			elfdata.gp = fio_gp;
			DPRINTF("fileXio load OK: epc=0x%08x gp=0x%08x\n", fio_entry, fio_gp);
		} else {
			DPRINTF("fileXio load also failed\n");
			SET_GS_BGCOLOUR(MAGENTA_BG);
			SifExitRpc();
			return -ENOENT;
		}
	}
	SET_GS_BGCOLOUR(YELLOW_BG);

	FlushCache(0);
	while (!SifIopReset(NULL, 0)) {
	}
	while (!SifIopSync()) {
	}
	SET_GS_BGCOLOUR(ORANGE_BG);

	SifInitRpc(0);
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
}

//--------------------------------------------------------------
//End of func:  int main(int argc, char *argv[])
//--------------------------------------------------------------
//End of file:  loader.c
//--------------------------------------------------------------
