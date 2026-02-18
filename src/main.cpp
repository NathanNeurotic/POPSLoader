
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sifrpc.h>
#include <loadfile.h>
#include <libmc.h>
#include <libcdvd.h>
#include <iopheap.h>
#include <iopcontrol.h>
#include <smod.h>
#include <audsrv.h>
#include <sys/stat.h>
#include <time.h>
#include <ctype.h>

#include <dirent.h>

#include <sbv_patches.h>
#include <smem.h>

#include "include/graphics.h"
#include "include/sound.h"
#include "include/luaplayer.h"
#include "include/pad.h"
#include "include/dprintf.h"

#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>

extern "C"{
#include <libds34bt.h>
#include <libds34usb.h>
}

extern char bootString[];
extern unsigned int size_bootString;

extern unsigned char iomanX_irx[];
extern unsigned int size_iomanX_irx;

extern unsigned char fileXio_irx[];
extern unsigned int size_fileXio_irx;

extern unsigned char sio2man_irx;
extern unsigned int size_sio2man_irx;

extern unsigned char mcman_irx;
extern unsigned int size_mcman_irx;

extern unsigned char mcserv_irx;
extern unsigned int size_mcserv_irx;

extern unsigned char padman_irx;
extern unsigned int size_padman_irx;

extern unsigned char libsd_irx;
extern unsigned int size_libsd_irx;

extern unsigned char cdfs_irx;
extern unsigned int size_cdfs_irx;

extern unsigned char usbd_irx;
extern unsigned int size_usbd_irx;

extern unsigned char bdm_irx;
extern unsigned int size_bdm_irx;

extern unsigned char bdmfs_fatfs_irx;
extern unsigned int size_bdmfs_fatfs_irx;

extern unsigned char usbmass_bd_irx;
extern unsigned int size_usbmass_bd_irx;

extern unsigned char audsrv_irx;
extern unsigned int size_audsrv_irx;

extern unsigned char ds34usb_irx;
extern unsigned int size_ds34usb_irx;

extern unsigned char ds34bt_irx;
extern unsigned int size_ds34bt_irx;

extern unsigned char mmceman_irx;
extern unsigned int size_mmceman_irx;

int mx4sio_init_and_get_root(const char *hint, char *out_root, size_t out_sz);

#ifndef BOOT_VARIANT_STR
#define BOOT_VARIANT_STR "standard"
#endif

char boot_path[255];
char app_dir[255];
int mmce_slot0_ready = -1;
int mmce_slot1_ready = -1;
static clock_t boot_start = 0;

static unsigned int boot_ms(void)
{
    if (boot_start == 0) {
        return 0;
    }
    return (unsigned int)(((clock() - boot_start) * 1000) / CLOCKS_PER_SEC);
}

static void InsertChar(char *base, size_t base_size, char *pos, char ch)
{
    size_t len = strlen(base);
    if (len + 1 >= base_size) {
        return;
    }
    memmove(pos + 1, pos, len - (pos - base) + 1);
    *pos = ch;
}

static void NormalizeDirPath(char *path, size_t size)
{
    if (path == NULL || path[0] == '\0') {
        return;
    }
    for (char *p = path; *p; ++p) {
        if (*p == '\\') {
            *p = '/';
        }
    }
    if (strncmp(path, "host:", 5) == 0) {
        if (path[5] != '/' && path[5] != '\0') {
            InsertChar(path, size, path + 5, '/');
        }
        if (strncmp(path, "host:/", 6) == 0) {
            char *drive = path + 6;
            if (isalpha((unsigned char)drive[0]) && drive[1] == ':' && drive[2] != '/' && drive[2] != '\0') {
                InsertChar(path, size, drive + 2, '/');
            }
        }
    } else {
        char *first_colon = strchr(path, ':');
        char *second_colon = first_colon ? strchr(first_colon + 1, ':') : NULL;
        if (first_colon != NULL && first_colon[1] != '/' && second_colon == NULL) {
            InsertChar(path, size, first_colon + 1, '/');
        }
    }
    size_t len = strlen(path);
    if (len > 0 && path[len - 1] != '/') {
        if (len + 1 < size) {
            path[len] = '/';
            path[len + 1] = '\0';
        }
    }
}

static void BootStamp(const char *stage)
{
    DPRINTF("BOOT: %s %u\n", stage, boot_ms());
}

static bool LoadIrxChecked(const char *name, unsigned char *irx, unsigned int size, int *out_id, int *out_ret);

static bool HasSystemLuaAtRoot(const char *root)
{
    if (root == NULL || root[0] == '\0') {
        return false;
    }
    char candidate[255];
    struct stat st;

    snprintf(candidate, sizeof(candidate), "%ssystem.lua", root);
    if (stat(candidate, &st) == 0) {
        return true;
    }

    snprintf(candidate, sizeof(candidate), "%sPOPSLDR/system.lua", root);
    if (stat(candidate, &st) == 0) {
        return true;
    }

    return false;
}

static bool TryBootRootCandidate(const char *root)
{
    if (root == NULL || root[0] == '\0') {
        return false;
    }

    char normalized[255];
    snprintf(normalized, sizeof(normalized), "%s", root);
    NormalizeDirPath(normalized, sizeof(normalized));

    if (!HasSystemLuaAtRoot(normalized)) {
        return false;
    }

    snprintf(boot_path, sizeof(boot_path), "%s", normalized);
    snprintf(app_dir, sizeof(app_dir), "%s", normalized);
    DPRINTF("Boot root selected: %s\n", normalized);
    return true;
}

static bool IsBootVariant(const char *name)
{
    return (strcmp(BOOT_VARIANT_STR, name) == 0);
}

static void initMMCEManager(bool filexio_ok)
{
    if (!filexio_ok) {
        DPRINTF("Skipping mmceman init; fileXio not ready.\n");
        mmce_slot0_ready = 0;
        mmce_slot1_ready = 0;
        BootStamp("mmceman load/init (skipped)");
        return;
    }

    int mmceman_id = -1;
    int mmceman_ret = -1;
    bool mmceman_ok = LoadIrxChecked("mmceman_irx", &mmceman_irx, size_mmceman_irx, &mmceman_id, &mmceman_ret);
    DPRINTF("mmceman load result: id=%d ret=%d\n", mmceman_id, mmceman_ret);
#ifdef DEBUG
    if (mmceman_ok) {
        smod_mod_info_t info;
        int lookup_ret = smod_get_mod_by_name("mmceman", &info);
        if (lookup_ret < 0) {
            DPRINTF("mmceman module lookup failed: ret=%d\n", lookup_ret);
            DumpLoadedModules();
        }
    }
#endif
    BootStamp("mmceman load/init");

    if (mmceman_ok) {
        mmce_slot0_ready = -1;
        mmce_slot1_ready = -1;
        DPRINTF("MMCE probe deferred until MMCE page entry.\n");
    } else {
        mmce_slot0_ready = 0;
        mmce_slot1_ready = 0;
    }
}

static void ResolveBootRootFromVariant(const char *mx4_hint_root)
{
    char cwd[255] = {0};
    getcwd(cwd, sizeof(cwd));

    if (TryBootRootCandidate(boot_path) ||
        TryBootRootCandidate(app_dir) ||
        TryBootRootCandidate(cwd)) {
        return;
    }

    const char *standard_order[] = {"mass:/", "mc0:/", "mc1:/", "host:/"};
    const char *mmce_order[] = {"mmce0:/", "mmce1:/", "mass:/", "mc0:/", "mc1:/", "host:/"};
    const char *mx4_order[] = {"mx4sio:/", "mx4sio0:/", "mass0:/", "mass:/", "mc0:/", "mc1:/", "host:/"};

    if (IsBootVariant("mmce")) {
        for (size_t i = 0; i < sizeof(mmce_order) / sizeof(mmce_order[0]); ++i) {
            if (TryBootRootCandidate(mmce_order[i])) {
                return;
            }
        }
    } else if (IsBootVariant("mx4sio")) {
        if (mx4_hint_root != NULL && TryBootRootCandidate(mx4_hint_root)) {
            return;
        }
        for (size_t i = 0; i < sizeof(mx4_order) / sizeof(mx4_order[0]); ++i) {
            if (TryBootRootCandidate(mx4_order[i])) {
                return;
            }
        }
    } else {
        for (size_t i = 0; i < sizeof(standard_order) / sizeof(standard_order[0]); ++i) {
            if (TryBootRootCandidate(standard_order[i])) {
                return;
            }
        }
    }

    DPRINTF("No validated boot root found for variant '%s'. Keeping argv-derived root.\n", BOOT_VARIANT_STR);
}

void setLuaBootPath(int argc, char ** argv, int idx)
{
    if (argc>=(idx+1))
    {

	char *p;
	if ((p = strrchr(argv[idx], '/'))!=NULL) {
	    snprintf(boot_path, sizeof(boot_path), "%s", argv[idx]);
	    p = strrchr(boot_path, '/');
	if (p!=NULL)
	    p[1]='\0';
	} else if ((p = strrchr(argv[idx], '\\'))!=NULL) {
	   snprintf(boot_path, sizeof(boot_path), "%s", argv[idx]);
	   p = strrchr(boot_path, '\\');
	   if (p!=NULL)
	     p[1]='\0';
	} else if ((p = strchr(argv[idx], ':'))!=NULL) {
	   snprintf(boot_path, sizeof(boot_path), "%s", argv[idx]);
	   p = strchr(boot_path, ':');
	   if (p!=NULL)
	   p[1]='\0';
	}

    }
    
    NormalizeDirPath(boot_path, sizeof(boot_path));
    
    
}

static void setAppDirFromPath(const char *path)
{
    if (!path || !path[0]) {
        snprintf(app_dir, sizeof(app_dir), "%s", boot_path);
        return;
    }

    char tmp[255];
    snprintf(tmp, sizeof(tmp), "%s", path);
    for (char *p = tmp; *p; ++p) {
        if (*p == '\\') {
            *p = '/';
        }
    }

    char *p = strrchr(tmp, '/');
    if (p != NULL) {
        p[1] = '\0';
    } else if ((p = strchr(tmp, ':')) != NULL) {
        p[1] = '\0';
        strncat(tmp, "/", sizeof(tmp) - strlen(tmp) - 1);
    }

    if (tmp[0] == '\0') {
        snprintf(app_dir, sizeof(app_dir), "%s", boot_path);
    } else {
        snprintf(app_dir, sizeof(app_dir), "%s", tmp);
    }

    size_t len = strlen(app_dir);
    if (len > 0 && app_dir[len - 1] != '/') {
        strncat(app_dir, "/", sizeof(app_dir) - len - 1);
    }
    NormalizeDirPath(app_dir, sizeof(app_dir));
}


void initMC(void)
{
   int ret;
   // mc variables
   int mc_Type, mc_Free, mc_Format;

   DPRINTF("initMC: Initializing Memory Card\n");
   ret = mcInit(MC_TYPE_XMC);
   if( ret < 0 ) {
        DPRINTF("initMC: failed to initialize memcard RPC.\n");
   } else {
        DPRINTF("initMC: memcard RPC started successfully.\n");
   }
   // Since this is the first call, -1 should be returned.
   // makes me sure that next ones will work !
   mcGetInfo(0, 0, &mc_Type, &mc_Free, &mc_Format); 
   mcSync(MC_WAIT, NULL, &ret);
}

static char* ARGV0 = NULL;
char* GetArgv0(void) {
    return ARGV0;
}

#define LOAD_IRX(_irx, argc, arglist) \
    ID = SifExecModuleBuffer(&_irx, size_##_irx, argc, arglist, &RET); \
    printf("%s: id:%d, ret:%d\n", #_irx, ID, RET)
#define LOAD_IRX_NARG(_irx) LOAD_IRX(_irx, 0, NULL)

static bool LoadIrxChecked(const char *name, unsigned char *irx, unsigned int size, int *out_id, int *out_ret)
{
    int id = -1;
    int ret = -1;
    id = SifExecModuleBuffer(irx, size, 0, NULL, &ret);
    if (out_id) {
        *out_id = id;
    }
    if (out_ret) {
        *out_ret = ret;
    }
    if (id < 0 || ret < 0) {
        DPRINTF("IOP module load failed: %s id=%d ret=%d\n", name, id, ret);
        return false;
    }
    DPRINTF("IOP module load ok: %s id=%d ret=%d\n", name, id, ret);
    return true;
}

#ifdef DEBUG
static void DumpLoadedModules(void)
{
    smod_mod_info_t cur;
    smod_mod_info_t next;
    int ret = smod_get_next_mod(NULL, &cur);
    if (ret < 0) {
        DPRINTF("IOP module list unavailable: ret=%d\n", ret);
        return;
    }
    for (;;) {
        char name[32] = {0};
        if (cur.name != NULL) {
            smem_read(cur.name, name, sizeof(name) - 1);
        } else {
            snprintf(name, sizeof(name), "<noname>");
        }
        DPRINTF("IOP module: name=%s id=%d\n", name, cur.id);
        ret = smod_get_next_mod(&cur, &next);
        if (ret < 0) {
            break;
        }
        cur = next;
    }
}
#endif

int main(int argc, char * argv[])
{
    int ID, RET;
    if (argc > 0) ARGV0 = argv[0];
    const char * errMsg;
    boot_start = clock();
    BootStamp("EE init start");

#ifdef RESET_IOP  
    SifInitRpc(0);
    while (!SifIopReset("", 0)){};
    while (!SifIopSync()){};
    SifInitRpc(0);
    BootStamp("IOP reset");
#endif
    
    // install sbv patch fix
    DPRINTF("Installing SBV Patches...\n");
    sbv_patch_enable_lmb();
    sbv_patch_disable_prefix_check(); 
    sbv_patch_fileio(); 

#ifdef POWERPC_UART
	LOAD_IRX_NARG(ppctty_irx);
#endif

    bool ioman_ok = LoadIrxChecked("iomanX_irx", iomanX_irx, size_iomanX_irx, NULL, NULL);
    BootStamp("iomanX load");
    bool filexio_ok = false;
    int filexio_ret = -1;
    if (ioman_ok) {
        filexio_ok = LoadIrxChecked("fileXio_irx", fileXio_irx, size_fileXio_irx, NULL, NULL);
        if (filexio_ok) {
            filexio_ret = fileXioInit();
            if (filexio_ret < 0) {
                DPRINTF("fileXioInit failed: ret=%d\n", filexio_ret);
                filexio_ok = false;
            }
        }
    } else {
        DPRINTF("Skipping fileXio init; iomanX failed to load.\n");
    }
    BootStamp("fileXio load/init");

	LOAD_IRX_NARG(sio2man_irx);
    initMMCEManager(filexio_ok);
    LOAD_IRX_NARG(mcman_irx);
    LOAD_IRX_NARG(mcserv_irx);
    initMC();
    LOAD_IRX_NARG(padman_irx);

    LOAD_IRX_NARG(libsd_irx);


    // load USB modules    
    LOAD_IRX_NARG(usbd_irx);

    
    int ds3pads = 1;
    LOAD_IRX(ds34usb_irx, 4, (char *)&ds3pads);
    LOAD_IRX(ds34bt_irx, 4, (char *)&ds3pads);
    ds34usb_init();
    ds34bt_init();

    LOAD_IRX_NARG(bdm_irx);
    LOAD_IRX_NARG(bdmfs_fatfs_irx);
    LOAD_IRX_NARG(usbmass_bd_irx);

    LOAD_IRX_NARG(cdfs_irx);

    LOAD_IRX_NARG(audsrv_irx);

    //waitUntilDeviceIsReady by fjtrujy

    struct stat buffer;
    int ret = -1;
    int retries = 50;

    while(ret != 0 && retries > 0)
    {
        ret = stat("mass:/", &buffer);
        /* Wait until the device is ready */
        nopdelay();

        retries--;
    }
	
    char mx4_root_hint[32] = {0};
    if (IsBootVariant("mx4sio")) {
        int mx4_init_rc = mx4sio_init_and_get_root(NULL, mx4_root_hint, sizeof(mx4_root_hint));
        if (mx4_init_rc == 0) {
            DPRINTF("MX4SIO early boot init ready: %s\n", mx4_root_hint);
        } else {
            DPRINTF("MX4SIO early boot init failed; falling back to standard root probing.\n");
            mx4_root_hint[0] = '\0';
        }
        BootStamp("mx4sio load/init");
    }

    setLuaBootPath (argc, argv, 0);
    if (argc > 0 && argv[0]) {
        setAppDirFromPath(argv[0]);
    } else {
        setAppDirFromPath(boot_path);
    }

    ResolveBootRootFromVariant(mx4_root_hint[0] ? mx4_root_hint : NULL);
	// Lua init
	// init internals library
    
    // graphics (gsKit)
    initGraphics();

    pad_init();

    // set base path luaplayer
    chdir(boot_path); 

    DPRINTF("boot path : %s\n", boot_path);
	dbgprintf("boot path : %s\n", boot_path);
    DPRINTF("app dir : %s\n", app_dir);
	dbgprintf("app dir : %s\n", app_dir);
    
    BootStamp("Lua init start");
    while (1)
    {
        errMsg = runScript(bootString, true);

        init_scr();

        if (errMsg != NULL)
        {
            scr_setfontcolor(0x0000ff);
		    scr_clear();
		    scr_setXY(5, 2);
		    scr_printf("Enceladus ERROR!\n");
		    scr_printf(errMsg);
		    puts(errMsg);
		    scr_printf("\nPress [start] to restart\n");
        	while (!isButtonPressed(PAD_START)) {
		    }
            scr_setfontcolor(0xffffff);
        }

    }

	return 0;
}
