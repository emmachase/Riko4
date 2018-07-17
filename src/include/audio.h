#pragma once

#define RIKO_AUD_NAME "speaker"

#include "luaIncludes.h"

namespace riko::audio {
    extern bool audioEnabled;

    LUALIB_API int openLua(lua_State *L);
    void closeAudio();
}
