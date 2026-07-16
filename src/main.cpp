
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sifrpc.h>
#include <sifcmd.h>
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



__attribute__((used)) static const char CI_MARKER_EXEC_PATH[] = "Exec path:";
__attribute__((used)) static const char CI_MARKER_COLD_PREP[] = "PrepareForColdExternalELFLaunch";
__attribute__((used)) static const char CI_MARKER_BOOT_ELF_FAIL[] = "BOOT.ELF launch failed";

#ifndef __SIFEXECMODULEBUFFER_DECLARED
extern "C" int SifExecModuleBuffer(void *ptr, int size, int arg_len, const char *args, int *mod_res);
#endif

/* Layer C lazy-load hooks defined in luasystem.cpp. EnsureMmceman loads
 * mmceman.irx on demand (idempotent); MarkMmcemanLoaded() lets the
 * eager MMCE-boot path here record the load so the lazy path is a no-op
 * later. See detectBootDeviceHintFromArgv0 for the device-kind hint that
 * gates the eager vs deferred decision; all HDD root variants (hdd, hdd0,
 * pfs, pfs0, pfs1, ata, apa) classify as "HDD" and defer mmceman. */
extern bool EnsureMmceman(void);
extern void MarkMmcemanLoaded(void);

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

extern unsigned char usbd_irx;
extern unsigned int size_usbd_irx;
// USB bring-up diagnostics, defined in luasystem.cpp (surfaced via System.getUsbDiag).
extern int g_usbd_load_id;
extern int g_usbd_load_ret;
// Defined in luasystem.cpp; brings up bdm + bdmfs_fatfs + usbmass_bd (idempotent).
extern bool EnsureUsbMass(void);

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

/* NHDDL-style launch arguments. Parsed early in main() so downstream
 * code (IRX loading, Lua boot) can act on the requested mode.
 *
 *   -page=hdd|ata|exfat|usb|mc|mmce|mx4sio|smb|bdma   auto-navigate to that page
 *                                            (ata|ata0|ataN -> HDD exFAT page;
 *                                             hdd|apa|pfs -> HDD PFS page)
 *   -mode=<value>                            NHDDL-compatible alias for -page= (e.g. -mode=ata)
 *   -game=<selector>                         auto-launch that game
 *   -debug                                   enable on-screen diagnostics
 *
 * (-noaudio was considered and dropped: audio modules are embedded in
 *  the ELF, load in ~few hundred ms, and POPSLoader uses sound for UI
 *  feedback. The skip-audio path was a footgun for negligible savings.)
 *
 * Empty strings / zero ints mean "not specified". Exported via the
 * System.getLaunchArgs() Lua binding (see luasystem.cpp).
 */
char launch_arg_page[64] = "";
char launch_arg_game[256] = "";
int  launch_arg_debug   = 0;

/* C-side mirror of system.lua DetectBootDevice. Returns the canonical
 * device-kind label (USB / HDD / MC / MMCE / MX4SIO / SMB / HOST) for a
 * given argv[0]-style path, or "" when unrecognized. This is consulted
 * by main() to decide whether device-specific IRX loads can be deferred
 * (Layer C lazy loading) and by the Lua binding System.getBootDeviceHint().
 *
 * IMPORTANT: this returns a CLASSIFICATION HINT, not the authoritative
 * boot device. The authoritative device is still resolved later in
 * system.lua DetectBootDevice() which handles the mass:/ MX4SIO fix
 * (BDM driver lookup + .boot_mx4sio marker). Use this hint only for
 * pre-Lua, pre-IRX-load decisions.
 */
char boot_device_hint[16] = "";

static const char * detectBootDeviceHintFromArgv0(const char * argv0)
{
    if (argv0 == NULL || argv0[0] == '\0') {
        return "";
    }
    if (strncmp(argv0, "mass", 4) == 0) {
        return "USB";    /* could be MX4SIO; classify_mass_boot refines later */
    }
    if (strncmp(argv0, "usb", 3) == 0) {
        return "USB";
    }
    if (strncmp(argv0, "mx4sio", 6) == 0) {
        return "MX4SIO";
    }
    if (strncmp(argv0, "mmce", 4) == 0) {
        return "MMCE";
    }
    if (strncmp(argv0, "mc", 2) == 0 && argv0[2] != 'm') {
        /* "mc0:" / "mc1:" but not "mcm" (mcman would never appear in argv0) */
        return "MC";
    }
    if (strncmp(argv0, "hdd", 3) == 0 ||
        strncmp(argv0, "pfs", 3) == 0 ||
        strncmp(argv0, "ata", 3) == 0 ||
        strncmp(argv0, "apa", 3) == 0) {
        return "HDD";
    }
    if (strncmp(argv0, "smb", 3) == 0) {
        return "SMB";
    }
    if (strncmp(argv0, "host", 4) == 0) {
        return "HOST";
    }
    return "";
}

/* Strip leading/trailing whitespace and one pair of surrounding quotes
 * from a launch-arg token, in place. CNF-sourced argv entries arrive
 * decorated in the wild: OSDMenu's parser strips only \r\n from an arg
 * line (trailing spaces survive into the token), and users quote values.
 * Internal spaces are deliberately preserved -- -game= selectors contain
 * them ("Bomberman - Party Edition"). */
static void trimLaunchArgToken(char * s)
{
    size_t len = strlen(s);
    size_t start = 0;
    while (len > 0 && (s[len - 1] == ' ' || s[len - 1] == '\t' ||
                       s[len - 1] == '\r' || s[len - 1] == '\n')) {
        s[--len] = '\0';
    }
    while (s[start] == ' ' || s[start] == '\t') {
        start++;
    }
    if (len >= start + 2 && (s[start] == '"' || s[start] == '\'') &&
        s[len - 1] == s[start]) {
        s[len - 1] = '\0';
        start++;
        len--;
    }
    if (start > 0) {
        memmove(s, s + start, len - start + 1);
    }
}

static void parseLaunchArgs(int argc, char ** argv)
{
    /* Scratch large enough for any token we care about (-game= values cap
     * at sizeof(launch_arg_game)). Longer tokens are truncated by snprintf,
     * matching the capture buffers' own limits. */
    char token[300];

    if (argc <= 1 || argv == NULL) {
        return;
    }
    for (int i = 1; i < argc; i++) {
        const char * a = argv[i];
        if (a == NULL || a[0] == '\0') {
            continue;
        }
        /* Work on a trimmed copy: argv strings live in the parent
         * launcher's memory and must not be modified in place. */
        snprintf(token, sizeof(token), "%s", a);
        trimLaunchArgToken(token);
        if (token[0] == '\0') {
            continue;
        }
        if (strncmp(token, "-page=", 6) == 0) {
            snprintf(launch_arg_page, sizeof(launch_arg_page), "%s", token + 6);
            trimLaunchArgToken(launch_arg_page);
        } else if (strncmp(token, "-mode=", 6) == 0) {
            /* NHDDL-compat alias for -page=: e.g. -mode=ata -> the HDD (exFAT) page */
            snprintf(launch_arg_page, sizeof(launch_arg_page), "%s", token + 6);
            trimLaunchArgToken(launch_arg_page);
        } else if (strncmp(token, "-game=", 6) == 0) {
            snprintf(launch_arg_game, sizeof(launch_arg_game), "%s", token + 6);
            trimLaunchArgToken(launch_arg_game);
        } else if (strcmp(token, "-debug") == 0) {
            launch_arg_debug = 1;
        }
    }
    DPRINTF("LaunchArgs: page=\"%s\" game=\"%s\" debug=%d\n",
            launch_arg_page, launch_arg_game, launch_arg_debug);
}

static unsigned int boot_ms(void)
{
    if (boot_start == 0) {
        return 0;
    }
    // clock() counts MICROSECONDS here (_CLOCKS_PER_SEC_ == 1000000), so the old
    // `(delta * 1000) / CLOCKS_PER_SEC` overflowed 32-bit signed once delta passed
    // 2,147,483us -- i.e. every stamp after the first ~2.1 SECONDS of boot returned
    // garbage, which is precisely the range worth measuring. Do it in 64-bit.
    // Same family as the Timer.getTime()-is-microseconds trap on the Lua side.
    return (unsigned int)(((unsigned long long)(clock() - boot_start) * 1000ULL) / (unsigned long long)CLOCKS_PER_SEC);
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

// Boot profile storage. BootStamp's only consumer was DPRINTF, which is #ifdef
// DEBUG and compiles to NOTHING in a shipped build -- so this profile has existed
// all along and has never once reached anyone. Exactly the blind spot that let two
// wrong USB fixes ship (see the usbd rc capture above). The whole boot is a black
// screen and we cannot currently say which module owns it. Record the stamps so
// System.getBootProfile() can show them.
#define BOOT_STAGE_MAX 24
typedef struct {
    const char *stage;   // static string literal; not copied
    unsigned int ms;
} boot_stage_t;
static boot_stage_t g_boot_stages[BOOT_STAGE_MAX];
static int g_boot_stage_count = 0;

static void BootStamp(const char *stage)
{
    unsigned int ms = boot_ms();
    if (g_boot_stage_count < BOOT_STAGE_MAX) {
        g_boot_stages[g_boot_stage_count].stage = stage;
        g_boot_stages[g_boot_stage_count].ms = ms;
        g_boot_stage_count++;
    }
    DPRINTF("BOOT: %s %u\n", stage, ms);
}

// Read side for luasystem.cpp's System.getBootProfile().
extern "C" int BootProfileCount(void)
{
    return g_boot_stage_count;
}
extern "C" const char *BootProfileStage(int i)
{
    if (i < 0 || i >= g_boot_stage_count) return "";
    return g_boot_stages[i].stage != NULL ? g_boot_stages[i].stage : "";
}
extern "C" unsigned int BootProfileMs(int i)
{
    if (i < 0 || i >= g_boot_stage_count) return 0;
    return g_boot_stages[i].ms;
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
    DPRINTF("%s: id:%d, ret:%d\n", #_irx, ID, RET)
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

    /* Parse NHDDL-style launch arguments early so Lua and any
     * conditional IRX loading paths can read them. Argv parsing has
     * no SDK dependencies so it's safe at this point. */
    parseLaunchArgs(argc, argv);

    /* Pre-IRX classification hint. Used by the conditional audsrv/libsd
     * load below and exposed to Lua via System.getBootDeviceHint(). */
    {
        const char * hint = detectBootDeviceHintFromArgv0(argc > 0 ? argv[0] : NULL);
        snprintf(boot_device_hint, sizeof(boot_device_hint), "%s", hint != NULL ? hint : "");
        DPRINTF("BootDeviceHint: \"%s\"\n", boot_device_hint);
    }

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
    BootStamp("sio2man");
    if (filexio_ok) {
        /* Layer C: mmceman is only needed for MMCE memcards (third-party
         * memory card adapters like MemoryCard Pro that expose mmce0:/,
         * mmce1:/ paths). This is a DISTINCT device from standard PS2
         * memory cards, which use mc0:/, mc1:/ paths and the mcman/mcserv
         * IRX stack loaded unconditionally just below.
         *
         * Load mmceman eagerly only when the boot device is MMCE;
         * otherwise defer to PLDR.EnsureMmceReadyOnce in system.lua
         * (which calls System.ensureMmceman before any MMCE probe).
         * All HDD root variants (hdd, hdd0, pfs, pfs0, pfs1, ata, apa)
         * classify as "HDD" via detectBootDeviceHintFromArgv0 and defer;
         * MC-booted units (boot_device_hint == "MC") also defer, since
         * MC support is provided entirely by mcman/mcserv. */
        bool mmceman_required_at_boot = (strcmp(boot_device_hint, "MMCE") == 0);
        if (mmceman_required_at_boot) {
            int mmceman_id = -1;
            int mmceman_ret = -1;
            bool mmceman_ok = LoadIrxChecked("mmceman_irx", &mmceman_irx, size_mmceman_irx, &mmceman_id, &mmceman_ret);
            DPRINTF("mmceman eager load (boot=MMCE) result: id=%d ret=%d\n", mmceman_id, mmceman_ret);
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
            if (mmceman_ok) {
                MarkMmcemanLoaded();
                mmce_slot0_ready = -1;
                mmce_slot1_ready = -1;
                DPRINTF("MMCE probe deferred until MMCE page entry.\n");
            } else {
                mmce_slot0_ready = 0;
                mmce_slot1_ready = 0;
            }
            BootStamp("mmceman load/init");
        } else {
            /* Non-MMCE boot: skip the eager load. System.ensureMmceman()
             * will load on demand if a configured POPSTARTER path lives
             * on MMCE (AutoInitStartupBackends -> DetectMMCESlot) or if
             * the user enters the MMCE page from the carousel. */
            DPRINTF("mmceman deferred (boot_device_hint=\"%s\"); will load on demand.\n", boot_device_hint);
            mmce_slot0_ready = -1;
            mmce_slot1_ready = -1;
            BootStamp("mmceman deferred");
        }
    } else {
        DPRINTF("Skipping mmceman init; fileXio not ready.\n");
        mmce_slot0_ready = 0;
        mmce_slot1_ready = 0;
        BootStamp("mmceman load/init (skipped)");
    }
    LOAD_IRX_NARG(mcman_irx);
    LOAD_IRX_NARG(mcserv_irx);
    BootStamp("mcman+mcserv");
    initMC();
    BootStamp("initMC");
    LOAD_IRX_NARG(padman_irx);
    BootStamp("padman");

    LOAD_IRX_NARG(libsd_irx);
    BootStamp("libsd");


    // load USB modules
    // usbd MUST load here, not lazily with the mass stack: ds34usb/ds34bt below
    // hard-import it for pad input. (wLaunchELF_R3Z gets to load usbd adjacent to
    // usbmass_bd only because it ships DS34 ?= 0 and has no pad driver to serve.)
    // Capture the result -- LOAD_IRX_NARG feeds id/ret to DPRINTF, which is a no-op
    // in a release build, so a failed usbd load was previously invisible and got
    // reported to us as "No USB backend detected", i.e. blamed on the drive.
    // Deliberately no DPRINTF on failure: DPRINTF IS the bug. The codes go to
    // g_usbd_load_* and reach the tester on the USB page via System.getUsbDiag().
    LoadIrxChecked("usbd_irx", &usbd_irx, size_usbd_irx, &g_usbd_load_id, &g_usbd_load_ret);
    BootStamp("usbd");

    // Bring the USB mass stack up HERE, adjacent to usbd -- matching what the two
    // launchers that read sAGA's drive actually do. wLaunchELF_R3Z's loadUsbModules()
    // does loadUsbDModule() then bdm/bdmfs_fatfs/settle/usbmass_bd in ONE function;
    // OPL's bdmsupport.c LoadModules() does bdm/bdmfs_fatfs/usbd/usbmass_bd back to
    // back. POPSLoader was the ONLY one loading usbd at boot and usbmass_bd minutes
    // later on page entry, which is the only configuration that depends on usbd's
    // late re-probe path (doRegisterDriver -> probeDeviceTree) to match a pendrive
    // that was ALREADY enumerated at boot. On OPL/R3Z the drive is matched by the
    // normal connect callback because usbmass_bd's driver is registered before the
    // device is ever seen.
    // Idempotent: EnsureUsbMass latches on success, so the lazy Lua-side call on
    // USB-page entry becomes a no-op rather than a second load.
    // Costs boot time (this is why the EXP6 boot profile landed first).
    EnsureUsbMass();
    BootStamp("usb mass stack (bdm+bdmfs_fatfs+usbmass_bd)");


    int ds3pads = 1;
    LOAD_IRX(ds34usb_irx, 4, (char *)&ds3pads);
    LOAD_IRX(ds34bt_irx, 4, (char *)&ds3pads);
    BootStamp("ds34usb+ds34bt load");
    ds34usb_init();
    ds34bt_init();
    BootStamp("ds34 init");

    LOAD_IRX_NARG(audsrv_irx);
    BootStamp("audsrv");
	
        setLuaBootPath (argc, argv, 0);
        if (argc > 0 && argv[0]) {
            setAppDirFromPath(argv[0]);
        } else {
            setAppDirFromPath(boot_path);
        }
	// Lua init
	// init internals library
    
    // graphics (gsKit)
    BootStamp("IRX block done (screen still black)");
    initGraphics();
    BootStamp("initGraphics");

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
        errMsg = runScript("boot.lua", false);

        init_scr();


        if (errMsg != NULL)
        {
            scr_setfontcolor(0x0000ff);
		    scr_clear();
		    scr_setXY(5, 2);
		    scr_printf("Enceladus ERROR!\n");
		    scr_printf("%s", errMsg);
		    scr_printf("\nPress [start] to restart\n");
        	while (!isButtonPressed(PAD_START)) {
		    }
            if (luaErrorIsHeapOwned(errMsg)) {
                free((void*)errMsg);
            }
            errMsg = NULL;
            scr_setfontcolor(0xffffff);
            continue;
        }

        break;
    }

	return 0;
}

extern "C" void _ps2sdk_memory_init() {
#ifdef RESET_IOP
    /* Bootstrap IOP hygiene for parent launchers that do NOT reset the
     * IOP before handing control to POPSLoader. The canonical offender
     * is wLaunchELF, which only resets the IOP for HDD targets (per
     * wLaunchELF/loader/loader.c). When POPSLoader is launched from
     * wLaunchELF off USB, MC, MX4SIO, or any non-HDD device, we inherit
     * wLaunchELF's fileXio + iomanX IOP modules. fileXio holds threads
     * and semaphores that BLOCK a plain SifIopReset (documented:
     * https://github.com/ps2dev/ps2sdk/issues/425). The symptom is a
     * silent hang here -> black screen for the user (CosmicScale report
     * 2026-05-25).
     *
     * The teardown contract below survives both clean and polluted
     * parents:
     *
     *   SifExitRpc()    -- drop any inherited RPC client binding so the
     *                      next SifInitRpc starts from a known state.
     *                      Safe on uninitialized RPC (graceful no-op).
     *   SifInitRpc(0)   -- fresh RPC handshake; required before
     *                      fileXioExit can issue any RPC.
     *   fileXioExit()   -- guarded by __fileXioInited internally
     *                      (ps2sdk PR #426 contract): restores libc fio
     *                      function pointers (open/read/close/...)
     *                      that fileXioInit would have hijacked, and
     *                      releases its EE-side semaphores. No-op on
     *                      clean parents because __fileXioInited == 0
     *                      in a fresh EE process; meaningful only if
     *                      newlib startup happens to have entered the
     *                      hijacked state.
     *   SifIopReset     -- now succeeds; no fileXio RPC channel pinned.
     *   SifIopSync      -- wait for IOP boot.
     *   SifInitRpc(0)   -- ready for main() to load our own IRX stack.
     *
     * Existing clean-parent paths (PSBBN, Browser, HOSDMenu, OSDMenu,
     * MC autoboot) are unaffected: each new call has a "not
     * initialized" guard. The only behavioral delta is that the IOP
     * reset now completes instead of hanging when fileXio was alive.
     */
    SifExitRpc();
    SifInitRpc(0);
    fileXioExit();
    while (!SifIopReset("", 0)){};
    while (!SifIopSync()){};
    SifInitRpc(0);
#endif
}
