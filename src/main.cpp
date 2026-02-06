
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
#include "include/bootdiag.h"

#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>

extern "C"{
#include <libds34bt.h>
#include <libds34usb.h>
}

#if defined(BOOT_HDD)
/*
 * EE-only early video probe.
 * Purpose: prove we reach main() when HDD-booted, without any SIF/IOP calls.
 * Draws a solid dark-red frame once, then continues.
 */
static void EarlyVideoProbe_HDD(void)
{
    GSGLOBAL *gsGlobal = gsKit_init_global();

    /* Safe defaults */
    gsGlobal->Mode = GS_MODE_NTSC;
    gsGlobal->Interlace = GS_INTERLACED;
    gsGlobal->Field = GS_FIELD;
    gsGlobal->Width = 640;
    gsGlobal->Height = 448;
    gsGlobal->PSM = GS_PSM_CT24;
    gsGlobal->ZBuffering = GS_SETTING_OFF;

    dmaKit_init(D_CTRL_RELE_OFF, D_CTRL_MFD_OFF, D_CTRL_STS_UNSPEC, D_CTRL_STD_OFF, D_CTRL_RCYC_8, 1<<DMA_CHANNEL_GIF);
    dmaKit_chan_init(DMA_CHANNEL_GIF);

    gsKit_init_screen(gsGlobal);

    /* Solid dark-red clear */
    gsKit_clear(gsGlobal, GS_SETREG_RGBAQ(0x40, 0x00, 0x00, 0x80, 0x00));
    gsKit_sync_flip(gsGlobal);
    gsKit_queue_exec(gsGlobal);
    gsKit_finish();

    /* Leave GS initialized; the normal graphics init will reconfigure later. */
}
#endif


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

extern unsigned char mx4sio_bd_irx[];
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

static int ExtractDeviceRoot(const char *path, char *out, size_t out_sz)
{
    if (!path || !out || out_sz == 0) return -1;
    const char *colon = strchr(path, ':');
    if (!colon) return -1;
    size_t n = (size_t)(colon - path) + 1; /* include ':' */
    if (n + 1 >= out_sz) return -1;
    memcpy(out, path, n);
    out[n] = '/';
    out[n + 1] = '\0';
    return 0;
}

static int FixupMassGenericPath(char *io_path, size_t io_sz)
{
    /* If path begins with mass:/... but the actual device is massN:/..., probe and rewrite. */
    if (!io_path || io_path[0] == '\0') return -1;
    /* Normalize backslashes to slashes for consistency. */
    for (char *p = io_path; *p; ++p) {
        if (*p == '\\') *p = '/';
    }
    if (strncmp(io_path, "mass:/", 6) != 0) return 0; /* nothing to do */

    struct stat st;
    if (stat(io_path, &st) == 0) return 0; /* mass:/ works */

    const char *suffix = io_path + 4; /* points at :/... */
    char cand[255];
    for (int i = 0; i <= 6; ++i) {
        snprintf(cand, sizeof(cand), "mass%d%s", i, suffix);
        if (stat(cand, &st) == 0) {
            snprintf(io_path, io_sz, "%s", cand);
            return 1; /* rewritten */
        }
    }
    return -1; /* not found */
}

static bool IsIopModuleLoadedByName(const char *name)
{
    if (!name || !name[0]) return false;
    smod_mod_info_t info;
    return smod_get_mod_by_name(name, &info) >= 0;
}

static bool IsIopModuleLoadedAny(const char *primary, const char *fallback)
{
    if (IsIopModuleLoadedByName(primary)) return true;
    if (fallback && IsIopModuleLoadedByName(fallback)) return true;
    return false;
}

static int ExtractPfsIndex(const char *path)
{
    if (!path || strncmp(path, "pfs", 3) != 0) return -1;
    if (isdigit((unsigned char)path[3])) return path[3] - '0';
    if (path[3] == ':') return 0;
    return -1;
}

static bool ExtractHddPartitionPath(const char *path, char *out, size_t out_sz)
{
    if (!path || strncmp(path, "hdd0:", 5) != 0) return false;
    const char *slash = strchr(path, '/');
    const char *second_colon = strchr(path + 5, ':');
    const char *end = NULL;
    if (second_colon && (!slash || second_colon < slash)) {
        end = second_colon;
    } else {
        end = slash;
    }
    size_t len = end ? (size_t)(end - path) : strlen(path);
    if (len + 1 > out_sz) return false;
    memcpy(out, path, len);
    out[len] = '\0';
    return true;
}

static bool ExtractHddPartitionPathFromString(const char *path, char *out, size_t out_sz)
{
    if (!path || !out || out_sz == 0) return false;
    if (ExtractHddPartitionPath(path, out, out_sz)) {
        return true;
    }
    const char *needle = strstr(path, "hdd0:");
    if (needle != NULL) {
        return ExtractHddPartitionPath(needle, out, out_sz);
    }
    return false;
}

static void RewritePathWithPfsRoot(const char *pfs_root, char *path, size_t path_sz)
{
    if (!path || strncmp(path, "hdd0:", 5) != 0) return;
    const char *suffix = strchr(path, '/');
    if (!suffix) {
        suffix = "/";
    }
    snprintf(path, path_sz, "%s%s", pfs_root, suffix);
    NormalizeDirPath(path, path_sz);
}

static bool RemountHddPartitionFromBootPath(const char *argv0)
{
    char hdd_part[64];
    bool got_part = ExtractHddPartitionPathFromString(boot_path, hdd_part, sizeof(hdd_part));
    if (!got_part) {
        got_part = ExtractHddPartitionPathFromString(argv0, hdd_part, sizeof(hdd_part));
    }
    if (!got_part) {
        char cwd[256];
        if (getcwd(cwd, sizeof(cwd)) != NULL) {
            got_part = ExtractHddPartitionPathFromString(cwd, hdd_part, sizeof(hdd_part));
        }
    }
    if (!got_part) {
        DPRINTF("HDD remount: unable to derive partition from boot path.\n");
        BootDiagLog("HDD remount: unable to derive partition (boot_path=%s argv0=%s)", boot_path, argv0 ? argv0 : "<null>");
        return false;
    }

    int pfs_index = ExtractPfsIndex(boot_path);
    if (pfs_index < 0) pfs_index = 0;
    char pfs_root[6] = "pfs0:";
    pfs_root[3] = '0' + pfs_index;

    BootDiagHeartbeat("HDD mount pre");
    BootDiagLog("HDD remount: mount %s -> %s", hdd_part, pfs_root);
    int mount_ret = fileXioMount(pfs_root, hdd_part, FIO_MT_RDWR);
    BootDiagHeartbeat("HDD mount post");
    BootDiagLog("HDD remount: mount ret=%d", mount_ret);
    if (mount_ret < 0) {
        DPRINTF("HDD remount: mount failed (%d), retrying after unmount.\n", mount_ret);
        BootDiagLog("HDD remount: retry after umount ret=%d", mount_ret);
        fileXioUmount(pfs_root);
        mount_ret = fileXioMount(pfs_root, hdd_part, FIO_MT_RDWR);
        BootDiagLog("HDD remount: mount retry ret=%d", mount_ret);
    }

    if (mount_ret < 0) {
        DPRINTF("HDD remount: mount failed (%d).\n", mount_ret);
        return false;
    }

    RewritePathWithPfsRoot(pfs_root, boot_path, sizeof(boot_path));
    RewritePathWithPfsRoot(pfs_root, app_dir, sizeof(app_dir));
    DPRINTF("HDD remount: %s mounted to %s (boot_path=%s, app_dir=%s).\n", hdd_part, pfs_root, boot_path, app_dir);
    BootDiagLog("HDD remount ok: %s -> %s boot_path=%s app_dir=%s", hdd_part, pfs_root, boot_path, app_dir);
    return true;
}


static void BootStamp(const char *stage)
{
    DPRINTF("BOOT: %s %u\n", stage, boot_ms());
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

#if defined(BOOT_HDD)
    /*
     * EARLIEST POSSIBLE HDD-variant marker.
     * Must not call SIF/IOP routines (no SifInitRpc, no fileXio, no stat).
     * If this does not show when launching from HDD, we are not reaching main().
     */
    init_scr();
    scr_setfontcolor(0xffffff);
    scr_clear();
    scr_setXY(5, 1);
    scr_printf("Entered main() (BOOT_HDD)\n");
    if (ARGV0) {
        scr_printf("ARGV0: %s\n", ARGV0);
    }
    /*
     * Optional EE-only GS probe (dark red) when launched from pfs/hdd.
     * Kept after init_scr so we always get some visible output first.
     */
    if (ARGV0 && (!strncmp(ARGV0, "pfs", 3) || !strncmp(ARGV0, "hdd", 3))) {
        EarlyVideoProbe_HDD();
    }
#endif
    BootDiagHeartbeat("Entered main()");
    BootDiagLog("Entered main() argv0=%s argc=%d", ARGV0 ? ARGV0 : "<null>", argc);
    boot_start = clock();
    BootStamp("EE init start");

    /* Capture boot path early (before any mass readiness waits). */
    setLuaBootPath(argc, argv, 0);
    if (argc > 0 && argv[0]) {
        setAppDirFromPath(argv[0]);
    } else {
        setAppDirFromPath(boot_path);
    }
    BootDiagLog("boot_path=%s app_dir=%s", boot_path, app_dir);
    BootStamp("boot path parse");

    /*
     * HDD boot note:
     * Many launchers execute an ELF from an already-mounted PFS device (commonly pfs0:/...).
     * Heavy IOP / mass-stack initialization at boot can deadlock under that loader-owned state
     * and we may never reach graphics or the error screen (pure black screen).
     *
     * For the HDD variant only: if launched from pfsX:/ or hdd0:, keep boot init minimal.
     */
    const int booted_from_hdd =
        (boot_path[0] && (!strncmp(boot_path, "pfs", 3) || !strncmp(boot_path, "hdd0:", 5)));
    BootDiagLog("booted_from_hdd=%d boot_path=%s", booted_from_hdd, boot_path);

#if defined(BOOT_HDD)
    if (booted_from_hdd) {
        init_scr();
        scr_setfontcolor(0xffffff);
        scr_clear();
        scr_setXY(5, 2);
        scr_printf("HDD boot: starting...\n");
        scr_printf("boot_path: %s\n", boot_path);
        scr_printf("(If this hangs, last line indicates stage)\n");
    }
#endif


#ifdef RESET_IOP
    /*
     * If launched from HDD/PFS, do NOT reset the IOP (would drop the loader-owned PFS mount).
     * But we MUST still initialize SIF RPC before any module loads / RPC subsystems.
     */
    BootDiagHeartbeat("SifInitRpc pre");
    BootDiagLog("SifInitRpc pre");
    SifInitRpc(0);
    BootDiagHeartbeat("SifInitRpc post");
    BootDiagLog("SifInitRpc post");
    if (!booted_from_hdd) {
        BootDiagHeartbeat("SifIopReset pre");
        BootDiagLog("SifIopReset pre");
        while (!SifIopReset("", 0)){};
        while (!SifIopSync()){};
        BootDiagHeartbeat("SifIopReset post");
        BootDiagLog("SifIopReset post");
        SifInitRpc(0);
        BootStamp("IOP reset");
    } else {
        BootStamp("IOP reset (skipped: HDD boot)");
        BootDiagLog("IOP reset skipped (HDD boot)");
    }
#endif
    
    // install sbv patch fix
    DPRINTF("Installing SBV Patches...\n");
    sbv_patch_enable_lmb();
    sbv_patch_disable_prefix_check(); 
    sbv_patch_fileio(); 

#ifdef POWERPC_UART
	LOAD_IRX_NARG(ppctty_irx);
#endif

    bool ioman_loaded = false;
    bool filexio_loaded = false;
    if (booted_from_hdd) {
        ioman_loaded = IsIopModuleLoadedAny("iomanX", "iomanX_irx");
        filexio_loaded = IsIopModuleLoadedAny("fileXio", "fileXio_irx");
        DPRINTF("HDD boot: iomanX loaded=%d fileXio loaded=%d\n", ioman_loaded ? 1 : 0, filexio_loaded ? 1 : 0);
    }

    bool ioman_ok = false;
    BootDiagHeartbeat("iomanX load pre");
    BootDiagLog("iomanX load pre");
    if (ioman_loaded) {
        ioman_ok = true;
        DPRINTF("iomanX already loaded; skipping reload to preserve PFS mount.\n");
    } else {
        ioman_ok = LoadIrxChecked("iomanX_irx", iomanX_irx, size_iomanX_irx, NULL, NULL);
    }
    BootDiagHeartbeat("iomanX load post");
    BootDiagLog("iomanX load post ok=%d", ioman_ok ? 1 : 0);
    BootStamp("iomanX load");
    bool filexio_ok = false;
    int filexio_ret = -1;
    if (ioman_ok) {
        if (filexio_loaded) {
            filexio_ok = true;
            DPRINTF("fileXio already loaded; skipping reload/init to preserve PFS mount.\n");
        } else {
            BootDiagHeartbeat("fileXio load pre");
            BootDiagLog("fileXio load pre");
            filexio_ok = LoadIrxChecked("fileXio_irx", fileXio_irx, size_fileXio_irx, NULL, NULL);
            if (filexio_ok) {
                filexio_ret = fileXioInit();
                if (filexio_ret < 0) {
                    DPRINTF("fileXioInit failed: ret=%d\n", filexio_ret);
                    filexio_ok = false;
                }
            }
            BootDiagHeartbeat("fileXio load post");
            BootDiagLog("fileXio load post ok=%d ret=%d", filexio_ok ? 1 : 0, filexio_ret);
        }
    } else {
        DPRINTF("Skipping fileXio init; iomanX failed to load.\n");
        BootDiagLog("Skipping fileXio init (iomanX failed)");
    }
    BootStamp("fileXio load/init");

#if defined(BOOT_HDD)
    if (booted_from_hdd && (!ioman_loaded || !filexio_loaded) && filexio_ok) {
        if (!RemountHddPartitionFromBootPath(ARGV0)) {
            DPRINTF("HDD remount: failed to restore PFS mount after fileXio reload.\n");
        }
    }
#endif

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
    BootDiagHeartbeat("initMC pre");
    BootDiagLog("initMC pre");
    initMC();
    BootDiagHeartbeat("initMC post");
    BootDiagLog("initMC post");
    LOAD_IRX_NARG(padman_irx);

    LOAD_IRX_NARG(libsd_irx);

    /*
     * Avoid mass/USB/BDM stack initialization when we were launched from HDD/PFS.
     * Those stacks are initialized lazily on page entry anyway.
     */
    int init_mass_stack = 1;
#if defined(BOOT_HDD)
    if (booted_from_hdd) init_mass_stack = 0;
#endif

    if (init_mass_stack) {
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
        BootStamp("mass stack load");
    } else {
        BootStamp("mass stack load (skipped: HDD boot)");
    }

#if defined(BOOT_MX4SIO)
    /* Load MX4SIO backend early so booting from MX4SIO works before Lua starts. */
    bool mx4sio_bd_ok = LoadIrxChecked("mx4sio_bd.irx", mx4sio_bd_irx, size_mx4sio_bd_irx, NULL, NULL);
    DPRINTF("mx4sio_bd load result: ok=%d\n", mx4sio_bd_ok ? 1 : 0);
    BootStamp("mx4sio_bd load");
#endif

    if (init_mass_stack) {
        LOAD_IRX_NARG(cdfs_irx);
    }

    LOAD_IRX_NARG(audsrv_irx);

    //waitUntilDeviceIsReady by fjtrujy

    struct stat buffer;
    int ret = -1;
    int retries = 80;
    char wait_root[16];
    wait_root[0] = '\0';

    /* If we were launched with a generic mass:/ path, rewrite it to the actual massN:/ prefix if needed. */
    char argv0_fix[255];
    argv0_fix[0] = '\0';
    if (argc > 0 && argv[0]) {
        snprintf(argv0_fix, sizeof(argv0_fix), "%s", argv[0]);
        NormalizeDirPath(argv0_fix, sizeof(argv0_fix));
        int fix = FixupMassGenericPath(argv0_fix, sizeof(argv0_fix));
        if (fix > 0) {
            char *tmpv[1]; tmpv[0] = argv0_fix;
            setLuaBootPath(1, tmpv, 0);
            setAppDirFromPath(argv0_fix);
            DPRINTF("boot path rewritten to %s (argv0=%s)\n", boot_path, argv0_fix);
        }
    }

    /* Only wait for mass devices; other roots (mc..., host..., pfs...) are either ready or handled elsewhere. */
    if (ExtractDeviceRoot(boot_path, wait_root, sizeof(wait_root)) < 0) {
        wait_root[0] = '\0';
    }
    if (!strncmp(wait_root, "mass", 4)) {
        BootStamp("mass wait begin");
        while (ret != 0 && retries > 0) {
            ret = stat(wait_root, &buffer);
            nopdelay();
            retries--;
        }
        BootStamp("mass wait end");
    } else {
        BootStamp("mass wait (skipped)");
    }
	
	// Lua init
	// init internals library
    
    // graphics (gsKit)
    BootDiagHeartbeat("GS init pre");
    BootDiagLog("GS init pre");
    initGraphics();
    BootDiagHeartbeat("GS init post");
    BootDiagLog("GS init post");

    pad_init();

    // set base path luaplayer
    chdir(boot_path); 

    DPRINTF("boot path : %s\n", boot_path);
	dbgprintf("boot path : %s\n", boot_path);
    DPRINTF("app dir : %s\n", app_dir);
	dbgprintf("app dir : %s\n", app_dir);
    
    {
        char cwd[256];
        if (getcwd(cwd, sizeof(cwd)) != NULL) {
            BootDiagLog("cwd=%s", cwd);
        }
    }
    BootStamp("Lua init start");
    BootDiagHeartbeat("Lua init start");
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
