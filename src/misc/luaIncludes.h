#pragma once

#ifdef __EMSCRIPTEN__
extern "C" {
#  include "Lua/lauxlib.h"
#  include "Lua/lua.h"
#  include "Lua/lualib.h"
}
#else
#  include <lua.hpp>
#  include <lauxlib.h>
#endif
