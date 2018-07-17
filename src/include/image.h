#pragma once

#define RIKO_IMAGE_NAME "image"

#include "luaIncludes.h"

namespace riko::image {
    LUALIB_API int openLua(lua_State *L);
}
