#ifndef RIKO4_TABLEINTERFACE_H
#define RIKO4_TABLEINTERFACE_H


#include "luaIncludes.h"

#include "LuaError.h"

class TableInterface {
private:
    lua_State *state;
    int offset;
    int arg;

    std::string lastKey = "unknown";

    void popToStack(std::string key);

public:
    TableInterface(lua_State *state, int arg);

    void throwError(std::string desc = "");

    double getNumber(std::string key);
    double getNumber(std::string key, double defaultValue);

    int getInteger(std::string key);
    int getInteger(std::string key, int defaultValue);
};


#endif //RIKO4_TABLEINTERFACE_H
