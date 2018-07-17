#pragma once

#ifdef __EMSCRIPTEN__
#  include "Lua/lua.h"
#  include "Lua/lauxlib.h"
#else
#  include <LuaJIT/lua.hpp>
#  include <LuaJIT/lauxlib.h>
#endif
