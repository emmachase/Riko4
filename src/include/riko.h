#pragma once

#include "SDL_gpu/SDL_gpu.h"

#include "luaIncludes.h"

namespace riko {
    extern bool running;
    extern int exitCode;

    extern bool useBundle;

    extern lua_State *mainThread;
    extern SDL_Window *window;
}
