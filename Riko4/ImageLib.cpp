#define LUA_LIB

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>
#include <SDL2/SDL.h>

#include <rikoImage.h>

extern SDL_Window *window;
extern SDL_Renderer *renderer;
extern int pixelSize;
extern int palette[16][3];

typedef struct imageType {
	int width;
	int height;
	bool free;
	int clr;
	SDL_Surface *surface;
	SDL_Texture *texture;
} imageType;

static float pWid = 1;
static float pHei = 1;

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

static int getColor(lua_State *L, int arg) {
	int color = (int)luaL_checknumber(L, arg) - 1;
	return color < 0 ? 0 : (color > 15 ? 15 : color);
}

static Uint32 getRectC(imageType *data, int color) {
	if (data->clr == color) {
		return SDL_MapRGBA(data->surface->format, palette[0][0], palette[0][1], palette[0][2], 0);
	} else {
		return SDL_MapRGBA(data->surface->format, palette[color][0], palette[color][1], palette[color][2], 255);
	}
}

static imageType *checkImage(lua_State *L) {
	void *ud = luaL_checkudata(L, 1, "Riko4.Image");
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

	luaL_getmetatable(L, "Riko4.Image");
	lua_setmetatable(L, -2);

	a->width = w;
	a->height = h;
	a->free = false;
	a->clr = 0;
	a->surface = SDL_CreateRGBSurface(0, w, h, 32, rmask, gmask, bmask, amask);

	// Init to black color
	SDL_FillRect(a->surface, NULL, SDL_MapRGBA(a->surface->format, 0, 0, 0, 0));
	a->texture = SDL_CreateTextureFromSurface(renderer, a->surface);

	return 1;
}

static int flushImage(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	SDL_DestroyTexture(data->texture);
	data->texture = SDL_CreateTextureFromSurface(renderer, data->surface);

	return 0;
}

static int renderImage(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	int x = (int)luaL_checknumber(L, 2);
	int y = (int)luaL_checknumber(L, 3);

	SDL_Rect rect;
	rect.x = x * pixelSize;
	rect.y = y * pixelSize;
	rect.w = data->width * pixelSize;
	rect.h = data->height * pixelSize;

	SDL_RenderCopy(renderer, data->texture, NULL, &rect);

	return 0;
}

static int freeImage(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	SDL_FreeSurface(data->surface);
	SDL_DestroyTexture(data->texture);
	data->free = true;

	return 0;
}

static int imageDrawPixel(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	int x = (int)luaL_checknumber(L, 2);
	int y = (int)luaL_checknumber(L, 3);

	int color = getColor(L, 4);

	Uint32 rectcolor = getRectC(data, color);
	SDL_Rect* rect = new SDL_Rect();
	rect->x = x;
	rect->y = y;
	rect->w = 1;
	rect->h = 1;
	SDL_FillRect(data->surface, rect, rectcolor);
	free(rect);
	return 0;
}

static int imageDrawRectangle(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	int x = (int)luaL_checknumber(L, 2);
	int y = (int)luaL_checknumber(L, 3);
	int w = (int)luaL_checknumber(L, 4);
	int h = (int)luaL_checknumber(L, 5);

	int color = getColor(L, 6);

	Uint32 rectcolor = getRectC(data, color);
	SDL_Rect* rect = new SDL_Rect();
	rect->x = x;
	rect->y = y;
	rect->w = w;
	rect->h = h;
	SDL_FillRect(data->surface, rect, rectcolor);
	free(rect);
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
		int color = lua_tonumber(L, -1) - 1;
		if (color == -1) {
			continue;
		}

		color = color < 0 ? 0 : (color > 15 ? 15 : color);

		int xp = ((i - 1) % (int)w);
		int yp = ((int)((i - 1) / (int)w));

		Uint32 rectcolor = getRectC(data, color);
		SDL_Rect* rect = new SDL_Rect();
		rect->x = x + xp;
		rect->y = y + yp;
		rect->w = 1;
		rect->h = 1;
		SDL_FillRect(data->surface, rect, rectcolor);
		free(rect);

		lua_pop(L, 1);
	}

	return 0;
}

static int imageClear(lua_State *L) {
	imageType *data = checkImage(L);
	if (!freeCheck(L, data)) return 0;

	SDL_FillRect(data->surface, NULL, SDL_MapRGBA(data->surface->format, 0, 0, 0, 0));

	return 0;
}

static int imageCopy(lua_State *L) {
	imageType *src = checkImage(L);

	void *ud = luaL_checkudata(L, 2, "Riko4.Image");
	luaL_argcheck(L, ud != NULL, 1, "`Image` expected");
	imageType *dst = (imageType *)ud;

	int x = (int)luaL_checknumber(L, 3);
	int y = (int)luaL_checknumber(L, 4);
	int wi;
	int he;

	SDL_Rect *srcRect = new SDL_Rect();

	if (lua_gettop(L) > 4) {
		wi = luaL_checknumber(L, 5);
		he = luaL_checknumber(L, 6);
		srcRect->x = luaL_checknumber(L, 7);
		srcRect->y = luaL_checknumber(L, 8);
		srcRect->w = wi;
		srcRect->h = he;
	} else {
		srcRect->x = 0;
		srcRect->y = 0;
		srcRect->w = src->width;
		srcRect->h = src->height;
		wi = src->width;
		he = src->height;
	}

	SDL_Rect *rect = new SDL_Rect();
	rect->x = x;
	rect->y = y;
	rect->w = wi;
	rect->h = he;
	SDL_BlitSurface(src->surface, srcRect, dst->surface, rect);
	free(srcRect);
	free(rect);
	return 0;
}

static int imageToString(lua_State *L) {
	imageType *data = checkImage(L);
	if (data->free) {
		lua_pushstring(L, "Image(freed)");
	} else {
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
	{ "blitPixels", imageBlitPixels },
	{ "copy", imageCopy },
	{ NULL, NULL }
};

LUALIB_API int luaopen_image(lua_State *L) {
	luaL_newmetatable(L, "Riko4.Image");

	lua_pushstring(L, "__index");
	lua_pushvalue(L, -2);  /* pushes the metatable */
	lua_settable(L, -3);  /* metatable.__index = metatable */

	luaL_openlib(L, NULL, imageLib_m, 0);

	luaL_openlib(L, RIKO_IMAGE_NAME, imageLib, 0);

	return 1;
}