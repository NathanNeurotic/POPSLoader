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

static bool is_dkwdrv_elf_path(const char *path) {
	if (path == NULL) return false;
	size_t len = strlen(path);
	if (len < 10) return false;
	const char *name = path + len - 10;
	if (!((name[0] == 'D' || name[0] == 'd') &&
	      (name[1] == 'K' || name[1] == 'k') &&
	      (name[2] == 'W' || name[2] == 'w') &&
	      (name[3] == 'D' || name[3] == 'd') &&
	      (name[4] == 'R' || name[4] == 'r') &&
	      (name[5] == 'V' || name[5] == 'v') &&
	      name[6] == '.' &&
	      (name[7] == 'E' || name[7] == 'e') &&
	      (name[8] == 'L' || name[8] == 'l') &&
	      (name[9] == 'F' || name[9] == 'f'))) {
		return false;
	}
	if (len == 10) {
		return true;
	}
	char sep = path[len - 11];
	if (sep == '/' || sep == '\\' || sep == ':') {
		return true;
	}
	return false;
}

/* extract_dkwdrv_pfs_path -- removed 2026-05-24 along with the V3
 * DKWDRV-bypass logic in LoadELFFromFileExecPS2RebootIOPWithPartition.
 * HDD DKWDRV now routes through ExecuteHddBackedViaEmbeddedLoader, which
 * derives the partition_context and mounts pfs0 on its own; the inline
 * pfs-segment extraction is no longer needed.
 */

static bool has_valid_target_argv0(int argc, char *argv[]) {
	return (argc > 0 && argv != NULL && argv[0] != NULL && argv[0][0] != '\0');
}

static int ExecuteViaEmbeddedLoader(const char *partition_context, const char *load_path, int argc, char *argv[]);

#define EMBEDDED_LOADER_METADATA_ADDR ((volatile struct EmbeddedLoaderMetadata *)0x00083C00)
#define EMBEDDED_LOADER_METADATA_MAGIC 0x504F504CU /* POPL */
#define EMBEDDED_LOADER_METADATA_VERSION 1

typedef struct EmbeddedLoaderMetadata {
	u32 magic;
	u32 version;
	u32 valid;
	u32 reserved;
	char partition_context[128];
	char load_path[256];
} EmbeddedLoaderMetadata;
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

	/* POPSTARTER contract for HDD-backed launch: argv[0] must carry the
	 * selector literal/path. Loader metadata is written separately.
	 */
	if (!has_valid_target_argv0(argc, argv)) {
		return -7;
	}

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
	int final_argc = extra_argc;
	static const int kMaxArgc = 32;
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

	{
		volatile EmbeddedLoaderMetadata *meta = EMBEDDED_LOADER_METADATA_ADDR;
		memset((void *)meta, 0, sizeof(*meta));
		meta->magic = EMBEDDED_LOADER_METADATA_MAGIC;
		meta->version = EMBEDDED_LOADER_METADATA_VERSION;
		snprintf((char *)meta->partition_context, sizeof(meta->partition_context), "%s", partition_context != NULL ? partition_context : "");
		snprintf((char *)meta->load_path, sizeof(meta->load_path), "%s", load_path != NULL ? load_path : "");
		meta->valid = 1;
		if (meta->magic != EMBEDDED_LOADER_METADATA_MAGIC || meta->version != EMBEDDED_LOADER_METADATA_VERSION ||
		    meta->valid != 1 || meta->load_path[0] == '\0') {
			return -6;
		}
	}

	/* The child loader synthesizes a default target argv0 from the load path
	 * when extra_argc == 0 (see loader.c:build_default_target_arg0). Allow
	 * argc == 0 through so that generic, non-HDD partition-aware paths can
	 * rely on the documented default-argv contract. POPSTARTER-specific
	 * argv0 enforcement still happens in ExecuteHddBackedViaEmbeddedLoader
	 * before this is reached.
	 */
	if (extra_argc > 0 && !has_valid_target_argv0(extra_argc, argv)) {
		return -7;
	}

	for (i = 0; i < extra_argc; i++) {
		char *stored_arg = store_arg(argv[i], launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
		if (!stored_arg) {
			return -3;
		}
		launch_argv[i] = stored_arg;
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

	SifExitIopHeap();
	SifExitRpc();
	SifExitCmd();
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

	if (strcmp(resolved_path, "mc0:/BOOT/BOOT.ELF") == 0 || strcmp(resolved_path, "mc1:/BOOT/BOOT.ELF") == 0) {
		char *boot_argv[1];
		boot_argv[0] = (char *)resolved_path;
		return ExecuteViaEmbeddedLoader("", resolved_path, 1, boot_argv);
	}

	/* DKWDRV special-case: mirror the BOOT.ELF V2 contract (d23520a,
	 * 2026-05-23) for the DKWDRV-on-HDD path. Route through
	 * ExecuteViaEmbeddedLoader so the child loader's wipeUserMem +
	 * filexio-direct-load + SifExitRpc + ExecPS2 sequence fires.
	 * Caller (ui.lua OpenDKWDRV) selects reboot_iop=0 for HDD paths so
	 * we land here; MC DKWDRV continues to use the reboot variant which
	 * already works. PR #452 (V4) tried reboot_iop=0 in Lua alone but
	 * skipped this routing, falling through to direct LoadExecPS2 --
	 * that black-screened on hardware. The V2 contract requires BOTH
	 * the Lua-side reboot_iop=0 AND this C-side embedded-loader route.
	 */
	if (is_dkwdrv_elf_path(resolved_path)) {
		char *dkwdrv_argv[1];
		dkwdrv_argv[0] = (char *)resolved_path;
		return ExecuteViaEmbeddedLoader("", resolved_path, 1, dkwdrv_argv);
	}

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
	DPRINTF("Exec path: %s\n", resolved_path);
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

	if (!has_valid_target_argv0(argc, argv)) {
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

	ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, argc, argv);
	return -1;
}


int LoadELFFromFileExecPS2RebootIOP(const char *filename, int argc, char *argv[])
{
	return LoadELFFromFileExecPS2RebootIOPWithPartition(filename, NULL, argc, argv);
}

int LoadELFFromFileExecPS2RebootIOPWithPartition(const char *filename, const char *partition, int argc, char *argv[])
{
	t_ExecData elfdata;
	char resolved_path[256];
	int ret;
	int final_argc = argc;
	char **final_argv = argv;
	static char *dkwdrv_argv[2];
	static char dkwdrv_argv0[256];

	/* HDD-backed launches (POPSTARTER on HDD AND DKWDRV on HDD) route
	 * through ExecuteHddBackedViaEmbeddedLoader -> ExecuteViaEmbeddedLoader
	 * -> BRAM child loader. This is the path that hardware-passes D-10
	 * (HDD POPSTARTER + HDD game) via the 2026-05-22 B2 fix.
	 *
	 * The previous V3 logic explicitly excluded DKWDRV from this path
	 * (via !is_dkwdrv_elf_path guards) and tried the standard
	 * SifLoadElf -> SifIopReset -> reload-MC-modules -> ExecPS2 route
	 * directly here instead. That route black-screened on hardware
	 * (2026-05-24). DKWDRV is now routed through the same BRAM child
	 * loader path as POPSTARTER so it inherits the proven IOP-state
	 * contract.
	 *
	 * The argv0 synthesis at the bottom of this function still applies
	 * to the NON-HDD DKWDRV path (e.g. mc0:/PS1_DKWDRV/DKWDRV.ELF) which
	 * falls through to the standard direct-launch path below.
	 */
	if (partition != NULL && partition[0] != '\0' &&
	    is_hdd_backed_exec_path(partition) &&
	    is_hdd_backed_exec_path(filename)) {
		return ExecuteHddBackedViaEmbeddedLoader(filename, partition, argc, argv);
	}

	if (resolve_exec_path(filename, resolved_path, sizeof(resolved_path)) < 0) {
		return -1;
	}

	if (is_hdd_backed_exec_path(resolved_path) || is_hdd_backed_exec_path(partition)) {
		return ExecuteHddBackedViaEmbeddedLoader(resolved_path, partition, argc, argv);
	}

	/* DKWDRV launch diagnostic (DKWDRV_DEBUG_COLORS, Makefile toggle).
	 * After the U-10 fix, the ONLY remaining caller of this reboot-IOP
	 * path is MC DKWDRV (ui.lua OpenDKWDRV; POPSTARTER uses reboot=0 and
	 * BOOT.ELF was moved to reboot=0). Nuno 2026-05-31 reported MC DKWDRV
	 * "hangs on pic" -> black screen. Paint the GS background at each
	 * stage so a tester photo shows exactly where it dies. No-op unless
	 * DKWDRV_DEBUG_COLORS is defined. Colors match the child loader's
	 * convention (loader.c) for consistency. */
#ifdef DKWDRV_DEBUG_COLORS
#define SET_DKW_BG(c) {*((volatile unsigned long int *)0x120000E0) = c;}
#else
#define SET_DKW_BG(c)
#endif
	SET_DKW_BG(0xFFFFFF); /* WHITE  - entered reboot-IOP exit path */

	SifInitRpc(0);
	SifLoadFileInit();
	ret = SifLoadElf(resolved_path, &elfdata);
	SifLoadFileExit();

	if (ret != 0 || elfdata.epc == 0) {
		return -2;
	}
	SET_DKW_BG(0xFFFF00); /* CYAN   - SifLoadElf OK, target in EE RAM */

	/* Unmount all live PFS slots before SifIopReset (see PR #463/#464 for
	 * the BOOT.ELF history). For MC DKWDRV with no HDD session the keep
	 * mask is 0 and there is typically nothing mounted, but this is kept
	 * unconditional so a DKWDRV launch after HDD use also tears pfs down.
	 */
	unmount_pfs_slots_for_exec(build_exec_keep_mask(resolved_path));
	SET_DKW_BG(0x00FF00); /* GREEN  - PFS unmount returned */

	FlushCache(0);
	SET_DKW_BG(0x00FFFF); /* YELLOW - about to SifIopReset (cold reboot) */

	/* H-B fix (grounded in the known-good build's src/system.cpp::IOP_Reset,
	 * which the maintainer's working POPSLoader used for every reboot
	 * launch): use a FULL cold IOP reboot with the UDNL/EELOADCNF image,
	 * NOT the bare soft reset. POPSLoader had SifIopReset("", 0) here; the
	 * working source had SifIopReset("rom0:UDNL rom0:EELOADCNF", 0). For a
	 * PS1 disc loader like DKWDRV the bare soft reset leaves the IOP in a
	 * state DKWDRV cannot drive (candidate cause of the "hangs on pic"
	 * black screen). The working reset also tears down IOP heap + cmd
	 * before re-init, mirrored below. */
	while (!SifIopReset("rom0:UDNL rom0:EELOADCNF", 0)) {
	}
	while (!SifIopSync()) {
	}
	/* Mirror the working IOP_Reset() teardown: tear down IOP heap + cmd
	 * before re-initializing RPC, exactly as src/system.cpp did. */
	SifExitIopHeap();
	SifLoadFileExit();
	SifExitRpc();
	SifExitCmd();
	SET_DKW_BG(0x00A5FF); /* ORANGE - IOP cold reboot + sync + teardown done */

	SifInitRpc(0);
	SifLoadFileInit();
	/* H-B fix: reload the FULL module set the working build's load_modules()
	 * used, not just SIO2MAN/MCMAN/MCSERV. DKWDRV is a PS1 disc loader and
	 * needs the CDVD modules; their absence is a strong candidate for a
	 * disc-init hang on the DKWDRV splash ("on pic"). Order matches the
	 * working source exactly (CDVDFSV before CDVDMAN). */
	SifLoadModule("rom0:SIO2MAN", 0, NULL);
	SifLoadModule("rom0:CDVDFSV", 0, NULL);
	SifLoadModule("rom0:CDVDMAN", 0, NULL);
	SifLoadModule("rom0:MCMAN", 0, NULL);
	SifLoadModule("rom0:MCSERV", 0, NULL);
	SifLoadModule("rom0:PADMAN", 0, NULL);
	SifLoadFileExit();
	SET_DKW_BG(0x800080); /* PURPLE - modules reloaded */

	FlushCache(0);
	FlushCache(2);

	if (is_dkwdrv_elf_path(resolved_path)) {
		snprintf(dkwdrv_argv0, sizeof(dkwdrv_argv0), "%s", resolved_path);
		dkwdrv_argv[0] = dkwdrv_argv0;
		dkwdrv_argv[1] = NULL;
		final_argc = 1;
		final_argv = dkwdrv_argv;
	}

	SET_DKW_BG(0x0000FF); /* RED    - about to ExecPS2 the target */
	ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, final_argc, final_argv);
#undef SET_DKW_BG
	return -1;
}
