#pragma once

#include <string>
#include "misc/luaIncludes.h"

namespace riko::net {
    class ChunkData {
       public:
        explicit ChunkData(const std::string &data);
        ~ChunkData();

        static void initMetatable(lua_State *L);

        ChunkData **constructUserdata(lua_State *L);
        std::string getData();
        size_t getSize();

        std::string data;
    };
}  // namespace riko::net