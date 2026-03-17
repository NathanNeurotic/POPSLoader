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
#include <ctype.h>
#include <kernel.h>
#include <loadfile.h>
#include <iopcontrol.h>
#include <iopheap.h>
#include <sifrpc.h>
#include <sifcmd.h>
#include <errno.h>
#include <ps2sdkapi.h>
#include <sbv_patches.h>
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>
#define DPRINTF(x...) printf(x)

#ifdef LOADER_ENABLE_DEBUG_COLORS
#define SET_GS_BGCOLOUR(colour) {*((volatile unsigned long int *)0x120000E0) = colour;}
#else
#define SET_GS_BGCOLOUR(colour)
#endif

// Color status helper in BGR format
#define WHITE_BG 0xFFFFFF // start main
#define CYAN_BG 0xFFFF00 // argc accepted
#define TEAL_BG 0x808000 // target path/args copied
#define RED_BG  0x0000FF // wrong argc count
#define GREEN_BG 0x00FF00 // before SifLoadELF
#define BLUE_BG 0xFF0000 // after SifLoadELF
#define YELLOW_BG 0x00FFFF // good SifLoadELF return
#define MAGENTA_BG 0xFF00FF // wrong SifLoadELF return
#define ORANGE_BG 0x00A5FF  // before SifExitIopHeap
#define CORAL_BG 0x507FFF   // before SifLoadFileExit
#define OLIVE_BG 0x008080   // before SifExitRpc
#define NAVY_BG 0x800000    // before SifExitCmd
#define GRAY_BG 0x808080    // before SifInitRpc
#define LIME_BG 0x00FF80    // before SifLoadFileInit
#define PINK_BG 0xCBC0FF    // before SifLoadModule(SIO2MAN)
#define AQUA_BG 0xFFFF80    // before SifLoadModule(MCMAN)
#define GOLD_BG 0x00D7FF    // before SifLoadModule(MCSERV)
#define TAN_BG 0x8CB4D2     // before SifLoadFileExit
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

static int starts_with_casefold(const char *value, const char *prefix)
{
	if (value == NULL || prefix == NULL) {
		return 0;
	}
	while (*prefix != '\0') {
		if (*value == '\0') {
			return 0;
		}
		if (tolower((unsigned char)*value) != tolower((unsigned char)*prefix)) {
			return 0;
		}
		value++;
		prefix++;
	}
	return 1;
}

static int looks_like_hdd_partition(const char *value)
{
	return starts_with_casefold(value, "hdd") || starts_with_casefold(value, "dvr_hdd");
}

static const char *extract_basename(const char *path)
{
	const char *last_slash;
	const char *last_colon;
	const char *result;

	if (path == NULL || path[0] == '\0') {
		return path;
	}

	result = path;
	last_slash = strrchr(path, '/');
	if (last_slash != NULL) {
		result = last_slash + 1;
	}

	last_colon = strrchr(result, ':');
	if (last_colon != NULL) {
		result = last_colon + 1;
	}

	return result;
}

static int mount_target_partition(const char *partition)
{
	int ret;
	int mount_attempts = 0;
	const int MAX_MOUNT_ATTEMPTS = 3;

	if (partition == NULL || partition[0] == '\0') {
		return 0;
	}

	ret = fileXioInit();
	if (ret < 0) {
		return ret;
	}

	// Try mounting with retries and delay between attempts
	while (mount_attempts < MAX_MOUNT_ATTEMPTS) {
		ret = fileXioMount("pfs:", partition, FIO_MT_RDONLY);
		if (ret >= 0) {
			// Mount succeeded
			return 0;
		}

		// Mount failed, unmount any partial mount and retry
		mount_attempts++;
		if (mount_attempts < MAX_MOUNT_ATTEMPTS) {
			fileXioUmount("pfs:");
			// Small delay before retry (approximately 50ms)
			for (volatile int i = 0; i < 100000; i++) {
				asm volatile("nop");
			}
		}
	}

	// All mount attempts failed
	fileXioExit();
	return -ENOENT;
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
	static char target_path[1024];
	static char target_partition[256];
	static char target_arg_storage[2048];
	static char *target_argv[33];
	size_t target_arg_offset = 0;
	int target_argc = argc - 1;
	int target_arg_start = 1;
	int use_partition_mount = 0;
	int ret, i;

	elfdata.epc = 0;

	// argv[0]=path to ELF, argv[1..]=arguments for the target executable
	if (argc < 2) {  
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	if (argc >= 3 && looks_like_hdd_partition(argv[1])) {
		use_partition_mount = 1;
		target_arg_start = 2;
		target_argc = argc - 2;
		snprintf(target_partition, sizeof(target_partition), "%s", argv[1] ? argv[1] : "");
	} else {
		target_partition[0] = '\0';
	}
	SET_GS_BGCOLOUR(CYAN_BG);
	snprintf(target_path, sizeof(target_path), "%s", argv[0] ? argv[0] : "");
	if (target_argc > 32) {
		return -E2BIG;
	}
	for (i = 0; i < target_argc; i++) {
		const char *arg_to_copy = argv[i + target_arg_start];
		const char *basename_arg;
		size_t arg_len;

		// For argv[0], extract just the basename without any path prefix
		// POPSTARTER expects argv[0] to be just the filename (e.g., "HELLOGAME.ELF")
		if (i == 0) {
			basename_arg = extract_basename(arg_to_copy);
			if (basename_arg == NULL || basename_arg[0] == '\0') {
				basename_arg = arg_to_copy;  // Fallback to original if extraction fails
			}
			arg_to_copy = basename_arg;
		}

		arg_len = strlen(arg_to_copy) + 1;
		if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
			return -E2BIG;
		}
		memcpy(&target_arg_storage[target_arg_offset], arg_to_copy, arg_len);
		target_argv[i] = &target_arg_storage[target_arg_offset];
		target_arg_offset += arg_len;
	}
	target_argv[target_argc] = NULL;
	SET_GS_BGCOLOUR(TEAL_BG);

	// Initialize
	SifInitRpc(0);
	sbv_patch_enable_lmb();
	sbv_patch_disable_prefix_check();
	sbv_patch_fileio();
	wipeUserMem();

	//Writeback data cache before loading ELF.
	FlushCache(0);
	if (use_partition_mount) {
		ret = mount_target_partition(target_partition);
		if (ret < 0) {
			SET_GS_BGCOLOUR(MAGENTA_BG);
			return ret;
		}
	}
	SET_GS_BGCOLOUR(GREEN_BG);
	SifLoadFileInit();
	ret = SifLoadElf(target_path, &elfdata);
	SifLoadFileExit();
	if (use_partition_mount && (ret != 0 || elfdata.epc == 0)) {
		fileXioUmount("pfs:");
		fileXioExit();
	}
	SET_GS_BGCOLOUR(BLUE_BG);
	if (ret == 0 && elfdata.epc != 0) {
		SET_GS_BGCOLOUR(YELLOW_BG);
		if (use_partition_mount) {
			SET_GS_BGCOLOUR(ORANGE_BG);
			fileXioUmount("pfs:");
			fileXioExit();
		}
		SET_GS_BGCOLOUR(CORAL_BG);
		SifExitIopHeap();
		SET_GS_BGCOLOUR(OLIVE_BG);
		SifExitRpc();
		SET_GS_BGCOLOUR(NAVY_BG);
		SifExitCmd();
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
