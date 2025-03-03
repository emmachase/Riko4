#pragma once

#define RIKO_GPU_NAME "gpu"

#include "SDL2/SDL_gpu.h"

#include "misc/luaIncludes.h"

namespace riko::gfx {
    extern bool shaderOn;
    extern int setPixelScale;
    extern int pixelScale;

    extern GPU_Target *renderer;
    extern GPU_Target *bufferTarget;
    extern GPU_Image *buffer;

    extern int windowWidth;
    extern int windowHeight;
    extern int drawX;
    extern int drawY;

    extern int lastWindowX;
    extern int lastWindowY;

    void assessWindow();
}

namespace riko::gpu {
    int openLua(lua_State *L);
}
