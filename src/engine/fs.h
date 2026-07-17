#pragma once

#define RIKO_FS_NAME "fs"

#include "misc/luaIncludes.h"

#ifdef __WINDOWS__
#define getFullPath(a, b) GetFullPathName(a, MAX_PATH, b, NULL)
#define rmdir(a) _rmdir(a)
#define PATH_SEPARATOR '\\'
#else
#define getFullPath(a, b) realpath(a, b)
#define PATH_SEPARATOR '/'
#endif

namespace riko::fs {
    extern char* appPath;
    extern char* scriptsPath;

    // Resolves a virtual Lua path to a real host OS path.
    // Returns true on success (out filled), false if the path escapes the sandbox.
    bool checkPath(const char *luaInput, char *out, size_t outSize);

    int openLua(lua_State* L);
}  // namespace riko::fs
