#pragma once

#define RIKO_FS_NAME "fs"

#include "misc/luaIncludes.h"

#ifdef __WINDOWS__
#  define getFullPath(a, b) GetFullPathName(a, MAX_PATH, b, NULL)
#  define rmdir(a) _rmdir(a)
#else
#  define getFullPath(a, b) realpath(a, b)
#endif

namespace riko::fs {
    extern char* appPath;
    extern char* scriptsPath;

    LUALIB_API int openLua(lua_State *L);
}
