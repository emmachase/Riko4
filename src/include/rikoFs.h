#pragma once

#define _LUALIB_H
#define RIKO_FS_NAME "fs"

#include "luaIncludes.h"

namespace riko::fs {
    LUALIB_API int openLua(lua_State *L);
}
