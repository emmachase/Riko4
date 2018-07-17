#pragma clang diagnostic push
#pragma ide diagnostic ignored "OCUnusedMacroInspection"
#define _CRT_SECURE_NO_WARNINGS

#if defined(_WIN32) || defined(_WIN64) || defined(__WIN32__) \
 || defined(__TOS_WIN__) || defined(__WINDOWS__)
/* Compiling for Windows */
#  ifndef __WINDOWS__
#    define __WINDOWS__
#  endif
#  include <windows.h>
#endif/* Predefined Windows macros */

#ifndef CALLBACK
#  if defined(_ARM_)
#    define CALLBACK
#  else
#    define CALLBACK __stdcall
#  endif
#endif

#ifdef __EMSCRIPTEN__
#  include "emscripten.h"
#endif

#ifndef __WINDOWS__
#  include <ftw.h>
#endif

#include "events.h"
#include "fs.h"
#include "luaIncludes.h"
#include "luaMachine.h"
#include "process.h"

#include "riko.h"

namespace riko {
    bool running = true;
    int exitCode = 0;

    bool useBundle = false;

    lua_State *mainThread;
}


int main(int argc, char * argv[]) {
    riko::process::parseCommands(argc, argv);

    riko::process::initSDL();

    riko::process::parseConfig();

    int scriptStatus = riko::process::openScripts();
    if (scriptStatus != 0) return scriptStatus;

    int windowStatus = riko::process::setupWindow();
    if (windowStatus != 0) return windowStatus;

    auto *bootLoc = new char[strlen(riko::fs::scriptsPath) + 10];
    sprintf(bootLoc, "%s/boot.lua", riko::fs::scriptsPath);
    riko::mainThread = riko::lua::createLuaInstance(bootLoc);

    if (riko::mainThread == nullptr) {
        return 7;
    }

#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(riko::events::loop, 0, 1);
#else
    while (riko::running) {
        riko::events::loop();
    }
#endif

    riko::process::cleanup();

    return riko::exitCode;
}

#pragma clang diagnostic pop
