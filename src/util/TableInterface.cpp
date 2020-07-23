#include <utility>

#include "TableInterface.h"

TableInterface::TableInterface(lua_State *state, int arg) : state(state), arg(arg), offset(lua_gettop(state)) {
    if (offset < arg) {
        throw LuaError("expected table as argument " + std::to_string(arg) + ", got nil",
                       LuaError::Type::NIL_ARG);
    }

    offset -= (arg - 1);

    int type = lua_type(state, -offset);
    if (type != LUA_TTABLE) {
        throw LuaError("expected table as argument " + std::to_string(arg) + ", got " + lua_typename(state, type),
                       type == LUA_TNIL ? LuaError::Type::NIL_ARG : LuaError::Type::BAD_TYPE);
    }
}

void TableInterface::throwError(std::string desc) {
    if (desc.empty()) {
        throw LuaError("bad element '" + lastKey + "' of argument " + std::to_string(arg));
    } else {
        throw LuaError("bad element '" + lastKey + "' of argument " + std::to_string(arg) + " (" + desc + ")");
    }
}

void TableInterface::popToStack(std::string key) {
    lua_pushstring(state, key.c_str());
    lua_gettable(state, -(++offset));
    lastKey = key;
}

void TableInterface::popToStack(int key) {
    lua_pushinteger(state, key);
    lua_gettable(state, -(++offset));
    lastKey = std::to_string(key);
    lastArrayIndex = key;
}

double TableInterface::getNumber(std::string key) {
    popToStack(key);

    double value;
    if (lua_isnil(state, -1)) {
        throw LuaError("expected number for element '" + key + "' of argument " + std::to_string(arg) + ", got nil",
                       LuaError::Type::NIL_ARG);
    } else {
        int type = lua_type(state, -1);

        if (type == LUA_TNUMBER) {
            value = lua_tonumber(state, -1);
        } else {
            throw LuaError("expected number for element '" + key + "' of argument " + std::to_string(arg) + ", got " +
                           lua_typename(state, type), LuaError::Type::BAD_TYPE);
        }
    }

    return value;
}

double TableInterface::getNumber(std::string key, double defaultValue) {
    try {
        return getNumber(std::move(key));
    } catch (const LuaError &e) {
        if (e.getErrorType() == LuaError::Type::NIL_ARG)
            return defaultValue;
        else
            throw e;
    }
}

int TableInterface::getInteger(std::string key) {
    popToStack(key);

    int value;
    if (lua_isnil(state, -1)) {
        throw LuaError("expected number for element '" + key + "' of argument " + std::to_string(arg) + ", got nil",
                       LuaError::Type::NIL_ARG);
    } else {
        int type = lua_type(state, -1);

        if (type == LUA_TNUMBER) {
            value = static_cast<int>(lua_tointeger(state, -1));
        } else {
            throw LuaError("expected number for element '" + key + "' of argument " + std::to_string(arg) + ", got " +
                           lua_typename(state, type), LuaError::Type::BAD_TYPE);
        }
    }

    return value;
}

int TableInterface::getInteger(std::string key, int defaultValue) {
    try {
        return getInteger(std::move(key));
    } catch (const LuaError &e) {
        if (e.getErrorType() == LuaError::Type::NIL_ARG)
            return defaultValue;
        else
            throw e;
    }
}

bool TableInterface::getBoolean(std::string key) {
    popToStack(key);

    bool value;
    if (lua_isnil(state, -1)) {
        throw LuaError("expected boolean for element '" + key + "' of argument " + std::to_string(arg) + ", got nil",
                       LuaError::Type::NIL_ARG);
    } else {
        int type = lua_type(state, -1);

        if (type == LUA_TBOOLEAN) {
            value = static_cast<bool>(lua_toboolean(state, -1));
        } else {
            throw LuaError("expected boolean for element '" + key + "' of argument " + std::to_string(arg) + ", got " +
                           lua_typename(state, type), LuaError::Type::BAD_TYPE);
        }
    }

    return value;
}

bool TableInterface::getBoolean(std::string key, bool defaultValue) {
    try {
        return getBoolean(std::move(key));
    } catch (const LuaError &e) {
        if (e.getErrorType() == LuaError::Type::NIL_ARG)
            return defaultValue;
        else
            throw e;
    }
}

std::string TableInterface::getString(std::string key) {
    popToStack(key);

    std::string value;
    if (lua_isnil(state, -1)) {
        throw LuaError("expected string for element '" + key + "' of argument " + std::to_string(arg) + ", got nil",
                       LuaError::Type::NIL_ARG);
    } else {
        int type = lua_type(state, -1);

        if (type == LUA_TSTRING) {
            value = std::string(lua_tostring(state, -1));
        } else {
            throw LuaError("expected string for element '" + key + "' of argument " + std::to_string(arg) + ", got " +
                           lua_typename(state, type), LuaError::Type::BAD_TYPE);
        }
    }

    return value;
}

std::string TableInterface::getString(std::string key, std::string defaultValue) {
    try {
        return getString(std::move(key));
    } catch (const LuaError &e) {
        if (e.getErrorType() == LuaError::Type::NIL_ARG)
            return defaultValue;
        else
            throw e;
    }
}

size_t TableInterface::getSize() {
    return lua_objlen(state, -offset);
}

double TableInterface::getNextNumber() {
    popToStack(lastArrayIndex + 1);

    double value;
    if (lua_isnil(state, -1)) {
        throw LuaError("expected number for element '" + std::to_string(lastArrayIndex) + "' of argument " +
                       std::to_string(arg) + ", got nil", LuaError::Type::NIL_ARG);
    } else {
        int type = lua_type(state, -1);

        if (type == LUA_TNUMBER) {
            value = lua_tonumber(state, -1);
        } else {
            throw LuaError("expected number for element '" + std::to_string(lastArrayIndex) + "' of argument " +
                           std::to_string(arg) + ", got " + lua_typename(state, type), LuaError::Type::BAD_TYPE);
        }
    }

    return value;
}

int TableInterface::getNextInteger() {
    popToStack(lastArrayIndex + 1);

    int value;
    if (lua_isnil(state, -1)) {
        throw LuaError("expected number for element '" + std::to_string(lastArrayIndex) + "' of argument " +
                       std::to_string(arg) + ", got nil", LuaError::Type::NIL_ARG);
    } else {
        int type = lua_type(state, -1);

        if (type == LUA_TNUMBER) {
            value = static_cast<int>(lua_tointeger(state, -1));
        } else {
            throw LuaError("expected number for element '" + std::to_string(lastArrayIndex) + "' of argument " +
                           std::to_string(arg) + ", got " + lua_typename(state, type), LuaError::Type::BAD_TYPE);
        }
    }

    return value;
}

bool TableInterface::getNextBoolean() {
    popToStack(lastArrayIndex + 1);

    bool value;
    if (lua_isnil(state, -1)) {
        throw LuaError("expected boolean for element '" + std::to_string(lastArrayIndex) + "' of argument " +
                       std::to_string(arg) + ", got nil", LuaError::Type::NIL_ARG);
    } else {
        int type = lua_type(state, -1);

        if (type == LUA_TBOOLEAN) {
            value = static_cast<bool>(lua_toboolean(state, -1));
        } else {
            throw LuaError("expected boolean for element '" + std::to_string(lastArrayIndex) + "' of argument " +
                           std::to_string(arg) + ", got " + lua_typename(state, type), LuaError::Type::BAD_TYPE);
        }
    }

    return value;
}

std::string TableInterface::getNextString() {
    popToStack(lastArrayIndex + 1);

    std::string value;
    if (lua_isnil(state, -1)) {
        throw LuaError("expected string for element '" + std::to_string(lastArrayIndex) + "' of argument " +
                       std::to_string(arg) + ", got nil", LuaError::Type::NIL_ARG);
    } else {
        int type = lua_type(state, -1);

        if (type == LUA_TSTRING) {
            value = std::string(lua_tostring(state, -1));
        } else {
            throw LuaError("expected string for element '" + std::to_string(lastArrayIndex) + "' of argument " +
                           std::to_string(arg) + ", got " + lua_typename(state, type), LuaError::Type::BAD_TYPE);
        }
    }

    return value;
}
