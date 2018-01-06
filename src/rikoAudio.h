#pragma once

#define _LUALIB_H
#define RIKO_AUD_NAME "speaker"

#include "luaIncludes.h"

LUALIB_API int luaopen_aud(lua_State *L);
void closeAudio();