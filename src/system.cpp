
#include <kernel.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <malloc.h>
#include <sys/stat.h>

#include "include/system.h"
#include "include/luaplayer.h"
#include "include/dprintf.h"

//extern int size_loader_elf;

void IOP_Reset(void);

/* Normalize a pathname by removing
  . and .. components, duplicated /, etc. */
char* __ps2_normalize_path(char *path_name)
{
	int i, j;
	int first, next;
	static char out[255];
	
	bool skip_leading_slash = (!strncmp(path_name, "pfs", 3));
	/* First copy the path into our temp buffer */
	strcpy(out, path_name);
        /* Then append "/" to make the rest easier */
	strcat(out,"/");

	/* Convert "//" to "/" */
	for(i=0; out[i+1]; i++) {
		if(out[i]=='/' && out[i+1]=='/') {
			for(j=i+1; out[j]; j++)
				out[j] = out[j+1];
			i--;
		}
	}

	/* Convert "/./" to "/" */
	for(i=0; out[i] && out[i+1] && out[i+2]; i++) {
		if(out[i]=='/' && out[i+1]=='.' && out[i+2]=='/') {
			for(j=i+1; out[j]; j++)
				out[j] = out[j+2];
			i--;
		}
	}

	/* Convert "/path/../" to "/" until we can't anymore.  Also
	 * convert leading "/../" to "/" */
	first = next = 0;
	while(1) {
		/* If a "../" follows, remove it and the parent */
		if(out[next+1] && out[next+1]=='.' && 
		   out[next+2] && out[next+2]=='.' &&
		   out[next+3] && out[next+3]=='/') {
			for(j=0; out[first+j+1]; j++)
				out[first+j+1] = out[next+j+4];
			first = next = 0;
			continue;
		}

		/* Find next slash */
		first = next;
		for(next=first+1; out[next] && out[next] != '/'; next++)
			continue;
		if(!out[next]) break;
	}

	/* Remove trailing "/" */
	for(i=1; out[i]; i++)
		continue;
	if(i >= 1 && out[i-1] == '/'  && !skip_leading_slash) // pfs:? filesystem driver expects trailing slash...
		out[i-1] = 0;

	return (char*)out;
}

int ResolveAssetPath(char* out, size_t outsz, const char* relativeName)
{
	if (!out || outsz == 0 || !relativeName) return 0;

	if (strchr(relativeName, ':') != NULL) {
		snprintf(out, outsz, "%s", relativeName);
		struct stat st;
		return (stat(out, &st) == 0);
	}

	char candidate[255];
	struct stat st;

	snprintf(candidate, sizeof(candidate), "%s%s", app_dir, relativeName);
	if (stat(candidate, &st) == 0) {
		DPRINTF("ResolveAssetPath: %s\n", candidate);
		snprintf(out, outsz, "%s", candidate);
		return 1;
	}

	snprintf(candidate, sizeof(candidate), "%sPOPSLDR/%s", app_dir, relativeName);
	if (stat(candidate, &st) == 0) {
		DPRINTF("ResolveAssetPath: %s\n", candidate);
		snprintf(out, outsz, "%s", candidate);
		return 1;
	}


	/* Fallback: current working directory (assets alongside the ELF folder). */
	char cwd[256];
	if (getcwd(cwd, sizeof(cwd)) != NULL) {
		size_t clen = strlen(cwd);
		if (clen > 0 && cwd[clen - 1] != '/') {
			strncat(cwd, "/", sizeof(cwd) - clen - 1);
		}
		snprintf(candidate, sizeof(candidate), "%s%s", cwd, relativeName);
		if (stat(candidate, &st) == 0) {
			DPRINTF("ResolveAssetPath: %s\n", candidate);
			snprintf(out, outsz, "%s", candidate);
			return 1;
		}
		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/%s", cwd, relativeName);
		if (stat(candidate, &st) == 0) {
			DPRINTF("ResolveAssetPath: %s\n", candidate);
			snprintf(out, outsz, "%s", candidate);
			return 1;
		}
	}

	/* Fallback: look relative to the boot device root (boot_root), not just app_dir.
	   This avoids relying on the ambiguous "mass:" alias when USB and MX4SIO are both present,
	   and supports layouts where POPSLDR is placed at the device root (e.g. mass1:/POPSLDR/). */
	snprintf(candidate, sizeof(candidate), "%s%s", boot_root, relativeName);
	if (stat(candidate, &st) == 0) {
		DPRINTF("ResolveAssetPath: %s\n", candidate);
		snprintf(out, outsz, "%s", candidate);
		return 1;
	}

	snprintf(candidate, sizeof(candidate), "%sPOPSLDR/%s", boot_root, relativeName);
	if (stat(candidate, &st) == 0) {
		DPRINTF("ResolveAssetPath: %s\n", candidate);
		snprintf(out, outsz, "%s", candidate);
		return 1;
	}

	return 0;
}

static int ResolveAssetCandidate(char* out, size_t outsz, const char* candidate)
{
	struct stat st;
	if (stat(candidate, &st) == 0) {
		DPRINTF("ResolveAssetPath: %s\n", candidate);
		snprintf(out, outsz, "%s", candidate);
		return 1;
	}
	return 0;
}

int ResolveAssetPathTyped(char* out, size_t outsz, const char* relativeName, AssetKind kind)
{
	if (!out || outsz == 0 || !relativeName) return 0;

	if (strchr(relativeName, ':') != NULL) {
		snprintf(out, outsz, "%s", relativeName);
		struct stat st;
		return (stat(out, &st) == 0);
	}

	char candidate[255];

	if (kind == ASSET_IMG) {
		snprintf(candidate, sizeof(candidate), "%s%s", app_dir, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sIMG/%s", app_dir, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/IMG/%s", app_dir, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/%s", app_dir, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		/* Fallback: search from boot device root as well (avoids ambiguous mass: alias). */
		snprintf(candidate, sizeof(candidate), "%s%s", boot_root, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sIMG/%s", boot_root, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/IMG/%s", boot_root, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/%s", boot_root, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		return 0;
	}

	if (kind == ASSET_IRX) {
		snprintf(candidate, sizeof(candidate), "%s%s", app_dir, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sIRX/%s", app_dir, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/IRX/%s", app_dir, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/%s", app_dir, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		/* Fallback: search from boot device root as well (avoids ambiguous mass: alias). */
		snprintf(candidate, sizeof(candidate), "%s%s", boot_root, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sIRX/%s", boot_root, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/IRX/%s", boot_root, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		snprintf(candidate, sizeof(candidate), "%sPOPSLDR/%s", boot_root, relativeName);
		if (ResolveAssetCandidate(out, outsz, candidate)) return 1;

		return 0;
	}

	return ResolveAssetPath(out, outsz, relativeName);
}


void IOP_Reset(void)
{
	// resets IOP and update with EELOADCNF
	
  	while(!SifIopReset("rom0:UDNL rom0:EELOADCNF",0));
  	while(!SifIopSync());
  	SifExitIopHeap();
  	SifLoadFileExit();
  	SifExitRpc();
  	SifExitCmd();
  	
  	SifInitRpc(0);
  	FlushCache(0);
  	FlushCache(2);
}

//--------------------------------------------------------------
// ELF-header structures and identifiers
#define ELF_MAGIC	0x464c457f
#define ELF_PT_LOAD	1

//--------------------------------------------------------------
typedef struct
{
	u8	ident[16];
	u16	type;
	u16	machine;
	u32	version;
	u32	entry;
	u32	phoff;
	u32	shoff;
	u32	flags;
	u16	ehsize;
	u16	phentsize;
	u16	phnum;
	u16	shentsize;
	u16	shnum;
	u16	shstrndx;
} elf_header_t;
//--------------------------------------------------------------
typedef struct
{
	u32	  type;
	u32	  offset;
	void *vaddr;
	u32	  paddr;
	u32	  filesz;
	u32	  memsz;
	u32	  flags;
	u32	  align;
} elf_pheader_t;

void load_modules(void)
{
    // Apply loadmodulebuffer and prefix check patch
    sbv_patch_enable_lmb();
    sbv_patch_disable_prefix_check();
    
    SifLoadModule("rom0:SIO2MAN", 0, 0);
	SifLoadModule("rom0:CDVDFSV", 0, 0);
    SifLoadModule("rom0:CDVDMAN", 0, 0);
    SifLoadModule("rom0:MCMAN", 0, 0);
    SifLoadModule("rom0:MCSERV", 0, 0);
   	SifLoadModule("rom0:PADMAN", 0, 0);  
	
}

void CleanUp(int iop_reset)
{	
   if (iop_reset) {
   		IOP_Reset();
    
   		SifLoadFileInit();
		load_modules();
	}
	
  	SifExitIopHeap();
  	SifLoadFileExit();
  	SifExitRpc();
  	SifExitCmd();
  	
  	FlushCache(0);
  	FlushCache(2);
}

/*
void load_elf(const char *elf_path, int reboot_iop, char** Cargs, int Cargc)
{   
	u8 *boot_elf;
	elf_header_t *boot_header;
	elf_pheader_t *boot_pheader;
	int i;
	char *args[6];
	char **final_argv;
	int final_argc = 1;
	char elfpath[1024];
	//int n = 0;
	
    CleanUp(reboot_iop);	

	SifInitRpc(0);
	SifLoadFileInit();
 	SifLoadFileExit();  

	strcpy(elfpath, elf_path);
	if (Cargs == NULL || Cargc < 1) {
		args[0] = elfpath;
		args[1] = elfpath;
		final_argv = args;
	} else {
		final_argv = Cargs;
		final_argc = Cargc;
	}

	// Load & execute embedded loader from here	
	boot_elf = (u8 *)&loader_elf;
	
	// Get Elf header
	boot_header = (elf_header_t *)boot_elf;
	
	// Check elf magic
	if ((*(u32*)boot_header->ident) != ELF_MAGIC) 
		return;

	// Get program headers
	boot_pheader = (elf_pheader_t *)(boot_elf + boot_header->phoff);
	
	// Scan through the ELF's program headers and copy them into apropriate RAM
	// section, then padd with zeros if needed.
	for (i = 0; i < boot_header->phnum; i++) {
		
		if (boot_pheader[i].type != ELF_PT_LOAD)
			continue;

		memcpy(boot_pheader[i].vaddr, boot_elf + boot_pheader[i].offset, boot_pheader[i].filesz);
	
		if (boot_pheader[i].memsz > boot_pheader[i].filesz)
			memset((void*)((int)boot_pheader[i].vaddr + boot_pheader[i].filesz), 0, boot_pheader[i].memsz - boot_pheader[i].filesz);
	}		
	
	SifExitRpc();
	
	// Execute Elf Loader
	ExecPS2((void *)boot_header->entry, 0, final_argc, final_argv);	
	
}
*/
///////////////////////////////////////////////

void* AllocateLargestFreeBlock(size_t* Size)
{
  size_t s0, s1;
  void* p;

  s0 = ~(size_t)0 ^ (~(size_t)0 >> 1);

  while (s0 && (p = malloc(s0)) == NULL)
    s0 >>= 1;

  if (p)
    free(p);

  s1 = s0 >> 1;

  while (s1)
  {
    if ((p = malloc(s0 + s1)) != NULL)
    {
      s0 += s1;
      free(p);
    }
    s1 >>= 1;
  }

  while (s0 && (p = malloc(s0)) == NULL)
    s0 ^= s0 & -s0;

  *Size = s0;
  return p;
}

size_t GetFreeSize(void)
{
  size_t total = 0;
  void* pFirst = NULL;
  void* pLast = NULL;

  for (;;)
  {
    size_t largest;
    void* p = AllocateLargestFreeBlock(&largest);

    if (largest < sizeof(void*))
    {
      if (p != NULL)
        free(p);
      break;
    }

    *(void**)p = NULL;

    total += largest;

    if (pFirst == NULL)
      pFirst = p;

    if (pLast != NULL)
      *(void**)pLast = p;

    pLast = p;
  }

  while (pFirst != NULL)
  {
    void* p = *(void**)pFirst;
    free(pFirst);
    pFirst = p;
  }

  return total;
}
