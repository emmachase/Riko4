#define LUA_LIB

#include <rikoGPU.h>

#include <LuaJIT\lua.hpp>
#include <LuaJIT\lauxlib.h>
#include <GL/glew.h>
#include <SDL2/SDL.h>

extern SDL_Window *window;

static float pWid = 1 / 170.0f;
static float pHei = 1 / 100.0f;

static unsigned char palette[16][3] = {
	{24, 24, 24},
	{100, 100, 100},
	{0, 18, 144},
	{0, 39, 251},
	{0, 143, 21},
	{0, 249, 44},
	{0, 144, 146},
	{0, 252, 254},
	{155, 23, 8},
	{255, 48, 22},
	{154, 32, 145},
	{255, 63, 252},
	{148, 145, 25},
	{255, 253, 51},
	{184, 184, 184},
	{235, 235, 235},

	/*{ 24, 24, 24 },     // Black
	{ 85, 85, 85 },     // Dark Gray
	{ 170, 170, 170 },  // Light Gray
	{ 239, 239, 239 },  // White
	{ 127, 72, 5 },     // Brown
	{ 230, 10, 10 },    // Red
	{ 245, 106, 10 },   // Orange
	{ 255, 255, 0 },    // Yellow
	{ 0, 255, 33 },     // Lime Green
	{ 87, 165, 77 },    // Dark Green
	{ 0, 147, 141 },    // Cyan
	{ 10, 142, 255 },   // Light Blue
	{ 0, 38, 255 },     // Blue
	{ 178, 0, 255 },    // Magenta
	{ 255, 0, 110 },    // Pink
	{ 255, 102, 107}    // Light Redish idk lol salmon maybe?*/
};

static int gpu_draw_pixel(lua_State *L) {
	lua_Number x = ((int)luaL_checknumber(L, 1)) / 170.0f - 1.0f;
	lua_Number y = 1.0f - ((int)luaL_checknumber(L, 2)) / 100.0f;

	lua_Number color = ((int)luaL_checknumber(L, 3));

	glColor3f(palette[(int) color][0] / 255.0f, palette[(int) color][1] / 255.0f, palette[(int) color][2] / 255.0f);

	glRectd(x, y, x + pWid, y - pHei);
	//printf("%f %f %f %f \n", x, y, x + pWid, y + pHei);
	//lua_pushboolean(L, luaL_checknumber(L, 2));
	return 0;
}

static int gpu_draw_rectangle(lua_State *L) {
	lua_Number x = ((int)luaL_checknumber(L, 1)) / 170.0f - 1.0f;
	lua_Number y = 1.0f - ((int)luaL_checknumber(L, 2)) / 100.0f;

	lua_Number color = ((int)luaL_checknumber(L, 5));

	glColor3f(palette[(int)color][0] / 255.0f, palette[(int)color][1] / 255.0f, palette[(int)color][2] / 255.0f);

	glRectd(x, y, x + pWid * ((int)luaL_checknumber(L, 3)), y - pHei * ((int)luaL_checknumber(L, 4)));
	//printf("%f %f %f %f \n", x, y, x + pWid, y + pHei);
	//lua_pushboolean(L, luaL_checknumber(L, 2));
	return 0;
}

static int gpu_blit_pixels(lua_State *L) {
	lua_Number x = ((int)luaL_checknumber(L, 1)) / 170.0f - 1.0f;
	lua_Number y = 1.0f - ((int)luaL_checknumber(L, 2)) / 100.0f;
	lua_Number w = ((int)luaL_checknumber(L, 3));
	lua_Number h = ((int)luaL_checknumber(L, 4));

	int amt = lua_objlen(L, -1);
	int len = (int)w*(int)h;
	if (amt < len) {
		luaL_error(L, "blitPixels expected %d pixels, got %d", len, amt);
		return 0;
	}
		//printf("%d\n", lua_objlen(L, -1));



	for (int i = 1; i <= len; i++) {
		lua_pushnumber(L, i);
		lua_gettable(L, -2);
		if (!lua_isnumber(L, -1)) {
			luaL_error(L, "Index %d is non-numeric", i);
		}
		int color = lua_tonumber(L, -1);

		float xp = ((i - 1) % (int) w) * pWid;
		float yp = ((int)((i - 1) / (int) w)) * pHei;
		
		glColor3f(palette[color][0] / 255.0f, palette[color][1] / 255.0f, palette[color][2] / 255.0f);

		glRectd(x + xp, y - yp, x + xp + pWid, y - yp - pHei);

		lua_pop(L, 1);
	}

	return 0;
}

static int gpu_clear(lua_State *L) {
	if (lua_gettop(L) > 0) {
		lua_Number color = luaL_checknumber(L, 1);
		glClearColor(palette[(int)color][0] / 255.0f, palette[(int)color][1] / 255.0f, palette[(int)color][2] / 255.0f, 0.0f);
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
	luaL_register(L, RIKO_GPU_NAME, gpuLib);
	lua_pushnumber(L, 340);
	lua_setfield(L, -2, "width");
	lua_pushnumber(L, 200);
	lua_setfield(L, -2, "height");
	return 1;
}