#pragma once

#define _LUALIB_H
#define RIKO_IMAGE_NAME "image"

#include <LuaJIT/lua.hpp>

typedef GLuint texture;

LUALIB_API int luaopen_image(lua_State *L);