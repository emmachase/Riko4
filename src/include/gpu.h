#pragma once

#define RIKO_GPU_NAME "gpu"

#include "luaIncludes.h"

namespace riko::gpu {
    LUALIB_API int openLua(lua_State *L);
}
