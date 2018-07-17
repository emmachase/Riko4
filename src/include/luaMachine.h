#pragma once

#include "luaIncludes.h"

namespace riko::lua {
    void printLuaError(lua_State *L, int result);
    lua_State* createConfigInstance(const char* filename);
    lua_State *createLuaInstance(const char* filename);
    void shutdownInstance(lua_State *L);
}
