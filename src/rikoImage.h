#pragma once

#define _LUALIB_H
#define RIKO_IMAGE_NAME "image"

#include "luaIncludes.h"

LUALIB_API int luaopen_image(lua_State *L);