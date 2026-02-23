#include <stdint.h>
#include "include/luaplayer.h"
#include "include/sound.h"
#include "include/assets.h"

static int lua_setformat(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 3) return luaL_error(L, "setFormat takes 3 arguments");
	sound_setformat(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2), luaL_checkinteger(L, 3));
	return 0;
}

static int lua_setvolume(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "setVolume takes only 1 argument");
	sound_setvolume(luaL_checkinteger(L, 1));
	return 0;
}

static int lua_setadpcmvolume(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "setADPCMVolume takes 2 arguments");
	sound_setadpcmvolume(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2));
	return 0;
}

static int lua_loadadpcm(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "loadADPCM takes only 1 argument");
	audsrv_adpcm_t *sample = sound_loadadpcm(luaL_checkstring(L, 1));
	if (sample == NULL) {
		lua_pushnil(L);
		return 1;
	}
	lua_pushinteger(L, (uint32_t)sample);
	return 1;
}

static int lua_loadadpcmfrombuffer(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "loadADPCMFromBuffer takes only 1 argument");

	const char* logicalPath = luaL_checkstring(L, 1);
	const void* ptr = NULL;
	size_t size = 0;
	bool isEmbedded = false;

	if (Asset_ReadAll(logicalPath, &ptr, &size, &isEmbedded) != 0) {
		lua_pushnil(L);
		return 1;
	}

	audsrv_adpcm_t *sample = sound_loadadpcmBuffer(ptr, size);
	Asset_FreeIfNeeded(ptr, isEmbedded);

	if (sample == NULL) {
		lua_pushnil(L);
		return 1;
	}

	lua_pushinteger(L, (uint32_t)sample);
	return 1;
}

static int lua_playadpcm(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "playADPCM takes 2 arguments");
	sound_playadpcm(luaL_checkinteger(L, 1), (audsrv_adpcm_t *)luaL_checkinteger(L, 2));
	return 0;
}

static int lua_freeadpcm(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "freeADPCM takes only 1 argument");
	sound_freeadpcm((audsrv_adpcm_t *)luaL_checkinteger(L, 1));
	return 0;
}

static const luaL_Reg Sound_functions[] = {
	{"setFormat",      							 lua_setformat},
	{"setVolume",      				   			 lua_setvolume},
	{"setADPCMVolume",      				lua_setadpcmvolume},
	{"loadADPCM",      							 lua_loadadpcm},
	{"loadADPCMFromBuffer",			 lua_loadadpcmfrombuffer},
	{"playADPCM",      							 lua_playadpcm},
	{"freeADPCM",      							 lua_freeadpcm},
	{0, 0}
};

void luaSound_init(lua_State *L) {
	lua_newtable(L);
	luaL_setfuncs(L, Sound_functions, 0);
	lua_setglobal(L, "Sound");
}
