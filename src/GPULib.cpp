#define LUA_LIB

#ifndef CALLBACK
#if defined(_ARM_)
#define CALLBACK
#else
#define CALLBACK __stdcall
#endif
#endif

#include "rikoConsts.h"

#include "rikoGPU.h"
#include "shader.h"

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>
#include <SDL2/SDL.h>
#include <SDL_gpu/SDL_gpu.h>

#include <stdint.h>
#include <stdlib.h>

extern GPU_Target *renderer;
extern GPU_Target *bufferTarget;
extern GPU_Image *buffer;
extern int pixelSize;

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

int paletteNum = 0;

int drawOffX = 0;
int drawOffY = 0;

#define off(o, t) o - drawOffX, t - drawOffY

static int getColor(lua_State *L, int arg) {
    int color = luaL_checkint(L, arg) - 1;
    return color < 0 ? 0 : (color > 15 ? 15 : color);
}

static int gpu_draw_pixel(lua_State *L) {
    int x = luaL_checkint(L, 1);
    int y = luaL_checkint(L, 2);

    int color = getColor(L, 3);

    SDL_Color colorS = {palette[(int)color][0], palette[(int)color][1], palette[(int)color][2], 255};

    GPU_RectangleFilled(bufferTarget, off(x, y), off(x + 1, y + 1), colorS);

    return 0;
}

static int gpu_draw_rectangle(lua_State *L) {
    int color = getColor(L, 5);

    int x = luaL_checkint(L, 1);
    int y = luaL_checkint(L, 2);

    GPU_Rect rect = {
        off(x, y),
        (luaL_checkint(L, 3)),
        (luaL_checkint(L, 4))
    };

    SDL_Color colorS = { palette[(int)color][0], palette[(int)color][1], palette[(int)color][2], 255 };
    GPU_RectangleFilled2(bufferTarget, rect, colorS);

    return 0;
}

static int gpu_blit_pixels(lua_State *L) {
    int x = luaL_checkint(L, 1);
    int y = luaL_checkint(L, 2);
    int w = luaL_checkint(L, 3);
    int h = luaL_checkint(L, 4);

    unsigned long long amt = lua_objlen(L, -1);
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
        int color = (int)lua_tointeger(L, -1) - 1;
        if (color == -1) {
            lua_pop(L, 1);
            continue;
        }

        color = color < 0 ? 0 : (color > 15 ? 15 : color);

        int xp = (i - 1) % (int) w;
        int yp = (int)((i - 1) / (int) w);
        
        GPU_Rect rect = {
            off(x + xp,
                y + yp),
            1, 1
        };

        SDL_Color colorS = { palette[(int)color][0], palette[(int)color][1], palette[(int)color][2], 255 };
        GPU_RectangleFilled2(bufferTarget, rect, colorS);

        lua_pop(L, 1);
    }

    return 0;
}

static int gpu_set_palette_color(lua_State *L) {
    int slot = getColor(L, 1);
    int r = luaL_checkint(L, 2);
    int g = luaL_checkint(L, 3);
    int b = luaL_checkint(L, 4);

    palette[slot][0] = r;
    palette[slot][1] = g;
    palette[slot][2] = b;
    paletteNum++;

    return 0;
}

static int gpu_blit_palette(lua_State *L) {
    char amt = (char) lua_objlen(L, -1);
    if (amt < 1) {
        return 0;
    }

    amt = amt > 16 ? 16 : amt;

    for (int i = 1; i <= amt; i++) {
        lua_pushnumber(L, i);
        lua_gettable(L, -2);

        if (lua_type(L, -1) == LUA_TNUMBER) {
            lua_pop(L, 1);
            continue;
        }

        lua_pushnumber(L, 1);
        lua_gettable(L, -2);
        palette[i - 1][0] = luaL_checkint(L, -1);

        lua_pushnumber(L, 2);
        lua_gettable(L, -3);
        palette[i - 1][1] = luaL_checkint(L, -1);

        lua_pushnumber(L, 3);
        lua_gettable(L, -4);
        palette[i - 1][2] = luaL_checkint(L, -1);

        lua_pop(L, 4);
    }

    paletteNum++;

    return 0;
}

static int gpu_get_palette(lua_State *L) {
    lua_newtable(L);

    for (int i = 0; i < 16; i++) {
        lua_pushinteger(L, i + 1);
        lua_newtable(L);
        for (int j = 0; j < 3; j++) {
            lua_pushinteger(L, j + 1);
            lua_pushinteger(L, palette[i][j]);
            lua_rawset(L, -3);
        }
        lua_rawset(L, -3);
    }

    return 1;
}

static int gpu_get_pixel(lua_State *L) {
    int x = luaL_checkint(L, 1);
    int y = luaL_checkint(L, 2);
    SDL_Color col = GPU_GetPixel(buffer->target, x, y);
    for (int i = 0; i < 16; i++) {
        int* pcol = palette[i];
        if (col.r == pcol[0] && col.g == pcol[1] && col.b == pcol[2]) {
            lua_pushinteger(L, i + 1);
            return 1;
        }
    }

    lua_pushinteger(L, 1); // Should never happen
    return 1;
}

static int gpu_clear(lua_State *L) {
    if (lua_gettop(L) > 0) {
        int color = getColor(L, 1);
        SDL_Color colorS = {palette[(int)color][0], palette[(int)color][1], palette[(int)color][2], 255};
        GPU_ClearColor(bufferTarget, colorS);
    } else {
        SDL_Color colorS = { palette[0][0], palette[0][1], palette[0][2], 255 };
        GPU_ClearColor(bufferTarget, colorS);
    }

    return 0;
}

int* translateStack;
int tStackUsed = 0;
int tStackSize = 32;

static int gpu_translate(lua_State *L) {
    drawOffX -= luaL_checkint(L, -2);
    drawOffY -= luaL_checkint(L, -1);

    return 0;
}

static int gpu_push(lua_State *L) {
    if (tStackUsed == tStackSize) {
        tStackSize *= 2;
        translateStack = (int *)realloc(translateStack, tStackSize * sizeof(int));
    }

    translateStack[tStackUsed]     = drawOffX;
    translateStack[tStackUsed + 1] = drawOffY;

    tStackUsed += 2;

    return 0;
}

static int gpu_pop(lua_State *L) {
    if (tStackUsed > 0) {
        tStackUsed -= 2;

        drawOffX = translateStack[tStackUsed];
        drawOffY = translateStack[tStackUsed + 1];

        lua_pushboolean(L, true);
        return 1;
    } else {
        lua_pushboolean(L, false);
        return 1;
    }
}

static int gpu_set_fullscreen(lua_State *L) {
    bool fsc = lua_toboolean(L, 1);
    GPU_SetFullscreen(fsc, true);

    return 0;
}

static int gpu_swap(lua_State *L) {
    GPU_Clear(renderer);

    updateShader();

    GPU_BlitRect(buffer, NULL, renderer, NULL);

    GPU_Flip(renderer);

    GPU_DeactivateShaderProgram();

    return 0;
}

static const luaL_Reg gpuLib[] = {
    { "setPaletteColor", gpu_set_palette_color },
    { "blitPalette", gpu_blit_palette },
    { "getPalette", gpu_get_palette },
    { "drawPixel", gpu_draw_pixel },
    { "drawRectangle", gpu_draw_rectangle },
    { "blitPixels", gpu_blit_pixels },
    { "translate", gpu_translate },
    { "push", gpu_push },
    { "pop", gpu_pop },
    { "setFullscreen", gpu_set_fullscreen },
    { "getPixel", gpu_get_pixel },
    { "clear", gpu_clear },
    { "swap", gpu_swap },
    {NULL, NULL}
};

LUALIB_API int luaopen_gpu(lua_State *L) {
    translateStack = (int *)malloc(32 * sizeof(int));

    luaL_openlib(L, RIKO_GPU_NAME, gpuLib, 0);
    lua_pushnumber(L, SCRN_WIDTH);
    lua_setfield(L, -2, "width");
    lua_pushnumber(L, SCRN_HEIGHT);
    lua_setfield(L, -2, "height");
    return 1;
}
