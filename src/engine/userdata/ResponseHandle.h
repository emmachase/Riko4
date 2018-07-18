#pragma once

#include <sstream>

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
