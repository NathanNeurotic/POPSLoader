#include <sifrpc.h>
#include <iopcontrol.h>
#include <iopheap.h>
#include <sbv_patches.h>
#include <loadfile.h>
#include <libcdvd.h>
#include <stdbool.h>
#include <stddef.h>

#define SCECdESRDVD_0 0x15  // ESR-patched DVD, as seen without ESR driver active
#define SCECdESRDVD_1 0x16  // ESR-patched DVD, as seen with ESR driver active

typedef struct
{
	int type;
	char name[16];
	int value;
} DiscType;

extern char* __ps2_normalize_path(char *path_name);
extern bool normalize_root(const char *devroot, char *out, size_t outsz);
extern bool join_path(char *out, size_t outsz, const char *root, const char *rel);
extern bool is_valid_root(const char *root);
extern void normalize_device_path(char *path);
#define load_elf_NoIOPReset(ELF) load_elf(ELF, 0, NULL, 0);
extern void load_elf(const char *elf_path, int reboot_iop, char** Cargs, int Cargc);
extern size_t GetFreeSize(void);
