#pragma once

#define _LUALIB_H
#define RIKO_GPU_NAME "gpu"

#include "luaIncludes.h"

LUALIB_API int luaopen_gpu(lua_State *L);