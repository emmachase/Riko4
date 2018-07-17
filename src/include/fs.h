#pragma once

#define RIKO_FS_NAME "fs"

#include "luaIncludes.h"

namespace riko::fs {
    extern char* appPath;
    extern char* scriptsPath;

    LUALIB_API int openLua(lua_State *L);
}
