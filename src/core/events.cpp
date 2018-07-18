#include <ctime>

#include "SDL_gpu/SDL_gpu.h"

#include "luaMachine.h"
#include "consts.h"

#include "../engine/userdata/ResponseHandle.h"
#include "events.h"

#if SDL_PATCHLEVEL <= 4
#define OLDSDL 
#endif

namespace riko {
    extern bool running;
    extern int exitCode;

    extern lua_State *mainThread;

    namespace gfx {
        extern int pixelScale;
    }
}

namespace riko::events {
    SDL_Event event;

    bool canRun = true;
    int pushedArgs = 0;

    int lastMoveX = 0;
    int lastMoveY = 0;

    int cx;
    int cy;
    int mult;

    bool readyForProp = true;

    bool ctrlMod = false;
    bool holdR = false;
    clock_t holdL = 0;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
    /* Taken from SDL_iconv() */
    char *sane_UCS4ToUTF8(Uint32 ch, char *dst) {
        auto *p = (Uint8 *)dst;
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
#pragma clang diagnostic pop

    const char *sane_GetScancodeName(SDL_Scancode scancode) {
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

    bool pushNonStandard(SDL_Event &event) {
        if (event.type == NET_SUCCESS) {
            lua_pushstring(riko::mainThread, "netSuccess");

            auto *url = (std::string *) event.user.data1;
            lua_pushlstring(riko::mainThread, url->c_str(), url->length());

            ((riko::net::ResponseHandle *) event.user.data2)->constructUserdata(riko::mainThread);

            pushedArgs = 3;

            return true;
        } else if (event.type == NET_FAILURE) {
            lua_pushstring(riko::mainThread, "netFailure");

            auto *url = (std::string *) event.user.data1;
            lua_pushlstring(riko::mainThread, url->c_str(), url->length());

            auto *errorStr = (std::string*) event.user.data2;
            lua_pushlstring(riko::mainThread, errorStr->c_str(), errorStr->length());

            pushedArgs = 3;

            delete errorStr;

            return true;
        }

        return false;
    }

    void loop() {
        if (ctrlMod && holdR && clock() - holdL >= CLOCKS_PER_SEC) {
            riko::lua::shutdownInstance(riko::mainThread);

            ctrlMod = false;
            holdR = false;
            holdL = 0;
        }

        while (true) {
            if (SDL_PollEvent(&event)) {
                readyForProp = true;

                switch (event.type) {
                case SDL_QUIT:
                    break;
                case SDL_TEXTINPUT:
                    lua_pushstring(riko::mainThread, "char");
                    lua_pushstring(riko::mainThread, event.text.text);
                    pushedArgs = 2;
                    break;
                case SDL_KEYDOWN:
                    lua_pushstring(riko::mainThread, "key");
                    lua_pushstring(riko::mainThread, riko::events::cleanKeyName(event.key.keysym.sym));
                    pushedArgs = 2;

                    if (event.key.keysym.scancode == SDL_SCANCODE_LCTRL) {
                        ctrlMod = true;
                    }
                    else if (event.key.keysym.scancode == SDL_SCANCODE_R) {
                        holdR = true;
                    }
                    if (holdL == 0 && ctrlMod && holdR) {
                        holdL = clock();
                    }
                    break;
                case SDL_KEYUP:
                    lua_pushstring(riko::mainThread, "keyUp");
                    lua_pushstring(riko::mainThread, riko::events::cleanKeyName(event.key.keysym.sym));
                    pushedArgs = 2;

                    if (event.key.keysym.scancode == SDL_SCANCODE_LCTRL) {
                        ctrlMod = false;
                        holdL = 0;
                    }
                    else if (event.key.keysym.scancode == SDL_SCANCODE_R) {
                        holdR = false;
                        holdL = 0;
                    }
                    break;
                case SDL_MOUSEWHEEL:
                    lua_pushstring(riko::mainThread, "mouseWheel");

#ifdef OLDSDL
                    mult = 1;
#else
                    mult = (event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED) ? -1 : 1;
#endif

                    lua_pushnumber(riko::mainThread, event.wheel.y * mult);
                    lua_pushnumber(riko::mainThread, event.wheel.x * mult);
                    lua_pushnumber(riko::mainThread, lastMoveX);
                    lua_pushnumber(riko::mainThread, lastMoveY);
                    pushedArgs = 5;
                    break;
                case SDL_MOUSEMOTION:
                    cx = event.motion.x / riko::gfx::pixelScale;
                    cy = event.motion.y / riko::gfx::pixelScale;
                    if (cx != lastMoveX || cy != lastMoveY) {
                        lua_pushstring(riko::mainThread, "mouseMoved");
                        lua_pushnumber(riko::mainThread, cx);
                        lua_pushnumber(riko::mainThread, cy);
                        lua_pushnumber(riko::mainThread, cx - lastMoveX);
                        lua_pushnumber(riko::mainThread, cy - lastMoveY);
                        lastMoveX = cx;
                        lastMoveY = cy;
                        readyForProp = true;
                        pushedArgs = 5;
                    }
                    else {
                        readyForProp = false;
                    }
                    break;
                case SDL_MOUSEBUTTONDOWN:
                    lua_pushstring(riko::mainThread, "mousePressed");
                    lua_pushnumber(riko::mainThread, (int)(event.button.x / riko::gfx::pixelScale));
                    lua_pushnumber(riko::mainThread, (int)(event.button.y / riko::gfx::pixelScale));
                    lua_pushnumber(riko::mainThread, event.button.button);
                    pushedArgs = 4;
                    break;
                case SDL_MOUSEBUTTONUP:
                    lua_pushstring(riko::mainThread, "mouseReleased");
                    lua_pushnumber(riko::mainThread, (int)(event.button.x / riko::gfx::pixelScale));
                    lua_pushnumber(riko::mainThread, (int)(event.button.y / riko::gfx::pixelScale));
                    lua_pushnumber(riko::mainThread, event.button.button);
                    pushedArgs = 4;
                    break;
                case SDL_JOYAXISMOTION:
                    lua_pushstring(riko::mainThread, "joyAxis");
                    lua_pushnumber(riko::mainThread, event.caxis.axis);
                    lua_pushnumber(riko::mainThread, event.caxis.value);
                    lua_pushnumber(riko::mainThread, event.caxis.which);
                    pushedArgs = 4;
                    break;
                case SDL_JOYBUTTONDOWN:
                    lua_pushstring(riko::mainThread, "joyButtonDown");
                    lua_pushnumber(riko::mainThread, event.cbutton.button);
                    lua_pushnumber(riko::mainThread, event.caxis.which);
                    pushedArgs = 3;
                    break;
                case SDL_JOYBUTTONUP:
                    lua_pushstring(riko::mainThread, "joyButtonUp");
                    lua_pushnumber(riko::mainThread, event.cbutton.button);
                    lua_pushnumber(riko::mainThread, event.caxis.which);
                    pushedArgs = 3;
                    break;
                case SDL_JOYHATMOTION:
                    lua_pushstring(riko::mainThread, "joyHat");
                    lua_pushnumber(riko::mainThread, event.jhat.value);
                    lua_pushnumber(riko::mainThread, event.jhat.hat);
                    lua_pushnumber(riko::mainThread, event.jhat.which);
                    pushedArgs = 4;
                    break;
                case SDL_JOYBALLMOTION:
                    lua_pushstring(riko::mainThread, "joyBall");
                    lua_pushnumber(riko::mainThread, event.jball.xrel);
                    lua_pushnumber(riko::mainThread, event.jball.yrel);
                    lua_pushnumber(riko::mainThread, event.jball.ball);
                    lua_pushnumber(riko::mainThread, event.jball.which);
                    pushedArgs = 5;
                    break;
                default:
                    if (!pushNonStandard(event))
                        readyForProp = false;
                }
            } else {
                if (canRun) {
                    int result = lua_resume(riko::mainThread, 0);

                    if (result == 0) {
                        printf("Script finished!\n");
                        canRun = false;
                    }
                    else if (result != LUA_YIELD) {
                        riko::lua::printLuaError(riko::mainThread, result);
                        puts(lua_tostring(riko::mainThread, -1));

                        canRun = false;
                        riko::exitCode = 1;
                    }
                }
                break;
            }

            if (event.type == SDL_QUIT) {
                riko::running = false;
            }

            if (readyForProp) {
                if (canRun) {
                    int result = lua_resume(riko::mainThread, pushedArgs);

                    if (result == 0) {
                        printf("Script finished!\n");
                        canRun = false;
                    }
                    else if (result != LUA_YIELD) {
                        riko::lua::printLuaError(riko::mainThread, result);
                        puts(lua_tostring(riko::mainThread, -1));

                        canRun = false;
                        riko::exitCode = 1;
                    }
                }

#ifndef __EMSCRIPTEN__
                SDL_Delay(1);
#endif
            }

            readyForProp = true;
            pushedArgs = 0;
        }
    }
}
