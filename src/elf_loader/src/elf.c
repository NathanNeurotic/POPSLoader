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
#include <ctype.h>
#include <kernel.h>
#include <loadfile.h>
#include <iopheap.h>
#include <iopcontrol.h>
#include <audsrv.h>
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
#define SET_GS_BGCOLOUR(colour) {*((volatile unsigned long int *)0x120000E0) = colour;}
#define EXECDBG_WHITE 0xFFFFFF
#define EXECDBG_GREEN 0x00FF00
#define EXECDBG_BLUE 0xFF0000
#define EXECDBG_YELLOW 0x00FFFF
#define EXECDBG_MAGENTA 0xFF00FF
#define EXECDBG_ORANGE 0x00A5FF
#define EXECDBG_CORAL 0x507FFF
#define EXECDBG_GRAY 0x808080
#define EXECDBG_LIME 0x00FF80
#define EXECDBG_PINK 0xCBC0FF
#define EXECDBG_AQUA 0xFFFF80
#define EXECDBG_GOLD 0x00D7FF
#define EXECDBG_TAN 0x8CB4D2
#define EXECDBG_BROWN 0x2A2AA5

extern unsigned char loader_elf[];
extern void gsKit_finish(void);

int LoadELFFromFileExecPS2RebootIOP(const char *filename, int argc, char *argv[]);

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

static bool starts_with_casefold(const char *value, const char *prefix) {
	if (value == NULL || prefix == NULL) {
		return false;
	}
	while (*prefix != '\0') {
		if (*value == '\0') {
			return false;
		}
		if (tolower((unsigned char)*value) != tolower((unsigned char)*prefix)) {
			return false;
		}
		value++;
		prefix++;
	}
	return true;
}

static bool parse_embedded_hdd_exec_path(const char *path, char *out_partition, size_t out_partition_size, char *out_target_path, size_t out_target_size) {
	const char *first_colon;
	const char *second_colon;
	const char *relpath;
	size_t device_len;
	size_t part_len;

	if (path == NULL || out_partition == NULL || out_target_path == NULL || out_partition_size == 0 || out_target_size == 0) {
		return false;
	}
	if (!starts_with_casefold(path, "hdd")) {
		return false;
	}

	first_colon = strchr(path, ':');
	if (first_colon == NULL) {
		return false;
	}

	second_colon = strchr(first_colon + 1, ':');
	if (second_colon != NULL) {
		const char *suffix = second_colon + 1;
		if (starts_with_casefold(suffix, "pfs")) {
			const char *pfs_colon = strchr(suffix, ':');
			if (pfs_colon == NULL) {
				return false;
			}
			relpath = pfs_colon + 1;
		} else {
			relpath = suffix;
		}
		device_len = (size_t)(first_colon - path);
		part_len = (size_t)(second_colon - (first_colon + 1));
	} else {
		const char *slash = strchr(first_colon + 1, '/');
		if (slash == NULL) {
			return false;
		}
		relpath = slash + 1;
		device_len = (size_t)(first_colon - path);
		part_len = (size_t)(slash - (first_colon + 1));
	}

	while (*relpath == '/') {
		relpath++;
	}
	if (*relpath == '\0' || device_len == 0 || part_len == 0) {
		return false;
	}

	snprintf(out_partition, out_partition_size, "%.*s:%.*s", (int)device_len, path, (int)part_len, first_colon + 1);
	snprintf(out_target_path, out_target_size, "pfs0:/%s", relpath);
	return true;
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

static void unmount_pfs_slots_for_exec(void) {
	char mount_name[6] = "pfs0:";
	int slot;
	for (slot = 0; slot <= 3; slot++) {
		mount_name[3] = '0' + slot;
		fileXioUmount(mount_name);
	}
}

static int ExecuteViaEmbeddedLoader(const char *resolved_path, const char *partition, int argc, char *argv[]) {
	int i;
	int arg_base = 1;
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
	if (partition != NULL && partition[0] != '\0') {
		final_argc += 1;
		arg_base = 2;
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
	if (arg_base == 2) {
		launch_argv[1] = store_arg(partition, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
		if (!launch_argv[1]) {
			return -3;
		}
	}
	for (i = 0; i < argc; i++) {
		char *stored_arg = store_arg(argv[i], launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
		if (!stored_arg) {
			return -3;
		}
		launch_argv[i + arg_base] = stored_arg;
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

	SifExitRpc();
	SifExitCmd();
	audsrv_quit();
	gsKit_finish();
	FlushCache(0);
	FlushCache(2);

	ExecPS2((void *)boot_header->entry, 0, final_argc, launch_argv);
	return -1;
}

int LoadELFFromFileWithPartition(const char *filename, int argc, char *argv[]) {
	int i;
	int new_argc = 1;
	int fd = -1;
	static const int kMaxArgc = 32;
	static char *launch_argv[33];
	static char launch_arg_storage[2048];
	char embedded_partition[256];
	char embedded_target_path[1024];
	char resolved_path[256];
	size_t storage_offset = 0;
	bool use_default_argv0 = false;

	if (parse_embedded_hdd_exec_path(filename, embedded_partition, sizeof(embedded_partition), embedded_target_path, sizeof(embedded_target_path))) {
		wipe_bramMem();
		DPRINTF("LAUNCH: Using embedded HDD loader path=%s partition=%s\n", embedded_target_path, embedded_partition);
		return ExecuteViaEmbeddedLoader(embedded_target_path, embedded_partition, argc, argv);
	}
	
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
	audsrv_quit();
	gsKit_finish();
	FlushCache(0);
	FlushCache(2);
	/* LoadExecPS2 should not return on success. */
	LoadExecPS2(resolved_path, new_argc, launch_argv);
	DPRINTF("LAUNCH: RETURNED rc=%d\n", -1);
	return -1;
}

int LoadELFFromFile(const char *filename, int argc, char *argv[])
{
	return LoadELFFromFileWithPartition(filename, argc, argv);
}

int LoadELFFromFileExecPS2(const char *filename, int argc, char *argv[])
{
	t_ExecData elfdata;
	char resolved_path[256];
	int ret;

	SET_GS_BGCOLOUR(EXECDBG_WHITE);
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
	SET_GS_BGCOLOUR(EXECDBG_GREEN);
	ret = SifLoadElf(resolved_path, &elfdata);
	SifLoadFileExit();
	SET_GS_BGCOLOUR(EXECDBG_BLUE);

	if (ret != 0 || elfdata.epc == 0) {
		SET_GS_BGCOLOUR(EXECDBG_MAGENTA);
		return -2;
	}

	SET_GS_BGCOLOUR(EXECDBG_YELLOW);
	SifExitIopHeap();
	SifExitRpc();
	SifExitCmd();
	audsrv_quit();
	gsKit_finish();
	FlushCache(0);
	FlushCache(2);
	ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, argc, argv);
	return -1;
}


int LoadELFFromFileExecPS2RebootIOP(const char *filename, int argc, char *argv[])
{
	t_ExecData elfdata;
	char resolved_path[256];
	int ret;

	SET_GS_BGCOLOUR(EXECDBG_WHITE);
	if (resolve_exec_path(filename, resolved_path, sizeof(resolved_path)) < 0) {
		SET_GS_BGCOLOUR(EXECDBG_MAGENTA);
		return -1;
	}

	SifInitRpc(0);
	SifLoadFileInit();
	SET_GS_BGCOLOUR(EXECDBG_GREEN);
	ret = SifLoadElf(resolved_path, &elfdata);
	SifLoadFileExit();
	SET_GS_BGCOLOUR(EXECDBG_BLUE);

	if (ret != 0 || elfdata.epc == 0) {
		SET_GS_BGCOLOUR(EXECDBG_MAGENTA);
		return -2;
	}

	SET_GS_BGCOLOUR(EXECDBG_YELLOW);
	FlushCache(0);
	SET_GS_BGCOLOUR(EXECDBG_ORANGE);
	unmount_pfs_slots_for_exec();
	fileXioExit();
	SifExitIopHeap();
	SifLoadFileExit();
	SifExitRpc();
	SifExitCmd();
	SifInitRpc(0);
	SET_GS_BGCOLOUR(EXECDBG_CORAL);
	while (!SifIopReset("rom0:UDNL rom0:EELOADCNF", 0)) {
	}
	SET_GS_BGCOLOUR(EXECDBG_GRAY);
	while (!SifIopSync()) {
	}

	SET_GS_BGCOLOUR(EXECDBG_LIME);
	SifInitRpc(0);
	SET_GS_BGCOLOUR(EXECDBG_PINK);
	SifLoadFileInit();
	SET_GS_BGCOLOUR(EXECDBG_AQUA);
	SifLoadModule("rom0:SIO2MAN", 0, NULL);
	SET_GS_BGCOLOUR(EXECDBG_GOLD);
	SifLoadModule("rom0:MCMAN", 0, NULL);
	SET_GS_BGCOLOUR(EXECDBG_TAN);
	SifLoadModule("rom0:MCSERV", 0, NULL);
	SET_GS_BGCOLOUR(EXECDBG_BROWN);
	SifLoadFileExit();
	SifExitRpc();

	FlushCache(0);
	FlushCache(2);

	ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, argc, argv);
	return -1;
}
