
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <tamtypes.h>
#include <loadfile.h>
#include <malloc.h>
#include <assert.h>
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>
#include <hdd-ioctl.h>


#include "include/luaplayer.h"
#include "include/dprintf.h"

int mnt(const char* path, int index, int openmod);

static int MountPart(lua_State *L)
{
    int indx = 0, openmod = FIO_MT_RDWR;
    const char* mount;
    int argc = lua_gettop(L);
	if (argc < 1 || argc > 3) return luaL_error(L, "%s: wrong number of arguments, expected 1, 2 or 3 args, got %d", __func__, argc); 

    mount = luaL_checkstring(L, 1);
    if (argc >= 2) indx = luaL_checkinteger(L, 2);
    if (argc == 3) openmod = luaL_checkinteger(L, 3);

    /* Second return = the raw mount rc so Lua can tell a clean "partition
     * absent" apart from an I/O fault (Nuno's non-HDD-boot HDD-list failure
     * shows only "No '__.POPS' partitions" today, hiding WHY mounts failed). */
    int rc = mnt(mount, indx, openmod);
    lua_pushboolean(L, rc == 0);
    lua_pushinteger(L, rc);
    return 2;

}

static int UmountPart(lua_State *L)
{
    char PFS[6] = "pfs0:";
	if (lua_gettop(L) != 1) return luaL_error(L, "%s: wrong number of arguments, expected 1", __func__);

    PFS[3] = '0' + luaL_checkinteger(L, 1);
    lua_pushinteger(L, fileXioUmount(PFS));
    return 1;
}

/* Set once the HDD platter is confirmed spinning this session: either a mount
 * succeeded, or we already spent the cold-spin-up budget waiting for it. After
 * that, every mount uses a single fail-fast attempt so a disk with mostly-absent
 * __.POPS candidates can't stall. An HDD boot sets this via boot.lua's mount. */
static int hdd_spinup_waited = 0;

int mnt(const char* path, int index, int openmod)
{
    char PFS[5+1] = "pfs0:";
    if (index > 0)
        PFS[3] = '0' + index;

    /* Cold-platter spin-up tolerance. On a NON-HDD boot (USB/MC) the drive is
     * mechanically cold and needs ~4-10s to reach DRDY, so the first PFS mount
     * faults on the still-settling platter -- the HDD list failed only from a
     * non-HDD boot (Nuno 2026-06-14: GetHDDStatus read 0 but the first PFS read
     * still faulted). An HDD boot is unaffected: the BIOS spun the platter up to
     * load us and boot.lua's mount already set hdd_spinup_waited, so the warm
     * path takes a single attempt. Wait for the platter ONCE (1s backoff) until
     * a mount succeeds or the budget is spent; afterwards every mount is one
     * fail-fast attempt. Was: a single zero-delay unmount+remount. */
    int max_attempts = hdd_spinup_waited ? 1 : 12;
    int attempt;
    int last_rc = -4;
    for (attempt = 1; attempt <= max_attempts; attempt++)
    {
        DPRINTF("Mounting '%s' into pfs%d: (attempt %d/%d)\n", path, index, attempt, max_attempts);
        int rc = fileXioMount(PFS, path, openmod);
        if (rc >= 0)
        {
            hdd_spinup_waited = 1;
            if (attempt > 1) DPRINTF("mount ok after %d attempts (cold spin-up)\n", attempt);
            return 0;
        }
        last_rc = rc;
        /* best-effort unmount in case the slot was left mounted by something else */
        if (fileXioUmount(PFS) < 0)
            DPRINTF("pre-retry unmount no-op\n");
        if (attempt < max_attempts)
        {
            DPRINTF("Mount failed; waiting 1s for drive spin-up, retrying...\n");
            sleep(1);
        }
    }
    hdd_spinup_waited = 1; /* budget spent: platter has had time; stop waiting on later partitions */
    DPRINTF("mount failed for '%s' after %d attempt(s), rc %d\n", path, max_attempts, last_rc);
    /* Real fileXioMount rc (negative errno family), not a made-up constant, so
     * callers can distinguish absent-partition from I/O-fault classes. */
    return (last_rc < 0) ? last_rc : -4;
}

static int GetHDDStatus(lua_State *L) {
    int ret = fileXioDevctl("hdd0:", HDIOC_STATUS, NULL, 0, NULL, 0);
    /* 0 = HDD connected and formatted, 1 = not formatted, 2 = HDD not usable, 3 = HDD not connected. */
    lua_pushinteger(L, ret);
    DPRINTF("%s: HDD status is %d\n", __func__, ret);
    return 1;
}

/* APA dirent semantics for a dread() on "hdd0:": every record is one partition
 * table entry; stat.attr distinguishes main vs sub records and stat.mode holds
 * the partition-format magic. Values match ps2sdk <libhdd.h> (ATTR_MAIN_PARTITION
 * / FS_TYPE_PFS; defined locally so this file keeps its existing include set)
 * and the OPL / wLaunchELF enumerators built on this same API. */
#define APA_ATTR_MAIN_PARTITION 0x0000
#define APA_FS_TYPE_PFS         0x0100

/* HDD.ListPartitions() -> array of PFS main-partition NAMES ({} when none;
 * nil, rc when hdd0: won't open -- e.g. ps2hdd not loaded yet). Read-only over
 * the APA table: nothing is mounted here; callers mount-probe the names they
 * care about through the tracked-slot helpers. */
static int ListPartitions(lua_State *L)
{
    /* Snapshot the qualifying names BEFORE touching the Lua heap:
     * lua_newtable/lua_pushstring can longjmp on an allocation failure, and an
     * unwind past fileXioDclose would strand one of ps2hdd's fixed directory
     * slots. APA partition names cap at 32 bytes; 512 main partitions is far
     * beyond any real drive (truncated with a log line if ever exceeded). */
    #define LP_MAX_PARTS 512
    static char lp_names[LP_MAX_PARTS][33];
    int n = 0;
    int fd = fileXioDopen("hdd0:");
    if (fd < 0)
    {
        DPRINTF("%s: fileXioDopen(hdd0:) failed rc=%d\n", __func__, fd);
        lua_pushnil(L);
        lua_pushinteger(L, fd);
        return 2;
    }
    iox_dirent_t dirent;
    while (fileXioDread(fd, &dirent) > 0)
    {
        if (dirent.stat.attr != APA_ATTR_MAIN_PARTITION) continue; /* skip sub-partition records */
        if (dirent.stat.mode != APA_FS_TYPE_PFS) continue;         /* PFS-formatted only (skips __mbr/HDL/raw) */
        if (n >= LP_MAX_PARTS)
        {
            DPRINTF("%s: more than %d PFS partitions, truncating\n", __func__, LP_MAX_PARTS);
            break;
        }
        strncpy(lp_names[n], dirent.name, 32);
        lp_names[n][32] = '\0';
        n++;
    }
    fileXioDclose(fd);
    lua_newtable(L);
    for (int i = 0; i < n; i++)
    {
        lua_pushstring(L, lp_names[i]);
        lua_rawseti(L, -2, i + 1);
    }
    DPRINTF("%s: %d PFS main partitions\n", __func__, n);
    return 1;
}

#define IMPORT_BIN2C(_n)       \
    extern unsigned char _n[]; \
    extern unsigned int size_##_n

IMPORT_BIN2C(poweroff_irx);
IMPORT_BIN2C(ps2dev9_irx);
IMPORT_BIN2C(ps2atad_irx);
IMPORT_BIN2C(ps2hdd_osd_irx);
IMPORT_BIN2C(ps2fs_irx);

// Defined in luasystem.cpp. ps2dev9 is shared with the menu-side SMB net stack
// (EnsureNet) -- load it exactly once across the HDD and SMB paths.
extern bool g_dev9_loaded;

// Defined in luasystem.cpp. Brings up dev9 + bdm + bdmfs_fatfs + ata_bd (the BDM-enabled
// atad) load-once, so the HDD-boot APA path and the exFAT page SHARE ONE atad instance:
// ata_bd's atad library drives PFS (ps2hdd/ps2fs below) while its BDM "ata" device drives
// exFAT. Replaces the old plain-ps2atad load -- two atad copies froze the exFAT scan when
// POPSLoader was booted from an APA-Jail HDD (CosmicScale 2026-06-25).
extern bool EnsureAtaBdm();

#define CHECK_ERR(MODULE) if (ID < 0 || RET == 1) {lua_pushboolean(L, false); lua_pushstring(L, MODULE); lua_pushinteger(L, ID); lua_pushinteger(L, RET); goto ERR;}

enum HDDLOADSTATES {
    NOT_LOADED = 0,
    LOADED,
    FAILED_TO_LOAD,
};
int HDDLOADSTATE = HDDLOADSTATES::NOT_LOADED;

static int Load_HDD_IRX(lua_State *L) {
    if (HDDLOADSTATE == HDDLOADSTATES::LOADED) goto OK;
    if (HDDLOADSTATE == HDDLOADSTATES::FAILED_TO_LOAD) {
        /* A prior init failed: do NOT re-run a partial load and do NOT report
         * success. The old `!= NOT_LOADED` jump to OK lied "true" on every retry,
         * which let a second caller (EnsureHddRuntimeReadyForExec) proceed against
         * a half-loaded HDD IRX stack. Report the prior failure honestly so the
         * caller fails fast. */
        lua_pushboolean(L, false);
        lua_pushstring(L, "HDD_PRIOR_FAIL");
        lua_pushinteger(L, -1);
        lua_pushinteger(L, -1);
        return 4;
    }
    int ID, RET;
#define _N "\0"
    static const char hddarg[] = "-o" _N "4" _N "-n" _N "20";
	static char pfsarg[] = "-m" _N "4"  _N
                           "-o" _N "10" _N
                           "-n" _N "40";
#undef _N
    /* dev9 + bdm + bdmfs_fatfs + ata_bd (the BDM-enabled atad), load-once via EnsureAtaBdm.
     * ata_bd IS ps2atad built with ATA_ENABLE_BDM=1: the SAME atad library ps2hdd/ps2fs use
     * below, PLUS a BDM "ata" mass device for exFAT -- so ONE instance serves both APA/PFS
     * and exFAT (the config OPL ships). Replaces the old plain-ps2atad load here: booting
     * from an APA HDD loaded plain ps2atad AND a 2nd ata_bd on the exFAT page = two atad
     * copies re-initing the live ATA bus -> the 42% scan freeze (CosmicScale APA-Jail). */
    if (!EnsureAtaBdm()) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "ATA_BD");
        lua_pushinteger(L, -1);
        lua_pushinteger(L, -1);
        goto ERR;
    }

    /* PS2HDD.IRX */
    ID = SifExecModuleBuffer(&ps2hdd_osd_irx, size_ps2hdd_osd_irx, sizeof(hddarg), hddarg, &RET);
    DPRINTF(" [PS2HDD.IRX]: ret=%d, ID=%d\n", RET, ID);
    CHECK_ERR("PS2HDD");

    /* Check if HDD is formatted and ready to be used */

    /* PS2FS.IRX */
    ID = SifExecModuleBuffer(&ps2fs_irx, size_ps2fs_irx, sizeof(pfsarg), pfsarg,  &RET);
    DPRINTF(" [PS2FS.IRX]: ret=%d, ID=%d\n", RET, ID);
    CHECK_ERR("PS2FS");
OK:
    lua_pushboolean(L, true);
    HDDLOADSTATE = HDDLOADSTATES::LOADED;
    return 1;
ERR:
    HDDLOADSTATE = HDDLOADSTATES::FAILED_TO_LOAD;
    return 4;
}
static const luaL_Reg HDD_functions[] = {
  	{"MountPartition",    MountPart},
  	{"UMountPartition",    UmountPart},
    {"Initialize", Load_HDD_IRX},
    {"GetHDDStatus", GetHDDStatus},
    {"ListPartitions", ListPartitions},
    {0, 0}
};

void luaHDD_init(lua_State *L) 
{
    lua_newtable(L);
	luaL_setfuncs(L, HDD_functions, 0);
	lua_setglobal(L, "HDD");

	lua_pushinteger(L, FIO_MT_RDWR);
	lua_setglobal (L, "FIO_MT_RDWR");

	lua_pushinteger(L, FIO_MT_RDONLY);
	lua_setglobal (L, "FIO_MT_RDONLY");
}
