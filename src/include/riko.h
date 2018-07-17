#pragma once

#include "luaIncludes.h"

namespace riko {
    extern bool running;
    extern int exitCode;

    extern bool useBundle;

    extern lua_State *mainThread;
}
