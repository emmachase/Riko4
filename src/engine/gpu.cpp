#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
#ifndef CALLBACK
#  if defined(_ARM_)
#    define CALLBACK
#  else
#    define CALLBACK __stdcall
#  endif
#endif

#include <cstdint>
#include <cstdlib>

#include "SDL_gpu/SDL_gpu.h"

#include "misc/consts.h"
#include "misc/luaIncludes.h"
#include "riko.h"
#include "core/shader.h"

#include "gpu.h"

namespace riko::gfx {
    bool shaderOn = false;

    int pixelScale = DEFAULT_SCALE;
    int setPixelScale = DEFAULT_SCALE;

    GPU_Image *buffer;
    GPU_Target *renderer;
    GPU_Target *bufferTarget;

    Uint8 palette[COLOR_LIMIT][3] = INIT_COLORS;

    int paletteNum = 0;

    int drawOffX = 0;
    int drawOffY = 0;
    int drawScale = 1;

    int windowWidth;
    int windowHeight;
    int drawX = 0;
    int drawY = 0;

    int lastWindowX = 0;
    int lastWindowY = 0;

    void assessWindow() {
        int winW = 0;
        int winH = 0;
        SDL_GetWindowSize(riko::window, &winW, &winH);

        int candidateOne = winH / SCRN_HEIGHT;
        int candidateTwo = winW / SCRN_WIDTH;

        if (winW != 0 && winH != 0) {
            pixelScale = (candidateOne > candidateTwo) ? candidateTwo : candidateOne;
            windowWidth = winW;
            windowHeight = winH;

            drawX = (windowWidth - pixelScale*SCRN_WIDTH) / 2;
            drawY = (windowHeight - pixelScale*SCRN_HEIGHT) / 2;

            GPU_SetWindowResolution(winW, winH);
        }
    }
}

#define off(o, t) (float)(riko::gfx::drawScale*((o) - riko::gfx::drawOffX)), (float)(riko::gfx::drawScale*((t) - riko::gfx::drawOffY))

namespace riko::gpu {
    static int getColor(lua_State *L, int arg) {
        int color = luaL_checkint(L, arg) - 1;
        return color < 0 ? 0 : (color > (COLOR_LIMIT - 1) ? (COLOR_LIMIT - 1) : color);
    }

    static int gpu_draw_pixel(lua_State *L) {
        int x = luaL_checkint(L, 1);
        int y = luaL_checkint(L, 2);

        int color = getColor(L, 3);

        SDL_Color colorS = {riko::gfx::palette[color][0], riko::gfx::palette[color][1], riko::gfx::palette[color][2],
                            255};

        GPU_RectangleFilled(riko::gfx::bufferTarget, off(x, y), off(x + 1, y + 1), colorS);

        return 0;
    }

    static int gpu_draw_rectangle(lua_State *L) {
        int color = getColor(L, 5);

        int x = luaL_checkint(L, 1);
        int y = luaL_checkint(L, 2);

        GPU_Rect rect = {
                off(x, y),
                (float) luaL_checkint(L, 3),
                (float) luaL_checkint(L, 4)
        };

        SDL_Color colorS = {riko::gfx::palette[color][0], riko::gfx::palette[color][1], riko::gfx::palette[color][2],
                            255};
        GPU_RectangleFilled2(riko::gfx::bufferTarget, rect, colorS);

        return 0;
    }

    static int gpu_blit_pixels(lua_State *L) {
        int x = luaL_checkint(L, 1);
        int y = luaL_checkint(L, 2);
        int w = luaL_checkint(L, 3);
        int h = luaL_checkint(L, 4);

        unsigned long long amt = lua_objlen(L, -1);
        int len = w * h;
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
            int color = (int) lua_tointeger(L, -1) - 1;
            if (color == -1) {
                lua_pop(L, 1);
                continue;
            }

            color = color < 0 ? 0 : (color > (COLOR_LIMIT - 1) ? (COLOR_LIMIT - 1) : color);

            int xp = (i - 1) % w;
            int yp = (i - 1) / w;

            GPU_Rect rect = {
                    off(x + xp,
                        y + yp),
                    1, 1
            };

            SDL_Color colorS = {riko::gfx::palette[color][0], riko::gfx::palette[color][1],
                                riko::gfx::palette[color][2], 255};
            GPU_RectangleFilled2(riko::gfx::bufferTarget, rect, colorS);

            lua_pop(L, 1);
        }

        return 0;
    }

    static int gpu_set_clipping(lua_State *L) {
        if (lua_gettop(L) == 0) {
            GPU_SetClip(riko::gfx::buffer->target, 0, 0, riko::gfx::buffer->w, riko::gfx::buffer->h);
            return 0;
        }

        auto x = static_cast<Sint16>luaL_checkint(L, 1);
        auto y = static_cast<Sint16>luaL_checkint(L, 2);
        auto w = static_cast<Uint16>luaL_checkint(L, 3);
        auto h = static_cast<Uint16>luaL_checkint(L, 4);

        GPU_SetClip(riko::gfx::buffer->target, x, y, w, h);

        return 0;
    }

    static int gpu_set_palette_color(lua_State *L) {
        int slot = getColor(L, 1) - 1;
	if (slot < 0 || slot >= COLOR_LIMIT) return 0;

        auto r = static_cast<Uint8>luaL_checkint(L, 2);
        auto g = static_cast<Uint8>luaL_checkint(L, 3);
        auto b = static_cast<Uint8>luaL_checkint(L, 4);

        riko::gfx::palette[slot][0] = r;
        riko::gfx::palette[slot][1] = g;
        riko::gfx::palette[slot][2] = b;
        riko::gfx::paletteNum++;

        return 0;
    }

    static int gpu_blit_palette(lua_State *L) {
        auto amt = (char) lua_objlen(L, -1);
        if (amt < 1) {
            return 0;
        }

        amt = static_cast<char>(amt > COLOR_LIMIT ? COLOR_LIMIT : amt);

        for (int i = 1; i <= amt; i++) {
            lua_pushnumber(L, i);
            lua_gettable(L, -2);

            if (lua_type(L, -1) == LUA_TNUMBER) {
                lua_pop(L, 1);
                continue;
            }

            lua_pushnumber(L, 1);
            lua_gettable(L, -2);
            riko::gfx::palette[i - 1][0] = static_cast<Uint8>luaL_checkint(L, -1);

            lua_pushnumber(L, 2);
            lua_gettable(L, -3);
            riko::gfx::palette[i - 1][1] = static_cast<Uint8>luaL_checkint(L, -1);

            lua_pushnumber(L, 3);
            lua_gettable(L, -4);
            riko::gfx::palette[i - 1][2] = static_cast<Uint8>luaL_checkint(L, -1);

            lua_pop(L, 4);
        }

        riko::gfx::paletteNum++;

        return 0;
    }

    static int gpu_get_palette(lua_State *L) {
        lua_newtable(L);

        for (int i = 0; i < COLOR_LIMIT; i++) {
            lua_pushinteger(L, i + 1);
            lua_newtable(L);
            for (int j = 0; j < 3; j++) {
                lua_pushinteger(L, j + 1);
                lua_pushinteger(L, riko::gfx::palette[i][j]);
                lua_rawset(L, -3);
            }
            lua_rawset(L, -3);
        }

        return 1;
    }

    static int gpu_get_pixel(lua_State *L) {
        auto x = static_cast<Sint16>luaL_checkint(L, 1);
        auto y = static_cast<Sint16>luaL_checkint(L, 2);
        SDL_Color col = GPU_GetPixel(riko::gfx::buffer->target, x, y);
        for (int i = 0; i < COLOR_LIMIT; i++) {
            Uint8 *pCol = riko::gfx::palette[i];
            if (col.r == pCol[0] && col.g == pCol[1] && col.b == pCol[2]) {
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
            SDL_Color colorS = {riko::gfx::palette[color][0], riko::gfx::palette[color][1],
                                riko::gfx::palette[color][2], 255};
            GPU_ClearColor(riko::gfx::bufferTarget, colorS);
        } else {
            SDL_Color colorS = {riko::gfx::palette[0][0], riko::gfx::palette[0][1], riko::gfx::palette[0][2], 255};
            GPU_ClearColor(riko::gfx::bufferTarget, colorS);
        }

        return 0;
    }

    struct TransformEntry {
        int offsetX; int offsetY;
        int scale;
    };

    TransformEntry *translateStack;
    int tStackUsed = 0;
    int tStackSize = 32;

    static int gpu_translate(lua_State *L) {
        riko::gfx::drawOffX -= luaL_checkint(L, -2);
        riko::gfx::drawOffY -= luaL_checkint(L, -1);

        return 0;
    }

    // int zoomOffsetX = 0;
    // int zoomOffsetY = 0;
    // static int gpu_set_zoom(lua_State *L) {
    //     auto scale = static_cast<Sint16>luaL_checkint(L, 1);
    //     auto originX = static_cast<Sint16>luaL_checkint(L, 2);
    //     auto originY = static_cast<Sint16>luaL_checkint(L, 3);

    //     if (scale < 1) scale = 1;

    //     int offsetX = originX * scale;
    //     int offsetY = originY * scale;

    //     riko::gfx::drawOffX += offsetX - zoomOffsetX;
    //     riko::gfx::drawOffY += offsetY - zoomOffsetY;
    //     riko::gfx::drawScale = scale;

    //     zoomOffsetX = offsetX;
    //     zoomOffsetY = offsetY;

    //     return 0;
    // }

    static int gpu_push(lua_State *L) {
        if (tStackUsed == tStackSize) {
            tStackSize *= 2;
            translateStack = (TransformEntry *) realloc(translateStack, tStackSize * sizeof(TransformEntry));
        }

        TransformEntry entry;
        entry.offsetX = riko::gfx::drawOffX;
        entry.offsetY = riko::gfx::drawOffY;
        entry.scale = riko::gfx::drawScale;
        translateStack[tStackUsed] = entry;

        tStackUsed += 1;

        return 0;
    }

    static int gpu_pop(lua_State *L) {
        if (tStackUsed > 0) {
            tStackUsed -= 1;

            TransformEntry &entry = translateStack[tStackUsed];
            riko::gfx::drawOffX = entry.offsetX;
            riko::gfx::drawOffY = entry.offsetY;
            riko::gfx::drawScale = entry.scale;

            lua_pushboolean(L, true);
            lua_pushinteger(L, tStackUsed);
            return 2;
        } else {
            lua_pushboolean(L, false);
            return 1;
        }
    }

    static int gpu_set_fullscreen(lua_State *L) {
        auto fsc = static_cast<bool>(lua_toboolean(L, 1));
        if (!GPU_SetFullscreen(fsc, true)) {
            riko::gfx::pixelScale = riko::gfx::setPixelScale;
            GPU_SetWindowResolution(
                riko::gfx::pixelScale * SCRN_WIDTH,
                riko::gfx::pixelScale * SCRN_HEIGHT);

            SDL_SetWindowPosition(riko::window, riko::gfx::lastWindowX, riko::gfx::lastWindowY);
        }

        riko::gfx::assessWindow();

        return 0;
    }

    static int gpu_swap(lua_State *L) {
        SDL_Color colorS = {riko::gfx::palette[0][0], riko::gfx::palette[0][1], riko::gfx::palette[0][2], 255};
        GPU_ClearColor(riko::gfx::renderer, colorS);

        riko::shader::updateShader();

        GPU_BlitScale(riko::gfx::buffer, nullptr, riko::gfx::renderer,
            riko::gfx::windowWidth / 2, riko::gfx::windowHeight / 2,
            riko::gfx::pixelScale, riko::gfx::pixelScale);

        GPU_Flip(riko::gfx::renderer);

        GPU_DeactivateShaderProgram();

        return 0;
    }

    static const luaL_Reg gpuLib[] = {
            {"setPaletteColor", gpu_set_palette_color},
            {"blitPalette",     gpu_blit_palette},
            {"getPalette",      gpu_get_palette},
            {"drawPixel",       gpu_draw_pixel},
            {"drawRectangle",   gpu_draw_rectangle},
            {"blitPixels",      gpu_blit_pixels},
            {"translate",       gpu_translate},
            // {"setZoom",         gpu_set_zoom},
            {"push",            gpu_push},
            {"pop",             gpu_pop},
            {"setFullscreen",   gpu_set_fullscreen},
            {"getPixel",        gpu_get_pixel},
            {"clear",           gpu_clear},
            {"swap",            gpu_swap},
            {"clip",            gpu_set_clipping},
            {nullptr,           nullptr}
    };

    LUALIB_API int openLua(lua_State *L) {
        translateStack = new TransformEntry[32];

        luaL_openlib(L, RIKO_GPU_NAME, gpuLib, 0);
        lua_pushnumber(L, SCRN_WIDTH);
        lua_setfield(L, -2, "width");
        lua_pushnumber(L, SCRN_HEIGHT);
        lua_setfield(L, -2, "height");
        return 1;
    }
}

#pragma clang diagnostic pop
