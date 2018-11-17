#pragma once

#include <sstream>

#include "misc/luaIncludes.h"

namespace riko::net {
    class ResponseHandle {
    public:
        explicit ResponseHandle(std::stringstream *stream);

        static void initMetatable(lua_State *L);

        ResponseHandle **constructUserdata(lua_State *L);
        std::string readAll();

        std::stringstream *stream;
    };
}
