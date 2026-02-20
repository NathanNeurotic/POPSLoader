
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

#define DPRINTF(x...) printf(x)
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

int mnt(const char* path, int index, int openmod)
{
    char PFS[5+1] = "pfs0:";
    if (index > 0)
        PFS[3] = '0' + index;

    DPRINTF("Mounting '%s' into pfs%d:\n", path, index);
    if (fileXioMount(PFS, path, openmod) < 0) // mount
    {
        DPRINTF("Mount failed. unmounting trying again...\n");
        if (fileXioUmount(PFS) < 0) //try to unmount then mount again in case it got mounted by something else
        {
            DPRINTF("Unmount failed!!!\n");
        }
        if (fileXioMount(PFS, path, openmod) < 0)
        {
            DPRINTF("mount failed again!\n");
            return -4;
        } else {
            DPRINTF("Second mount succed!\n");
        }
    } else DPRINTF("mount successfull on first attemp\n");
    return 0;
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


bool HDDInitializeStack(void)
{
    lua_State *L = luaL_newstate();
    if (L == NULL) {
        return false;
    }

    int result_count = Load_HDD_IRX(L);
    bool ok = false;
    if (result_count >= 1 && lua_isboolean(L, -result_count)) {
        ok = lua_toboolean(L, -result_count) != 0;
    }

    lua_close(L);
    return ok;
}

int HDDMountPartition(const char *path, int index, int openmod)
{
    return mnt(path, index, openmod);
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