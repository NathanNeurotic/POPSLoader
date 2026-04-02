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
#include <sbv_patches.h>
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

/* Embedded IOP module binaries for HDD access (loaded via SifExecModuleBuffer) */
extern unsigned char iomanX_irx[];
extern unsigned int size_iomanX_irx;
extern unsigned char fileXio_irx[];
extern unsigned int size_fileXio_irx;
extern unsigned char ps2dev9_irx[];
extern unsigned int size_ps2dev9_irx;
extern unsigned char ps2atad_irx[];
extern unsigned int size_ps2atad_irx;
extern unsigned char ps2hdd_osd_irx[];
extern unsigned int size_ps2hdd_osd_irx;
extern unsigned char ps2fs_irx[];
extern unsigned int size_ps2fs_irx;

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
	if (filename != NULL && filename[0] != '/' && strchr(filename, ':') == NULL) {
		char cwd[256];
		if (getcwd(cwd, sizeof(cwd)) != NULL) {
			snprintf(out, out_size, "%s%s%s", cwd, (cwd[strlen(cwd)-1] == '/' || cwd[strlen(cwd)-1] == ':') ? "" : "/", filename);
			if (can_open_exec_path(out)) {
				return 0;
			}
		}
	}
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

static void load_post_reset_modules(void) {
	sbv_patch_enable_lmb();
	sbv_patch_disable_prefix_check();
	SifLoadModule("rom0:SIO2MAN", 0, NULL);
	SifLoadModule("rom0:CDVDFSV", 0, NULL);
	SifLoadModule("rom0:CDVDMAN", 0, NULL);
	SifLoadModule("rom0:MCMAN", 0, NULL);
	SifLoadModule("rom0:MCSERV", 0, NULL);
	SifLoadModule("rom0:PADMAN", 0, NULL);
}

static void prepare_reboot_exec_environment(void) {
	FlushCache(0);
	while (!SifIopReset("rom0:UDNL rom0:EELOADCNF", 0)) {
	}
	while (!SifIopSync()) {
	}

	SifExitIopHeap();
	SifLoadFileExit();
	SifExitRpc();
	SifExitCmd();

	SifInitRpc(0);
	SifLoadFileInit();
	load_post_reset_modules();
	SifExitIopHeap();
	SifLoadFileExit();
	SifExitRpc();
	SifExitCmd();

	FlushCache(0);
	FlushCache(2);
}

static bool is_hdd_backed_exec_path(const char *path) {
	return (path != NULL &&
	        (strncmp(path, "hdd", 3) == 0 || strncmp(path, "pfs", 3) == 0));
}

/* Extract HDD partition name (e.g., "hdd0:partition" from "hdd0:partition:file.elf") */
static bool extract_hdd_partition_prefix(const char *path, char *out, size_t out_size) {
	const char *partition_end;
	size_t partition_len;

	if (path == NULL || strncmp(path, "hdd", 3) != 0) {
		return false;
	}
	/* Find second ':' in hdd0:partition:... format */
	partition_end = strchr(path + 5, ':');
	if (partition_end == NULL) {
		return false;
	}
	partition_len = (size_t)(partition_end - path);
	if (partition_len >= out_size) {
		return false;
	}
	memcpy(out, path, partition_len);
	out[partition_len] = '\0';
	return true;
}

static int ExecuteViaEmbeddedLoader(const char *partition_context, const char *load_path, int argc, char *argv[]);
int LoadELFFromFileExecPS2RebootIOPWithPartition(const char *filename, const char *partition, int argc, char *argv[]);

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
	const char *relpath;
	char partition_name[256];
	size_t partition_len;

	if (resolved_path == NULL || partition_context == NULL || load_path == NULL || keep_mask_out == NULL) {
		return -1;
	}
	if (strncmp(partition_context, "hdd", 3) != 0) {
		return -1;
	}

	relpath = extract_exec_relpath(resolved_path);
	if (relpath == NULL) {
		return -1;
	}

	partition_len = strlen(partition_context);
	while (partition_len > 0 && partition_context[partition_len - 1] == ':') {
		partition_len--;
	}
	if (partition_len == 0 || partition_len >= sizeof(partition_name)) {
		return -1;
	}

	memcpy(partition_name, partition_context, partition_len);
	partition_name[partition_len] = '\0';

	fileXioInit();
	/* Critical: The target partition might already be mounted on pfs1:, pfs2:, or pfs3:
	   by the background Lua scanner. PS2 PFS strictly blocks duplicate block mounts.
	   We MUST force-unmount all other slots before attempting to mount it to pfs0:. */
	unmount_pfs_slots_for_exec(1);

	fileXioUmount("pfs0:");
	if (fileXioMount("pfs0:", partition_name, FIO_MT_RDONLY) < 0) {
		fileXioUmount("pfs0:");
		if (fileXioMount("pfs0:", partition_name, FIO_MT_RDONLY) < 0) {
			return -1;
		}
	}

	snprintf(load_path, load_path_size, "pfs0:/%s", relpath);
	/* Retain pfs0: so the embedded child loader can read the target ELF from it.
	   unmount_pfs_slots_for_exec will preserve this bit mask slot. */
	*keep_mask_out = 1;
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

static int build_hdd_embedded_loader_target(const char *resolved_path, const char *partition_context, char *load_path, size_t load_path_size, unsigned int *keep_mask_out) {
	if (partition_context != NULL && strncmp(partition_context, "hdd", 3) == 0) {
		return build_hdd_embedded_loader_target_from_partition(resolved_path, partition_context, load_path, load_path_size, keep_mask_out);
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

static int ExecuteHddBackedViaEmbeddedLoader(const char *resolved_path, const char *partition_context_override, int argc, char *argv[]) {
	char load_path[256];
	const char *partition_context;
	unsigned int previous_keep_mask;
	unsigned int required_keep_mask;
	int ret;

	partition_context = partition_context_override;
	if ((partition_context == NULL || partition_context[0] == '\0') &&
	    resolved_path != NULL && strncmp(resolved_path, "hdd", 3) == 0) {
		static char derived_partition[128];
		const char *partition_end = strchr(resolved_path + 5, ':');
		size_t partition_len = partition_end != NULL ? (size_t)(partition_end - resolved_path) + 1 : 0;
		if (partition_len > 0 && partition_len < sizeof(derived_partition)) {
			memcpy(derived_partition, resolved_path, partition_len);
			derived_partition[partition_len] = '\0';
			partition_context = derived_partition;
		}
	}

	if (build_hdd_embedded_loader_target(resolved_path, partition_context, load_path, sizeof(load_path), &required_keep_mask) != 0) {
		return -1;
	}

	previous_keep_mask = GetExecKeepPfsMask();
	SetExecKeepPfsMask(previous_keep_mask | required_keep_mask);

	/* Unmount ALL PFS slots EXCEPT the one needed for the embedded loader target.
	   Note: build_hdd_embedded_loader_target_from_partition pre-emptively unmounts
	   them to guarantee pfs0: mount success. Doing it again here is a harmless no-op
	   that enforces the keep mask cleanly across all codepaths. */
	unmount_pfs_slots_for_exec(required_keep_mask);

	ret = ExecuteViaEmbeddedLoader(partition_context != NULL ? partition_context : "", load_path, argc, argv);
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

static int ExecuteViaEmbeddedLoader(const char *partition_context, const char *load_path, int argc, char *argv[]) {
	int i;
	int ret;
	int extra_argc = (argc > 0 && argv != NULL) ? argc : 0;
	int final_argc = extra_argc + 2;
	static const int kMaxArgc = 34;
	static char *launch_argv[35];
	static char launch_arg_storage[2048];
	size_t storage_offset = 0;
	u8 *boot_elf = (u8 *)&loader_elf;
	elf_header_t *boot_header = (elf_header_t *)boot_elf;
	elf_pheader_t *boot_pheader;

	if (final_argc > kMaxArgc) {
		return -2;
	}
	if ((*(u32*)boot_header->ident) != ELF_MAGIC) {
		return -5;
	}

	/* The embedded loader is linked into BRAM. Keep the original BRAM wipe
	 * contract before copying its segments there.
	 */
	wipe_bramMem();

	launch_argv[0] = store_arg(partition_context != NULL ? partition_context : "", launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
	if (!launch_argv[0]) {
		return -3;
	}
	launch_argv[1] = store_arg(load_path, launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
	if (!launch_argv[1]) {
		return -3;
	}
	for (i = 0; i < extra_argc; i++) {
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

	SifExitRpc();
	FlushCache(0);
	FlushCache(2);

	ret = ExecPS2((void *)boot_header->entry, 0, final_argc, launch_argv);
	return (ret != 0) ? ret : -3600;
}

int LoadELFFromFileWithPartition(const char *filename, const char *partition, int argc, char *argv[]) {
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

	if (partition != NULL && partition[0] != '\0') {
		return ExecuteViaEmbeddedLoader(partition, resolved_path, argc, argv);
	}

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
	return LoadELFFromFileWithPartition(filename, NULL, argc, argv);
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
	return LoadELFFromFileExecPS2RebootIOPWithPartition(filename, NULL, argc, argv);
}

int LoadELFFromFileExecPS2RebootIOPWithPartition(const char *filename, const char *partition, int argc, char *argv[])
{
	char resolved_path[256];
	int resolve_result;
	int ret;
	t_ExecData elfdata;
	char partition_context[128];
	size_t partition_len;
	bool is_hdd_popstarter;

	/* Check if args are valid for execution */
	bool has_valid_args = (argc == 0 || (argc > 0 && argv != NULL && argv[0] != NULL));

	/* Check if this is HDD-backed POPSTARTER scenario (both filename and partition point to HDD) */
	is_hdd_popstarter = (has_valid_args &&
	                     partition != NULL && partition[0] != '\0' &&
	                     is_hdd_backed_exec_path(partition) &&
	                     filename != NULL && is_hdd_backed_exec_path(filename));

	resolve_result = resolve_exec_path(filename, resolved_path, sizeof(resolved_path));

	/* Simplify: Check if partition context explicitly indicates HDD.
	   If partition parameter has HDD prefix (hdd0:, dvr_hdd0:), treat as HDD load.
	   Otherwise, check filename and resolved_path for HDD paths to extract partition context. */
	bool has_explicit_hdd_partition = (partition != NULL && partition[0] != '\0' &&
	                                    ((strncmp(partition, "hdd", 3) == 0 && partition[3] >= '0' && partition[3] <= '9') ||
	                                     (strncmp(partition, "dvr_hdd", 7) == 0 && partition[7] >= '0' && partition[7] <= '9')));

	bool is_hdd_scenario = (has_valid_args &&
	                        (has_explicit_hdd_partition ||
	                         (filename != NULL && is_hdd_backed_exec_path(filename)) ||
	                         (resolve_result >= 0 && is_hdd_backed_exec_path(resolved_path))));

	/* ARCHITECTURAL FIX (GitHub Issue D-10):
	   The parent-context HDD ELF loading path violated a fundamental PS2 constraint:
	   RPC client connections created in one EE context become INVALID in another EE
	   context after ExecPS2(). This caused POPSTARTER to have no fileXio RPC client,
	   resulting in black screen (unable to access files, no debug output).

	   Solution: Route all HDD execution through the embedded loader, which properly
	   initializes RPC in its own context. This is proven to work by:
	   1. The embedded loader itself (loader.c:375-503)
	   2. Reference implementations (wLaunchELF, Enceladus, etc.)

	   The embedded loader expects partition info in argv[0] and will handle HDD setup.
	*/
	if (is_hdd_scenario) {
		/* Extract partition context and relative path for embedded loader */
		char hdd_relpath[1024];
		const char *relpath_src = NULL;

		if (has_explicit_hdd_partition) {
			partition_len = strlen(partition);
			while (partition_len > 0 && partition[partition_len - 1] == ':') {
				partition_len--;
			}
			if (partition_len >= sizeof(partition_context)) {
				return -1;
			}
			memcpy(partition_context, partition, partition_len);
			partition_context[partition_len] = '\0';
			relpath_src = filename;
		} else if (filename != NULL && strncmp(filename, "hdd", 3) == 0) {
			const char *partition_end = strchr(filename + 5, ':');
			if (partition_end == NULL) {
				partition_end = strchr(filename + 5, '/');
			}
			if (partition_end == NULL) {
				return -1;
			}
			partition_len = (size_t)(partition_end - filename);
			if (partition_len >= sizeof(partition_context)) {
				return -1;
			}
			memcpy(partition_context, filename, partition_len);
			partition_context[partition_len] = '\0';
			while (partition_len > 0 &&
			       (partition_context[partition_len - 1] == ':' ||
			        partition_context[partition_len - 1] == '/')) {
				partition_len--;
				partition_context[partition_len] = '\0';
			}
			relpath_src = partition_end;
		} else if (resolve_result >= 0 && strncmp(resolved_path, "hdd", 3) == 0) {
			const char *partition_end = strchr(resolved_path + 5, ':');
			if (partition_end == NULL) {
				partition_end = strchr(resolved_path + 5, '/');
			}
			if (partition_end == NULL) {
				return -1;
			}
			partition_len = (size_t)(partition_end - resolved_path);
			if (partition_len >= sizeof(partition_context)) {
				return -1;
			}
			memcpy(partition_context, resolved_path, partition_len);
			partition_context[partition_len] = '\0';
			while (partition_len > 0 &&
			       (partition_context[partition_len - 1] == ':' ||
			        partition_context[partition_len - 1] == '/')) {
				partition_len--;
				partition_context[partition_len] = '\0';
			}
			relpath_src = partition_end;
		} else {
			return -1;
		}

		/* Extract relative path: skip leading ':' or '/' and everything before it */
		if (relpath_src != NULL && relpath_src[0] != '\0') {
			/* Skip any leading ':' or '/' characters */
			while (relpath_src[0] == ':' || relpath_src[0] == '/') {
				relpath_src++;
			}
			strncpy(hdd_relpath, relpath_src, sizeof(hdd_relpath) - 1);
			hdd_relpath[sizeof(hdd_relpath) - 1] = '\0';
		} else {
			hdd_relpath[0] = '\0';
		}

		/* Route to embedded loader with partition context and relative path.
		   The embedded loader will initialize RPC in its own context and handle
		   HDD mounting/loading properly. This avoids RPC context loss after ExecPS2. */
		prepare_reboot_exec_environment();
		return ExecuteViaEmbeddedLoader(partition_context, hdd_relpath, argc, argv);
	}

	/* Non-HDD fallback: use embedded loader (legacy path) */
	if (resolve_result < 0) {
		return -1;
	}

	prepare_reboot_exec_environment();
	return ExecuteViaEmbeddedLoader("", resolved_path, argc, argv);
}
