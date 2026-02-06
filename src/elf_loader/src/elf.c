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
#include <loadfile.h>
#include <sys/stat.h>
#include <stdbool.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

/*
 * NOTE (NEWLIB_PORT_AWARE):
 * This project is built with the ps2sdk newlib port. ps2sdk intentionally
 * errors out if fio/fileXio headers are used without explicitly opting in.
 *
 * We opt-in here because:
 * - Launching via LoadExecPS2 from HDD/PFS can deadlock depending on the
 *   launcher environment.
 * - Using POSIX open/read/lseek on pfs:/ paths has proven fragile in this
 *   project’s HDD-boot scenario.
 *
 * For PFS/HDD paths (e.g. "pfs0:/..." or "hdd0:...") we will use fileXio* calls for raw ELF reading in the
 * FileIO loader path.
 */
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include "elf.h"
#define DPRINTF(x...) printf(x)

extern void gsKit_finish(void);

static bool is_pfs_or_hdd_path(const char *filename) {
    if (!filename) {
        return false;
    }
    if (strncmp(filename, "pfs", 3) == 0) {
        return true;
    }
    if (strncmp(filename, "hdd0:", 5) == 0) {
        return true;
    }
    return false;
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

static int resolve_exec_path(const char *filename, char *out, size_t out_size) {
	if (!filename || !out || out_size == 0) {
		return -1;
	}

	/* For pfs/hdd, avoid newlib stat() and use fileXioGetStat instead. */
	if (is_pfs_or_hdd_path(filename)) {
		iox_stat_t st;
		memset(&st, 0, sizeof(st));
		if (fileXioGetStat(filename, &st) == 0) {
			snprintf(out, out_size, "%s", filename);
			return 0;
		}
		return -1;
	}

	{
		struct stat buffer;
		if (stat(filename, &buffer) == 0) {
			snprintf(out, out_size, "%s", filename);
			return 0;
		}
		if (build_host_alt_path(filename, out, out_size) && stat(out, &buffer) == 0) {
			return 0;
		}
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

static void copy_span(char *dest, size_t dest_size, const char *start, size_t len) {
	if (!dest || dest_size == 0) {
		return;
	}
	if (!start) {
		dest[0] = '\0';
		return;
	}
	if (len >= dest_size) {
		len = dest_size - 1;
	}
	memcpy(dest, start, len);
	dest[len] = '\0';
}

static void parse_selector_parts(const char *argv0, char *out_prefix, size_t out_prefix_size, char *out_game, size_t out_game_size) {
	const char *last_dot;
	const char *prefix = "XX.";
	size_t prefix_len = strlen(prefix);
	if (out_prefix_size > 0) {
		out_prefix[0] = '\0';
	}
	if (out_game_size > 0) {
		out_game[0] = '\0';
	}
	if (!argv0) {
		return;
	}
	last_dot = strrchr(argv0, '.');
	if (!last_dot) {
		copy_span(out_game, out_game_size, argv0, strlen(argv0));
		return;
	}
	if (strncmp(argv0, prefix, prefix_len) == 0) {
		copy_span(out_prefix, out_prefix_size, "XX", 2);
		copy_span(out_game, out_game_size, argv0 + prefix_len, (size_t)(last_dot - (argv0 + prefix_len)));
		return;
	}
	copy_span(out_game, out_game_size, argv0, (size_t)(last_dot - argv0));
}

static void append_launch_log_line(const char *line) {
	/*
	 * Avoid writing to disk during launch. When running from HDD/PFS,
	 * performing extra file I/O here has been observed to contribute to hangs.
	 *
	 * Launch diagnostics should be done via on-screen markers/logs instead.
	 */
	(void)line;
	return;
}

static void append_launch_log_fmt(const char *label, int index, const char *value) {
	char buffer[256];
	if (index >= 0) {
		snprintf(buffer, sizeof(buffer), "LAUNCH: %s[%d]=%s\n", label, index, value ? value : "(null)");
	} else {
		snprintf(buffer, sizeof(buffer), "LAUNCH: %s=%s\n", label, value ? value : "(null)");
	}
	append_launch_log_line(buffer);
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

typedef struct
{
	u32 name;
	u32 type;
	u32 flags;
	u32 addr;
	u32 offset;
	u32 size;
	u32 link;
	u32 info;
	u32 addralign;
	u32 entsize;
} elf_sheader_t;

typedef struct
{
	u32 gprmask;
	u32 cprmask[4];
	s32 gp_value;
} elf_reginfo_t;

static int read_full_ex(int fd, void *buf, size_t size, bool use_filexio) {
	size_t total = 0;
	while (total < size) {
		int rc;
		if (use_filexio) {
			rc = fileXioRead(fd, (char *)buf + (int)total, (int)(size - total));
		} else {
			rc = (int)read(fd, (char *)buf + total, size - total);
		}
		if (rc <= 0) {
			return -1;
		}
		total += (size_t)rc;
	}
	return 0;
}

static int elf_lseek_ex(int fd, off_t off, int whence, bool use_filexio) {
	if (use_filexio) {
		/* fileXioLseek returns the new offset or negative on error. */
		return fileXioLseek(fd, (int)off, whence);
	}
	return (int)lseek(fd, off, whence);
}

static int elf_close_ex(int fd, bool use_filexio) {
	if (use_filexio) {
		return fileXioClose(fd);
	}
	return close(fd);
}

static int elf_open_ex(const char *path, int flags, bool use_filexio) {
	if (use_filexio) {
		/* fileXioOpen takes POSIX-like flags, mode is ignored for O_RDONLY. */
		return fileXioOpen(path, flags, 0);
	}
	return open(path, flags);
}

static int load_elf_segments_ex(int fd, const elf_header_t *eh, bool use_filexio) {
	elf_pheader_t ph;
	u32 i;
	if (eh->phoff == 0 || eh->phnum == 0) {
		return -1;
	}
	if (elf_lseek_ex(fd, (off_t)eh->phoff, SEEK_SET, use_filexio) < 0) {
		return -1;
	}
	for (i = 0; i < eh->phnum; ++i) {
		if (read_full_ex(fd, &ph, sizeof(ph), use_filexio) < 0) {
			return -1;
		}
		if (ph.type != 1 || ph.memsz == 0) {
			continue;
		}
		void *dest = ph.paddr ? (void *)ph.paddr : ph.vaddr;
		if (elf_lseek_ex(fd, (off_t)ph.offset, SEEK_SET, use_filexio) < 0) {
			return -1;
		}
		if (read_full_ex(fd, dest, ph.filesz, use_filexio) < 0) {
			return -1;
		}
		if (ph.memsz > ph.filesz) {
			memset((char *)dest + ph.filesz, 0, ph.memsz - ph.filesz);
		}
		if (elf_lseek_ex(fd, (off_t)(eh->phoff + (i + 1) * sizeof(ph)), SEEK_SET, use_filexio) < 0) {
			return -1;
		}
	}
	return 0;
}

static int find_gp_value_ex(int fd, const elf_header_t *eh, u32 *out_gp, bool use_filexio) {
	u32 i;
	elf_sheader_t sh;
	if (!out_gp) {
		return -1;
	}
	*out_gp = 0;
	if (eh->shoff == 0 || eh->shnum == 0) {
		return -1;
	}
	if (elf_lseek_ex(fd, (off_t)eh->shoff, SEEK_SET, use_filexio) < 0) {
		return -1;
	}
	for (i = 0; i < eh->shnum; ++i) {
		if (read_full_ex(fd, &sh, sizeof(sh), use_filexio) < 0) {
			return -1;
		}
		if (sh.type == 0x70000006 && sh.size >= sizeof(elf_reginfo_t)) {
			elf_reginfo_t reginfo;
			if (elf_lseek_ex(fd, (off_t)sh.offset, SEEK_SET, use_filexio) < 0) {
				return -1;
			}
			if (read_full_ex(fd, &reginfo, sizeof(reginfo), use_filexio) < 0) {
				return -1;
			}
			*out_gp = (u32)reginfo.gp_value;
			return 0;
		}
		if (elf_lseek_ex(fd, (off_t)(eh->shoff + (i + 1) * sizeof(sh)), SEEK_SET, use_filexio) < 0) {
			return -1;
		}
	}
	return -1;
}

int LoadELFFromFileFileIO(const char *filename, int argc, char *argv[]) {
	int fd;
	elf_header_t eh;
	u32 gp = 0;
	bool use_filexio;
	if (!filename) {
		return -1;
	}
	use_filexio = is_pfs_or_hdd_path(filename);
	fd = elf_open_ex(filename, O_RDONLY, use_filexio);
	if (fd < 0) {
		return fd;
	}
	if (read_full_ex(fd, &eh, sizeof(eh), use_filexio) < 0) {
		elf_close_ex(fd, use_filexio);
		return -2;
	}
	if (eh.ident[0] != 0x7f || eh.ident[1] != 'E' || eh.ident[2] != 'L' || eh.ident[3] != 'F') {
		elf_close_ex(fd, use_filexio);
		return -3;
	}
	if (load_elf_segments_ex(fd, &eh, use_filexio) < 0) {
		elf_close_ex(fd, use_filexio);
		return -4;
	}
	find_gp_value_ex(fd, &eh, &gp, use_filexio);
	elf_close_ex(fd, use_filexio);

	FlushCache(0);
	FlushCache(2);
	ExecPS2((void *)eh.entry, (void *)gp, argc, argv);
	return -1;
}

int LoadELFFromFileWithPartition(const char *filename, int argc, char *argv[]) {
	int i;
	int new_argc = argc + 1;
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
	{
		bool use_filexio = is_pfs_or_hdd_path(resolved_path);
		fd = elf_open_ex(resolved_path, O_RDONLY, use_filexio);
		DPRINTF("LAUNCH: popstarter open rc=%d (%s)\n", fd, use_filexio ? "fileXioOpen" : "open");
		if (fd >= 0) {
			elf_close_ex(fd, use_filexio);
		} else {
			return fd;
		}
	}
	DPRINTF("LAUNCH: argc_in=%d argv_ptr=%s\n", argc, argv ? "set" : "null");
	{
		char argc_buf[32];
		snprintf(argc_buf, sizeof(argc_buf), "%d", argc);
		append_launch_log_fmt("argc_in", -1, argc_buf);
	}
	append_launch_log_fmt("argv_ptr", -1, argv ? "set" : "null");
	use_default_argv0 = (argc <= 0 || argv == NULL || argv[0] == NULL);
	new_argc = use_default_argv0 ? 1 : argc;
	DPRINTF("LAUNCH: argv0 source: %s\n", use_default_argv0 ? "resolved path" : "caller");
	append_launch_log_fmt("argv0_source", -1, use_default_argv0 ? "resolved path" : "caller");
	// Preparing filename and partition to be sent in the argv
	if (new_argc + 1 > kMaxArgc) {
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
			char *stored_arg = store_arg(argv[i], launch_arg_storage, sizeof(launch_arg_storage), &storage_offset);
			if (!stored_arg) {
				return -3;
			}
			launch_argv[i] = stored_arg;
		}
	}
	launch_argv[new_argc] = NULL;

	/*
	 * HDD/PFS launch:
	 * LoadExecPS2/LOADFILE can deadlock depending on the IOP state left by the
	 * launcher. When the target ELF is on PFS/HDD (pfs*:... or hdd0:...), prefer the FileIO loader
	 * path which reads the ELF ourselves (using fileXio* for pfs/hdd) and then
	 * hands off via ExecPS2.
	 */
	if (is_pfs_or_hdd_path(resolved_path)) {
		DPRINTF("LAUNCH: Using FileIO loader (pfs/hdd)\n");
		FlushCache(0);
		FlushCache(2);
		return LoadELFFromFileFileIO(resolved_path, new_argc, launch_argv);
	}

	DPRINTF("LAUNCH: Using LoadExecPS2\n");
	DPRINTF("LAUNCH: exec path=%s\n", resolved_path);
	DPRINTF("LAUNCH: argc=%d\n", new_argc);
	DPRINTF("LAUNCH: use_default_argv0=%s argv0=%s\n",
		use_default_argv0 ? "true" : "false",
		launch_argv[0] ? launch_argv[0] : "(null)");
	DPRINTF("LAUNCH: argv0_final=%s\n", use_default_argv0 ? resolved_path : (launch_argv[0] ? launch_argv[0] : "(null)"));
	DPRINTF("LAUNCH: argv1=%s\n", launch_argv[1] ? launch_argv[1] : "(null)");
	DPRINTF("LAUNCH: argv2_is_null=%s\n", launch_argv[2] == NULL ? "yes" : "no");
	{
		char selector_prefix[32];
		char selector_game[128];
		parse_selector_parts(launch_argv[0], selector_prefix, sizeof(selector_prefix), selector_game, sizeof(selector_game));
		DPRINTF("LAUNCH: selector_prefix=%s selector_game=%s\n",
			selector_prefix[0] ? selector_prefix : "(none)",
			selector_game[0] ? selector_game : "(unknown)");
		DPRINTF("LAUNCH: selector_mode=%s\n", selector_prefix[0] ? "XX" : "NO_PREFIX");
		append_launch_log_fmt("selector_prefix", -1, selector_prefix[0] ? selector_prefix : "(none)");
		append_launch_log_fmt("selector_game", -1, selector_game[0] ? selector_game : "(unknown)");
		append_launch_log_fmt("selector_mode", -1, selector_prefix[0] ? "XX" : "NO_PREFIX");
	}
	append_launch_log_fmt("exec path", -1, resolved_path);
	{
		char argc_buf[32];
		snprintf(argc_buf, sizeof(argc_buf), "%d", new_argc);
		append_launch_log_fmt("argc", -1, argc_buf);
	}
	append_launch_log_fmt("use_default_argv0", -1, use_default_argv0 ? "true" : "false");
	append_launch_log_fmt("argv0", -1, launch_argv[0]);
	append_launch_log_fmt("argv1", -1, launch_argv[1]);
	append_launch_log_fmt("argv2_is_null", -1, launch_argv[2] == NULL ? "yes" : "no");
	append_launch_log_fmt("argv0_final", -1, use_default_argv0 ? resolved_path : launch_argv[0]);
	for (i = 0; i < new_argc; i++) {
		DPRINTF("LAUNCH: argv[%d]=%s\n", i, launch_argv[i] ? launch_argv[i] : "(null)");
		append_launch_log_fmt("argv", i, launch_argv[i]);
	}
	DPRINTF("LAUNCH: argv[%d] is NULL: %s\n", new_argc, launch_argv[new_argc] == NULL ? "yes" : "no");
	append_launch_log_fmt("argv_null", new_argc, launch_argv[new_argc] == NULL ? "yes" : "no");
	FlushCache(0);
	FlushCache(2);
	/* LoadExecPS2 should not return on success. */
	LoadExecPS2(resolved_path, new_argc, launch_argv);
	DPRINTF("LAUNCH: RETURNED rc=%d\n", -1);
	append_launch_log_line("LAUNCH: RETURNED rc=-1\n");
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

	ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, argc, argv);
	return -1;
}
