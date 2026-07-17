#pragma once
// luagpu_types.h — registers GLSL type constructors (float, int, bool,
// vec2..vec4, ivec2..ivec4, mat2..mat4) as Lua globals.
// These metatables must match the names expected by ShaderCompiler.cpp.

#include "misc/luaIncludes.h"

namespace riko::luagpu_types {
    void openLua(lua_State *L);
}
