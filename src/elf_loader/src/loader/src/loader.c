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
#include <fileXio_rpc.h>
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

/*
 * Minimal ELF struct definitions for loading a 32-bit PS2 ELF.
 * Only the fields needed for segment loading are included.
 */
#define LDR_ELF_MAGIC   0x464c457fu  /* "\x7fELF" */
#define LDR_ELF_PT_LOAD 1u
#define LDR_MAX_PHDRS   32

typedef struct {
	unsigned char e_ident[16];
	unsigned short e_type, e_machine;
	unsigned int e_version, e_entry, e_phoff, e_shoff, e_flags;
	unsigned short e_ehsize, e_phentsize, e_phnum;
	unsigned short e_shentsize, e_shnum, e_shstrndx;
} ldr_elf_hdr_t;

typedef struct {
	unsigned int p_type, p_offset;
	void *p_vaddr;
	unsigned int p_paddr, p_filesz, p_memsz, p_flags, p_align;
} ldr_elf_phdr_t;

/*
 * Load a PS2 ELF from a pfs: path using fileXio RPC calls directly.
 * SifLoadElf uses the old IOP IOMAN which cannot access iomanX-registered
 * pfs: devices.  fileXio (already running on the IOP) uses iomanX and CAN.
 * This function must be called after fileXioInit() and SifInitRpc(0).
 * Single-threaded by design — the embedded loader has no other threads.
 * PS2 ELFs are always well under 2GB so int casts on offsets are safe.
 * Returns 0 on success (sets *out_entry to the ELF entry point), -1 on error.
 */
static int load_elf_via_filexio(const char *path, unsigned int *out_entry)
{
	static ldr_elf_hdr_t hdr;
	static ldr_elf_phdr_t phdrs[LDR_MAX_PHDRS];
	static const unsigned char elf_magic[4] = { 0x7f, 'E', 'L', 'F' };
	int fd, i;

	fd = fileXioOpen(path, FIO_O_RDONLY, 0);
	if (fd < 0)
		return -1;

	if (fileXioRead(fd, &hdr, sizeof(hdr)) != (int)sizeof(hdr))
		goto fail;
	if (memcmp(hdr.e_ident, elf_magic, 4) != 0)
		goto fail;
	if (hdr.e_phnum == 0 || hdr.e_phnum > LDR_MAX_PHDRS)
		goto fail;

	if (fileXioLseek(fd, (int)hdr.e_phoff, SEEK_SET) < 0)
		goto fail;
	if (fileXioRead(fd, phdrs, hdr.e_phnum * sizeof(ldr_elf_phdr_t)) !=
	    (int)(hdr.e_phnum * sizeof(ldr_elf_phdr_t)))
		goto fail;

	for (i = 0; i < hdr.e_phnum; i++) {
		if (phdrs[i].p_type != LDR_ELF_PT_LOAD)
			continue;
		if (phdrs[i].p_filesz > 0) {
			if (fileXioLseek(fd, (int)phdrs[i].p_offset, SEEK_SET) < 0)
				goto fail;
			if (fileXioRead(fd, phdrs[i].p_vaddr,
			                (int)phdrs[i].p_filesz) !=
			    (int)phdrs[i].p_filesz)
				goto fail;
		}
		if (phdrs[i].p_memsz > phdrs[i].p_filesz) {
			memset((char *)phdrs[i].p_vaddr + phdrs[i].p_filesz, 0,
			       phdrs[i].p_memsz - phdrs[i].p_filesz);
		}
	}

	fileXioClose(fd);
	*out_entry = hdr.e_entry;
	return 0;
fail:
	fileXioClose(fd);
	return -1;
}

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

	if (strncmp(target_path, "pfs", 3) == 0) {
		/*
		 * pfs: paths are registered with iomanX, not the old IOP IOMAN.
		 * SifLoadElf (IOP LOADFILE service) uses IOMAN and cannot access
		 * pfs: devices.  Use fileXio RPC directly instead.
		 */
		unsigned int elf_entry = 0;
		fileXioInit();
		ret = load_elf_via_filexio(target_path, &elf_entry);
		fileXioExit();
		SET_GS_BGCOLOUR(BLUE_BG);
		if (ret != 0 || elf_entry == 0) {
			SET_GS_BGCOLOUR(MAGENTA_BG);
			SifExitRpc();
			return -ENOENT;
		}
		elfdata.epc = elf_entry;
		/* GP is zeroed: POPSTARTER.ELF's crt0 initializes $gp itself
		 * (via lui/addiu from the _gp symbol) before calling main. */
		elfdata.gp = 0;
	} else {
		SifLoadFileInit();
		ret = SifLoadElf(target_path, &elfdata);
		SifLoadFileExit();
		SET_GS_BGCOLOUR(BLUE_BG);
		if (ret != 0 || elfdata.epc == 0) {
			SET_GS_BGCOLOUR(MAGENTA_BG);
			SifExitRpc();
			return -ENOENT;
		}
	}

	SET_GS_BGCOLOUR(YELLOW_BG);

	// Let's reset IOP because ELF was already loaded in memory
	while(!SifIopReset(NULL, 0)){};
	while (!SifIopSync()) {};

	SET_GS_BGCOLOUR(ORANGE_BG);

        SifInitRpc(0);
        // Load modules.
        SifLoadFileInit();
        SifLoadModule("rom0:SIO2MAN", 0, NULL);
        SifLoadModule("rom0:MCMAN", 0, NULL);
        SifLoadModule("rom0:MCSERV", 0, NULL);
        SifLoadFileExit();
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
}

//--------------------------------------------------------------
//End of func:  int main(int argc, char *argv[])
//--------------------------------------------------------------
//End of file:  loader.c
//--------------------------------------------------------------
