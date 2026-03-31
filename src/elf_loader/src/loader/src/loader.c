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
#include <fcntl.h>
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>

#ifndef FIO_MT_RDONLY
#define FIO_MT_RDONLY 0x01
#endif

#ifdef LOADER_ENABLE_DEBUG_COLORS
#include <debug.h>
#define SET_GS_BGCOLOUR(colour) {*((volatile unsigned long int *)0x120000E0) = colour;}
#define DPRINTF(x...) scr_printf(x)
#else
#define SET_GS_BGCOLOUR(colour)
#define DPRINTF(x...) do {} while (0)
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
	/* Memory note: Avoid wiping the top 1MB of memory where the PS2 kernel state,
	   thread stacks, and RPC buffers reside, to prevent breaking fileXio and causing crashes. */
	for (i = 0x100000; i < (GetMemorySize() - 0x100000); i += 64) {
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

static int should_use_filexio_direct_load(const char *partition_context, const char *load_path)
{
	/* wLaunchELF intentionally bypasses SifLoadElf for pfs0:/... paths because
	   the IOP loadfile module often fails to read from PFS.
	   We force fileXio for ALL HDD/PFS paths (even with partition context). */
	return (is_hdd_partition_context(partition_context) ||
	        (load_path != NULL &&
	         (strncmp(load_path, "pfs", 3) == 0 || strncmp(load_path, "PFS", 3) == 0 ||
	          strncmp(load_path, "hdd", 3) == 0 || strncmp(load_path, "HDD", 3) == 0)));
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
		strncpy(out, load_path, out_size - 1);
		out[out_size - 1] = '\0';
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
		strncpy(out, partition_context, out_size - 1);
		out[out_size - 1] = '\0';
		if (suffix[0] != '/') {
			strncat(out, "pfs:/", out_size - strlen(out) - 1);
			strncat(out, suffix, out_size - strlen(out) - 1);
		} else {
			strncat(out, "pfs:", out_size - strlen(out) - 1);
			strncat(out, suffix, out_size - strlen(out) - 1);
		}
		return 0;
	}

	strncpy(out, partition_context, out_size - 1);
	out[out_size - 1] = '\0';
	strncat(out, load_path, out_size - strlen(out) - 1);
	return 0;
}

#define LOADER_ELF_MAGIC        0x464c457fU
#define LOADER_PT_LOAD          1
#define LOADER_PT_MIPS_REGINFO  0x70000000U
#define LOADER_ELF_MAX_PHDRS    16

typedef struct {
	unsigned char  ident[16];
	unsigned short type, machine;
	unsigned int   version, entry, phoff, shoff, flags;
	unsigned short ehsize, phentsize, phnum, shentsize, shnum, shstrndx;
} loader_elf_hdr_t;

typedef struct {
	unsigned int type, offset;
	void        *vaddr;
	unsigned int paddr, filesz, memsz, flags, align;
} loader_elf_phdr_t;

static int load_elf_via_filexio(const char *path,
                                unsigned int *entry_out,
                                unsigned int *gp_out)
{
	int fd;
	int i;
	int n;
	static loader_elf_hdr_t hdr;
	static loader_elf_phdr_t phdrs[LOADER_ELF_MAX_PHDRS];
	unsigned int gp = 0;
	int wLaunchElfFileMode = FIO_S_IRUSR | FIO_S_IWUSR | FIO_S_IXUSR | FIO_S_IRGRP | FIO_S_IWGRP | FIO_S_IXGRP | FIO_S_IROTH | FIO_S_IWOTH | FIO_S_IXOTH;

	if (entry_out == NULL || gp_out == NULL) {
		return -EINVAL;
	}

	*entry_out = 0;
	*gp_out = 0;

	fd = fileXioOpen(path, O_RDONLY, wLaunchElfFileMode);
	if (fd < 0 && path != NULL &&
	    (strncmp(path, "hdd", 3) == 0 || strncmp(path, "HDD", 3) == 0)) {
		const char *first_colon = strchr(path, ':');
		const char *second_colon = first_colon ? strchr(first_colon + 1, ':') : NULL;
		if (second_colon != NULL &&
		    (strncmp(second_colon + 1, "pfs", 3) == 0 ||
		     strncmp(second_colon + 1, "PFS", 3) == 0)) {
			fd = fileXioOpen(second_colon + 1, O_RDONLY, wLaunchElfFileMode);
		}
	}
	if (fd < 0) {
		return -ENOENT;
	}

	n = fileXioRead(fd, &hdr, sizeof(hdr));
	if (n != (int)sizeof(hdr) || *(unsigned int *)hdr.ident != LOADER_ELF_MAGIC) {
		fileXioClose(fd);
		return -ENOEXEC;
	}
	if (hdr.phnum == 0 || hdr.phnum > LOADER_ELF_MAX_PHDRS) {
		fileXioClose(fd);
		return -ENOEXEC;
	}

	fileXioLseek(fd, hdr.phoff, SEEK_SET);
	n = fileXioRead(fd, phdrs, sizeof(loader_elf_phdr_t) * hdr.phnum);
	if (n != (int)(sizeof(loader_elf_phdr_t) * hdr.phnum)) {
		fileXioClose(fd);
		return -EIO;
	}

	for (i = 0; i < hdr.phnum; i++) {
		if (phdrs[i].type == LOADER_PT_MIPS_REGINFO) {
			unsigned int tmp_gp = 0;
			fileXioLseek(fd, phdrs[i].offset + 20, SEEK_SET);
			if (fileXioRead(fd, &tmp_gp, sizeof(tmp_gp)) == (int)sizeof(tmp_gp)) {
				gp = tmp_gp;
			}
		}
		if (phdrs[i].type != LOADER_PT_LOAD || phdrs[i].filesz == 0) {
			continue;
		}
		fileXioLseek(fd, phdrs[i].offset, SEEK_SET);
		n = fileXioRead(fd, phdrs[i].vaddr, phdrs[i].filesz);
		if (n != (int)phdrs[i].filesz) {
			fileXioClose(fd);
			return -EIO;
		}
		if (phdrs[i].memsz > phdrs[i].filesz) {
			memset((void *)((unsigned int)phdrs[i].vaddr + phdrs[i].filesz),
			       0, phdrs[i].memsz - phdrs[i].filesz);
		}
	}

	fileXioClose(fd);
	*entry_out = hdr.entry;
	*gp_out = gp;
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
	unsigned int filexio_entry = 0;
	unsigned int filexio_gp = 0;
	int loaded_via_filexio = 0;
	int target_argc = 0;
	int ret, i;

	elfdata.epc = 0;

	// argv[0]=partition context when present, argv[1]=load path,
	// argv[2..]=arguments for the target ELF
	if (argc < 2) {  
		SET_GS_BGCOLOUR(RED_BG);
		return -EINVAL;
	}
	strncpy(partition_context, argv[0] ? argv[0] : "", sizeof(partition_context) - 1);
	partition_context[sizeof(partition_context) - 1] = '\0';
	strncpy(load_path, argv[1] ? argv[1] : "", sizeof(load_path) - 1);
	load_path[sizeof(load_path) - 1] = '\0';
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
	if (should_use_filexio_direct_load(partition_context, load_path)) {
		loaded_via_filexio = 1;
		fileXioInit();
		ret = load_elf_via_filexio(load_path, &filexio_entry, &filexio_gp);
		if (ret == 0) {
			elfdata.epc = filexio_entry;
			elfdata.gp = filexio_gp;
		} else {
			elfdata.epc = 0;
			elfdata.gp = 0;
		}
	} else {
		ret = mount_partition_context_on_pfs0(partition_context);
		if (ret == 0) {
			SifLoadFileInit();
			ret = SifLoadElf(load_path, &elfdata);
			SifLoadFileExit();
		} else {
			elfdata.epc = 0;
			elfdata.gp = 0;
		}
	}
	SET_GS_BGCOLOUR(BLUE_BG);
	if (ret == 0 && elfdata.epc != 0) {
		SET_GS_BGCOLOUR(YELLOW_BG);

		/* Properly teardown any EE-side RPC clients *before* we wipe the IOP,
		   otherwise the DMA channel will hang waiting for a response from the dead IOP. */
		if (!loaded_via_filexio) {
			SifLoadFileExit();
		}
		SifExitRpc();
		SifExitCmd();

		if (is_hdd_partition_context(partition_context)) {
			while(!SifIopReset("", 0)){};
			while (!SifIopSync()) {};

			SET_GS_BGCOLOUR(ORANGE_BG);

			/* Re-initialize RPC temporarily to load the necessary modules */
			SifInitRpc(0);
			SifLoadFileInit();
			SifLoadModule("rom0:SIO2MAN", 0, NULL);
			SifLoadModule("rom0:MCMAN", 0, NULL);
			SifLoadModule("rom0:MCSERV", 0, NULL);

			/* Teardown again before ExecPS2 */
			SifLoadFileExit();
			SifExitRpc();
		}

		SET_GS_BGCOLOUR(BROWN_BG);

		FlushCache(0);
		FlushCache(2);

		SET_GS_BGCOLOUR(PURPBLE_BG);
		
		DPRINTF("POPS EXEC: argc=%d\n", target_argc);
		for (i = 0; i < target_argc; i++) {
			DPRINTF("POPS EXEC: argv[%d] = %s\n", i, target_argv[i]);
		}
		ret = ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, target_argc, target_argv);
		return (ret != 0) ? ret : -3500;
	} else {
		SET_GS_BGCOLOUR(MAGENTA_BG);
		SifExitRpc();
		if (ret != 0) {
			return -3200 + ret;
		}
		return -3201;
	}
}

//--------------------------------------------------------------
//End of func:  int main(int argc, char *argv[])
//--------------------------------------------------------------
//End of file:  loader.c
//--------------------------------------------------------------
