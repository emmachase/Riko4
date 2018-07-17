#pragma once

#define _LUALIB_H
#define RIKO_AUD_NAME "speaker"

#include "luaIncludes.h"

namespace riko::audio {
  LUALIB_API int openLua(lua_State *L);
  void closeAudio();
}
