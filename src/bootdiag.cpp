#include "include/bootdiag.h"

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <debug.h>

static int boot_log_slot = -1;
static char boot_log_path[32] = {0};

static int BootDiagOpenLog(void)
{
	if (boot_log_slot >= 0 && boot_log_path[0]) {
		return open(boot_log_path, O_WRONLY | O_CREAT | O_APPEND, 0666);
	}

	const char *paths[] = {"mc0:/POPSLDR.LOG", "mc1:/POPSLDR.LOG"};
	for (size_t i = 0; i < (sizeof(paths) / sizeof(paths[0])); ++i) {
		int fd = open(paths[i], O_WRONLY | O_CREAT | O_APPEND, 0666);
		if (fd >= 0) {
			boot_log_slot = (int)i;
			snprintf(boot_log_path, sizeof(boot_log_path), "%s", paths[i]);
			return fd;
		}
	}
	return -1;
}

void BootDiagLog(const char *fmt, ...)
{
#if defined(BOOT_DIAG)
	char buffer[256];
	va_list args;
	va_start(args, fmt);
	vsnprintf(buffer, sizeof(buffer), fmt, args);
	va_end(args);

	size_t len = strnlen(buffer, sizeof(buffer));
	if (len + 1 < sizeof(buffer)) {
		buffer[len] = '\n';
		buffer[len + 1] = '\0';
		len += 1;
	}

	int fd = BootDiagOpenLog();
	if (fd < 0) {
		return;
	}
	write(fd, buffer, len);
	close(fd);
#else
	(void)fmt;
#endif
}

void BootDiagHeartbeat(const char *stage)
{
#if defined(BOOT_DIAG)
	static int stage_index = 0;
	init_scr();
	scr_setfontcolor(0x00ff00);
	scr_clear();
	scr_setXY(2, 1);
	scr_printf("BOOT DIAG %d\n", stage_index++);
	if (stage) {
		scr_printf("%s\n", stage);
	}
#else
	(void)stage;
#endif
}
