/*
# _____     ___ ____     ___ ____
#  ____|   |    ____|   |        | |____|
# |     ___|   |____ ___|    ____| |    \    PS2DEV Open Source Project.
#-----------------------------------------------------------------------
# (c) 2020 Francisco Javier Trujillo Mata <fjtrujy@gmail.com>
# Licenced under Academic Free License version 2.0
# Review ps2sdk README & LICENSE files for further details.
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <kernel.h>
#include <loadfile.h>
#include <iopcontrol.h>
#include <sifrpc.h>
#include <errno.h>
#include <ps2sdkapi.h>
#define DPRINTF(x...) printf(x)

#ifdef LOADER_ENABLE_DEBUG_COLORS
#define SET_GS_BGCOLOUR(colour) {*((volatile unsigned long int *)0x120000E0) = colour;}
#else
#define SET_GS_BGCOLOUR(colour)
#endif

// Color status helper in BGR format
#define WHITE_BG 0xFFFFFF // start main
#define CYAN_BG 0xFFFF00 // proper argc count
#define RED_BG  0x0000FF // wrong argc count
#define GREEN_BG 0x00FF00 // before SifLoadELF
#define BLUE_BG 0xFF0000 // after SifLoadELF
#define YELLOW_BG 0x00FFFF // good SifLoadELF return
#define MAGENTA_BG 0xFF00FF // wrong SifLoadELF return
#define ORANGE_BG 0x00A5FF  // after reset IOP
#define BROWN_BG 0x2A2AA5  // before FlushCache
#define PURPBLE_BG 0x800080  // before ExecPS2


//--------------------------------------------------------------
// Redefinition of init/deinit libc:
//--------------------------------------------------------------
// DON'T REMOVE is for reducing binary size. 
// These funtios are defined as weak in /libc/src/init.c
//--------------------------------------------------------------
   void _libcglue_init() {}
   void _libcglue_deinit() {}

   DISABLE_PATCHED_FUNCTIONS();
   DISABLE_EXTRA_TIMERS_FUNCTIONS();
   PS2_DISABLE_AUTOSTART_PTHREAD();

//--------------------------------------------------------------
//Start of function code:
//--------------------------------------------------------------
// Clear user memory
// PS2Link (C) 2003 Tord Lindstrom (pukko@home.se)
//         (C) 2003 adresd (adresd_ps2dev@yahoo.com)
//--------------------------------------------------------------
static void wipeUserMem(void)
{
	int i;
	for (i = 0x100000; i < GetMemorySize(); i += 64) {
		asm volatile(
			"\tsq $0, 0(%0) \n"
			"\tsq $0, 16(%0) \n"
			"\tsq $0, 32(%0) \n"
			"\tsq $0, 48(%0) \n" ::"r"(i));
	}
}

static int is_hdd_partition_context(const char *partition_context)
{
	return (partition_context != NULL &&
	        strncmp(partition_context, "hdd", 3) == 0 &&
	        partition_context[3] >= '0' && partition_context[3] <= '9' &&
	        partition_context[4] == ':');
}

static int build_default_target_arg0(const char *partition_context, const char *load_path, char *out, size_t out_size)
{
	const char *suffix = load_path;

	if (out == NULL || out_size == 0) {
		return -EINVAL;
	}

	if (load_path == NULL) {
		out[0] = '\0';
		return 0;
	}

	if (partition_context == NULL || partition_context[0] == '\0') {
		snprintf(out, out_size, "%s", load_path);
		return 0;
	}

	if (strncmp(load_path, "pfs", 3) == 0) {
		const char *prefix_end = strchr(load_path, ':');
		if (prefix_end != NULL) {
			suffix = prefix_end + 1;
		}
		if (suffix == NULL || suffix[0] == '\0') {
			suffix = "/";
		}
		if (suffix[0] != '/') {
			snprintf(out, out_size, "%spfs:/%s", partition_context, suffix);
		} else {
			snprintf(out, out_size, "%spfs:%s", partition_context, suffix);
		}
		return 0;
	}

	snprintf(out, out_size, "%s%s", partition_context, load_path);
	return 0;
}

//--------------------------------------------------------------
//End of func:  void wipeUserMem(void)
//--------------------------------------------------------------
// *** MAIN ***
// 
//--------------------------------------------------------------
int main(int argc, char *argv[])
{
	SET_GS_BGCOLOUR(WHITE_BG);
	static t_ExecData elfdata;
	static char partition_context[256];
	static char load_path[1024];
	static char default_target_arg0[1024];
	static char target_arg_storage[1024];
	static char *target_argv[33];
	size_t target_arg_offset = 0;
	int target_argc = 0;
	int ret, i;

	elfdata.epc = 0;

	// argv[0]=partition context when present, argv[1]=load path,
	// argv[2..]=arguments for the target ELF
	if (argc < 2) {  
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	snprintf(partition_context, sizeof(partition_context), "%s", argv[0] ? argv[0] : "");
	snprintf(load_path, sizeof(load_path), "%s", argv[1] ? argv[1] : "");
	if (load_path[0] == '\0') {
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	target_argc = argc - 2;
	if (target_argc > 32) {
		return -E2BIG;
	}
	if (target_argc == 0) {
		if (build_default_target_arg0(partition_context, load_path, default_target_arg0, sizeof(default_target_arg0)) != 0) {
			return -EINVAL;
		}
		target_argv[0] = default_target_arg0;
		target_argc = 1;
	} else {
		for (i = 2; i < argc; i++) {
			size_t arg_len = strlen(argv[i]) + 1;
			if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
				return -E2BIG;
			}
			memcpy(&target_arg_storage[target_arg_offset], argv[i], arg_len);
			target_argv[i - 2] = &target_arg_storage[target_arg_offset];
			target_arg_offset += arg_len;
		}
	}
	target_argv[target_argc] = NULL;

	DPRINTF("> argv[0] = %s\n", argv[0]);
	for (i = 1; i < argc; i++) {
		DPRINTF("> argv[%d] = %s\n", i, argv[i]);
	}
	
	// new_argv[0] = argv[0];
	// new_argv[1] = argv[1];
	//new_argv[3] = argv[3];

	SET_GS_BGCOLOUR(CYAN_BG);

	// Initialize
	SifInitRpc(0);
	wipeUserMem();

	//Writeback data cache before loading ELF.
	FlushCache(0);
	SET_GS_BGCOLOUR(GREEN_BG);
	SifLoadFileInit();
	ret = SifLoadElf(load_path, &elfdata);
	SifLoadFileExit();
	SET_GS_BGCOLOUR(BLUE_BG);
	if (ret == 0 && elfdata.epc != 0) {
		SET_GS_BGCOLOUR(YELLOW_BG);

		if (is_hdd_partition_context(partition_context)) {
			while(!SifIopReset("", 0)){};
			while (!SifIopSync()) {};

			SET_GS_BGCOLOUR(ORANGE_BG);

			SifInitRpc(0);
			SifLoadFileInit();
			SifLoadModule("rom0:SIO2MAN", 0, NULL);
			SifLoadModule("rom0:MCMAN", 0, NULL);
			SifLoadModule("rom0:MCSERV", 0, NULL);
			SifLoadFileExit();
		}
		SifExitRpc();

		SET_GS_BGCOLOUR(BROWN_BG);

		FlushCache(0);
		FlushCache(2);

		SET_GS_BGCOLOUR(PURPBLE_BG);
		
		DPRINTF("POPS EXEC: argc=%d\n", target_argc);
		for (i = 0; i < target_argc; i++) {
			DPRINTF("POPS EXEC: argv[%d] = %s\n", i, target_argv[i]);
		}
		return ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, target_argc, target_argv);
	} else {
		SET_GS_BGCOLOUR(MAGENTA_BG);
		SifExitRpc();
		return -ENOENT;
	}
}

//--------------------------------------------------------------
//End of func:  int main(int argc, char *argv[])
//--------------------------------------------------------------
//End of file:  loader.c
//--------------------------------------------------------------
