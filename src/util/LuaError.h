#ifndef RIKO4_LUAERROR_H
#define RIKO4_LUAERROR_H

#include <string>
#include <utility>
#include <stdexcept>

class LuaError : public std::runtime_error {
   public:
    enum class Type { GENERIC,
                      NIL_ARG,
                      BAD_TYPE };

   private:
    Type errorType = Type::GENERIC;

   public:
    explicit LuaError(const std::string &error) : runtime_error(error) {}
    LuaError(const std::string &error, Type errorType) : runtime_error(error), errorType(errorType) {}

    Type getErrorType() const {
        return errorType;
    }
};

#endif  // RIKO4_LUAERROR_H
