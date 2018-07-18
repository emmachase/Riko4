#include "luaIncludes.h"

#include "ResponseHandle.h"

namespace riko::net {
    ResponseHandle::ResponseHandle(std::stringstream *stream) {
        this->stream = stream;
    }

    ResponseHandle **ResponseHandle::constructUserdata(lua_State *L) {
        auto **handle = (ResponseHandle **)lua_newuserdata(L, sizeof(ResponseHandle *));

        luaL_getmetatable(L, "Riko.Net.ResponseHandle");
        lua_setmetatable(L, -2);

        *handle = this;
        return handle;
    }

    std::string ResponseHandle::readAll() {
        return stream->str();
    }



    static ResponseHandle *checkUData (lua_State *L) {
        void *ud = luaL_checkudata(L, 1, "Riko.Net.ResponseHandle");
        luaL_argcheck(L, ud != nullptr, 1, "`ResponseHandle' expected");
        return *(ResponseHandle **)ud;
    }

    static int luaReadAll(lua_State *L) {
        ResponseHandle *handle = checkUData(L);
        std::string str = handle->readAll();
        lua_pushlstring(L, str.c_str(), str.length());

        return 1;
    }

    static int luaClose(lua_State *L) {
        ResponseHandle *handle = checkUData(L);

        delete handle->stream;
        delete handle;

        return 0;
    }

    static const luaL_Reg luaBinding[] = {
            {"readAll", luaReadAll},
            {nullptr, nullptr}
    };

    void ResponseHandle::initMetatable(lua_State *L) {
        luaL_newmetatable(L, "Riko.Net.ResponseHandle");

        lua_pushstring(L, "__index");
        lua_pushvalue(L, -2);  /* pushes the metatable */
        lua_settable(L, -3);  /* metatable.__index = metatable */
        lua_pushstring(L, "__gc");
        lua_pushcfunction(L, luaClose);
        lua_settable(L, -3);

        luaL_openlib(L, nullptr, luaBinding, 0);
    }
}
