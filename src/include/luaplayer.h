#ifndef __LUAPLAYER_H
#define __LUAPLAYER_H

#include <debug.h>
#include <stddef.h>

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

extern char boot_path[255];
extern char app_dir[255];

/* NHDDL-style launch arguments + pre-Lua boot-device classification.
 * Definitions live in main.cpp; consumers (luasystem.cpp Lua bindings)
 * read these via the System.* binding layer. See parseLaunchArgs() and
 * detectBootDeviceHintFromArgv0() in main.cpp. */
extern char launch_arg_page[64];
extern char launch_arg_game[256];
extern char launch_arg_bdma[32];
extern int  launch_arg_debug;
extern char boot_device_hint[16];

typedef enum AssetKind {
	ASSET_GENERIC = 0,
	ASSET_IMG = 1,
	ASSET_IRX = 2,
} AssetKind;

int ResolveAssetPath(char* out, size_t outsz, const char* relativeName);
int ResolveAssetPathTyped(char* out, size_t outsz, const char* relativeName, AssetKind kind);

#ifdef DEBUG
#define dbgprintf(args...) scr_printf(args)
#else
#define dbgprintf(args...) ;
#endif

#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define CLAMP(val, min, max) ((val)>(max)?(max):((val)<(min)?(min):(val)))

#define ASYNC_TASKS_MAX 1

extern size_t GetFreeSize(void);

extern const char * runScript(const char* script, bool isStringBuffer);
extern int luaErrorIsHeapOwned(const char *errMsg);
extern void luaC_collectgarbage (lua_State *L);

//extern void luaSound_init(lua_State *L);
extern void luaControls_init(lua_State *L);
extern void luaGraphics_init(lua_State *L);
extern void luaScreen_init(lua_State *L);
extern void luaTimer_init(lua_State *L);
extern void luaSystem_init(lua_State *L);
extern void luaSound_init(lua_State *L);
extern void luaHDD_init(lua_State *L);
extern void stackDump (lua_State *L);

#endif
