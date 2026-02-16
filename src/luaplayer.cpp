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

const char * runScript(const char* script, bool isStringBuffer, size_t scriptSize )
{	
    DPRINTF("Creating luaVM... \n");

  	L = luaL_newstate();
	if (!L) return "Failed to create LUA STATE\n";
    lua_atpanic(L, test_error);
	
	  // Init Standard libraries
	  luaL_openlibs(L);

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
     
	if(!isStringBuffer){
        DPRINTF("Loading script : `%s'\n", script);
	}

	int s = 0;
	const char * errMsg =(const char*)malloc(sizeof(char)*512);

	if(!isStringBuffer) {
		s = luaL_loadfile(L, script);
	}
	else {
		size_t bufferSize = scriptSize;
		if (bufferSize == 0) {
			bufferSize = strlen(script);
		}
		if (bufferSize > 0 && script[bufferSize - 1] == '\0') {
			bufferSize--;
		}

		const char *buffer = script;
		if (bufferSize >= 3 && (unsigned char)buffer[0] == 0xEF && (unsigned char)buffer[1] == 0xBB && (unsigned char)buffer[2] == 0xBF) {
			buffer += 3;
			bufferSize -= 3;
		}

		s = luaL_loadbuffer(L, buffer, bufferSize, "boot.lua");
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
