
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

    lua_pushboolean(L, (mnt(mount, indx, openmod)==0));
    return 1;

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
    for (attempt = 1; attempt <= max_attempts; attempt++)
    {
        DPRINTF("Mounting '%s' into pfs%d: (attempt %d/%d)\n", path, index, attempt, max_attempts);
        if (fileXioMount(PFS, path, openmod) >= 0)
        {
            hdd_spinup_waited = 1;
            if (attempt > 1) DPRINTF("mount ok after %d attempts (cold spin-up)\n", attempt);
            return 0;
        }
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
    DPRINTF("mount failed for '%s' after %d attempt(s)\n", path, max_attempts);
    return -4;
}

static int GetHDDStatus(lua_State *L) {
    int ret = fileXioDevctl("hdd0:", HDIOC_STATUS, NULL, 0, NULL, 0);
    /* 0 = HDD connected and formatted, 1 = not formatted, 2 = HDD not usable, 3 = HDD not connected. */
    lua_pushinteger(L, ret);
    DPRINTF("%s: HDD status is %d\n", __func__, ret);
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

#define CHECK_ERR(MODULE) if (ID < 0 || RET == 1) {lua_pushboolean(L, false); lua_pushstring(L, MODULE); lua_pushinteger(L, ID); lua_pushinteger(L, RET); goto ERR;}

enum HDDLOADSTATES {
    NOT_LOADED = 0,
    LOADED,
    FAILED_TO_LOAD,
};
int HDDLOADSTATE = HDDLOADSTATES::NOT_LOADED;

static int Load_HDD_IRX(lua_State *L) {
    if (HDDLOADSTATE != HDDLOADSTATES::NOT_LOADED) goto OK;
    int ID, RET;
#define _N "\0"
    static const char hddarg[] = "-o" _N "4" _N "-n" _N "20";
	static char pfsarg[] = "-m" _N "4"  _N
                           "-o" _N "10" _N
                           "-n" _N "40";
#undef _N
    /* PS2DEV9.IRX */
    ID = SifExecModuleBuffer(&ps2dev9_irx, size_ps2dev9_irx, 0, NULL, &RET);
    DPRINTF(" [DEV9.IRX]: ret=%d, ID=%d\n", RET, ID);
    CHECK_ERR("DEV9");

    /* PS2ATAD.IRX */
    ID = SifExecModuleBuffer(&ps2atad_irx, size_ps2atad_irx, 0, NULL, &RET);
    DPRINTF(" [ATAD.IRX]: ret=%d, ID=%d\n", RET, ID);
    CHECK_ERR("ATAD");

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
