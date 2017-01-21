#define LUA_LIB

#include <LuaJIT\lua.hpp>
#include <LuaJIT\lauxlib.h>
#include <GL/glew.h>
#include <SDL2/SDL.h>

#include <rikoImage.h>

extern SDL_Window *window;
extern char16_t palette[16][3];

typedef struct imageType {
	int width;
	int height;
	bool free;
	SDL_Surface *surface;
	texture glTex;
} imageType;

static float pWid = 1 / 170.0f;
static float pHei = 1 / 100.0f;

#if SDL_BYTEORDER == SDL_BIG_ENDIAN
	int rmask = 0xff000000;
	int gmask = 0x00ff0000;
	int bmask = 0x0000ff00;
	int amask = 0x000000ff;
#else
	int rmask = 0x000000ff;
	int gmask = 0x0000ff00;
	int bmask = 0x00ff0000;
	int amask = 0xff000000;
#endif

static imageType *checkImage(lua_State *L) {
	void *ud = luaL_checkudata(L, 1, "RIKO4.Image");
	luaL_argcheck(L, ud != NULL, 1, "`Image` expected");
	return (imageType *)ud;
}

bool freeCheck(lua_State *L, imageType *data) {
	if (data->free) {
		luaL_error(L, "Attempt to perform Image operation but Image was freed");
		return false;
	}
	return true;
}

static int newImage(lua_State *L) {
	int w = luaL_checkint(L, 1);
	int h = luaL_checkint(L, 2);
	size_t nbytes = sizeof(imageType);
	imageType *a = (imageType *)lua_newuserdata(L, nbytes);

	luaL_getmetatable(L, "RIKO4.Image");
	lua_setmetatable(L, -2);

	a->width = w;
	a->height = h;
	a->free = false;
	a->surface = SDL_CreateRGBSurface(0, w, h, 24, rmask, gmask, bmask, amask);
	texture ret;
	glGenTextures(1, &ret);
	a->glTex = ret;

	// Init to black color
	Uint32 rectcolor = SDL_MapRGB(a->surface->format, palette[5][0], palette[0][1], palette[0][2]);
	SDL_FillRect(a->surface, NULL, rectcolor);

	glBindTexture(GL_TEXTURE_2D, a->glTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexImage2D(GL_TEXTURE_2D, 0, 3, a->width, a->height, 0, GL_RGB,
		GL_UNSIGNED_BYTE, a->surface->pixels);
	glBindTexture(GL_TEXTURE_2D, 0);

	return 1;
}

static int flushImage(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	glBindTexture(GL_TEXTURE_2D, data->glTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexImage2D(GL_TEXTURE_2D, 0, 3, data->width, data->height, 0, GL_RGB,
		GL_UNSIGNED_BYTE, data->surface->pixels);
	glBindTexture(GL_TEXTURE_2D, 0);

	return 0;
}

static int renderImage(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	GLfloat x = ((int)luaL_checknumber(L, 2)) / 170.0f - 1.0f;
	GLfloat y = 1.0f - ((int)luaL_checknumber(L, 3)) / 100.0f;

	texture ret = data->glTex;
	
	glBindTexture(GL_TEXTURE_2D, ret);

	glColor3f(1, 1, 1);
	glEnable(GL_TEXTURE_2D);

	glBegin(GL_QUADS);
	glTexCoord2i(0, 0); glVertex3f(x, y, 0);
	glTexCoord2i(0, 1); glVertex3f(x, y - pHei*data->height, 0);
	glTexCoord2i(1, 1); glVertex3f(x + pWid*data->width, y - pHei*data->height, 0);
	glTexCoord2i(1, 0); glVertex3f(x + pWid*data->width, y, 0);
	glEnd();


	glDisable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, 0);

	return 0;
}

static int freeImage(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	SDL_FreeSurface(data->surface);
	data->free = true;
	glDeleteTextures(1, &(data->glTex));

	return 0;
}

static int imageDrawPixel(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	int x = (int)luaL_checknumber(L, 2);
	int y = (int)luaL_checknumber(L, 3);

	int color = (int)luaL_checknumber(L, 4);

	Uint32 rectcolor = SDL_MapRGB(data->surface->format, palette[color][0], palette[color][1], palette[color][2]);
	SDL_Rect* rect = new SDL_Rect();
	rect->x = x;
	rect->y = y;
	rect->w = 1;
	rect->h = 1;
	SDL_FillRect(data->surface, rect, rectcolor);
	return 0;
}

static int imageDrawRectangle(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	int x = (int)luaL_checknumber(L, 2);
	int y = (int)luaL_checknumber(L, 3);
	int w = (int)luaL_checknumber(L, 4);
	int h = (int)luaL_checknumber(L, 5);

	int color = (int)luaL_checknumber(L, 6);

	Uint32 rectcolor = SDL_MapRGB(data->surface->format, palette[color][0], palette[color][1], palette[color][2]);
	SDL_Rect* rect = new SDL_Rect();
	rect->x = x;
	rect->y = y;
	rect->w = w;
	rect->h = h;
	SDL_FillRect(data->surface, rect, rectcolor);
	return 0;
}


static int imageBlitPixels(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	int x = (int)luaL_checknumber(L, 2);
	int y = (int)luaL_checknumber(L, 3);
	int w = (int)luaL_checknumber(L, 4);
	int h = (int)luaL_checknumber(L, 5);

	int amt = lua_objlen(L, -1);
	int len = (int)w*(int)h;
	if (amt < len) {
		luaL_error(L, "blitPixels expected %d pixels, got %d", len, amt);
		return 0;
	}

	for (int i = 1; i <= len; i++) {
		lua_pushnumber(L, i);
		lua_gettable(L, -2);
		if (!lua_isnumber(L, -1)) {
			luaL_error(L, "Index %d is non-numeric", i);
		}
		int color = lua_tonumber(L, -1);

		float xp = ((i - 1) % (int)w) * pWid;
		float yp = ((int)((i - 1) / (int)w)) * pHei;

		Uint32 rectcolor = SDL_MapRGB(data->surface->format, palette[color][0], palette[color][1], palette[color][2]);
		SDL_Rect* rect = new SDL_Rect();
		rect->x = x + xp;
		rect->y = y - yp;
		rect->w = 1;
		rect->h = 1;
		SDL_FillRect(data->surface, rect, rectcolor);

		lua_pop(L, 1);
	}

	return 0;
}

static int imageClear(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	if (lua_gettop(L) > 0) {
		int color = luaL_checknumber(L, 1);
		Uint32 rectcolor = SDL_MapRGB(data->surface->format, palette[color][0], palette[color][1], palette[color][2]);
		SDL_FillRect(data->surface, NULL, rectcolor);
	}

	Uint32 rectcolor = SDL_MapRGB(data->surface->format, palette[0][0], palette[0][1], palette[0][2]);
	SDL_FillRect(data->surface, NULL, rectcolor);

	return 0;
}

static int imageToString(lua_State *L) {
	imageType *data = checkImage(L);
	if (data->free) {
		lua_pushstring(L, "Image(freed)");
	}
	else {
		lua_pushfstring(L, "Image(%dx%d)", data->width, data->height);
	}
	return 1;
}

static const luaL_Reg imageLib[] = {
	{ "newImage", newImage },
	{ NULL, NULL }
};

static const luaL_Reg imageLib_m[] = {
	{ "__tostring", imageToString },
	{ "free", freeImage },
	{ "flush", flushImage },
	{ "render", renderImage },
	{ "clear", imageClear },
	{ "drawPixel", imageDrawPixel },
	{ "drawRectangle", imageDrawRectangle },
	{ NULL, NULL }
};

LUALIB_API int luaopen_image(lua_State *L) {
	luaL_newmetatable(L, "RIKO4.Image");

	lua_pushstring(L, "__index");
	lua_pushvalue(L, -2);  /* pushes the metatable */
	lua_settable(L, -3);  /* metatable.__index = metatable */

	luaL_openlib(L, NULL, imageLib_m, 0);

	luaL_openlib(L, RIKO_IMAGE_NAME, imageLib, 0);

	return 1;
}