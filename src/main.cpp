
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
#include <kernel.h>
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

extern "C" int DelayThread(int usec);

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

extern unsigned char mx4sio_bd_irx;
extern unsigned int size_mx4sio_bd_irx;

extern unsigned char audsrv_irx;
extern unsigned int size_audsrv_irx;

extern unsigned char ds34usb_irx;
extern unsigned int size_ds34usb_irx;

extern unsigned char ds34bt_irx;
extern unsigned int size_ds34bt_irx;

extern unsigned char mmceman_irx;
extern unsigned int size_mmceman_irx;

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

static void NormalizeArgv0Path(char *path)
{
    if (path == NULL || path[0] == '\0') {
        return;
    }

    for (char *p = path; *p; ++p) {
        if (*p == '\\') {
            *p = '/';
        }
    }

    if (strncmp(path, "mass://", 7) == 0) {
        memmove(path + 6, path + 7, strlen(path + 7) + 1);
    }
}

static bool BootPathMatchesLaunchPath(const char *launch_path)
{
    if (boot_path[0] == '\0') {
        return false;
    }

    size_t boot_len = strlen(boot_path);
    if (boot_len == 0 || boot_path[boot_len - 1] != '/') {
        return false;
    }

    if (launch_path == NULL || launch_path[0] == '\0') {
        return true;
    }

    return strncmp(launch_path, boot_path, boot_len) == 0;
}

static const char *GetLaunchPath(int argc, char **argv)
{
    if (argc > 0 && argv != NULL && argv[0] != NULL && argv[0][0] != '\0') {
        NormalizeArgv0Path(argv[0]);
        return argv[0];
    }

    static char cwd_path[255];
    if (getcwd(cwd_path, sizeof(cwd_path)) != NULL) {
        NormalizeDirPath(cwd_path, sizeof(cwd_path));
        return cwd_path;
    }

    return NULL;
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

static bool ExtractDeviceRoot(const char *path, char *root, size_t root_size)
{
    if (path == NULL || root == NULL || root_size < 4) {
        return false;
    }

    const char *colon = strchr(path, ':');
    if (colon == NULL) {
        return false;
    }

    size_t prefix_len = (size_t)(colon - path) + 1;
    if (prefix_len + 1 >= root_size) {
        return false;
    }

    memcpy(root, path, prefix_len);
    root[prefix_len] = '/';
    root[prefix_len + 1] = '\0';
    return true;
}

static bool ResolveMassAliasLaunchPath(const char *launch_path, char *resolved_path, size_t resolved_size)
{
    if (launch_path == NULL || resolved_path == NULL || resolved_size == 0) {
        return false;
    }
    if (strncmp(launch_path, "mass:/", 6) != 0) {
        return false;
    }
    int explicit_idx = -1;
    if (sscanf(launch_path, "mass%d:/", &explicit_idx) == 1) {
        return false;
    }

    const char *relative = launch_path + 6;
    struct stat st;
    for (int i = 0; i <= 9; ++i) {
        char candidate[255];
        snprintf(candidate, sizeof(candidate), "mass%d:/%s", i, relative);
        if (stat(candidate, &st) == 0) {
            snprintf(resolved_path, resolved_size, "%s", candidate);
            return true;
        }
    }

    return false;
}

static bool BuildSystemLuaPath(const char *dir, char *out_path, size_t out_size)
{
    if (dir == NULL || out_path == NULL || out_size == 0) {
        return false;
    }
    int written = snprintf(out_path, out_size, "%ssystem.lua", dir);
    return written > 0 && (size_t)written < out_size;
}

static bool RebindAppDirFromLaunchPath(const char *launch_path)
{
    if (launch_path == NULL) {
        return false;
    }
    if (strncmp(launch_path, "mass", 4) != 0 && strncmp(launch_path, "mx4sio", 6) != 0) {
        return false;
    }

    char launch_copy[255];
    snprintf(launch_copy, sizeof(launch_copy), "%s", launch_path);
    for (char *p = launch_copy; *p; ++p) {
        if (*p == '\\') {
            *p = '/';
        }
    }

    const char *suffix = strchr(launch_copy, ':');
    if (suffix == NULL || suffix[1] != '/') {
        return false;
    }

    char launch_dir[255];
    snprintf(launch_dir, sizeof(launch_dir), "%s", launch_copy);
    char *last_slash = strrchr(launch_dir, '/');
    if (last_slash == NULL) {
        return false;
    }
    last_slash[1] = '\0';

    const char *dir_suffix = strchr(launch_dir, ':');
    if (dir_suffix == NULL || dir_suffix[1] != '/') {
        return false;
    }

    struct stat st;
    for (int i = 0; i <= 9; ++i) {
        char candidate_launch[255];
        char candidate_dir[255];
        char candidate_system[255];
        snprintf(candidate_launch, sizeof(candidate_launch), "mass%d:%s", i, suffix + 1);
        snprintf(candidate_dir, sizeof(candidate_dir), "mass%d:%s", i, dir_suffix + 1);

        if (stat(candidate_launch, &st) != 0) {
            continue;
        }
        if (!BuildSystemLuaPath(candidate_dir, candidate_system, sizeof(candidate_system))) {
            continue;
        }
        if (stat(candidate_system, &st) != 0) {
            continue;
        }

        snprintf(app_dir, sizeof(app_dir), "%s", candidate_dir);
        snprintf(boot_path, sizeof(boot_path), "%s", candidate_dir);
        NormalizeDirPath(app_dir, sizeof(app_dir));
        NormalizeDirPath(boot_path, sizeof(boot_path));
        setenv("APP_DIR", app_dir, 1);
        return true;
    }

    return false;
}

static int WaitUntilDeviceRootIsReady(const char *root, int retries)
{
    struct stat buffer;
    int ret = -1;

    while (ret != 0 && retries > 0)
    {
        ret = stat(root, &buffer);
        /* Wait until the device is ready */
        DelayThread(100 * 1000);
        retries--;
    }

    return ret;
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
    if (filexio_ok) {
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
    } else {
        DPRINTF("Skipping mmceman init; fileXio not ready.\n");
        mmce_slot0_ready = 0;
        mmce_slot1_ready = 0;
        BootStamp("mmceman load/init (skipped)");
    }
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
    LOAD_IRX_NARG(mx4sio_bd_irx);

    LOAD_IRX_NARG(cdfs_irx);

    LOAD_IRX_NARG(audsrv_irx);

    const char *launch_path = GetLaunchPath(argc, argv);
    char resolved_launch_path[255];
    bool mass_alias_resolved = false;
    if (launch_path != NULL && strncmp(launch_path, "mass:/", 6) == 0) {
        int explicit_idx = -1;
        if (sscanf(launch_path, "mass%d:/", &explicit_idx) != 1) {
            for (int tries = 0; tries < 60; ++tries) {
                if (ResolveMassAliasLaunchPath(launch_path, resolved_launch_path, sizeof(resolved_launch_path))) {
                    launch_path = resolved_launch_path;
                    mass_alias_resolved = true;
                    break;
                }
                DelayThread(100 * 1000);
            }
        }
    } else if (ResolveMassAliasLaunchPath(launch_path, resolved_launch_path, sizeof(resolved_launch_path))) {
        launch_path = resolved_launch_path;
        mass_alias_resolved = true;
    }
    if (launch_path != NULL && (argc <= 0 || argv == NULL || argv[0] == NULL)) {
        setAppDirFromPath(launch_path);
        snprintf(boot_path, sizeof(boot_path), "%s", app_dir);
    } else {
        setLuaBootPath(argc, argv, 0);
        if (launch_path != NULL) {
            setAppDirFromPath(launch_path);
        } else {
            setAppDirFromPath(boot_path);
        }
    }
    NormalizeDirPath(boot_path, sizeof(boot_path));
    NormalizeDirPath(app_dir, sizeof(app_dir));

    if (mass_alias_resolved) {
        setAppDirFromPath(launch_path);
        snprintf(boot_path, sizeof(boot_path), "%s", app_dir);
        NormalizeDirPath(boot_path, sizeof(boot_path));
        NormalizeDirPath(app_dir, sizeof(app_dir));
    }

    // waitUntilDeviceIsReady by fjtrujy (root path derived from boot path when possible)
    char device_root[16];
    const char *ready_root = boot_path;
    if (ExtractDeviceRoot(boot_path, device_root, sizeof(device_root))) {
        ready_root = device_root;
    }
    WaitUntilDeviceRootIsReady(ready_root, 60);

    if (!BootPathMatchesLaunchPath(launch_path)) {
        DPRINTF("boot_path verification failed for argv0=%s; using app_dir fallback\n", launch_path ? launch_path : "<null>");
        snprintf(boot_path, sizeof(boot_path), "%s", app_dir);
        NormalizeDirPath(boot_path, sizeof(boot_path));
    }

    char system_lua_path[255];
    struct stat st;
    if (!BuildSystemLuaPath(app_dir, system_lua_path, sizeof(system_lua_path)) || stat(system_lua_path, &st) != 0) {
        RebindAppDirFromLaunchPath(launch_path);
    }

    if (!BuildSystemLuaPath(app_dir, system_lua_path, sizeof(system_lua_path)) || stat(system_lua_path, &st) != 0) {
        printf("BOOT FATAL: APP_DIR=%s missing system.lua\n", app_dir);
        return 1;
    }

    setenv("APP_DIR", app_dir, 1);

    const char *boot_script = bootString;
    const char *app_dir_prefix = "APP_DIR=[[";
    const char *app_dir_suffix = "]]\n";
    size_t app_dir_len = strlen(app_dir);
    size_t boot_len = strlen(bootString);
    size_t script_len = strlen(app_dir_prefix) + app_dir_len + strlen(app_dir_suffix) + boot_len;
    char *boot_script_with_app_dir = (char *)malloc(script_len + 1);
    if (boot_script_with_app_dir != NULL) {
        snprintf(boot_script_with_app_dir, script_len + 1, "%s%s%s%s", app_dir_prefix, app_dir, app_dir_suffix, bootString);
        boot_script = boot_script_with_app_dir;
    }
	// Lua init
	// init internals library
    
    // graphics (gsKit)
    initGraphics();

    pad_init();

    DPRINTF("boot path : %s\n", boot_path);
	dbgprintf("boot path : %s\n", boot_path);
    DPRINTF("app dir : %s\n", app_dir);
	dbgprintf("app dir : %s\n", app_dir);
    
    // set base path luaplayer (after argv0 normalization and finalized boot_path computation)
    chdir(boot_path);

    BootStamp("Lua init start");
    while (1)
    {
        errMsg = runScript(boot_script, true);

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

    free(boot_script_with_app_dir);
	return 0;
}
