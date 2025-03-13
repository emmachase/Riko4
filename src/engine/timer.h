#pragma once

#include "misc/luaIncludes.h"

namespace riko::timer {
    // Initialize the timer system
    int init();

    // Clean up the timer system
    void cleanup();

    // Open the timer functionality to Lua
    int openLua(lua_State *L);
}  // namespace riko::timer