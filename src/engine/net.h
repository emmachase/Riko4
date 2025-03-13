#pragma once

#define MAX_CONCURRENT 6
#define RIKO_NET_NAME "net"

namespace riko::net {
    int init();
    void cleanup();

    int openLua(lua_State *L);
}  // namespace riko::net
