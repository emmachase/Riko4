#pragma once

#define RIKO_POLY_NAME "poly"

#include "misc/luaIncludes.h"

namespace riko::poly {
    LUALIB_API int openLua(lua_State *L);
}
