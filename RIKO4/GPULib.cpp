#define LUA_LIB

#include <LuaJIT\lua.hpp>
#include <LuaJIT\lauxlib.h>
#include <rikoGPU.h>
#include <GL/glew.h>
#include <SDL2/SDL.h>

extern SDL_Window *window;

static float pWid = 1 / 170.0f;
static float pHei = 1 / 100.0f;

static unsigned char pallete[16][3] = {
	{ 0, 0, 0 },
	{ 255, 255, 255 },
	{ 255, 0, 0 },
	{ 255, 106, 0 },
	{ 255, 255, 0 },
	{ 0, 255, 33 },
	{ 0, 147, 141 },
	{ 0, 38, 255 },
	{ 178, 0, 255 },
	{ 255, 0, 110 },
	{ 100, 100, 100 },
};

static int gpu_draw_pixel(lua_State *L) {
	lua_Number x = luaL_checknumber(L, 1) / 170.0f - 1.0f;
	lua_Number y = 1.0f - luaL_checknumber(L, 2) / 100.0f;

	lua_Number color = luaL_checknumber(L, 3);

	glColor3f(pallete[(int) color][0] / 255.0f, pallete[(int) color][1] / 255.0f, pallete[(int) color][2] / 255.0f);

	glRectd(x, y, x + pWid, y - pHei);
	//printf("%f %f %f %f \n", x, y, x + pWid, y + pHei);
	//lua_pushboolean(L, luaL_checknumber(L, 2));
	return 0;
}

static int gpu_draw_rectangle(lua_State *L) {
	lua_Number x = luaL_checknumber(L, 1) / 170.0f - 1.0f;
	lua_Number y = 1.0f - luaL_checknumber(L, 2) / 100.0f;

	lua_Number color = luaL_checknumber(L, 5);

	glColor3f(pallete[(int)color][0] / 255.0f, pallete[(int)color][1] / 255.0f, pallete[(int)color][2] / 255.0f);

	glRectd(x, y, x + pWid * luaL_checknumber(L, 3), y - pHei * luaL_checknumber(L, 4));
	//printf("%f %f %f %f \n", x, y, x + pWid, y + pHei);
	//lua_pushboolean(L, luaL_checknumber(L, 2));
	return 0;
}

static int gpu_clear(lua_State *L) {
	if (lua_gettop(L) > 0) {
		lua_Number color = luaL_checknumber(L, 1);
		glClearColor(pallete[(int)color][0] / 255.0f, pallete[(int)color][1] / 255.0f, pallete[(int)color][2] / 255.0f, 0.0f);
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
	{ "clear", gpu_clear },
	{ "swap", gpu_swap },
	{NULL, NULL}
};

LUALIB_API int luaopen_gpu(lua_State *L) {
	luaL_register(L, RIKO_GPU_NAME, gpuLib);
	lua_pushnumber(L, 340);
	lua_setfield(L, -2, "width");
	lua_pushnumber(L, 200);
	lua_setfield(L, -2, "height");
	return 1;
}