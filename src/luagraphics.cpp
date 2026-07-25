#include <stdlib.h>
#include <malloc.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#include "include/graphics.h"
#include "include/fntsys.h"
#include "include/luaplayer.h"

/* Default vertex tint: neutral 50% white (no modulation). */
static const Color GS_DEFAULT_COLOR = 0x80808080;

typedef struct embedded_font_asset {
    const char *key;
    const unsigned char *data;
    unsigned int size;
} embedded_font_asset_t;

static bool asyncDelayed = true;

volatile int imgThreadResult = 1;
unsigned char* imgThreadData = NULL;
uint32_t imgThreadSize = 0;

static u8 imgThreadStack[4096] __attribute__((aligned(16)));

// Extern symbol
extern void *_gp;

//---------------------------------------------------------------------------
// EXP49: off-render-thread cover loading.
//
// The MX4SIO cover stutter was never probe COUNT -- it was that the probe runs on
// the thread that draws. Graphics.loadImage -> load_image -> fopen blocks in
// WaitSema until the IOP finishes a FatFs directory walk; on a large shared OPL
// ART/ folder over bit-banged SPI a MISS is ~0.3-0.6s, and one per newly-selected
// title is enough to freeze the list. OPL probes MORE than we do with the same
// primitive and never stutters, purely because its probes run on an IO worker
// while the render thread draws a placeholder (texcache.c / ioman.c).
//
// This is NOT the pre-existing Graphics.threadLoadImage. That one has never had a
// single Lua caller in this fork, and it is unsafe as written: it passes the
// Lua-owned string straight to the thread (it can be collected mid-load), has one
// global slot with no association to WHICH request finished, and on decode failure
// leaves imgThreadData holding a stale pointer that getLoadData will hand back.
//
// Contract, deliberately minimal (one request in flight, which is all we need --
// only the selected game's cover is ever loaded):
//   Graphics.coverLoadBegin(path, token) -> true if accepted, false if busy
//   Graphics.coverLoadPoll()             -> nil while busy
//                                        -> token, ptr|nil once done (consumes it)
// `token` is an integer the caller uses to decide whether the answer is still
// wanted; if the selection moved on, Lua frees the texture and drops it. The path
// is COPIED here and freed by the worker, so Lua may collect its string freely.
// load_image runs with delayed=true, so the gsKit VRAM upload stays on the main
// thread at draw time and decoding off-thread is GS-safe.
#define COVER_LOAD_IDLE 0
#define COVER_LOAD_BUSY 1
#define COVER_LOAD_DONE 2

static volatile int coverLoadState = COVER_LOAD_IDLE;
static volatile int coverLoadToken = 0;
static GSTEXTURE *coverLoadResult = NULL;
static char *coverLoadPath = NULL;
// PNG decode needs far more headroom than the 4 KiB the legacy imgThread gets
// (that stack is one reason it was never trusted); OPL's IO worker uses 96 KiB.
static u8 coverLoadStack[32768] __attribute__((aligned(16)));

// EXP58: ONE long-lived worker, woken by a semaphore.
//
// EXP49-57 created a fresh EE thread for every cover request and let it delete
// itself. That churns a thread per navigation, and if CreateThread ever fails the
// request is refused -- which left the loader permanently pending until EXP57 bounded
// the retry (sAGA's stuck "Loading ART..."). OPL has always used a single IO worker
// (ioman.c) rather than one per request; this matches that.
//
// The thread is created LAZILY on the first cover request, never at boot, and never
// exits. Semaphore pattern copied from the in-tree font lock (src/fntsys.cpp:350).
static int coverLoadSema = -1;
static int coverLoadThreadId = -1;

static int coverLoadThread(void *arg)
{
	(void)arg;
	for (;;) {
		WaitSema(coverLoadSema);          // sleeps until a request arrives
		char *path = coverLoadPath;
		GSTEXTURE *tex = (path != NULL) ? load_image(path, true) : NULL;
		if (path != NULL) {
			free(path);
			coverLoadPath = NULL;
		}
		coverLoadResult = tex;   // NULL is a legitimate result: the cover is absent
		coverLoadState = COVER_LOAD_DONE;
	}
	return 0;
}

// Returns 1 once the worker exists and is waiting. Idempotent.
static int coverLoadEnsureWorker(void)
{
	if (coverLoadThreadId >= 0) return 1;

	if (coverLoadSema < 0) {
		ee_sema_t s;
		s.init_count = 0;      // nothing queued yet
		s.max_count  = 1;      // one request in flight, which is all we ever need
		s.option     = 0;
		coverLoadSema = CreateSema(&s);
		if (coverLoadSema < 0) return 0;
	}

	ee_thread_t tp;
	tp.gp_reg = &_gp;
	tp.func = (void *)coverLoadThread;
	tp.stack = (void *)coverLoadStack;
	tp.stack_size = sizeof(coverLoadStack);
	tp.initial_priority = 32;
	int tid = CreateThread(&tp);
	if (tid < 0) return 0;
	StartThread(tid, NULL);
	coverLoadThreadId = tid;
	return 1;
}

static int lua_coverloadbegin(lua_State *L)
{
	if (lua_gettop(L) != 2)
		return luaL_error(L, "Argument error: Graphics.coverLoadBegin(path, token) takes two arguments.");
	const char *path = luaL_checkstring(L, 1);
	int token = (int)luaL_checkinteger(L, 2);

	if (coverLoadState != COVER_LOAD_IDLE) {
		lua_pushboolean(L, 0);   // one in flight at a time; caller retries next frame
		return 1;
	}

	size_t len = strlen(path);
	char *copy = (char *)malloc(len + 1);
	if (copy == NULL) {
		lua_pushboolean(L, 0);
		return 1;
	}
	memcpy(copy, path, len + 1);

	if (!coverLoadEnsureWorker()) {
		free(copy);
		lua_pushboolean(L, 0);
		return 1;
	}

	coverLoadPath = copy;
	coverLoadResult = NULL;
	coverLoadToken = token;
	coverLoadState = COVER_LOAD_BUSY;
	SignalSema(coverLoadSema);   // hand it to the resident worker
	lua_pushboolean(L, 1);
	return 1;
}

static int lua_coverloadpoll(lua_State *L)
{
	if (lua_gettop(L) != 0)
		return luaL_error(L, "Argument error: Graphics.coverLoadPoll() takes no arguments.");
	if (coverLoadState != COVER_LOAD_DONE) {
		lua_pushnil(L);
		return 1;
	}
	GSTEXTURE *tex = coverLoadResult;
	int token = coverLoadToken;
	coverLoadResult = NULL;
	coverLoadState = COVER_LOAD_IDLE;   // consumed; the next request may start
	lua_pushinteger(L, token);
	if (tex != NULL)
		lua_pushinteger(L, (uint32_t)tex);
	else
		lua_pushnil(L);
	return 2;
}

static int imgThread(void* data)
{
	char* text = (char*)data;
	bool delayed = asyncDelayed;
	GSTEXTURE* image = load_image(text, delayed);
	if (image == NULL) 
	{
		imgThreadResult = 1;
		ExitDeleteThread();
		return 0;
	}
	char* buffer = (char*)malloc(16);
	memset(buffer, 0, 16);
	sprintf(buffer, "%i", (int)image);
	imgThreadData = (unsigned char*)buffer;
	imgThreadSize = strlen(buffer);
	imgThreadResult = 1;
	ExitDeleteThread();
	return 0;
}


static int lua_fontload(lua_State *L){
	if (lua_gettop(L) != 1) return luaL_error(L, "wrong number of arguments"); 
	const char* path = luaL_checkstring(L, 1);
	GSFONT* font = loadFont(path);
	if (font == NULL) return luaL_error(L, "Error loading font (invalid magic).");
	lua_pushinteger(L, (uint32_t)(font));
	return 1;
}

static int lua_print(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 5 && argc != 6) return luaL_error(L, "wrong number of arguments");
	GSFONT* font = (GSFONT*)luaL_checkinteger(L, 1);
    float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
    float scale =  luaL_checknumber(L, 4);
    const char* text = luaL_checkstring(L, 5);
	Color color = GS_DEFAULT_COLOR;
	if (argc == 6) color = luaL_checkinteger(L, 6);
	printFontText(font, text, x, y, scale, color);
	return 0;
}

static int lua_fontunload(lua_State *L){
	int argc = lua_gettop(L); 
	if (argc != 1) return luaL_error(L, "wrong number of arguments"); 
	GSFONT* font = (GSFONT*)luaL_checkinteger(L, 1);
	unloadFont(font);
	return 0;
}

static int lua_ftinit(lua_State *L){
	if (lua_gettop(L) != 0) return luaL_error(L, "wrong number of arguments"); 
	fntInit();
	return 0;
}

static int lua_ftload(lua_State *L){
	if (lua_gettop(L) != 1) return luaL_error(L, "wrong number of arguments"); 
	const char* fontpath = luaL_checkstring(L, 1);
	int fntHandle = fntLoadFile(fontpath);
    lua_pushinteger(L, fntHandle);
	return 1;
}
extern unsigned char builtin_font[];
extern unsigned int size_builtin_font;

static const embedded_font_asset_t g_embedded_font_assets[] = {
    {"fonts/Roboto-Regular.ttf", builtin_font, size_builtin_font},
    {"builtin_font.ttf", builtin_font, size_builtin_font}
};

static const embedded_font_asset_t *FindEmbeddedFontAsset(const char *key)
{
    if (key == NULL) {
        return NULL;
    }

    for (size_t i = 0; i < sizeof(g_embedded_font_assets) / sizeof(g_embedded_font_assets[0]); ++i) {
        if (strcmp(key, g_embedded_font_assets[i].key) == 0) {
            return &g_embedded_font_assets[i];
        }
    }

    return NULL;
}

static int lua_ftloadDefault(lua_State *L){
	int fntHandle = fntLoadbuff(builtin_font, size_builtin_font);
	if (fntHandle == -1) lua_pushnil(L); else lua_pushinteger(L, fntHandle);
	return 1;
}

static int lua_ftloadEmbedded(lua_State *L)
{
    if (lua_gettop(L) != 1) return luaL_error(L, "wrong number of arguments");
    const char *fontkey = luaL_checkstring(L, 1);
    const embedded_font_asset_t *asset = FindEmbeddedFontAsset(fontkey);
    if (asset == NULL) {
        lua_pushnil(L);
        return 1;
    }

    int fntHandle = fntLoadbuff((void *)asset->data, (int)asset->size);
    if (fntHandle < 0) {
        lua_pushnil(L);
    } else {
        lua_pushinteger(L, fntHandle);
    }
    return 1;
}

static int lua_ftSetPixelSize(lua_State *L) {
	if (lua_gettop(L) != 3) return luaL_error(L, "wrong number of arguments"); 
	int fontid = luaL_checkinteger(L, 1);
	int width = luaL_checknumber(L, 2); 
	int height = luaL_checknumber(L, 3); 
	fntSetPixelSize(fontid, width, height);
	return 0;
}

static int lua_ftSetCharSize(lua_State *L) {
	if (lua_gettop(L) != 3) return luaL_error(L, "wrong number of arguments"); 
	int fontid = luaL_checkinteger(L, 1);
	int width = luaL_checkinteger(L, 2); 
	int height = luaL_checkinteger(L, 3); 
	fntSetCharSize(fontid, width, height);
	return 0;
}

static int lua_ftprint(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 7 && argc != 8) return luaL_error(L, "wrong number of arguments");
	int fontid = luaL_checkinteger(L, 1);
    int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	int alignment = luaL_checkinteger(L, 4);
	int width = luaL_checkinteger(L, 5); 
	int height = luaL_checkinteger(L, 6); 
    const char* text = luaL_checkstring(L, 7);
	Color color = GS_DEFAULT_COLOR;
	if (argc == 8) color = luaL_checkinteger(L, 8);
	fntRenderString(fontid, x, y, alignment, width, height, text, color);
	return 0;
}

static int lua_ftwidth(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "wrong number of arguments");
	int fontid = luaL_checkinteger(L, 1);
	const char* text = luaL_checkstring(L, 2);
	lua_pushinteger(L, fntCalcDimensions(fontid, text));
	return 1;
}

static int lua_ftunload(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "wrong number of arguments");
	int fontid = luaL_checkinteger(L, 1);
	fntRelease(fontid);
	return 0;
}

static int lua_ftend(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 0) return luaL_error(L, "wrong number of arguments");
	fntEnd();
	return 0;
}

static int lua_fmload(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 0) return luaL_error(L, "wrong number of arguments");
	loadFontM();
	return 0;
}

static int lua_fmprint(lua_State *L) {
	int argc = lua_gettop(L);
	//if (argc != 3) return luaL_error(L, "wrong number of arguments");
    float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
    float scale =  luaL_checknumber(L, 3);
    const char* text = luaL_checkstring(L, 4);
	Color color = GS_DEFAULT_COLOR;
	if (argc == 5) color =  luaL_checkinteger(L, 5);
	printFontMText(text, x, y, scale, color);
	return 0;
}

static int lua_fmunload(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 0) return luaL_error(L, "wrong number of arguments");
	unloadFontM();
	return 0;
}


static const luaL_Reg Font_functions[] = {
	//FreeType functions
	{"ftInit",            		  lua_ftinit},
	{"ftLoad",            		  lua_ftload},
	{"LoadBuiltinFont",    lua_ftloadDefault},
	{"ftLoadEmbedded",     lua_ftloadEmbedded},
	{"ftSetPixelSize",    lua_ftSetPixelSize},
	{"ftSetCharSize", 	   lua_ftSetCharSize},
	{"ftPrint",         		 lua_ftprint},
	{"ftWidth",            		 lua_ftwidth},
	{"ftUnload",           		lua_ftunload},
	{"ftEnd",           	       lua_ftend},
	//gsFont functions
  	{"load",	                lua_fontload},
  	{"print",                      lua_print},
    {"unload",                lua_fontunload},
	//gsFontM functions
  	{"fmLoad",            		  lua_fmload}, 
	{"fmPrint",           		 lua_fmprint}, 
	{"fmUnload",         	    lua_fmunload}, 
  {0, 0}
};


static int lua_loadimgasync(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "wrong number of arguments");
	char* text = (char*)(luaL_checkstring(L, 1));
	if (argc == 2) asyncDelayed = lua_toboolean(L, 2);
	
	ee_thread_t thread_param;
	
	thread_param.gp_reg = &_gp;
    thread_param.func = (void*)imgThread;
    thread_param.stack = (void *)imgThreadStack;
    thread_param.stack_size = sizeof(imgThreadStack);
    thread_param.initial_priority = 16;
	int thread = CreateThread(&thread_param);
	if (thread < 0)
	{
		imgThreadResult = -1;
		return 0;
	}
	
	imgThreadResult = 0;
	StartThread(thread, (void*)text);
	return 0;
}

static int lua_loadimg(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 1 && argc != 2) return luaL_error(L, "wrong number of arguments");
	const char* text = luaL_checkstring(L, 1);
	bool delayed = true;
	if (argc == 2) delayed = lua_toboolean(L, 2);
	GSTEXTURE* image = load_image(text, delayed);

	if (image != NULL)
		lua_pushinteger(L, (uint32_t)(image));
	else
		lua_pushnil(L);
	return 1;
}

static int lua_drawimg(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 3 && argc != 4) return luaL_error(L, "wrong number of arguments");
    GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	Color color = GS_DEFAULT_COLOR;
	if (argc == 4) color = (Color)luaL_checknumber(L, 4);
	float width = source->Width;
	float height = source->Height;
	float startx = 0.0f;
	float starty = 0.0f;
	float endx = source->Width;
	float endy = source->Height;

	drawImage(source, x, y, width, height, startx, starty, endx, endy, color);

	return 0;
}

static int lua_drawimg_rotate(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 4 && argc != 5) return luaL_error(L, "wrong number of arguments");
    GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	float radius = luaL_checknumber(L, 4);
	Color color = GS_DEFAULT_COLOR;
	if (argc == 5) color = (Color)luaL_checknumber(L, 5);
	float width = source->Width;
	float height = source->Height;
	float startx = 0.0f;
	float starty = 0.0f;
	float endx = source->Width;
	float endy = source->Height;

	drawImageRotate(source, x, y, width, height, startx, starty, endx, endy, radius, color);

	return 0;
}

static int lua_drawimg_scale(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 5 && argc != 6) return luaL_error(L, "wrong number of arguments");
    GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	float width = luaL_checknumber(L, 4);
	float height = luaL_checknumber(L, 5);
	Color color = GS_DEFAULT_COLOR;
	if (argc == 6) color = (Color)luaL_checknumber(L, 6);
	float startx = 0.0f;
	float starty = 0.0f;
	float endx = source->Width;
	float endy = source->Height;

	drawImage(source, x, y, width, height, startx, starty, endx, endy, color);

	return 0;
}

static int lua_drawimg_part(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 7 && argc != 8) return luaL_error(L, "wrong number of arguments");
    GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	float startx = (float)luaL_checknumber(L, 4);
	float starty = (float)luaL_checknumber(L, 5);
	float endx = (float)luaL_checknumber(L, 6);
	float endy = (float)luaL_checknumber(L, 7);
	Color color = GS_DEFAULT_COLOR;
	if (argc == 8) color = (Color)luaL_checknumber(L, 8);
	float width = source->Width;
	float height = source->Height;
	
	drawImage(source, x, y, width, height, startx, starty, endx, endy, color);

	return 0;
}

static int lua_drawimg_full(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 10 && argc != 11) return luaL_error(L, "wrong number of arguments");
    GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	float startx = (float)luaL_checknumber(L, 4);
	float starty = (float)luaL_checknumber(L, 5);
	float endx = (float)luaL_checknumber(L, 6);
	float endy = (float)luaL_checknumber(L, 7);
	float width = (float)luaL_checknumber(L, 8);
	float height = (float)luaL_checknumber(L, 9);
	float angle = (float)luaL_checknumber(L, 10);
	Color color = GS_DEFAULT_COLOR;
	if (argc == 11) color = (Color)luaL_checknumber(L, 11);

	drawImageRotate(source, x, y, width, height, startx, starty, endx, endy, angle, color);

	return 0;
}

static int lua_width(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "wrong number of arguments");
    GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));
	lua_pushinteger(L, (uint32_t)(source->Width));
	return 1;
}

static int lua_height(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "wrong number of arguments");
    GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));
	lua_pushinteger(L, (uint32_t)(source->Height));
	return 1;
}

static int lua_filters(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "wrong number of arguments");
    GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));
	source->Filter = luaL_checknumber(L, 2);
	return 0;
}

static int lua_rect(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 5) return luaL_error(L, "wrong number of arguments");
	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
    float width = luaL_checknumber(L, 3);
    float height = luaL_checknumber(L, 4);
    Color color =  luaL_checkinteger(L, 5);

	drawRect(x, y, width, height, color);

	return 0;
}

static int lua_line(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 5) return luaL_error(L, "wrong number of arguments");
	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
    float x2 = luaL_checknumber(L, 3);
    float y2 = luaL_checknumber(L, 4);
    Color color = luaL_checkinteger(L, 5);

	drawLine(x, y, x2, y2, color);

	return 0;
}

static int lua_pixel(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 3) return luaL_error(L, "wrong number of arguments");
	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
    Color color =  luaL_checkinteger(L, 3);

	drawPixel(x, y, color);
	return 0;
}

static int lua_triangle(lua_State *L) {
	int argc = lua_gettop(L);

	if (argc != 7 && argc != 9) return luaL_error(L, "wrong number of arguments");

	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
    float x2 = luaL_checknumber(L, 3);
    float y2 = luaL_checknumber(L, 4);
	float x3 = luaL_checknumber(L, 5);
    float y3 = luaL_checknumber(L, 6);
    Color color =  luaL_checkinteger(L, 7);

	if (argc == 7) drawTriangle(x, y, x2, y2, x3, y3, color);

	if (argc == 9) {
		Color color2 =  luaL_checkinteger(L, 8);
		Color color3 =  luaL_checkinteger(L, 9);
		drawTriangle_gouraud(x, y, x2, y2, x3, y3, color, color2, color3);
	}
	return 0;
}

static int lua_quad(lua_State *L) {
	int argc = lua_gettop(L);

	if (argc != 9 && argc != 12) return luaL_error(L, "wrong number of arguments");

	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
    float x2 = luaL_checknumber(L, 3);
    float y2 = luaL_checknumber(L, 4);
	float x3 = luaL_checknumber(L, 5);
    float y3 = luaL_checknumber(L, 6);
	float x4 = luaL_checknumber(L, 7);
    float y4 = luaL_checknumber(L, 8);
    Color color =  luaL_checkinteger(L, 9);

	if (argc == 9) drawQuad(x, y, x2, y2, x3, y3, x4, y4, color);

	if (argc == 12) {
		Color color2 = luaL_checkinteger(L, 10);
		Color color3 = luaL_checkinteger(L, 11);
		Color color4 = luaL_checkinteger(L, 12);
		drawQuad_gouraud(x, y, x2, y2, x3, y3, x4, y4, color, color2, color3, color4);
	}
	return 0;
}

static int lua_circle(lua_State *L) {
	int argc = lua_gettop(L);

	if (argc != 4 && argc != 5) return luaL_error(L, "wrong number of arguments");

	float x = luaL_checknumber(L, 1);
	float y = luaL_checknumber(L, 2);
    float radius = luaL_checknumber(L, 3);
    Color color = luaL_checkinteger(L, 4);

	bool filling = (argc == 5);
    int filled = filling? luaL_checknumber(L, 5) : 1;

	drawCircle(x, y, radius, color, filled);

	return 0;
}

static int lua_free(lua_State *L) {
	int argc = lua_gettop(L);
#ifndef SKIP_ERROR_HANDLING
	if (argc != 1) return luaL_error(L, "wrong number of arguments");
#endif
	
	GSTEXTURE* source = (GSTEXTURE*)(luaL_checkinteger(L, 1));

	UnloadTexture(source);

	free(source->Mem);
	source->Mem = NULL;
	
	// Free texture CLUT
	if(source->Clut != NULL)
	{
		
		free(source->Clut);
		source->Clut = NULL;
	}

	free(source);
	source = NULL;

	return 0;
}

static int lua_getloadstate(lua_State *L){
	int argc = lua_gettop(L);
#ifndef SKIP_ERROR_HANDLING
	if(argc != 0) return luaL_error(L, "wrong number of arguments.");
#endif
	lua_pushinteger(L, imgThreadResult);
	return 1;
}

static int lua_getloaddata(lua_State *L){
	int argc = lua_gettop(L);
#ifndef SKIP_ERROR_HANDLING
	if(argc != 0) return luaL_error(L, "wrong number of arguments.");
#endif
	if (imgThreadData != NULL){
		lua_pushlstring(L,(const char*)imgThreadData,imgThreadSize);
		free(imgThreadData);
		imgThreadData = NULL;
		return 1;
	}else return 0;
}

static int lua_load_embedded_png(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "wrong number of arguments");
    lua_gc(L, LUA_GCCOLLECT, 0);
	uint8_t* ptr = (uint8_t *)luaL_checkstring(L, 1);
	size_t siz = luaL_checkinteger(L, 2);
	GSTEXTURE* image = NULL;
	image = loadEmbeddedPNG(ptr, siz, true);
	// Push nil (not 0) on a failed decode so the Lua "if img == nil" guards in
	// images.lua actually catch it -- pushing integer 0 made callers cache/draw a
	// NULL handle (NULL deref). Mirrors lua_loadimg's nil-on-failure convention.
	if (image != NULL)
		lua_pushinteger(L, (uint32_t)(image));
	else
		lua_pushnil(L);
	return 1;
}
//Register our Graphics Functions
static const luaL_Reg Graphics_functions[] = {
    {"loadImageEmbedded",         lua_load_embedded_png},
  	{"drawPixel",           		   lua_pixel},
  //{"getPixel",            		  lua_gpixel},
  	{"drawRect",           				lua_rect},
  	{"drawLine",            			lua_line},
  	{"drawCircle",         			  lua_circle},
	{"drawTriangle",        		lua_triangle},
	{"drawQuad",        				lua_quad},
    {"loadImage",           		 lua_loadimg},
  	{"threadLoadImage",        	lua_loadimgasync},
  //{"loadAnimatedImage",   	   lua_loadanimg},
  //{"getImageFramesNum",   	lua_getnumframes},
  //{"setImageFrame",       		lua_setframe},
    {"drawImage",           		 lua_drawimg},
  	{"drawRotateImage",       lua_drawimg_rotate},
  	{"drawScaleImage",     	   lua_drawimg_scale},
  	{"drawPartialImage",    	lua_drawimg_part},
  	{"drawImageExtended",   	lua_drawimg_full},
  //{"createImage",         	 lua_createimage},
  	{"setImageFilters",     		 lua_filters},
  	{"getImageWidth",       		   lua_width},
  	{"getImageHeight",      		  lua_height},
    {"freeImage",           			lua_free},
	{"getLoadState",            lua_getloadstate},
  	{"getLoadData",     	     lua_getloaddata},
	{"coverLoadBegin",          lua_coverloadbegin},
	{"coverLoadPoll",           lua_coverloadpoll},
  {0, 0}
};


void luaGraphics_init(lua_State *L) {

    lua_newtable(L);
	luaL_setfuncs(L, Graphics_functions, 0);
	lua_setglobal(L, "Graphics");

	lua_newtable(L);
	luaL_setfuncs(L, Font_functions, 0);
	lua_setglobal(L, "Font");

	lua_pushinteger(L, GS_FILTER_NEAREST);
	lua_setglobal (L, "NEAREST");

	lua_pushinteger(L, GS_FILTER_LINEAR);
	lua_setglobal (L, "LINEAR");
}
