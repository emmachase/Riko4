#pragma once

#define RIKO_AUD_NAME "speaker"

#include "misc/luaIncludes.h"

namespace riko::audio {
    extern bool audioEnabled;

    int openLua(lua_State *L);
    void closeAudio();
}
