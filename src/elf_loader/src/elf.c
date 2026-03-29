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
#include <fileio.h>
#include "../../include/dprintf.h"
#include "elf.h"

#define ELF_MAGIC 0x464c457f
#define ELF_PT_LOAD 1
extern unsigned char loader_elf[];
static unsigned int s_exec_keep_pfs_mask = 0;

void SetExecKeepPfsMask(unsigned int mask) {
	s_exec_keep_pfs_mask = mask & 0x0F;
}

void ClearExecKeepPfsMask(void) {
	s_exec_keep_pfs_mask = 0;
}

static unsigned int GetExecKeepPfsMask(void) {
	return s_exec_keep_pfs_mask & 0x0F;
}

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

static void unmount_pfs_slots_for_exec(unsigned int keep_mask) {
	char mount_name[6] = "pfs0:";
	int slot;
	for (slot = 0; slot <= 3; slot++) {
		if ((keep_mask & (1U << slot)) != 0) {
			continue;
		}
		mount_name[3] = '0' + slot;
		fileXioUmount(mount_name);
	}
}

static unsigned int build_exec_keep_mask(const char *resolved_path) {
	(void)resolved_path;
	return GetExecKeepPfsMask() & 0x0F;
}

static bool is_hdd_backed_exec_path(const char *path) {
	return (path != NULL &&
	        (strncmp(path, "hdd", 3) == 0 || strncmp(path, "pfs", 3) == 0));
}

static int ExecuteViaEmbeddedLoader(const char *resolved_path, const char *source_context, int argc, char *argv[]);
int LoadELFFromFileExecPS2RebootIOPWithContext(const char *filename, const char *source_context, int argc, char *argv[]);

static int extract_exec_pfs_slot(const char *path) {
	if (path != NULL && strncmp(path, "pfs", 3) == 0) {
		const char *prefix = path + 3;
		if (*prefix == ':') {
			return 0;
		}
		if (*prefix >= '0' && *prefix <= '3' && prefix[1] == ':') {
			return *prefix - '0';
		}
	}
	return -1;
}

static int mount_hdd_exec_partition(const char *partition, int slot) {
	char mount_name[6] = "pfs0:";

	if (partition == NULL || slot < 0 || slot > 3) {
		return -1;
	}

	mount_name[3] = '0' + slot;
	if (fileXioMount(mount_name, partition, FIO_MT_RDONLY) < 0) {
		fileXioUmount(mount_name);
		if (fileXioMount(mount_name, partition, FIO_MT_RDONLY) < 0) {
			return -1;
		}
	}

	return 0;
}

static const char *extract_exec_relpath(const char *path) {
	const char *relpath;
	const char *prefix_end;

	if (path == NULL) {
		return NULL;
	}
	if (strncmp(path, "pfs", 3) == 0) {
		prefix_end = strchr(path, ':');
		if (prefix_end == NULL) {
			return NULL;
		}
		relpath = prefix_end + 1;
		while (*relpath == '/') {
			relpath++;
		}
		return (*relpath != '\0') ? relpath : NULL;
	}
	if (strncmp(path, "hdd", 3) == 0) {
		const char *partition_end = strchr(path + 5, ':');
		const char *fs_prefix_end = partition_end ? strchr(partition_end + 1, ':') : NULL;
		if (fs_prefix_end == NULL) {
			return NULL;
		}
		relpath = fs_prefix_end + 1;
		while (*relpath == '/') {
			relpath++;
		}
		return (*relpath != '\0') ? relpath : NULL;
	}
	return NULL;
}

static int build_hdd_embedded_loader_target_from_partition(const char *resolved_path, const char *partition_context, char *load_path, size_t load_path_size, unsigned int *keep_mask_out) {
	char partition[128];
	const char *relpath;
	size_t partition_len;

	if (resolved_path == NULL || partition_context == NULL || load_path == NULL || keep_mask_out == NULL) {
		return -1;
	}
	if (strncmp(partition_context, "hdd", 3) != 0) {
		return -1;
	}

	partition_len = strlen(partition_context);
	while (partition_len > 0 && partition_context[partition_len - 1] == ':') {
		partition_len--;
	}
	if (partition_len == 0 || partition_len >= sizeof(partition)) {
		return -1;
	}
	memcpy(partition, partition_context, partition_len);
	partition[partition_len] = '\0';

	relpath = extract_exec_relpath(resolved_path);
	if (relpath == NULL) {
		return -1;
	}

	if (mount_hdd_exec_partition(partition, 0) != 0) {
		return -1;
	}

	snprintf(load_path, load_path_size, "pfs0:/%s", relpath);
	if (!can_open_exec_path(load_path)) {
		return -1;
	}

	*keep_mask_out = 0x01;
	return 0;
}

static int build_hdd_embedded_loader_target_from_hdd_path(const char *source_path, char *load_path, size_t load_path_size, unsigned int *keep_mask_out) {
	const char *partition_end;
	char partition_context[128];
	size_t partition_len;

	if (source_path == NULL || load_path == NULL || keep_mask_out == NULL) {
		return -1;
	}

	if (strncmp(source_path, "hdd", 3) != 0) {
		return -1;
	}

	partition_end = strchr(source_path + 5, ':');
	if (partition_end == NULL) {
		return -1;
	}
	partition_len = (size_t)(partition_end - source_path) + 1;
	if (partition_len == 0 || partition_len >= sizeof(partition_context)) {
		return -1;
	}
	memcpy(partition_context, source_path, partition_len);
	partition_context[partition_len] = '\0';
	return build_hdd_embedded_loader_target_from_partition(source_path, partition_context, load_path, load_path_size, keep_mask_out);
}

static int build_hdd_embedded_loader_target(const char *resolved_path, const char *source_context, char *load_path, size_t load_path_size, unsigned int *keep_mask_out) {
	if (source_context != NULL && strncmp(source_context, "hdd", 3) == 0) {
		if (build_hdd_embedded_loader_target_from_partition(resolved_path, source_context, load_path, load_path_size, keep_mask_out) == 0) {
			return 0;
		}
	}

	if (resolved_path != NULL && strncmp(resolved_path, "pfs", 3) == 0) {
		int slot = extract_exec_pfs_slot(resolved_path);
		if (slot < 0 || slot > 3) {
			return -1;
		}
		snprintf(load_path, load_path_size, "%s", resolved_path);
		*keep_mask_out = (1U << slot);
		return 0;
	}

	if (resolved_path != NULL && strncmp(resolved_path, "hdd", 3) == 0) {
		return build_hdd_embedded_loader_target_from_hdd_path(resolved_path, load_path, load_path_size, keep_mask_out);
	}

	return -1;
}

static int ExecuteHddBackedViaEmbeddedLoader(const char *requested_path, const char *resolved_path, const char *source_context_override, int argc, char *argv[]) {
	char load_path[256];
	const char *source_context;
	unsigned int previous_keep_mask;
	unsigned int required_keep_mask;
	int ret;

	if (argc <= 0 || argv == NULL || argv[0] == NULL) {
		return -4;
	}

	source_context = source_context_override;
	if (source_context == NULL || source_context[0] == '\0') {
		source_context = requested_path;
	}
	if (source_context == NULL || source_context[0] == '\0') {
		source_context = resolved_path;
	}

	if (build_hdd_embedded_loader_target(resolved_path, source_context, load_path, sizeof(load_path), &required_keep_mask) != 0) {
		return -1;
	}

	previous_keep_mask = GetExecKeepPfsMask();
	SetExecKeepPfsMask(previous_keep_mask | required_keep_mask);
	ret = ExecuteViaEmbeddedLoader(load_path, source_context, argc, argv);
	SetExecKeepPfsMask(previous_keep_mask);
	return ret;
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

static int ExecuteViaEmbeddedLoader(const char *resolved_path, const char *source_context, int argc, char *argv[]) {
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

	launch_argv[0] = store_arg(resolved_path, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
	if (!launch_argv[0]) {
		return -3;
	}
	launch_argv[1] = store_arg(source_context != NULL ? source_context : resolved_path, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
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

	/* Repo-local HDD diagnostics previously narrowed one failure boundary to
	 * tearing down EE RPC right before the jump into the embedded loader.
	 * Keep the mounted pfs0: handoff minimal here, but leave EE RPC state
	 * intact across the final ExecPS2 boundary.
	 */
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
	char resolved_path[256];
	size_t storage_offset = 0;
	bool use_default_argv0 = false;
	
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

	if (is_hdd_backed_exec_path(resolved_path)) {
		/* SifLoadElf has already copied the ELF into EE RAM. For HDD-backed
		 * handoff, drop stale PFS/SIF state before ExecPS2 so POPSTARTER
		 * starts with the same clean runtime expected by the other HDD
		 * launch paths.
		 */
		unmount_pfs_slots_for_exec(build_exec_keep_mask(resolved_path));
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
	return LoadELFFromFileExecPS2RebootIOPWithContext(filename, NULL, argc, argv);
}

int LoadELFFromFileExecPS2RebootIOPWithContext(const char *filename, const char *source_context, int argc, char *argv[])
{
	t_ExecData elfdata;
	char resolved_path[256];
	int ret;

	if (resolve_exec_path(filename, resolved_path, sizeof(resolved_path)) < 0) {
		return -1;
	}

	if ((is_hdd_backed_exec_path(resolved_path) || is_hdd_backed_exec_path(source_context)) &&
	    argc > 0 && argv != NULL && argv[0] != NULL) {
		return ExecuteHddBackedViaEmbeddedLoader(filename, resolved_path, source_context, argc, argv);
	}

	SifInitRpc(0);
	SifLoadFileInit();
	ret = SifLoadElf(resolved_path, &elfdata);
	SifLoadFileExit();

	if (ret != 0 || elfdata.epc == 0) {
		return -2;
	}

	if (is_hdd_backed_exec_path(resolved_path)) {
		unmount_pfs_slots_for_exec(build_exec_keep_mask(resolved_path));
	}

	FlushCache(0);
	while (!SifIopReset("", 0)) {
	}
	while (!SifIopSync()) {
	}

	SifInitRpc(0);
	SifLoadFileInit();
	SifLoadModule("rom0:SIO2MAN", 0, NULL);
	SifLoadModule("rom0:MCMAN", 0, NULL);
	SifLoadModule("rom0:MCSERV", 0, NULL);
	SifLoadFileExit();
	SifExitRpc();

	FlushCache(0);
	FlushCache(2);

	ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, argc, argv);
	return -1;
}
