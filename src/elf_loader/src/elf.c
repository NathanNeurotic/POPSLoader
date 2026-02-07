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

/* Allow direct fileXio usage under newlib (PS2SDK guard). */
#ifndef NEWLIB_PORT_AWARE
#define NEWLIB_PORT_AWARE
#endif
#include <fileXio_rpc.h>

#include "elf.h"
#define DPRINTF(x...) printf(x)

extern void gsKit_finish(void);

/*
 * IO backend notes:
 * - For targets on PFS/HDD (paths starting with "pfs" or "hdd0:"), use fileXio* with an aligned bounce buffer.
 *   This avoids cases where a direct read into stack/unaligned buffers yields short/0 reads (causing -2).
 * - For all other paths, use standard POSIX open/read/lseek/close.
 */
typedef struct {
    int fd;
    int use_filexio;
} elfio_handle_t;

static int is_pfs_or_hdd_path(const char *path) {
    if (!path) return 0;
    if (!strncmp(path, "hdd0:", 5)) return 1;
    if (!strncmp(path, "pfs", 3)) return 1;
    return 0;
}

static int elfio_open(elfio_handle_t *h, const char *path) {
    if (!h) return -1;
    h->fd = -1;
    h->use_filexio = is_pfs_or_hdd_path(path);
    if (h->use_filexio) {
        h->fd = fileXioOpen(path, O_RDONLY, 0);
    } else {
        h->fd = open(path, O_RDONLY);
    }
    return h->fd;
}

static int elfio_close(elfio_handle_t *h) {
    if (!h) return -1;
    if (h->fd < 0) return 0;
    if (h->use_filexio) return fileXioClose(h->fd);
    return close(h->fd);
}

static int elfio_lseek(elfio_handle_t *h, int offset, int whence) {
    if (!h || h->fd < 0) return -1;
    if (h->use_filexio) return fileXioLseek(h->fd, offset, whence);
    return (int)lseek(h->fd, (off_t)offset, whence);
}

static int elfio_read_raw(elfio_handle_t *h, void *buf, int size) {
    if (!h || h->fd < 0) return -1;
    if (size <= 0) return 0;

    if (h->use_filexio) {
        static unsigned char bounce[512] __attribute__((aligned(64)));
        unsigned char *dst = (unsigned char *)buf;
        int total = 0;
        while (total < size) {
            int chunk = size - total;
            if (chunk > (int)sizeof(bounce)) chunk = (int)sizeof(bounce);
            int r = fileXioRead(h->fd, bounce, chunk);
            if (r <= 0) return (total > 0) ? total : r;
            memcpy(dst + total, bounce, (size_t)r);
            total += r;
        }
        return total;
    }

    return read(h->fd, buf, size);
}

static int elfio_read_full(elfio_handle_t *h, void *buf, size_t size) {
    unsigned char *p = (unsigned char *)buf;
    size_t remaining = size;
    while (remaining > 0) {
        int r = elfio_read_raw(h, p, (int)remaining);
        if (r <= 0) return -1;
        p += (size_t)r;
        remaining -= (size_t)r;
    }
    return 0;
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
	struct stat buffer;
	if (stat(filename, &buffer) == 0) {
		snprintf(out, out_size, "%s", filename);
		return 0;
	}
	if (build_host_alt_path(filename, out, out_size) && stat(out, &buffer) == 0) {
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
	int fd = open("launch.log", O_WRONLY | O_CREAT, 0666);
	if (fd < 0) {
		return;
	}
	elfio_lseek(h, 0, SEEK_END);
	write(fd, line, strlen(line));
	close(fd);
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

static int read_full(elfio_handle_t *h, void *buf, size_t size) {
	return elfio_read_full(h, buf, size);
}

		total += (size_t)rc;
	}
	return 0;
}

static int load_elf_segments(elfio_handle_t *h, const elf_header_t *eh) {
	elf_pheader_t ph;
	u32 i;
	if (eh->phoff == 0 || eh->phnum == 0) {
		return -1;
	}
	if (elfio_lseek(h, (off_t)eh->phoff, SEEK_SET) < 0) {
		return -1;
	}
	for (i = 0; i < eh->phnum; ++i) {
		if (read_full(h, &ph, sizeof(ph)) < 0) {
			return -1;
		}
		if (ph.type != 1 || ph.memsz == 0) {
			continue;
		}
		void *dest = ph.paddr ? (void *)ph.paddr : ph.vaddr;
		if (elfio_lseek(h, (off_t)ph.offset, SEEK_SET) < 0) {
			return -1;
		}
		if (read_full(h, dest, ph.filesz) < 0) {
			return -1;
		}
		if (ph.memsz > ph.filesz) {
			memset((char *)dest + ph.filesz, 0, ph.memsz - ph.filesz);
		}
		if (elfio_lseek(h, (off_t)(eh->phoff + (i + 1) * sizeof(ph)), SEEK_SET) < 0) {
			return -1;
		}
	}
	return 0;
}

static int find_gp_value(elfio_handle_t *h, const elf_header_t *eh, u32 *out_gp) {
	u32 i;
	elf_sheader_t sh;
	if (!out_gp) {
		return -1;
	}
	*out_gp = 0;
	if (eh->shoff == 0 || eh->shnum == 0) {
		return -1;
	}
	if (elfio_lseek(h, (off_t)eh->shoff, SEEK_SET) < 0) {
		return -1;
	}
	for (i = 0; i < eh->shnum; ++i) {
		if (read_full(h, &sh, sizeof(sh)) < 0) {
			return -1;
		}
		if (sh.type == 0x70000006 && sh.size >= sizeof(elf_reginfo_t)) {
			elf_reginfo_t reginfo;
			if (elfio_lseek(h, (off_t)sh.offset, SEEK_SET) < 0) {
				return -1;
			}
			if (read_full(h, &reginfo, sizeof(reginfo)) < 0) {
				return -1;
			}
			*out_gp = (u32)reginfo.gp_value;
			return 0;
		}
		if (elfio_lseek(h, (off_t)(eh->shoff + (i + 1) * sizeof(sh)), SEEK_SET) < 0) {
			return -1;
		}
	}
	return -1;
}

int LoadELFFromFileFileIO(const char *filename, int argc, char *argv[]) {
	elfio_handle_t h;
	elf_header_t eh;
	u32 gp = 0;

	if (!filename) {
		return -1;
	}

	if (elfio_open(&h, filename) < 0) {
		return h.fd;
	}

	if (read_full(&h, &eh, sizeof(eh)) < 0) {
		elfio_close(&h);
		return -2;
	}

	if (eh.ident[0] != 0x7f || eh.ident[1] != 'E' || eh.ident[2] != 'L' || eh.ident[3] != 'F') {
		elfio_close(&h);
		return -3;
	}

	if (load_elf_segments(&h, &eh) < 0) {
		elfio_close(&h);
		return -4;
	}

	find_gp_value(&h, &eh, &gp);
	elfio_close(&h);

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
	fd = open(resolved_path, O_RDONLY);
	DPRINTF("LAUNCH: popstarter open rc=%d (open)\n", fd);
	if (fd >= 0) {
		close(fd);
	} else {
		return fd;
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