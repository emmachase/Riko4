#pragma once

#define _LUALIB_H
#define RIKO_FS_NAME "fs"

#include "luaIncludes.h"

LUALIB_API int luaopen_fs(lua_State *L);