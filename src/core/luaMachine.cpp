#include <string>
#include <fstream>
#include <iostream>
#include <vector>

#include "SDL_gpu/SDL_gpu.h"
#include "misc/luaIncludes.h"

#include "misc/consts.h"

#include "engine/fs.h"
#include "engine/gpu.h"
#include "engine/audio.h"
#include "engine/image.h"
#include "engine/net.h"

#include "luaMachine.h"

namespace riko::lua {
    static const luaL_Reg lj_lib_load[] = {
            {"", luaopen_base},
            {LUA_TABLIBNAME, luaopen_table},
            {LUA_OSLIBNAME, luaopen_os},
            {LUA_STRLIBNAME, luaopen_string},
            {LUA_MATHLIBNAME, luaopen_math},
            {LUA_DBLIBNAME, luaopen_debug},
#ifndef __EMSCRIPTEN__
            {LUA_LOADLIBNAME, luaopen_package},
            {LUA_BITLIBNAME, luaopen_bit},
            {LUA_JITLIBNAME, luaopen_jit},
#else
    { LUA_COLIBNAME,   luaopen_coroutine },
    { LUA_BITLIBNAME,  luaopen_bit32 },
#endif
            {nullptr, nullptr}
    };

#ifndef __EMSCRIPTEN__
    static const luaL_Reg lj_lib_preload[] = {
            {LUA_FFILIBNAME, luaopen_ffi},
            {nullptr,        nullptr}
    };
#endif


    void printLuaError(lua_State *L, int result) {
        printf("%s\n", lua_tostring(L, -1));

        if (result != 0) {
            switch (result) {
                case LUA_ERRRUN:
                    SDL_Log("Lua Runtime error");
                    break;
                case LUA_ERRSYNTAX:
                    SDL_Log("Lua syntax error");
                    break;
                case LUA_ERRMEM:
                    SDL_Log("Lua was unable to allocate the required memory");
                    break;
                case LUA_ERRFILE:
                    SDL_Log("Lua was unable to find boot file");
                    break;
                default:
                    SDL_Log("Unknown lua error: %d", result);
            }
        }
    }

    lua_State *createConfigInstance(const char *filename) {
        lua_State *state = luaL_newstate();

        // Meh, io is probably safe
        luaL_openlibs(state);


        lua_State *L = lua_newthread(state);

        int result = luaL_loadfile(L, filename);

        if (result != 0) {
            L = lua_newthread(state); // To clear out failed load

            std::string appPath = SDL_GetPrefPath("riko4", "app");
            luaL_loadfile(L, (appPath + filename).c_str());
        }

        // We don't care if it errors really bc the config can not exist or be invalid and that's fine

        return L;
    }

    lua_State *createLuaInstance(const char *filename, const char *innerFilename) {
        lua_State *state = luaL_newstate();

        // Make standard libraries available in the Lua object
        const luaL_Reg *lib;
#ifdef __EMSCRIPTEN__
        for (lib = lj_lib_load; lib->func; lib++) {
            luaL_requiref(state, lib->name, lib->func, 1);
            lua_pop(state, 1);  /* remove lib */
        }
#else
        for (lib = lj_lib_load; lib->func; lib++) {
            lua_pushcfunction(state, lib->func);
            lua_pushstring(state, lib->name);
            lua_call(state, 1, 0);
        }
#endif

#ifndef __EMSCRIPTEN__
        luaL_findtable(state, LUA_REGISTRYINDEX, "_PRELOAD",
                       sizeof(lj_lib_preload) / sizeof(lj_lib_preload[0]) - 1);
        for (lib = lj_lib_preload; lib->func; lib++) {
            lua_pushcfunction(state, lib->func);
            lua_setfield(state, -2, lib->name);
        }
        lua_pop(state, 1);
#endif

        if (riko::fs::openLua(state) == 2) {
            return nullptr;
        }
        riko::gpu::openLua(state);
        riko::audio::openLua(state);
        riko::image::openLua(state);
        riko::net::openLua(state);

        lua_pushstring(state, _RIKO_VERSION_);
        lua_setglobal(state, "riko");

        lua_State *thread = lua_newthread(state);

        int result;

        std::ifstream bootFile(filename);
        std::string fileContents;

        bootFile.seekg(0, std::ios::end);
        fileContents.reserve(static_cast<unsigned long long int>(bootFile.tellg()));
        bootFile.seekg(0, std::ios::beg);

        fileContents.assign((std::istreambuf_iterator<char>(bootFile)),
                            std::istreambuf_iterator<char>());

        result = luaL_loadbuffer(thread, fileContents.data(), fileContents.length(), innerFilename);

        if (result != 0) {
            riko::lua::printLuaError(thread, result);
            return nullptr;
        }

        return thread;
    }

    void shutdownInstance(lua_State *L) {
        riko::audio::closeAudio();
        lua_close(L);
    }
}
