/*
# _____     ___ ____     ___ ____
#  ____|   |    ____|   |        | |____|
# |     ___|   |____ ___|    ____| |    \    PS2DEV Open Source Project.
#-----------------------------------------------------------------------
# (c) 2020 Francisco Javier Trujillo Mata <fjtrujy@gmail.com>
# Licenced under Academic Free License version 2.0
# Review ps2sdk README & LICENSE files for further details.
*/

#include <string.h>
#include <sifrpc.h>
#include <stdio.h>
#include <kernel.h>
#include <sys/stat.h>
#include <stdbool.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <fileXio_rpc.h>

#include "elf.h"

#define DPRINTF(x...) printf(x)
// Loader ELF variables
extern u8 loader_elf[];
extern int size_loader_elf;

// ELF-loading stuff
#define ELF_MAGIC 0x464c457f
#define ELF_PT_LOAD 1

static bool file_exists(const char *filename) {
	iox_stat_t buffer;
	return (fileXioGetStat(filename, &buffer) == 0);
}

static char *store_arg(const char *src, char *storage, size_t storage_size, size_t *offset) {
	size_t len;
	char *dest;
	if (!src) return NULL;
	len = strlen(src) + 1;
	if ((*offset + len) > storage_size) {
		return NULL;
	}
	dest = &storage[*offset];
	memcpy(dest, src, len);
	*offset += len;
	return dest;
}

/* IMPORTANT: This method wipe memory where the loader is going to be allocated 
* This values come from the linkfile used by the loader.c
MEMORY {
	bios	: ORIGIN = 0x00000000, LENGTH = 528K --- 0x00000000 - 0x00084000: BIOS memory
	bram	: ORIGIN = 0x00084000, LENGTH = 496K --- 0x00084000 - 0x00100000: BIOS unused memory
	gram	: ORIGIN = 0x00100000, LENGTH =  31M --- 0x00100000 - 0x02000000: GAME memory
}
*/

static void wipe_bramMem(void) {
	int i;
	for (i = 0x00084000; i < 0x100000; i += 64) {
		asm volatile(
			"\tsq $0, 0(%0) \n"
			"\tsq $0, 16(%0) \n"
			"\tsq $0, 32(%0) \n"
			"\tsq $0, 48(%0) \n" ::"r"(i));
	}
}

int LoadELFFromFileWithPartition(const char *filename, int argc, char *argv[]) {
	u8 *boot_elf;
	elf_header_t *eh;
	elf_pheader_t *eph;
	void *pdata;
	int i;
	int new_argc = argc + 1;
	int fd = -1;
	static const int kMaxArgc = 32;
	static char *launch_argv[33];
	static char launch_arg_storage[2048];
	size_t storage_offset = 0;
	
	// We need to check that the ELF file before continue
	if (!file_exists(filename)) {
		return -1; // ELF file doesn't exists
	}
	// ELF Exists
	wipe_bramMem();

	DPRINTF("LAUNCH: BEGIN\n");
	DPRINTF("LAUNCH: popstarter path: %s\n", filename);
	fd = fileXioOpen(filename, O_RDONLY, 0);
	DPRINTF("LAUNCH: popstarter open rc=%d (fileXioOpen)\n", fd);
	if (fd >= 0) {
		fileXioClose(fd);
	} else {
		return fd;
	}
	for (i = 0; i < argc; i++) { DPRINTF("LAUNCH: argv[%d]: %s\n", i, argv[i]);}
	// Preparing filename and partition to be sent in the argv
	DPRINTF("LAUNCH: argv[0]: %s\n", filename);
	if (new_argc + 1 > kMaxArgc) {
		return -2;
	}
	char *stored_filename = store_arg(filename, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
	if (!stored_filename) {
		return -3;
	}
	launch_argv[0] = stored_filename;
	for (i = 1; i < new_argc; i++) {
		char *stored_arg = store_arg(argv[i - 1], launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
		if (!stored_arg) {
			return -3;
		}
		launch_argv[i] = stored_arg;
		DPRINTF("LAUNCH: argv[%d]: %s\n", i, launch_argv[i]);
	}
	launch_argv[new_argc] = NULL;
	
	/* NB: LOADER.ELF is embedded  */
	boot_elf = (u8 *)loader_elf;
	eh = (elf_header_t *)boot_elf;
	if (_lw((u32)&eh->ident) != ELF_MAGIC)
		asm volatile("break\n");

	eph = (elf_pheader_t *)(boot_elf + eh->phoff);

	/* Scan through the ELF's program headers and copy them into RAM, then zero out any non-loaded regions.  */
	for (i = 0; i < eh->phnum; i++) {
		if (eph[i].type != ELF_PT_LOAD)
			continue;

		pdata = (void *)(boot_elf + eph[i].offset);
		memcpy(eph[i].vaddr, pdata, eph[i].filesz);

		if (eph[i].memsz > eph[i].filesz)
			memset((void *)((u8 *)(eph[i].vaddr) + eph[i].filesz), 0, eph[i].memsz - eph[i].filesz);
	}

	/* Let's go.  */
	SifExitRpc();
	FlushCache(0);
	FlushCache(2);
	
	int rc = ExecPS2((void *)eh->entry, NULL, new_argc, launch_argv);
	DPRINTF("LAUNCH: RETURNED rc=%d\n", rc);
	return rc;
}

int LoadELFFromFile(const char *filename, int argc, char *argv[])
{
	return LoadELFFromFileWithPartition(filename, argc, argv);
}
