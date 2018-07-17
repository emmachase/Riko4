#pragma once

#define RIKO_FS_NAME "fs"

#include "luaIncludes.h"

namespace riko::fs {
    LUALIB_API int openLua(lua_State *L);
}
