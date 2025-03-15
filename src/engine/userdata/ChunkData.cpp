#include "ChunkData.h"

namespace riko::net {
    ChunkData::ChunkData(const std::string &data) : data(data) {}

    ChunkData::~ChunkData() = default;

    ChunkData **ChunkData::constructUserdata(lua_State *L) {
        ChunkData **udata = (ChunkData **)lua_newuserdata(L, sizeof(ChunkData *));
        *udata = this;
        luaL_getmetatable(L, "riko.net.ChunkData");
        lua_setmetatable(L, -2);
        return udata;
    }

    std::string ChunkData::getData() {
        return data;
    }

    size_t ChunkData::getSize() {
        return data.size();
    }

    static int chunkData_getData(lua_State *L) {
        ChunkData **udata = (ChunkData **)luaL_checkudata(L, 1, "riko.net.ChunkData");
        std::string data = (*udata)->getData();
        lua_pushlstring(L, data.c_str(), data.length());
        return 1;
    }

    static int chunkData_getSize(lua_State *L) {
        ChunkData **udata = (ChunkData **)luaL_checkudata(L, 1, "riko.net.ChunkData");
        lua_pushinteger(L, (*udata)->getSize());
        return 1;
    }

    static int chunkData_gc(lua_State *L) {
        ChunkData **udata = (ChunkData **)luaL_checkudata(L, 1, "riko.net.ChunkData");
        delete *udata;
        return 0;
    }

    static const luaL_Reg chunkDataLib[] = {
        {"getData", chunkData_getData},
        {"getSize", chunkData_getSize},
        {nullptr, nullptr}};

    static const luaL_Reg chunkDataLib_meta[] = {
        {"__gc", chunkData_gc},
        {nullptr, nullptr}};

    void ChunkData::initMetatable(lua_State *L) {
        luaL_newmetatable(L, "riko.net.ChunkData");
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_register(L, nullptr, chunkDataLib_meta);
        luaL_register(L, nullptr, chunkDataLib);
        lua_pop(L, 1);
    }
}  // namespace riko::net