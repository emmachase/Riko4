#include "misc/luaIncludes.h"

#include "poly.h"

#define REPLACE_TABLE_FUNCTION(L, table, name, func) \
    lua_getglobal(L, table); \
    lua_pushstring(L, name); \
    lua_pushcfunction(L, func); \
    lua_settable(L, -3); \
    lua_pop(L, 1)

namespace riko::poly {
    // LuaJIT's debug.traceback implementation is not consistent with PUC Lua's
    // Namely that it isn't possible to pass a nil message as the first argument,
    // as it assumes you wan't to pass a nil thread; causing the stacktrace to be nil.
    static int poly_traceback(lua_State *L) {
        // poly.traceback ( [thread,] message [, level])

        int nArgs = lua_gettop(L);

        lua_State *L1 = L;
        const char *msg = NULL;
        int level = 1;

        
        if (nArgs > 0) {
            int type = lua_type(L, 1);
            if (type == LUA_TSTRING || type == LUA_TNIL) {
                // Assume nil arg 1 means no message

                msg = lua_tostring(L, 1);

                if (nArgs > 1) {
                    level = lua_tointeger(L, 2);
                }
            } else if (type == LUA_TTHREAD) {
                L1 = lua_tothread(L, 1);
                
                if (nArgs > 1) {
                    msg = lua_tostring(L, 2);

                    if (nArgs > 2) {
                        level = lua_tointeger(L, 3);
                    }
                }
            }
        }

        luaL_traceback(L, L1, msg, level);

        return 1;
    }

    int openLua(lua_State *L) {
        REPLACE_TABLE_FUNCTION(L, "debug", "traceback", poly_traceback);

        return 1;
    }
}
