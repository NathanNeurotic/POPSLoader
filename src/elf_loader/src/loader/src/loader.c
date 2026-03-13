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
#include <iopheap.h>
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
	static char target_arg_storage[1024];
	static char *target_argv[33];
	size_t target_arg_offset = 0;
	int target_argc = 0;
	int ret, i;

	elfdata.epc = 0;

	// argv[0]=path to ELF, argv[1..]=arguments
	if (argc < 2) {  
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	SET_GS_BGCOLOUR(CYAN_BG);
	snprintf(target_path, sizeof(target_path), "%s", argv[0] ? argv[0] : "");
	target_argc = argc - 1;
	if (target_argc > 32) {
		return -E2BIG;
	}
	for (i = 1; i < argc; i++) {
		size_t arg_len = strlen(argv[i]) + 1;
		if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
			return -E2BIG;
		}
		memcpy(&target_arg_storage[target_arg_offset], argv[i], arg_len);
		target_argv[i - 1] = &target_arg_storage[target_arg_offset];
		target_arg_offset += arg_len;
	}
	target_argv[target_argc] = NULL;
	SET_GS_BGCOLOUR(TEAL_BG);

	// Initialize
	SifInitRpc(0);
	wipeUserMem();

	//Writeback data cache before loading ELF.
	FlushCache(0);
	SET_GS_BGCOLOUR(GREEN_BG);
	SifLoadFileInit();
	ret = SifLoadElf(target_path, &elfdata);
	SifLoadFileExit();
	SET_GS_BGCOLOUR(BLUE_BG);
	if (ret == 0 && elfdata.epc != 0) {
		SET_GS_BGCOLOUR(YELLOW_BG);

		// Let's reset IOP because ELF was already loaded in memory
		while(!SifIopReset("rom0:UDNL rom0:EELOADCNF", 0)){};
		while (!SifIopSync()) {};

		SET_GS_BGCOLOUR(ORANGE_BG);
		SifExitIopHeap();
		SET_GS_BGCOLOUR(CORAL_BG);
		SifLoadFileExit();
		SET_GS_BGCOLOUR(OLIVE_BG);
		SifExitRpc();
		SET_GS_BGCOLOUR(NAVY_BG);
		SifExitCmd();

		SET_GS_BGCOLOUR(GRAY_BG);
        SifInitRpc(0);
        // Load modules.
		SET_GS_BGCOLOUR(LIME_BG);
        SifLoadFileInit();
		SET_GS_BGCOLOUR(PINK_BG);
        SifLoadModule("rom0:SIO2MAN", 0, NULL);
		SET_GS_BGCOLOUR(AQUA_BG);
        SifLoadModule("rom0:MCMAN", 0, NULL);
		SET_GS_BGCOLOUR(GOLD_BG);
        SifLoadModule("rom0:MCSERV", 0, NULL);
		SET_GS_BGCOLOUR(TAN_BG);
        SifLoadFileExit();
		SET_GS_BGCOLOUR(BROWN_BG);
        SifExitRpc();

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
