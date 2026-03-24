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
#include <iopheap.h>
#include <iopcontrol.h>
#include <sifcmd.h>
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
#define WHITE_BG 0x008080 // start main (teal)
#define CYAN_BG 0xFFFF00 // proper argc count
#define RED_BG  0x0000FF // wrong argc count
#define GREEN_BG 0x00FF00 // before SifLoadELF
#define BLUE_BG 0xFF0000 // after SifLoadELF
#define YELLOW_BG 0x00FFFF // good SifLoadELF return
#define MAGENTA_BG 0xFF00FF // wrong SifLoadELF return
#define ORANGE_BG 0x00A5FF  // after SifIopReset
#define BROWN_BG 0x2A2AA5  // after SifIopSync
#define PURPBLE_BG 0x800080  // before ExecPS2
#define IOP_RESET_ARGS "rom0:UDNL rom0:EELOADCNF"


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

static void prepare_iop_reset_handoff(void)
{
	SifExitIopHeap();
	SifExitRpc();
	SifInitRpc(0);
}

static int SifIopResetCompatNoDmaStop(const char *arg, int mode)
{
	static SifCmdResetData_t reset_pkt __attribute__((aligned(64)));
	struct t_SifDmaTransfer dmat;
	int arglen;

	if (arg != NULL) {
		for (arglen = 0; arg[arglen] != '\0'; arglen++) {
			reset_pkt.arg[arglen] = arg[arglen];
		}
	} else {
		arglen = 0;
	}

	reset_pkt.header.psize = sizeof reset_pkt;
	reset_pkt.header.cid   = SIF_CMD_RESET_CMD;
	reset_pkt.arglen       = arglen;
	reset_pkt.mode         = mode;

	dmat.src  = &reset_pkt;
	dmat.dest = (void *)sceSifGetReg(SIF_SYSREG_SUBADDR);
	dmat.size = sizeof(reset_pkt);
	dmat.attr = SIF_DMA_ERT | SIF_DMA_INT_O;
	sceSifWriteBackDCache(&reset_pkt, sizeof(reset_pkt));

	DIntr();
	ee_kmode_enter();
	sceSifSetReg(SIF_REG_SMFLAG, SIF_STAT_BOOTEND);

	if (!sceSifSetDma(&dmat, 1)) {
		ee_kmode_exit();
		EIntr();
		return 0;
	}

	sceSifSetReg(SIF_REG_SMFLAG, SIF_STAT_SIFINIT);
	sceSifSetReg(SIF_REG_SMFLAG, SIF_STAT_CMDINIT);
	sceSifSetReg(SIF_SYSREG_RPCINIT, 0);
	sceSifSetReg(SIF_SYSREG_SUBADDR, (int)NULL);
	ee_kmode_exit();
	EIntr();

	return 1;
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
	static char partition_prefix[1024];
	static char target_path[1024];
	static char full_path[1024];
	const char *load_path;
	static char target_arg_storage[1024];
	static char *target_argv[33];
	size_t target_arg_offset = 0;
	int target_argc = 0;
	int ret, i;

	elfdata.epc = 0;

	// argv[0]=partition prefix, argv[1]=path to ELF, argv[2..]=arguments
	if (argc < 2) {  
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	snprintf(partition_prefix, sizeof(partition_prefix), "%s", argv[0] ? argv[0] : "");
	snprintf(target_path, sizeof(target_path), "%s", argv[1] ? argv[1] : "");
	if (target_path[0] != '\0' &&
	    (strncmp(target_path, "hdd", 3) == 0 || strncmp(target_path, "HDD", 3) == 0)) {
		snprintf(full_path, sizeof(full_path), "%s", target_path);
	} else {
		size_t partition_len = strlen(partition_prefix);
		size_t target_len = strlen(target_path);
		if (partition_len + target_len >= sizeof(full_path)) {
			return -ENAMETOOLONG;
		}
		memcpy(full_path, partition_prefix, partition_len);
		memcpy(full_path + partition_len, target_path, target_len + 1);
	}
	load_path = full_path;
	target_argc = argc - 1;
	if (target_argc > 32) {
		return -E2BIG;
	}
	target_argv[0] = full_path;
	for (i = 2; i < argc; i++) {
		size_t arg_len = strlen(argv[i]) + 1;
		if ((target_arg_offset + arg_len) > sizeof(target_arg_storage)) {
			return -E2BIG;
		}
		memcpy(&target_arg_storage[target_arg_offset], argv[i], arg_len);
		target_argv[i - 1] = &target_arg_storage[target_arg_offset];
		target_arg_offset += arg_len;
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

		// Let's reset IOP because ELF was already loaded in memory
		prepare_iop_reset_handoff();
		while(!SifIopResetCompatNoDmaStop(IOP_RESET_ARGS, 0)){};
		SET_GS_BGCOLOUR(ORANGE_BG);
		while (!SifIopSync()) {};

		SET_GS_BGCOLOUR(BROWN_BG);

	        SifInitRpc(0);
	        // Load modules.
	        SifLoadFileInit();
	        SifLoadModule("rom0:SIO2MAN", 0, NULL);
	        SifLoadModule("rom0:MCMAN", 0, NULL);
	        SifLoadModule("rom0:MCSERV", 0, NULL);
	        SifLoadFileExit();
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
