#pragma once

#define _LUALIB_H
#define RIKO_FS_NAME "fs"

#include <LuaJIT/lua.hpp>

LUALIB_API int luaopen_fs(lua_State *L);