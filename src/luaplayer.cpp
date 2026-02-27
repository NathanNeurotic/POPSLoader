#include <kernel.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <malloc.h>
#include <debug.h>

#include "include/luaplayer.h"
#include "include/graphics.h"
#include "include/dprintf.h"

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

static const embedded_asset_t g_embedded_lua_assets[] = {
    {"system.lua", asset_system_lua, size_asset_system_lua},
    {"ui.lua", asset_ui_lua, size_asset_ui_lua},
    {"images.lua", asset_images_lua, size_asset_images_lua},
    {"pops_profiles.lua", asset_pops_profiles_lua, size_asset_pops_profiles_lua}
};

static const embedded_asset_t* FindEmbeddedLuaAsset(const char *name)
{
    if (name == NULL) {
        return NULL;
    }
    for (size_t i = 0; i < sizeof(g_embedded_lua_assets) / sizeof(g_embedded_lua_assets[0]); ++i) {
        if (strcmp(name, g_embedded_lua_assets[i].name) == 0) {
            return &g_embedded_lua_assets[i];
        }
    }
    return NULL;
}

static int lua_embedded_searcher(lua_State *L)
{
    const char *module_name = luaL_checkstring(L, 1);
    char embedded_name[128];
    size_t i = 0;
    for (; module_name[i] != '\0' && i < sizeof(embedded_name) - 5; ++i) {
        embedded_name[i] = (module_name[i] == '.') ? '/' : module_name[i];
    }
    embedded_name[i] = '\0';
    strcat(embedded_name, ".lua");

    const embedded_asset_t *asset = FindEmbeddedLuaAsset(embedded_name);
    if (asset == NULL) {
        lua_pushfstring(L, "\n\tno embedded Lua module '%s'", module_name);
        return 1;
    }

    int load_ret = luaL_loadbuffer(L, (const char *)asset->data, asset->size, embedded_name);
    if (load_ret != 0) {
        lua_pushfstring(L, "\n\terror loading embedded module '%s': %s", module_name, lua_tostring(L, -1));
        return 1;
    }
    return 1;
}

static void InstallEmbeddedLuaSearcher(lua_State *L)
{
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "loaders");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 2);
        return;
    }

    int n = (int)lua_objlen(L, -1);
    for (int i = n + 1; i > 1; --i) {
        lua_rawgeti(L, -1, i - 1);
        lua_rawseti(L, -2, i);
    }
    lua_pushcfunction(L, lua_embedded_searcher);
    lua_rawseti(L, -2, 1);

    int n_after = (int)lua_objlen(L, -1);
    for (int i = 2; i <= n_after; ++i) {
        lua_pushnil(L);
        lua_rawseti(L, -2, i);
    }
    lua_pop(L, 2);
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
	if (!L) return "Failed to create LUA STATE\n";
    lua_atpanic(L, test_error);
	
	  // Init Standard libraries
	  luaL_openlibs(L);
      InstallEmbeddedLuaSearcher(L);

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
	const char * errMsg =(const char*)malloc(sizeof(char)*512);

	if(!isStringBuffer){
        DPRINTF("Loading embedded script key: `%s'\n", script);
        const embedded_asset_t *asset = FindEmbeddedLuaAsset(script);
        if (asset == NULL) {
            sprintf((char*)errMsg, "FATAL: embedded Lua script missing: %s\n", script);
            DPRINTF("%s", errMsg);
            lua_close(L);
            return errMsg;
        }
        s = luaL_loadbuffer(L, (const char *)asset->data, asset->size, script);
	} else {
        s = luaL_loadbuffer(L, script, strlen(script), NULL);
    }

		
	if (s == 0) s = lua_pcall(L, 0, LUA_MULTRET, 0);

	if (s) {
		sprintf((char*)errMsg, "%s\n", lua_tostring(L, -1));
    DPRINTF("%s\n", lua_tostring(L, -1));
		lua_pop(L, 1); // remove error message
	}
	lua_close(L);
	
	return errMsg;
}
