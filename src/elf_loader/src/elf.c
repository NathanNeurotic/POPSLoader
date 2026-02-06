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
#include <debug.h>
#include <sys/stat.h>
#include <stdbool.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#define DPRINTF(x...) printf(x)

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
	lseek(fd, 0, SEEK_END);
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
	/* LoadExecPS2 should not return on success. */
	LoadExecPS2(resolved_path, new_argc, launch_argv);
	DPRINTF("LAUNCH: RETURNED rc=%d\n", -1);
	append_launch_log_line("LAUNCH: RETURNED rc=-1\n");
	init_scr();
	scr_setfontcolor(0x0000ff);
	scr_clear();
	scr_setXY(5, 2);
	scr_printf("POPSLoader ERROR!\n");
	scr_printf("LoadExecPS2 returned.\n");
	scr_printf("path: %s\n", resolved_path);
	scr_printf("rc: %d\n", -1);
	scr_printf("Restart required.\n");
	for (;;) {
		SleepThread();
	}
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
