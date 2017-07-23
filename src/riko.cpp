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

#include <climits>
#include <string.h>

#include <iostream>

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifndef __WINDOWS__
#  include <ftw.h>
#endif

#include <sys/types.h>
#include <sys/stat.h>

#include <SDL2/SDL.h>

#include <LuaJIT/lua.hpp>

#include "rikoConsts.h"

#include "rikoFs.h"
#include "rikoGPU.h"
#include "rikoAudio.h"
#include "rikoImage.h"

SDL_Window *window;
SDL_Renderer *renderer;

lua_State *mainThread;

char* appPath;
char* scriptsPath;

int pixelSize = 5;
int afPixscale = 5;

bool audEnabled = true;

void printLuaError(int result) {
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

static const luaL_Reg lj_lib_load[] = {
    { "",              luaopen_base },
    { LUA_LOADLIBNAME, luaopen_package },
    { LUA_TABLIBNAME,  luaopen_table },
    { LUA_OSLIBNAME,   luaopen_os },
    { LUA_STRLIBNAME,  luaopen_string },
    { LUA_MATHLIBNAME, luaopen_math },
    { LUA_DBLIBNAME,   luaopen_debug },
    { LUA_BITLIBNAME,  luaopen_bit },
    { LUA_JITLIBNAME,  luaopen_jit },
    { NULL,  NULL }
};

static const luaL_Reg lj_lib_preload[] = {
    { LUA_FFILIBNAME,  luaopen_ffi },
    { NULL,  NULL }
};

bool fatalLoadError = false;

void createLuaInstance(const char* filename) {
    lua_State *state = luaL_newstate();

    // Make standard libraries available in the Lua object
    const luaL_Reg *lib;
    for (lib = lj_lib_load; lib->func; lib++) {
        lua_pushcfunction(state, lib->func);
        lua_pushstring(state, lib->name);
        lua_call(state, 1, 0);
    }
    luaL_findtable(state, LUA_REGISTRYINDEX, "_PRELOAD",
            sizeof(lj_lib_preload) / sizeof(lj_lib_preload[0]) - 1);
    for (lib = lj_lib_preload; lib->func; lib++) {
        lua_pushcfunction(state, lib->func);
        lua_setfield(state, -2, lib->name);
    }
    lua_pop(state, 1);

    if (luaopen_fs(state) == 2) {
        fatalLoadError = true;
    }
    luaopen_gpu(state);
    luaopen_aud(state);
    luaopen_image(state);

    lua_pushstring(state, _RIKO_VERSION_);
    lua_setglobal(state, "riko");

    mainThread = lua_newthread(state);

    int result;

    result = luaL_loadfile(mainThread, filename);

    if (result != 0) {
        printLuaError(result);
        return;
    }
}

lua_State* createConfigInstance(const char* filename) {
    lua_State *state = luaL_newstate();

    // Make standard libraries available in the Lua object
    const luaL_Reg *lib;
    for (lib = lj_lib_load; lib->func; lib++) {
        lua_pushcfunction(state, lib->func);
        lua_pushstring(state, lib->name);
        lua_call(state, 1, 0);
    }
    luaL_findtable(state, LUA_REGISTRYINDEX, "_PRELOAD",
        sizeof(lj_lib_preload) / sizeof(lj_lib_preload[0]) - 1);
    for (lib = lj_lib_preload; lib->func; lib++) {
        lua_pushcfunction(state, lib->func);
        lua_setfield(state, -2, lib->name);
    }
    lua_pop(state, 1);

    lua_State *L = lua_newthread(state);

    int result;

    result = luaL_loadfile(L, filename);

    // We don't care if it errors bc the config can not exist and thats fine

    return L;
}

/* Taken from SDL_iconv() */
char *sane_UCS4ToUTF8(Uint32 ch, char *dst)
{
    Uint8 *p = (Uint8 *)dst;
    if (ch <= 0x7F) {
        *p = (Uint8)ch;
        ++dst;
    } else if (ch <= 0x7FF) {
        p[0] = 0xC0 | (Uint8)((ch >> 6) & 0x1F);
        p[1] = 0x80 | (Uint8)(ch & 0x3F);
        dst += 2;
    } else if (ch <= 0xFFFF) {
        p[0] = 0xE0 | (Uint8)((ch >> 12) & 0x0F);
        p[1] = 0x80 | (Uint8)((ch >> 6) & 0x3F);
        p[2] = 0x80 | (Uint8)(ch & 0x3F);
        dst += 3;
    } else if (ch <= 0x1FFFFF) {
        p[0] = 0xF0 | (Uint8)((ch >> 18) & 0x07);
        p[1] = 0x80 | (Uint8)((ch >> 12) & 0x3F);
        p[2] = 0x80 | (Uint8)((ch >> 6) & 0x3F);
        p[3] = 0x80 | (Uint8)(ch & 0x3F);
        dst += 4;
    } else if (ch <= 0x3FFFFFF) {
        p[0] = 0xF8 | (Uint8)((ch >> 24) & 0x03);
        p[1] = 0x80 | (Uint8)((ch >> 18) & 0x3F);
        p[2] = 0x80 | (Uint8)((ch >> 12) & 0x3F);
        p[3] = 0x80 | (Uint8)((ch >> 6) & 0x3F);
        p[4] = 0x80 | (Uint8)(ch & 0x3F);
        dst += 5;
    } else {
        p[0] = 0xFC | (Uint8)((ch >> 30) & 0x01);
        p[1] = 0x80 | (Uint8)((ch >> 24) & 0x3F);
        p[2] = 0x80 | (Uint8)((ch >> 18) & 0x3F);
        p[3] = 0x80 | (Uint8)((ch >> 12) & 0x3F);
        p[4] = 0x80 | (Uint8)((ch >> 6) & 0x3F);
        p[5] = 0x80 | (Uint8)(ch & 0x3F);
        dst += 6;
    }
    return dst;
}

const char *sane_GetScancodeName(SDL_Scancode scancode)
{
    const char *name;
    if (((int)scancode) < ((int)SDL_SCANCODE_UNKNOWN) || scancode >= SDL_NUM_SCANCODES) {
        SDL_InvalidParamError("scancode");
        return "";
    }

    name = sane_scancode_names[scancode];
    if (name)
        return name;
    else
        return "";
}

const char *cleanKeyName(SDL_Keycode key) {
    static char name[8];
    char *end;

    if (key & SDLK_SCANCODE_MASK) {
        return
            sane_GetScancodeName((SDL_Scancode)(key & ~SDLK_SCANCODE_MASK));
    }

    switch (key) {
    case SDLK_RETURN:
        return sane_GetScancodeName(SDL_SCANCODE_RETURN);
    case SDLK_ESCAPE:
        return sane_GetScancodeName(SDL_SCANCODE_ESCAPE);
    case SDLK_BACKSPACE:
        return sane_GetScancodeName(SDL_SCANCODE_BACKSPACE);
    case SDLK_TAB:
        return sane_GetScancodeName(SDL_SCANCODE_TAB);
    case SDLK_SPACE:
        return sane_GetScancodeName(SDL_SCANCODE_SPACE);
    case SDLK_DELETE:
        return sane_GetScancodeName(SDL_SCANCODE_DELETE);
    default:
        end = sane_UCS4ToUTF8((Uint32)key, name);
        *end = '\0';
        return name;
    }
}

#ifndef __WINDOWS__
int fileCopyCallback(const char *fpath, const struct stat *sb, int typeflag, struct FTW *ftwbuf) {
    char endPath[sizeof(char) * (strlen(fpath) + strlen(appPath) + 1)];
    sprintf(endPath, "%s%s", appPath, fpath);

    if (typeflag == FTW_D) {
        mkdir(endPath, 0777);
    } else {
        FILE *handle = fopen(fpath, "r");

        fseek(handle, 0, SEEK_END);
        long lSize = ftell(handle);
        rewind(handle);

        char *dataBuf = (char*)malloc(sizeof(char) * lSize);
        if (dataBuf == NULL) return 3;

        size_t result = fread(dataBuf, 1, lSize, handle);
        if (result != lSize) return 3;

        fclose(handle);

        handle = fopen(endPath, "w");

        fwrite(dataBuf, 1, lSize, handle);

        fclose(handle);

        free(dataBuf);
    }
    return 0;
}
#endif

int main(int argc, char * argv[]) {
    if (argc > 1) {
        if (!strcmp("--noaud", argv[1])) {
            audEnabled = false;
        }
    }

    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER);

    /* Open the first available controller. */
    SDL_GameController *controller = NULL;
    for (int i = 0; i < SDL_NumJoysticks(); ++i) {
        if (SDL_IsGameController(i)) {
            controller = SDL_GameControllerOpen(i);
            if (controller) {
                printf("Connected controller %i\n", i);
                break;
            } else {
                fprintf(stderr, "Could not open gamecontroller %i: %s\n", i, SDL_GetError());
            }
        }
    }

    lua_State *configState = createConfigInstance("config.lua");
    int narg = lua_resume(configState, 0);
    printf("Got %d\n", narg);
    
    bool bundle = false;

    if (lua_type(configState, 1) == LUA_TTABLE) {
        lua_pushstring(configState, "usebundle");
        lua_gettable(configState, -2);

        if (lua_type(configState, -1) == LUA_TBOOLEAN) {
            bundle = lua_toboolean(configState, -1);
        }

        lua_pushstring(configState, "scale");
        lua_gettable(configState, -3);

        if (lua_type(configState, -1) == LUA_TNUMBER) {
            pixelSize = lua_tointeger(configState, -1);
            afPixscale = lua_tointeger(configState, -1);
        }
    }

    if (bundle) {
        appPath = SDL_GetBasePath();
    } else {
        appPath = SDL_GetPrefPath("riko4", "app");
    }

    if (appPath == NULL) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Unable to open application directory, possibly out of free space?");
        return 2;
    }
    printf("Riko4 path: '%s'\n", appPath);


    scriptsPath = (char*)malloc(strlen(appPath) + sizeof(char) * 8);
    sprintf(scriptsPath, "%sscripts", appPath);

    struct stat statbuf;
    if (stat(scriptsPath, &statbuf) != 0) {
        // Create standard directory as first time setup
#ifdef __WINDOWS__
        SHFILEOPSTRUCT s = { 0 };
        s.wFunc = FO_COPY;
        s.pTo = scriptsPath;
        s.pFrom = ".\\scripts";
        s.fFlags = FOF_SILENT | FOF_NOCONFIRMMKDIR | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_NO_UI;
        int res = SHFileOperation(&s);

        if (res != 0) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Was unable to perform first-time scripts setup, quitting..");
            return 4;
        }
#else
        nftw("./scripts/", &fileCopyCallback, OPEN_FS_DESC, 0);
#endif
    }

    SDL_DisplayMode current;
    int lw = INT_MAX;
    int lh = INT_MAX;

    for (int i = 0; i < SDL_GetNumVideoDisplays(); ++i) {

        int should_be_zero = SDL_GetCurrentDisplayMode(i, &current);

        if (should_be_zero != 0) {
            SDL_Log("Could not get display mode for video display #%d: %s", i, SDL_GetError());
        } else {
            if (current.w < lw && current.h < lh) {
                lw = current.w;
                lh = current.h;
            }
        }
    }

    window = SDL_CreateWindow(
        "Riko4",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        SCRN_WIDTH  * pixelSize,
        SCRN_HEIGHT * pixelSize,
        SDL_WINDOW_OPENGL
    );

    SDL_ShowCursor(SDL_DISABLE);

    if (window == NULL) {
        printf("Could not create window: %s\n", SDL_GetError());
        return 1;
    }

    renderer = SDL_CreateRenderer(window, -1, 
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

    SDL_SetRenderDrawColor(renderer, 24, 24, 24, 255);
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);

    SDL_Surface *surface;
    surface = SDL_LoadBMP("icon.ico");

    SDL_SetWindowIcon(window, surface);

    SDL_Event event;

    char *bootLoc = (char*)malloc(sizeof(char)*(strlen(scriptsPath) + 10));
    sprintf(bootLoc, "%s/boot.lua", scriptsPath);
    createLuaInstance(bootLoc);

    if (fatalLoadError) {
        return 7;
    }

    bool canRun = true;
    bool running = true;
    int pushedArgs = 0;

    int lastMoveX = 0;
    int lastMoveY = 0;

    int cx;
    int cy;
    int mult;

    int exitCode = 0;

    bool readyForProp = true;

    bool ctrlMod = false;
    bool holdR = false;
    clock_t holdL = 0;

    while (running) {
        if (ctrlMod && holdR && clock() - holdL >= CLOCKS_PER_SEC) {
            closeAudio();
            lua_close(mainThread);
            createLuaInstance(bootLoc);
            int result = lua_resume(mainThread, 0);

            ctrlMod = false;
            holdR = false;
            holdL = 0;
        }

        if (SDL_PollEvent(&event)) {
            readyForProp = true;

            switch (event.type) {
                case SDL_QUIT:
                    break;
                case SDL_TEXTINPUT:
                    lua_pushstring(mainThread, "char");
                    lua_pushstring(mainThread, event.text.text);
                    pushedArgs = 2;
                    break;
                case SDL_KEYDOWN:
                    lua_pushstring(mainThread, "key");
                    lua_pushstring(mainThread, cleanKeyName(event.key.keysym.sym));
                    pushedArgs = 2;

                    if (event.key.keysym.scancode == SDL_SCANCODE_LCTRL) {
                        ctrlMod = true;
                    } else if (event.key.keysym.scancode == SDL_SCANCODE_R) {
                        holdR = true;
                    }
                    if (holdL == 0 && ctrlMod && holdR) {
                        holdL = clock();
                    }
                    break;
                case SDL_KEYUP:
                    lua_pushstring(mainThread, "keyUp");
                    lua_pushstring(mainThread, cleanKeyName(event.key.keysym.sym));
                    pushedArgs = 2;

                    if (event.key.keysym.scancode == SDL_SCANCODE_LCTRL) {
                        ctrlMod = false;
                        holdL = 0;
                    } else if (event.key.keysym.scancode == SDL_SCANCODE_R) {
                        holdR = false;
                        holdL = 0;
                    }
                    break;
                case SDL_MOUSEWHEEL:
                    lua_pushstring(mainThread, "mouseWheel");
                    mult = (event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED) ? -1 : 1;
                    
                    lua_pushnumber(mainThread, event.wheel.y * mult);
                    lua_pushnumber(mainThread, event.wheel.x * mult);
                    lua_pushnumber(mainThread, lastMoveX);
                    lua_pushnumber(mainThread, lastMoveY);
                    pushedArgs = 5;
                    break;
                case SDL_MOUSEMOTION:
                    cx = event.motion.x / afPixscale;
                    cy = event.motion.y / afPixscale;
                    if (cx != lastMoveX || cy != lastMoveY) {
                        lua_pushstring(mainThread, "mouseMoved");
                        lua_pushnumber(mainThread, cx);
                        lua_pushnumber(mainThread, cy);
                        lua_pushnumber(mainThread, cx - lastMoveX);
                        lua_pushnumber(mainThread, cy - lastMoveY);
                        lastMoveX = cx;
                        lastMoveY = cy;
                        readyForProp = true;
                        pushedArgs = 5;
                    } else {
                        readyForProp = false;
                    }
                    break;
                case SDL_MOUSEBUTTONDOWN:
                    lua_pushstring(mainThread, "mousePressed");
                    lua_pushnumber(mainThread, (int) event.button.x / afPixscale);
                    lua_pushnumber(mainThread, (int) event.button.y / afPixscale);
                    lua_pushnumber(mainThread, event.button.button);
                    pushedArgs = 4;
                    break;
                case SDL_MOUSEBUTTONUP:
                    lua_pushstring(mainThread, "mouseReleased");
                    lua_pushnumber(mainThread, (int)event.button.x / afPixscale);
                    lua_pushnumber(mainThread, (int)event.button.y / afPixscale);
                    lua_pushnumber(mainThread, event.button.button);
                    pushedArgs = 4;
                    break;
                case SDL_JOYAXISMOTION:
                    lua_pushstring(mainThread, "joyAxis");
                    lua_pushnumber(mainThread, event.caxis.axis);
                    lua_pushnumber(mainThread, event.caxis.value);
                    lua_pushnumber(mainThread, event.caxis.which);
                    pushedArgs = 4;
                    break;
                case SDL_JOYBUTTONDOWN:
                    lua_pushstring(mainThread, "joyButtonDown");
                    lua_pushnumber(mainThread, event.cbutton.button);
                    lua_pushnumber(mainThread, event.caxis.which);
                    pushedArgs = 3;
                    break;
                case SDL_JOYBUTTONUP:
                    lua_pushstring(mainThread, "joyButtonUp");
                    lua_pushnumber(mainThread, event.cbutton.button);
                    lua_pushnumber(mainThread, event.caxis.which);
                    pushedArgs = 3;
                    break;
                case SDL_JOYHATMOTION:
                    lua_pushstring(mainThread, "joyHat");
                    lua_pushnumber(mainThread, event.jhat.value);
                    lua_pushnumber(mainThread, event.jhat.hat);
                    lua_pushnumber(mainThread, event.jhat.which);
                    pushedArgs = 4;
                    break;
                case SDL_JOYBALLMOTION:
                    lua_pushstring(mainThread, "joyBall");
                    lua_pushnumber(mainThread, event.jball.xrel);
                    lua_pushnumber(mainThread, event.jball.yrel);
                    lua_pushnumber(mainThread, event.jball.ball);
                    lua_pushnumber(mainThread, event.jball.which);
                    pushedArgs = 4;
                    break;
                default:
                    readyForProp = false;
            }
        }

        if (event.type == SDL_QUIT) {
            break;
        }

        if (readyForProp) {
            if (canRun) {
                int result = lua_resume(mainThread, pushedArgs);

                if (result == 0) {
                    printf("Script finished!\n");
                    canRun = false;
                } else if (result != LUA_YIELD) {
                    printLuaError(result);
                    canRun = false;
                    exitCode = 1;
                }
            }

            SDL_Delay(1);
        }

        readyForProp = true;
        pushedArgs = 0;
    }

    SDL_free(appPath);

    closeAudio();

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);

    SDL_Quit();

    return exitCode;
}
