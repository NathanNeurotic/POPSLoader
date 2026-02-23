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
#include "include/assets.h"

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

static int LuaLoadLogical(lua_State *Lstate, const char *logicalPath)
{
    const void *ptr = NULL;
    size_t size = 0;
    bool isEmbedded = false;
    int rc = Asset_ReadAll(logicalPath, &ptr, &size, &isEmbedded);
    if (rc != 0) {
        lua_pushfstring(Lstate, "unable to load '%s' via assets (rc=%d)", logicalPath, rc);
        return LUA_ERRFILE;
    }
    int s = luaL_loadbuffer(Lstate, (const char*)ptr, size, logicalPath);
    Asset_FreeIfNeeded(ptr, isEmbedded);
    return s;
}

static void ModuleToLogicalPath(const char *moduleName, char *out, size_t outSize)
{
    size_t n = 0;
    for (size_t i = 0; moduleName[i] != '\0' && n + 1 < outSize; ++i) {
        out[n++] = (moduleName[i] == '.') ? '/' : moduleName[i];
    }
    out[n] = '\0';
    strncat(out, ".lua", outSize - strlen(out) - 1);
}

static int lua_asset_module_loader(lua_State *Lstate)
{
    const char *name = lua_tostring(Lstate, lua_upvalueindex(1));
    int s = LuaLoadLogical(Lstate, name);
    if (s != 0) return lua_error(Lstate);
    return 1;
}

static int lua_asset_searcher(lua_State *Lstate)
{
    const char *moduleName = luaL_checkstring(Lstate, 1);
    char logical[255] = {0};
    ModuleToLogicalPath(moduleName, logical, sizeof(logical));

    if (Asset_Exists(logical)) {
        lua_pushstring(Lstate, logical);
        lua_pushcclosure(Lstate, lua_asset_module_loader, 1);
        return 1;
    }

    char prefixed[255];
    snprintf(prefixed, sizeof(prefixed), "POPSLDR/%s", logical);
    if (Asset_Exists(prefixed)) {
        lua_pushstring(Lstate, prefixed);
        lua_pushcclosure(Lstate, lua_asset_module_loader, 1);
        return 1;
    }

    lua_pushfstring(Lstate, "\n\tno embedded asset module '%s'", moduleName);
    return 1;
}

static int lua_asset_loadfile(lua_State *Lstate)
{
    const char *path = luaL_checkstring(Lstate, 1);
    int s = LuaLoadLogical(Lstate, path);
    if (s == 0) return 1;
    lua_pushnil(Lstate);
    lua_insert(Lstate, -2);
    return 2;
}

static int lua_asset_dofile(lua_State *Lstate)
{
    const char *path = luaL_checkstring(Lstate, 1);
    int s = LuaLoadLogical(Lstate, path);
    if (s != 0) {
        return lua_error(Lstate);
    }
    if (lua_pcall(Lstate, 0, LUA_MULTRET, 0) != 0) {
        return lua_error(Lstate);
    }
    return lua_gettop(Lstate);
}

static void InstallAssetLuaHooks(lua_State *Lstate)
{
    lua_getglobal(Lstate, "package");
    lua_getfield(Lstate, -1, "searchers");
    if (!lua_istable(Lstate, -1)) {
        lua_pop(Lstate, 2);
        return;
    }
    int n = (int)lua_objlen(Lstate, -1);
    lua_pushcfunction(Lstate, lua_asset_searcher);
    lua_rawseti(Lstate, -2, n + 1);
    lua_pop(Lstate, 2);

    lua_pushcfunction(Lstate, lua_asset_loadfile);
    lua_setglobal(Lstate, "loadfile");
    lua_pushcfunction(Lstate, lua_asset_dofile);
    lua_setglobal(Lstate, "dofile");
}

int test_error(lua_State * L) {
    scr_clear();
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

    luaL_openlibs(L);
    InstallAssetLuaHooks(L);

    DPRINTF("Loading libs... ");

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

    if(!isStringBuffer) {
        DPRINTF("Loading script : `%s'\n", script);
        s = LuaLoadLogical(L, script);
    } else {
        s = luaL_loadbuffer(L, script, strlen(script), NULL);
    }

    if (s == 0) s = lua_pcall(L, 0, LUA_MULTRET, 0);

    if (s) {
        sprintf((char*)errMsg, "%s\n", lua_tostring(L, -1));
        DPRINTF("%s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }
    lua_close(L);

    return errMsg;
}
