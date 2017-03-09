#define LUA_LIB

#ifndef CALLBACK
#if defined(_ARM_)
#define CALLBACK
#else
#define CALLBACK __stdcall
#endif
#endif

#include <rikoGPU.h>

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>
#include <SDL2/SDL.h>

#include <stdint.h>
#include <stdlib.h>

extern SDL_Window *window;
extern SDL_Renderer *renderer;
extern double pixelSize;

static float pWid = 1;
static float pHei = 1;

int palette[16][3] = {
	{24,   24,   24},
	{29,   43,   82},
	{126,  37,   83},
	{0,    134,  81},
	{171,  81,   54},
	{86,   86,   86},
	{157,  157,  157},
	{255,  0,    76},
	{255,  163,  0},
	{255,  240,  35},
	{0,    231,  85},
	{41,   173,  255},
	{130,  118,  156},
	{255,  119,  169},
	{254,  204,  169},
	{236,  236,  236}
};

static int getColor(lua_State *L, int arg) {
	int color = (int)luaL_checknumber(L, arg) - 1;
	return color < 0 ? 0 : (color > 15 ? 15 : color);
}

static int gpu_draw_pixel(lua_State *L) {
	int x = ((int)luaL_checknumber(L, 1));
	int y = ((int)luaL_checknumber(L, 2));

	int color = getColor(L, 3);

	SDL_Rect rect;
	rect.x = x * pixelSize;
	rect.y = y * pixelSize;
	rect.w = pixelSize;
	rect.h = pixelSize;

	SDL_SetRenderDrawColor(renderer, palette[(int)color][0], palette[(int)color][1], palette[(int)color][2], 255);
	SDL_RenderFillRect(renderer, &rect);

	return 0;
}

static int gpu_draw_rectangle(lua_State *L) {
	int color = getColor(L, 5);

	SDL_Rect rect;
	rect.x = ((double)luaL_checknumber(L, 1)) * pixelSize;
	rect.y = ((double)luaL_checknumber(L, 2)) * pixelSize;
	rect.w = ((double)luaL_checknumber(L, 3) * pixelSize);
	//printf("Rect width: %d with %d pz\n should be %d", rect.w, pixelSize, ((double)luaL_checknumber(L, 3) * pixelSize));
	rect.h = ((double)luaL_checknumber(L, 4)) * pixelSize;

	SDL_SetRenderDrawColor(renderer, palette[(int)color][0], palette[(int)color][1], palette[(int)color][2], 255);
	SDL_RenderFillRect(renderer, &rect);


	return 0;
}

static int gpu_blit_pixels(lua_State *L) {
	int x = ((int)luaL_checknumber(L, 1));
	int y = ((int)luaL_checknumber(L, 2));
	int w = (int)luaL_checknumber(L, 3);
	int h = (int)luaL_checknumber(L, 4);

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

		float xp = ((i - 1) % (int) w) * pWid;
		float yp = ((int)((i - 1) / (int) w)) * pHei;
		
		SDL_Rect rect;
		rect.x = (x + xp) * pixelSize;
		rect.y = (y + yp) * pixelSize;
		rect.w = pixelSize;
		rect.h = pixelSize;

		SDL_SetRenderDrawColor(renderer, palette[(int)color][0], palette[(int)color][1], palette[(int)color][2], 255);
		SDL_RenderFillRect(renderer, &rect);

		lua_pop(L, 1);
	}

	return 0;
}

static int gpu_clear(lua_State *L) {
	if (lua_gettop(L) > 0) {
		int color = getColor(L, 1);
		SDL_SetRenderDrawColor(renderer, palette[(int)color][0], palette[(int)color][1], palette[(int)color][2], 255);
	} else {
		SDL_SetRenderDrawColor(renderer, palette[0][0], palette[0][1], palette[0][2], 255);
	}

	SDL_RenderClear(renderer);

	return 0;
}

static int gpu_swap(lua_State *L) {
	SDL_RenderPresent(renderer);
	return 0;
}

static const luaL_Reg gpuLib[] = {
	{ "drawPixel", gpu_draw_pixel },
	{ "drawRectangle", gpu_draw_rectangle },
	{ "blitPixels", gpu_blit_pixels },
	{ "clear", gpu_clear },
	{ "swap", gpu_swap },
	{NULL, NULL}
};

LUALIB_API int luaopen_gpu(lua_State *L) {
	luaL_openlib(L, RIKO_GPU_NAME, gpuLib, 0);
	lua_pushnumber(L, 340);
	lua_setfield(L, -2, "width");
	lua_pushnumber(L, 200);
	lua_setfield(L, -2, "height");
	return 1;
}