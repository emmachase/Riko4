#pragma once

#include "misc/luaIncludes.h"

namespace riko::lua {
    void printLuaError(lua_State* L, int result);
    lua_State* createConfigInstance(const char* filename);
    lua_State* createLuaInstance(const char* filename, const char* innerFilename);
    void shutdownInstance(lua_State* L);
}  // namespace riko::lua
