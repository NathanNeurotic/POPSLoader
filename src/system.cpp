
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

		return 0;
	}

	return ResolveAssetPath(out, outsz, relativeName);
}


/* Removed 2026-05-25 (audit cleanup):
 *
 * The IOP_Reset / load_modules / CleanUp trio and the commented-out
 * load_elf function were the original (pre-elf_loader) launch
 * infrastructure. They were superseded by src/elf_loader/src/elf.c and
 * the BRAM child loader long ago; the only caller of CleanUp was the
 * already-commented-out load_elf, so the whole chain was dead weight
 * with shadow elf_header_t / elf_pheader_t typedefs that conflicted
 * with the proper definitions in src/elf_loader/src/elf.h.
 *
 * If you need to reference the historical implementation, it's
 * preserved in git history at commit dff091c (BETA-12-PLAY pre-audit).
 */

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
