#include <kernel.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <malloc.h>
#include <debug.h>
#include <stdint.h>

#include "include/luaplayer.h"
#include "include/graphics.h"
#include "include/dprintf.h"

#ifndef lua_objlen
#define lua_objlen lua_rawlen
#endif

typedef struct embedded_asset {
    const char *name;
    const unsigned char *data;
    unsigned int size;
} embedded_asset_t;

extern unsigned char asset_system_lua[];
extern unsigned int size_asset_system_lua;
extern unsigned char asset_ui_lua[];
extern unsigned int size_asset_ui_lua;
extern unsigned char asset_images_lua[];
extern unsigned int size_asset_images_lua;
extern unsigned char asset_pops_profiles_lua[];
extern unsigned int size_asset_pops_profiles_lua;
extern unsigned char bootString[];
extern unsigned int size_bootString;

static const embedded_asset_t g_embedded_lua_assets[] = {
    {"boot.lua", (const unsigned char *)bootString, size_bootString},
    {"system.lua", asset_system_lua, size_asset_system_lua},
    {"ui.lua", asset_ui_lua, size_asset_ui_lua},
    {"images.lua", asset_images_lua, size_asset_images_lua},
    {"pops_profiles.lua", asset_pops_profiles_lua, size_asset_pops_profiles_lua}
};

static const uint8_t* FindEmbeddedLua(const char *key, size_t *out_size)
{
    if (out_size != NULL) {
        *out_size = 0;
    }
    if (key == NULL) {
        return NULL;
    }
    for (size_t i = 0; i < sizeof(g_embedded_lua_assets) / sizeof(g_embedded_lua_assets[0]); ++i) {
        if (strcmp(key, g_embedded_lua_assets[i].name) == 0) {
            if (out_size != NULL) {
                *out_size = (size_t)g_embedded_lua_assets[i].size;
            }
            return (const uint8_t *)g_embedded_lua_assets[i].data;
        }
    }
    return NULL;
}

static int BuildEmbeddedLuaModulePath(const char *module_name, char *out_path, size_t out_path_size)
{
    if (module_name == NULL || out_path == NULL || out_path_size == 0) {
        return 0;
    }
    size_t idx = 0;
    while (module_name[idx] != '\0' && idx < out_path_size - 1) {
        const char c = module_name[idx];
        out_path[idx] = (c == '.') ? '/' : c;
        idx++;
    }
    if (module_name[idx] != '\0') {
        return 0;
    }
    out_path[idx] = '\0';
    return 1;
}

static int lua_embedded_searcher(lua_State *L)
{
    const char *module_name = luaL_checkstring(L, 1);
    char module_path[128];
    char module_key[160];
    size_t module_size = 0;
    const uint8_t *module_data = NULL;

    if (!BuildEmbeddedLuaModulePath(module_name, module_path, sizeof(module_path))) {
        lua_pushfstring(L, "\n\tinvalid embedded Lua module '%s'", module_name);
        return 1;
    }

    snprintf(module_key, sizeof(module_key), "%s.lua", module_path);
    module_data = FindEmbeddedLua(module_key, &module_size);
    if (module_data == NULL) {
        snprintf(module_key, sizeof(module_key), "%s/init.lua", module_path);
        module_data = FindEmbeddedLua(module_key, &module_size);
    }

    if (module_data == NULL) {
        lua_pushfstring(L, "\n\tno embedded Lua module '%s'", module_name);
        return 1;
    }

    int load_ret = luaL_loadbuffer(L, (const char *)module_data, module_size, module_key);
    if (load_ret != 0) {
        const char *load_err = lua_tostring(L, -1);
        lua_pushfstring(L, "\n\terror loading embedded module '%s': %s", module_name, load_err != NULL ? load_err : "(unknown lua error)");
        return 1;
    }
    return 1;
}

static void InstallEmbeddedLuaSearcher(lua_State *L)
{
    lua_getglobal(L, "package");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return;
    }

    lua_getfield(L, -1, "loaders");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        lua_getfield(L, -1, "searchers");
    }
    if (!lua_istable(L, -1)) {
        lua_pop(L, 2);
        return;
    }

    lua_rawgeti(L, -1, 1); // preload loader
    lua_pushcfunction(L, lua_embedded_searcher);
    lua_rawseti(L, -3, 2);
    lua_rawseti(L, -2, 1);

    int n_after = (int)lua_rawlen(L, -1);
    for (int i = 3; i <= n_after; ++i) {
        lua_pushnil(L);
        lua_rawseti(L, -2, i);
    }

    lua_pop(L, 2);
}

static void DisableLuaFilesystemScriptLoaders(lua_State *L)
{
    static const char kLoadFileName[] = {'l','o','a','d','f','i','l','e','\0'};

    lua_pushnil(L);
    lua_setglobal(L, "dofile");

    lua_pushnil(L);
    lua_setglobal(L, kLoadFileName);

    lua_getglobal(L, "package");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_setglobal(L, "package");
        lua_getglobal(L, "package");
    }

    lua_getfield(L, -1, "path");
    if (!lua_isstring(L, -1)) {
        lua_pop(L, 1);
        lua_pushliteral(L, "");
        lua_setfield(L, -2, "path");
    } else {
        lua_pop(L, 1);
    }

    lua_getfield(L, -1, "cpath");
    if (!lua_isstring(L, -1)) {
        lua_pop(L, 1);
        lua_pushliteral(L, "");
        lua_setfield(L, -2, "cpath");
    } else {
        lua_pop(L, 1);
    }

    lua_pop(L, 1);
}

#ifndef FORBID_LUA_ATPANIC_TEXTDUMP
#define LOGDUMP(x...) if (LOG != NULL) fprintf(x)
#else
#define LOGDUMP(x...)
#endif
#define TPRINTF(arg, x...) \
    printf(arg, ##x); \
    scr_printf(arg, ##x); \
    LOGDUMP(LOG, arg, ##x)

static lua_State *L;

static const char *kLuaErrorOutOfMemory = "(out of memory building lua error)";
static const char *kLuaErrorCreateState = "Failed to create LUA STATE\n";

int luaErrorIsHeapOwned(const char *errMsg)
{
    return errMsg != NULL && errMsg != kLuaErrorOutOfMemory && errMsg != kLuaErrorCreateState;
}


int test_error(lua_State * L) {
    scr_clear();
    //normalize video mode in case it was changed on lua script
    setVideoMode(gsKit_check_rom(), 640, (gsKit_check_rom()==GS_MODE_PAL) ? 512 : 448, GS_PSM_CT24, GS_INTERLACED, GS_FIELD, GS_SETTING_OFF, GS_PSMZ_16S);
    init_scr();
    scr_clear();
    scr_clear();
    scr_setCursor(0);
#ifndef FORBID_LUA_ATPANIC_TEXTDUMP
    FILE* LOG = fopen("lua_crashlog.txt", "w");
#endif
    int n = lua_gettop(L);
    int i;
        scr_printf("\t");
    TPRINTF("LUA ERR.\n");

    if (n == 0) {
        scr_printf("\t");
        TPRINTF("Stack is empty!!!!\n");
    }

    for (i = 1; i <= n; i++) {
        scr_printf("\t");
        TPRINTF("%i: ", i);
        switch(lua_type(L, i)) {
        case LUA_TNONE:
            TPRINTF("Invalid");
            break;
        case LUA_TNIL:
            TPRINTF("(Nil)");
            break;
        case LUA_TNUMBER:
            TPRINTF("(Number) %f", lua_tonumber(L, i));
            break;
        case LUA_TBOOLEAN:
            TPRINTF("(Bool)   %s", (lua_toboolean(L, i) ? "true" : "false"));
            break;
        case LUA_TSTRING:
            TPRINTF("%s", lua_tostring(L, i));
            break;
        case LUA_TTABLE:
            TPRINTF("(Table)");
            break;
        case LUA_TFUNCTION:
            TPRINTF("(Function)");
            break;
        default:
            TPRINTF("Unknown");
        }
    TPRINTF("\n");
    }
#ifndef FORBID_LUA_ATPANIC_TEXTDUMP
    fflush(LOG);
    fclose(LOG);
#endif
	SleepThread();
    return 0;
}

const char * runScript(const char* script, bool isStringBuffer )
{	
    DPRINTF("Creating luaVM... \n");

  	L = luaL_newstate();
	if (!L) {
        char *errMsg = (char*)malloc(512);
        if (errMsg != NULL) {
            snprintf(errMsg, 512, "%s", kLuaErrorCreateState);
            return errMsg;
        }
        return kLuaErrorCreateState;
    }
    lua_atpanic(L, test_error);
	
	  // Init Standard libraries
	  luaL_openlibs(L);
      InstallEmbeddedLuaSearcher(L);
      DisableLuaFilesystemScriptLoaders(L);

    DPRINTF("Loading libs... ");

	  // init graphics
    luaGraphics_init(L);
    luaControls_init(L);
	luaScreen_init(L);
    luaTimer_init(L);
    luaSystem_init(L);
    luaSound_init(L);
    luaRender_init(L);
	luaHDD_init(L);
    	
    DPRINTF("done !\n");
     
	int s = 0;

	if(!isStringBuffer){
        DPRINTF("Loading embedded script key: `%s'\n", script);
        size_t embedded_size = 0;
        const uint8_t *embedded_script = FindEmbeddedLua(script, &embedded_size);
        if (embedded_script == NULL) {
            char *errMsg = (char*)malloc(512);
            if (errMsg != NULL) {
                snprintf(errMsg, 512, "FATAL: embedded Lua script missing: %s\n", script);
                DPRINTF("%s", errMsg);
            }
            lua_close(L);
            return (errMsg != NULL) ? errMsg : kLuaErrorOutOfMemory;
        }
        s = luaL_loadbuffer(L, (const char *)embedded_script, embedded_size, script);
        if (s == 0) {
            s = lua_pcall(L, 0, LUA_MULTRET, 0);
        }
	} else {
            const char *boot_script_key = "boot.lua";
            size_t boot_script_size = 0;
            const uint8_t *boot_script_data = FindEmbeddedLua(boot_script_key, &boot_script_size);
            if (boot_script_data == NULL) {
                s = LUA_ERRFILE;
                lua_pushfstring(L, "FATAL: embedded Lua script missing: %s", boot_script_key);
            } else {
                s = luaL_loadbuffer(L, (const char *)boot_script_data, boot_script_size, boot_script_key);
                if (s == 0) {
                    s = lua_pcall(L, 0, LUA_MULTRET, 0);
                }
            }
        if (s == 0) {
            const char *boot_entry = "system.lua";
            size_t boot_entry_size = 0;
            const uint8_t *boot_entry_data = FindEmbeddedLua(boot_entry, &boot_entry_size);
            if (boot_entry_data == NULL) {
                s = LUA_ERRFILE;
                lua_pushfstring(L, "FATAL: embedded Lua script missing: %s", boot_entry);
            } else {
                s = luaL_loadbuffer(L, (const char *)boot_entry_data, boot_entry_size, boot_entry);
                if (s == 0) {
                    s = lua_pcall(L, 0, LUA_MULTRET, 0);
                }
            }
        }
    }

	if (s == 0) {
		lua_close(L);
		return NULL;
	}

	const char *lua_error = lua_tostring(L, -1);
	const char *safe_error = (lua_error != NULL) ? lua_error : "(unknown lua error)";
	char *errMsg = (char*)malloc(512);
	if (errMsg != NULL) {
		snprintf(errMsg, 512, "%s\n", safe_error);
	}
    DPRINTF("%s\n", safe_error);
	lua_pop(L, 1); // remove error message
	lua_close(L);
	
	return (errMsg != NULL) ? errMsg : kLuaErrorOutOfMemory;
}
