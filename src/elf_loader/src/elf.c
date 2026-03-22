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
#include <sifcmd.h>
#include <stdio.h>
#include <kernel.h>
#include <loadfile.h>
#include <iopheap.h>
#include <iopcontrol.h>
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <sys/stat.h>
#include <stdbool.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include "../../include/dprintf.h"
#include "elf.h"

#define ELF_MAGIC 0x464c457f
#define ELF_PT_LOAD 1

extern unsigned char loader_elf[];

#define SET_GS_BGCOLOUR(colour) {*((volatile unsigned long int *)0x120000E0) = colour;}

/* Hardware-visible handoff stages in BGR format. Keep these aligned with
 * src/elf_loader/src/loader/src/loader.c so both direct and embedded HDD
 * launch paths report the same colours on hardware. */
#define LOAD_STAGE_BEFORE_SIFLOAD   0x00FF00
#define LOAD_STAGE_AFTER_SIFLOAD    0xFF0000
#define LOAD_STAGE_SIFLOAD_OK       0x00FFFF
#define LOAD_STAGE_SIFLOAD_FAILED   0xFF00FF
#define LOAD_STAGE_AFTER_IOP_RESET  0x00A5FF
#define LOAD_STAGE_AFTER_IOP_SYNC   0x2A2AA5
#define LOAD_STAGE_BEFORE_EXECPS2   0x800080
#define IOP_RESET_ARGS             "rom0:UDNL rom0:EELOADCNF"

static bool is_host_path(const char *filename) {
	return (filename != NULL && strncmp(filename, "host:/", 6) == 0);
}

static bool build_host_alt_path(const char *filename, char *out, size_t out_size) {
	if (!is_host_path(filename)) {
		return false;
	}
	snprintf(out, out_size, "host:%s", filename + 6);
	return true;
}

static bool can_open_exec_path(const char *filename) {
	int fd;
	if (filename == NULL || filename[0] == '\0') {
		return false;
	}
	fd = open(filename, O_RDONLY);
	if (fd < 0) {
		return false;
	}
	close(fd);
	return true;
}

static int resolve_exec_path(const char *filename, char *out, size_t out_size) {
	if (can_open_exec_path(filename)) {
		snprintf(out, out_size, "%s", filename);
		return 0;
	}
	if (build_host_alt_path(filename, out, out_size) && can_open_exec_path(out)) {
		return 0;
	}
	return -1;
}

static bool is_hdd_or_pfs_exec_path(const char *filename) {
	if (filename == NULL) {
		return false;
	}
	return strncmp(filename, "hdd", 3) == 0 ||
		strncmp(filename, "HDD", 3) == 0 ||
		strncmp(filename, "pfs", 3) == 0 ||
		strncmp(filename, "PFS", 3) == 0;
}

static void set_hdd_exec_stage_colour(const char *filename, unsigned long colour) {
	if (is_hdd_or_pfs_exec_path(filename)) {
		SET_GS_BGCOLOUR(colour);
	}
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

static bool build_partition_loader_target(const char *filename, const char *partition, char *out, size_t out_size) {
	size_t partition_len;
	const char *suffix;
	const char *suffix_colon;

	if (filename == NULL || partition == NULL || partition[0] == '\0' || out == NULL || out_size < 2) {
		return false;
	}

	partition_len = strlen(partition);
	if (partition_len == 0 || strncmp(filename, partition, partition_len) != 0) {
		return false;
	}

	suffix = filename + partition_len;
	suffix_colon = strchr(suffix, ':');
	if (suffix_colon == NULL || suffix_colon <= suffix + 2) {
		return false;
	}
	if (!((suffix[0] == 'p' || suffix[0] == 'P') &&
	      (suffix[1] == 'f' || suffix[1] == 'F') &&
	      (suffix[2] == 's' || suffix[2] == 'S'))) {
		return false;
	}

	snprintf(out, out_size, "%s", suffix);
	return true;
}

static void unmount_pfs_slots_for_exec(void) {
	char mount_name[6] = "pfs0:";
	int slot;
	for (slot = 0; slot <= 3; slot++) {
		mount_name[3] = '0' + slot;
		fileXioUmount(mount_name);
	}
}

static void cleanup_hdd_exec_handoff(void) {
	unmount_pfs_slots_for_exec();
	fileXioExit();
	SifExitIopHeap();
	SifExitRpc();
	SifExitCmd();
	FlushCache(0);
	FlushCache(2);
}

static void cleanup_for_embedded_loader(void) {
	SifExitIopHeap();
	SifExitRpc();
	SifExitCmd();
	FlushCache(0);
	FlushCache(2);
}

static void prepare_iop_reset_handoff(bool teardown_filexio) {
	if (teardown_filexio) {
		fileXioExit();
	}
	SifExitIopHeap();
	SifExitRpc();
	SifInitRpc(0);
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

static int ExecuteViaEmbeddedLoader(const char *resolved_path, int argc, char *argv[]) {
	int i;
	int final_argc = argc + 1;
	static const int kMaxArgc = 32;
	static char *launch_argv[33];
	static char launch_arg_storage[2048];
	size_t storage_offset = 0;
	u8 *boot_elf = (u8 *)&loader_elf;
	elf_header_t *boot_header = (elf_header_t *)boot_elf;
	elf_pheader_t *boot_pheader;

	if (argc <= 0 || argv == NULL || argv[0] == NULL) {
		return -4;
	}
	if (final_argc > kMaxArgc) {
		return -2;
	}
	if ((*(u32*)boot_header->ident) != ELF_MAGIC) {
		return -5;
	}

	launch_argv[0] = store_arg(resolved_path, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
	if (!launch_argv[0]) {
		return -3;
	}
	for (i = 0; i < argc; i++) {
		char *stored_arg = store_arg(argv[i], launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
		if (!stored_arg) {
			return -3;
		}
		launch_argv[i + 1] = stored_arg;
	}
	launch_argv[final_argc] = NULL;

	SifInitRpc(0);
	SifLoadFileInit();
	SifLoadFileExit();

	boot_pheader = (elf_pheader_t *)(boot_elf + boot_header->phoff);
	for (i = 0; i < boot_header->phnum; i++) {
		if (boot_pheader[i].type != ELF_PT_LOAD) {
			continue;
		}
		memcpy(boot_pheader[i].vaddr, boot_elf + boot_pheader[i].offset, boot_pheader[i].filesz);
		if (boot_pheader[i].memsz > boot_pheader[i].filesz) {
			memset((void *)((int)boot_pheader[i].vaddr + boot_pheader[i].filesz), 0, boot_pheader[i].memsz - boot_pheader[i].filesz);
		}
	}

	cleanup_for_embedded_loader();

	ExecPS2((void *)boot_header->entry, 0, final_argc, launch_argv);
	return -1;
}

static int ExecuteViaEmbeddedLoaderWithPartition(const char *partition, const char *resolved_path, int argc, char *argv[]) {
	int i;
	int final_argc = argc + 2;
	static const int kMaxArgc = 32;
	static char *launch_argv[33];
	static char launch_arg_storage[2048];
	size_t storage_offset = 0;
	u8 *boot_elf = (u8 *)&loader_elf;
	elf_header_t *boot_header = (elf_header_t *)boot_elf;
	elf_pheader_t *boot_pheader;

	if (argc <= 0 || argv == NULL || argv[0] == NULL) {
		return -4;
	}
	if (final_argc > kMaxArgc) {
		return -2;
	}
	if ((*(u32*)boot_header->ident) != ELF_MAGIC) {
		return -5;
	}

	launch_argv[0] = store_arg(partition != NULL ? partition : "", launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
	if (!launch_argv[0]) {
		return -3;
	}
	launch_argv[1] = store_arg(resolved_path, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
	if (!launch_argv[1]) {
		return -3;
	}
	for (i = 0; i < argc; i++) {
		char *stored_arg = store_arg(argv[i], launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
		if (!stored_arg) {
			return -3;
		}
		launch_argv[i + 2] = stored_arg;
	}
	launch_argv[final_argc] = NULL;

	SifInitRpc(0);
	SifLoadFileInit();
	SifLoadFileExit();

	boot_pheader = (elf_pheader_t *)(boot_elf + boot_header->phoff);
	for (i = 0; i < boot_header->phnum; i++) {
		if (boot_pheader[i].type != ELF_PT_LOAD) {
			continue;
		}
		memcpy(boot_pheader[i].vaddr, boot_elf + boot_pheader[i].offset, boot_pheader[i].filesz);
		if (boot_pheader[i].memsz > boot_pheader[i].filesz) {
			memset((void *)((int)boot_pheader[i].vaddr + boot_pheader[i].filesz), 0, boot_pheader[i].memsz - boot_pheader[i].filesz);
		}
	}

	cleanup_for_embedded_loader();

	ExecPS2((void *)boot_header->entry, 0, final_argc, launch_argv);
	return -1;
}

static int LoadELFFromFileInternal(const char *filename, const char *partition, int argc, char *argv[], bool keep_partition_in_argv0) {
	int i;
	int new_argc = 1;
	int fd = -1;
	static const int kMaxArgc = 32;
	static char *launch_argv[33];
	static char launch_arg_storage[2048];
	char resolved_path[256];
	char loader_target[256];
	size_t storage_offset = 0;
	bool use_default_argv0 = false;
	const char *embedded_loader_path = resolved_path;
	
	// We need to check that the ELF file before continue
	if (resolve_exec_path(filename, resolved_path, sizeof(resolved_path)) < 0) {
		return -1; // ELF file doesn't exists
	}
	// ELF Exists
	wipe_bramMem();

	DPRINTF("LAUNCH: BEGIN\n");
	if (strcmp(resolved_path, filename) != 0) {
		DPRINTF("LAUNCH: popstarter path: %s (resolved to %s)\n", filename, resolved_path);
	} else {
		DPRINTF("LAUNCH: popstarter path: %s\n", resolved_path);
	}
	fd = open(resolved_path, O_RDONLY);
	DPRINTF("LAUNCH: popstarter open rc=%d (open)\n", fd);
	if (fd >= 0) {
		close(fd);
	} else {
		return fd;
	}
	DPRINTF("LAUNCH: argc_in=%d argv_ptr=%s\n", argc, argv ? "set" : "null");
	use_default_argv0 = (argc <= 0 || argv == NULL || argv[0] == NULL);
	new_argc = use_default_argv0 ? 1 : argc;
	if (new_argc > kMaxArgc) {
		return -2;
	}
	char *stored_filename = store_arg(resolved_path, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
	if (!stored_filename) {
		return -3;
	}
	if (use_default_argv0) {
		launch_argv[0] = stored_filename;
	} else {
		for (i = 0; i < new_argc; i++) {
			const char *arg = argv[i];
			if (arg == NULL) {
				continue;
			}
			char *stored_arg = store_arg(arg, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
			if (!stored_arg) {
				return -3;
			}
			launch_argv[i] = stored_arg;
		}
	}
	launch_argv[new_argc] = NULL;

	DPRINTF("LAUNCH: Using LoadExecPS2\n");
	DPRINTF("LAUNCH: exec path=%s\n", resolved_path);
	DPRINTF("LAUNCH: argc=%d\n", new_argc);
	DPRINTF("LAUNCH: argv0_final=%s\n", launch_argv[0] ? launch_argv[0] : "(null)");
	DPRINTF("LAUNCH: argv1=%s\n", launch_argv[1] ? launch_argv[1] : "(null)");
	DPRINTF("LAUNCH: argv2_is_null=%s\n", launch_argv[2] == NULL ? "yes" : "no");
	if (!use_default_argv0 && is_hdd_or_pfs_exec_path(resolved_path)) {
		DPRINTF("LAUNCH: Using embedded loader%s\n", keep_partition_in_argv0 ? " (partition-aware)" : "");
		if (keep_partition_in_argv0) {
			if (build_partition_loader_target(resolved_path, partition, loader_target, sizeof(loader_target))) {
				embedded_loader_path = loader_target;
			}
			return ExecuteViaEmbeddedLoaderWithPartition(partition, embedded_loader_path, new_argc, launch_argv);
		}
		return ExecuteViaEmbeddedLoader(resolved_path, new_argc, launch_argv);
	}
	/* LoadExecPS2 should not return on success. */
	LoadExecPS2(resolved_path, new_argc, launch_argv);
	DPRINTF("LAUNCH: RETURNED rc=%d\n", -1);
	return -1;
}

int LoadELFFromFileWithPartition(const char *filename, const char *partition, int argc, char *argv[])
{
	return LoadELFFromFileInternal(filename, partition, argc, argv, true);
}

int LoadELFFromFile(const char *filename, int argc, char *argv[])
{
	return LoadELFFromFileInternal(filename, NULL, argc, argv, false);
}

int LoadELFFromFileExecPS2(const char *filename, int argc, char *argv[])
{
	t_ExecData elfdata;
	char resolved_path[256];
	int ret;

	if (argc <= 0 || argv == NULL || argv[0] == NULL) {
		return -4;
	}
	if (resolve_exec_path(filename, resolved_path, sizeof(resolved_path)) < 0) {
		return -1;
	}
	DPRINTF("LAUNCH: Using ExecPS2\n");
	DPRINTF("POPSTARTER ExecPS2 argv0=%s\n", argv[0]);

	SifInitRpc(0);
	SifLoadFileInit();
	ret = SifLoadElf(resolved_path, &elfdata);
	SifLoadFileExit();

	if (ret != 0 || elfdata.epc == 0) {
		return -2;
	}

	if (is_hdd_or_pfs_exec_path(resolved_path)) {
		cleanup_hdd_exec_handoff();
	} else {
		SifExitIopHeap();
		SifExitRpc();
		SifExitCmd();
		FlushCache(0);
		FlushCache(2);
	}

	ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, argc, argv);
	return -1;
}


int LoadELFFromFileExecPS2RebootIOP(const char *filename, int argc, char *argv[])
{
	t_ExecData elfdata;
	char resolved_path[256];
	int ret;

	if (resolve_exec_path(filename, resolved_path, sizeof(resolved_path)) < 0) {
		return -1;
	}

	DPRINTF("LAUNCH: Using ExecPS2RebootIOP\n");
	DPRINTF("LAUNCH: exec path=%s\n", resolved_path);
	DPRINTF("LAUNCH: argc=%d\n", argc);
	DPRINTF("LAUNCH: argv0=%s\n", (argc > 0 && argv != NULL && argv[0] != NULL) ? argv[0] : "(null)");

	set_hdd_exec_stage_colour(resolved_path, LOAD_STAGE_BEFORE_SIFLOAD);
	SifInitRpc(0);
	SifLoadFileInit();
	ret = SifLoadElf(resolved_path, &elfdata);
	SifLoadFileExit();
	set_hdd_exec_stage_colour(resolved_path, LOAD_STAGE_AFTER_SIFLOAD);
	DPRINTF("LAUNCH: SifLoadElf ret=%d epc=%p gp=%p\n", ret, (void *)elfdata.epc, (void *)elfdata.gp);

	if (ret != 0 || elfdata.epc == 0) {
		set_hdd_exec_stage_colour(resolved_path, LOAD_STAGE_SIFLOAD_FAILED);
		return -2;
	}
	set_hdd_exec_stage_colour(resolved_path, LOAD_STAGE_SIFLOAD_OK);

	prepare_iop_reset_handoff(is_hdd_or_pfs_exec_path(resolved_path));
	FlushCache(0);
	while (!SifIopReset(IOP_RESET_ARGS, 0)) {
	}
	set_hdd_exec_stage_colour(resolved_path, LOAD_STAGE_AFTER_IOP_RESET);
	while (!SifIopSync()) {
	}
	set_hdd_exec_stage_colour(resolved_path, LOAD_STAGE_AFTER_IOP_SYNC);

	SifInitRpc(0);
	SifLoadFileInit();
	SifLoadModule("rom0:SIO2MAN", 0, NULL);
	SifLoadModule("rom0:MCMAN", 0, NULL);
	SifLoadModule("rom0:MCSERV", 0, NULL);
	SifLoadFileExit();
	SifExitRpc();

	FlushCache(0);
	FlushCache(2);

	set_hdd_exec_stage_colour(resolved_path, LOAD_STAGE_BEFORE_EXECPS2);
	DPRINTF("LAUNCH: ExecPS2 argc=%d argv0=%s\n", argc, (argc > 0 && argv != NULL && argv[0] != NULL) ? argv[0] : "(null)");
	ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, argc, argv);
	return -1;
}
