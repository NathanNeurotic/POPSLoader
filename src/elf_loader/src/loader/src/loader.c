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
/* NEWLIB_PORT_AWARE must precede fileXio_rpc.h so the fileXio function
 * prototypes are exposed for direct use (DISABLE_PATCHED_FUNCTIONS is
 * active here so POSIX open/read are not available). */
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
#define ORANGE_BG 0x00A5FF  // after SifIopReset
#define BROWN_BG 0x2A2AA5  // after SifIopSync
#define PURPBLE_BG 0x800080  // before ExecPS2
#define IOP_RESET_ARGS "rom0:UDNL rom0:EELOADCNF"


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
// Minimal ELF type definitions used by load_elf_via_filexio.
// (The parent project's elf.h is not available in this sub-build.)
//--------------------------------------------------------------
#define _LOADER_ELF_MAGIC    0x464c457fUL
#define _LOADER_ELF_PT_LOAD  1
#define _LOADER_ELF_PT_REGINFO 0x70000000UL /* PT_MIPS_REGINFO */
#define _LOADER_PFS_MAX_PHDRS 16

typedef struct {
	unsigned char ident[16];
	unsigned short type, machine;
	unsigned int version, entry, phoff, shoff, flags;
	unsigned short ehsize, phentsize, phnum, shentsize, shnum, shstrndx;
} _loader_elf_hdr_t;

typedef struct {
	unsigned int type, offset;
	void *vaddr;
	unsigned int paddr, filesz, memsz, flags, align;
} _loader_elf_phdr_t;

/* load_elf_via_filexio - load an ELF from a pfs: path using fileXio.
 *
 * SifLoadElf uses the old IOMAN service which cannot access iomanX-only
 * devices (pfs:, hdd:).  fileXio communicates with the iomanX IOP module
 * that has the pfs driver already loaded, so it can open pfs: paths
 * directly without mounting or an IOP reset.
 *
 * The caller must ensure the pfs: volume is still mounted (i.e. POPSLoader
 * must not have called fileXioUmount before handing off to this loader).
 *
 * Returns 0 on success, negative on error.
 * On success elfdata->epc is the entry point and elfdata->gp is the GP value
 * extracted from PT_MIPS_REGINFO (or 0 if not found).
 */
static int load_elf_via_filexio(const char *path, t_ExecData *elfdata)
{
	int fd;
	int i;
	int rc;
	static _loader_elf_hdr_t  ehdr;
	static _loader_elf_phdr_t phdrs[_LOADER_PFS_MAX_PHDRS];
	int num_phdrs;

	elfdata->epc = 0;
	elfdata->gp  = 0;

	rc = fileXioInit();
	if (rc < 0) {
		return -1;
	}

	fd = fileXioOpen(path, O_RDONLY, 0);
	if (fd < 0) {
		fileXioExit();
		return -2;
	}

	if (fileXioRead(fd, &ehdr, sizeof(ehdr)) != (int)sizeof(ehdr)) {
		fileXioClose(fd);
		fileXioExit();
		return -3;
	}
	if (*((unsigned int *)ehdr.ident) != _LOADER_ELF_MAGIC) {
		fileXioClose(fd);
		fileXioExit();
		return -4;
	}

	num_phdrs = (int)ehdr.phnum;
	if (num_phdrs > _LOADER_PFS_MAX_PHDRS)
		num_phdrs = _LOADER_PFS_MAX_PHDRS;

	if (fileXioLseek(fd, (int)ehdr.phoff, SEEK_SET) < 0) {
		fileXioClose(fd);
		fileXioExit();
		return -5;
	}
	if (fileXioRead(fd, phdrs, (int)sizeof(_loader_elf_phdr_t) * num_phdrs) <= 0) {
		fileXioClose(fd);
		fileXioExit();
		return -6;
	}

	for (i = 0; i < num_phdrs; i++) {
		if (phdrs[i].type == _LOADER_ELF_PT_LOAD) {
			if (phdrs[i].filesz > 0) {
				if (fileXioLseek(fd, (int)phdrs[i].offset, SEEK_SET) < 0 ||
				    fileXioRead(fd, phdrs[i].vaddr, (int)phdrs[i].filesz) != (int)phdrs[i].filesz) {
					fileXioClose(fd);
					fileXioExit();
					return -7;
				}
			}
			if (phdrs[i].memsz > phdrs[i].filesz) {
				memset((char *)phdrs[i].vaddr + phdrs[i].filesz, 0,
				       phdrs[i].memsz - phdrs[i].filesz);
			}
		} else if (phdrs[i].type == _LOADER_ELF_PT_REGINFO) {
			/* PT_MIPS_REGINFO: GP value is at offset +20 within the
			 * 24-byte Elf32_RegInfo structure. */
			unsigned int gp_val = 0;
			if (fileXioLseek(fd, (int)phdrs[i].offset + 20, SEEK_SET) >= 0)
				if (fileXioRead(fd, &gp_val, 4) == 4)
					elfdata->gp = (void *)(unsigned int)gp_val;
		}
	}

	fileXioClose(fd);
	fileXioExit();

	elfdata->epc = (void *)(unsigned int)ehdr.entry;
	return 0;
}


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

static void prepare_iop_reset_handoff(void)
{
	SifExitIopHeap();
	SifExitRpc();
	SifInitRpc(0);
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
	const char *load_path;
	static char target_arg_storage[1024];
	static char *target_argv[33];
	size_t target_arg_offset = 0;
	int target_argc = 0;
	int is_pfs_path = 0;
	int ret, i;

	elfdata.epc = 0;

	// argv[0]=partition prefix, argv[1]=path to ELF, argv[2..]=arguments
	if (argc < 2) {  
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	snprintf(partition_prefix, sizeof(partition_prefix), "%s", argv[0] ? argv[0] : "");
	snprintf(target_path, sizeof(target_path), "%s", argv[1] ? argv[1] : "");

	/* pfs: target_path: the ELF lives on an already-mounted PFS volume.
	 * full_path is the pfs: path itself; the target ELF args are argv[2..].
	 * We use fileXio (not SifLoadElf) and do NOT reset the IOP, because
	 * the HDD/pfs driver is still needed to read the ELF. */
	if (target_path[0] != '\0' &&
	    (strncmp(target_path, "pfs", 3) == 0 || strncmp(target_path, "PFS", 3) == 0)) {
		is_pfs_path = 1;
		snprintf(full_path, sizeof(full_path), "%s", target_path);
		/* For pfs: ELFs the caller placed the target args in argv[2..].
		 * POPSTARTER expects argv[0] = selector path. */
		target_argc = argc - 2;
		if (target_argc < 0) target_argc = 0;
		if (target_argc > 32) {
			return -E2BIG;
		}
		for (i = 2; i < argc; i++) {
			size_t arg_len = strlen(argv[i]) + 1;
			if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
				return -E2BIG;
			}
			memcpy(&target_arg_storage[target_arg_offset], argv[i], arg_len);
			target_argv[i - 2] = &target_arg_storage[target_arg_offset];
			target_arg_offset += arg_len;
		}
		target_argv[target_argc] = NULL;
	} else if (target_path[0] != '\0' &&
	           (strncmp(target_path, "hdd", 3) == 0 || strncmp(target_path, "HDD", 3) == 0)) {
		snprintf(full_path, sizeof(full_path), "%s", target_path);
		target_argc = argc - 1;
		if (target_argc > 32) {
			return -E2BIG;
		}
		target_argv[0] = full_path;
		for (i = 2; i < argc; i++) {
			size_t arg_len = strlen(argv[i]) + 1;
			if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
				return -E2BIG;
			}
			memcpy(&target_arg_storage[target_arg_offset], argv[i], arg_len);
			target_argv[i - 1] = &target_arg_storage[target_arg_offset];
			target_arg_offset += arg_len;
		}
		target_argv[target_argc] = NULL;
	} else {
		size_t partition_len = strlen(partition_prefix);
		size_t target_len = strlen(target_path);
		if (partition_len + target_len >= sizeof(full_path)) {
			return -ENAMETOOLONG;
		}
		memcpy(full_path, partition_prefix, partition_len);
		memcpy(full_path + partition_len, target_path, target_len + 1);
		target_argc = argc - 1;
		if (target_argc > 32) {
			return -E2BIG;
		}
		target_argv[0] = full_path;
		for (i = 2; i < argc; i++) {
			size_t arg_len = strlen(argv[i]) + 1;
			if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
				return -E2BIG;
			}
			memcpy(&target_arg_storage[target_arg_offset], argv[i], arg_len);
			target_argv[i - 1] = &target_arg_storage[target_arg_offset];
			target_arg_offset += arg_len;
		}
		target_argv[target_argc] = NULL;
	}
	load_path = full_path;

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

	if (is_pfs_path) {
		/* Load the ELF via fileXio — SifLoadElf (IOMAN) cannot access
		 * iomanX-only pfs: devices and will hang.  The pfs: volume is
		 * still mounted because elf.c's cleanup_for_embedded_loader only
		 * calls FlushCache, leaving SIF and fileXio state intact. */
		SET_GS_BGCOLOUR(GREEN_BG);
		ret = load_elf_via_filexio(load_path, &elfdata);
		SET_GS_BGCOLOUR(BLUE_BG);
		if (ret != 0 || elfdata.epc == 0) {
			SET_GS_BGCOLOUR(MAGENTA_BG);
			return -ENOENT;
		}
		SET_GS_BGCOLOUR(YELLOW_BG);
		/* No IOP reset: POPSTARTER handles its own IOP reset at startup.
		 * Resetting here would destroy the HDD modules still needed by
		 * POPSTARTER to access HDD game data. */
		FlushCache(0);
		FlushCache(2);
		SET_GS_BGCOLOUR(PURPBLE_BG);
		DPRINTF("POPS EXEC (pfs): argc=%d\n", target_argc);
		for (i = 0; i < target_argc; i++) {
			DPRINTF("POPS EXEC (pfs): argv[%d] = %s\n", i, target_argv[i]);
		}
		return ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, target_argc, target_argv);
	}

	SET_GS_BGCOLOUR(GREEN_BG);
	SifLoadFileInit();
	ret = SifLoadElf(load_path, &elfdata);
	SifLoadFileExit();
	SET_GS_BGCOLOUR(BLUE_BG);
	if (ret == 0 && elfdata.epc != 0) {
		SET_GS_BGCOLOUR(YELLOW_BG);

		// Let's reset IOP because ELF was already loaded in memory
		prepare_iop_reset_handoff();
		while(!SifIopReset(IOP_RESET_ARGS, 0)){};
		SET_GS_BGCOLOUR(ORANGE_BG);
		while (!SifIopSync()) {};

		SET_GS_BGCOLOUR(BROWN_BG);

	        SifInitRpc(0);
	        // Load modules.
	        SifLoadFileInit();
	        SifLoadModule("rom0:SIO2MAN", 0, NULL);
	        SifLoadModule("rom0:MCMAN", 0, NULL);
	        SifLoadModule("rom0:MCSERV", 0, NULL);
	        SifLoadFileExit();
	        SifExitRpc();

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
