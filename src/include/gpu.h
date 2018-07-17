#pragma once

#define RIKO_GPU_NAME "gpu"

#include "SDL_gpu/SDL_gpu.h"

#include "luaIncludes.h"

namespace riko::gfx {
    extern bool shaderOn;
    extern int pixelScale;

    extern GPU_Target *renderer;
    extern GPU_Target *bufferTarget;
    extern GPU_Image *buffer;
}

namespace riko::gpu {
    LUALIB_API int openLua(lua_State *L);
}
