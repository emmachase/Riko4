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
#include <GL/glew.h>
#include <SDL2/SDL.h>

#include <stdint.h>
#include <stdlib.h>

extern SDL_Window *window;

static float pWid = 1 / 170.0f;
static float pHei = 1 / 100.0f;

char16_t palette[16][3] = {
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
	{236,  236,  255}
};

static int getColor(lua_State *L, int arg) {
	int color = (int)luaL_checknumber(L, arg) - 1;
	//printf("color %d", color);
	return color < 0 ? 0 : (color > 15 ? 15 : color);
}

static int gpu_draw_pixel(lua_State *L) {
	lua_Number x = ((int)luaL_checknumber(L, 1)) / 170.0f - 1.0f;
	lua_Number y = 1.0f - ((int)luaL_checknumber(L, 2)) / 100.0f;

	int color = getColor(L, 3);

	glColor3f(palette[(int) color][0] / 255.0f, palette[(int) color][1] / 255.0f, palette[(int) color][2] / 255.0f);

	glBegin(GL_POLYGON);
	glVertex2d(x, y);
	glVertex2d(x + pWid, y);
	glVertex2d(x + pWid, y - pHei);
	glVertex2d(x, y - pHei);
	glEnd();

	return 0;
}

static int gpu_draw_rectangle(lua_State *L) {
	lua_Number x1 = ((int)luaL_checknumber(L, 1)) / 170.0f - 1.0f;
	lua_Number y1 = 1.0f - ((int)luaL_checknumber(L, 2)) / 100.0f;

	int color = getColor(L, 5);

	glColor3f(palette[(int)color][0] / 255.0f, palette[(int)color][1] / 255.0f, palette[(int)color][2] / 255.0f);

	double x2 = x1 + pWid * ((int)luaL_checknumber(L, 3));
	double y2 = y1 - pHei * ((int)luaL_checknumber(L, 4));

	glBegin(GL_POLYGON);
	glVertex2d(x1, y1);
	glVertex2d(x2, y1);
	glVertex2d(x2, y2);
	glVertex2d(x1, y2);
	glEnd();

	return 0;
}

static int gpu_blit_pixels(lua_State *L) {
	lua_Number x = ((int)luaL_checknumber(L, 1)) / 170.0f - 1.0f;
	lua_Number y = 1.0f - ((int)luaL_checknumber(L, 2)) / 100.0f;
	lua_Number w = (int)luaL_checknumber(L, 3);
	lua_Number h = (int)luaL_checknumber(L, 4);

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
		
		glColor3f(palette[color][0] / 255.0f, palette[color][1] / 255.0f, palette[color][2] / 255.0f);

		glBegin(GL_POLYGON);
		glVertex2d(x + xp, y - yp);
		glVertex2d(x + xp + pWid, y - yp);
		glVertex2d(x + xp + pWid, y - yp - pHei);
		glVertex2d(x + xp, y - yp - pHei);
		glEnd();

		lua_pop(L, 1);
	}

	return 0;
}

static int gpu_clear(lua_State *L) {
	if (lua_gettop(L) > 0) {
		int color = getColor(L, 1);
		glClearColor(palette[(int)color][0] / 255.0f, palette[(int)color][1] / 255.0f, palette[(int)color][2] / 255.0f, 0.0f);
	} else {
		glClearColor(palette[0][0] / 255.0f, palette[0][1] / 255.0f, palette[0][2] / 255.0f, 0.0f);
	}

	glClear(GL_COLOR_BUFFER_BIT);

	return 0;
}

static int gpu_swap(lua_State *L) {
	SDL_GL_SwapWindow(window);
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