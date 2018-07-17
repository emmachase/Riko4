#include <cstring>
#include <ftw.h>

#include "SDL_gpu/SDL_gpu.h"

#include "audio.h"
#include "consts.h"
#include "fs.h"
#include "gpu.h"
#include "luaMachine.h"
#include "riko.h"
#include "shader.h"

#include "process.h"

namespace riko::process {
#ifndef __WINDOWS__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
    int fileCopyCallback(const char *fPath, const struct stat *sb, int typeFlag, struct FTW *ftwBuf) {
        char endPath[sizeof(char) * (strlen(fPath) + strlen(riko::fs::appPath) + 1)];
        sprintf(endPath, "%s%s", riko::fs::appPath, fPath);

        if (typeFlag == FTW_D) {
            mkdir(endPath, 0777);
        } else {
            FILE *handle = fopen(fPath, "r");

            fseek(handle, 0, SEEK_END);
            long lSize = ftell(handle);
            rewind(handle);

            char dataBuf[lSize];

            size_t result = fread(dataBuf, 1, static_cast<size_t>(lSize), handle);
            if (result != lSize) return 3;

            fclose(handle);

            handle = fopen(endPath, "w");
            fwrite(dataBuf, 1, static_cast<size_t>(lSize), handle);
            fclose(handle);
        }
        return 0;
    }
#pragma clang diagnostic pop
#endif

    void parseCommands(int argc, char * argv[]) {
        if (argc > 1) {
            if (!strcmp("--noaud", argv[1])) {
                riko::audio::audioEnabled = false;
            }
        }
    }

    void initSDL() {
        SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER);

        /* Open the first available controller. */
        SDL_GameController *controller = nullptr;
        for (int i = 0; i < SDL_NumJoysticks(); ++i) {
            if (SDL_IsGameController(i)) {
                controller = SDL_GameControllerOpen(i);
                if (controller) {
                    printf("Connected controller %i\n", i);
                    break;
                } else {
                    fprintf(stderr, "Could not open game-controller %i: %s\n", i, SDL_GetError());
                }
            }
        }
    }

    void parseConfig() {
        lua_State *configState = riko::lua::createConfigInstance("config.lua");
        int nArg = lua_resume(configState, 0);
        printf("Got %d\n", nArg);

        if (lua_type(configState, 1) == LUA_TTABLE) {
            lua_pushstring(configState, "usebundle");
            lua_gettable(configState, -2);

            if (lua_type(configState, -1) == LUA_TBOOLEAN) {
                riko::useBundle = static_cast<bool>(lua_toboolean(configState, -1));
            }
            lua_pop(configState, 1);

            lua_pushstring(configState, "scale");
            lua_gettable(configState, -2);

            if (lua_type(configState, -1) == LUA_TNUMBER) {
                riko::gfx::pixelScale = static_cast<int>(lua_tointeger(configState, -1));
            }
            lua_pop(configState, 1);

            lua_pushstring(configState, "screenshader");
            lua_gettable(configState, -2);

            if (lua_type(configState, -1) == LUA_TBOOLEAN) {
                riko::gfx::shaderOn = static_cast<bool>(lua_toboolean(configState, -1));
            }
        }
    }

    int openScripts() {
#ifdef __EMSCRIPTEN__
        riko::fs::appPath = "/";
#else
        if (riko::useBundle) {
            riko::fs::appPath = SDL_GetBasePath();
        } else {
            riko::fs::appPath = SDL_GetPrefPath("riko4", "app");
        }
#endif

        if (riko::fs::appPath == nullptr) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Unable to open application directory, possibly out of free space?");
            return 2;
        }
        printf("Riko4 path: '%s'\n", riko::fs::appPath);


        riko::fs::scriptsPath = new char[strlen(riko::fs::appPath) + 8];
        sprintf(riko::fs::scriptsPath, "%sscripts", riko::fs::appPath);

        struct stat statbuf{};
        if (stat(riko::fs::scriptsPath, &statbuf) != 0) {
            // Create standard directory as first time setup
#ifdef __WINDOWS__
            SHFILEOPSTRUCT s = { 0 };
            s.wFunc = FO_COPY;
            s.pTo = scriptsPath;
            s.pFrom = ".\\scripts";
            s.fFlags = FOF_SILENT | FOF_NOCONFIRMMKDIR | FOF_NOCONFIRMATION | FOF_NOERRORUI;
            int res = SHFileOperationA(&s);

            if (res != 0) {
                SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Was unable to perform first-time scripts setup, quitting..");
                return 4;
            }
#else
            nftw("./scripts/", &fileCopyCallback, OPEN_FS_DESC, 0);
#endif
        }

        return 0;
    }

    int setupWindow() {
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

        SDL_Window *window;
        window = SDL_CreateWindow(
                "Riko4",
                SDL_WINDOWPOS_CENTERED,
                SDL_WINDOWPOS_CENTERED,
                SCRN_WIDTH * riko::gfx::pixelScale,
                SCRN_HEIGHT * riko::gfx::pixelScale,
                SDL_WINDOW_OPENGL
        );

        GPU_SetInitWindow(SDL_GetWindowID(window));
        riko::gfx::renderer = GPU_Init(
                static_cast<Uint16>(SCRN_WIDTH * riko::gfx::pixelScale),
                static_cast<Uint16>(SCRN_HEIGHT * riko::gfx::pixelScale),
                GPU_DEFAULT_INIT_FLAGS
        );

        SDL_ShowCursor(SDL_DISABLE);

        if (riko::gfx::renderer == nullptr) {
            printf("Could not create window: %s\n", SDL_GetError());
            return 1;
        }

        riko::gfx::buffer = GPU_CreateImage(SCRN_WIDTH, SCRN_HEIGHT, GPU_FORMAT_RGBA);

        GPU_SetBlending(riko::gfx::buffer, GPU_FALSE);
        GPU_SetImageFilter(riko::gfx::buffer, GPU_FILTER_NEAREST);

        riko::gfx::bufferTarget = GPU_LoadTarget(riko::gfx::buffer);

        GPU_Clear(riko::gfx::renderer);

        riko::shader::initShader();

        GPU_Flip(riko::gfx::renderer);

        SDL_Surface *surface;
        surface = SDL_LoadBMP("icon.ico");

        SDL_SetWindowIcon(window, surface);

        return 0;
    }

    void cleanup() {
        SDL_free(riko::fs::appPath);

        riko::lua::shutdownInstance(riko::mainThread);

        GPU_FreeTarget(riko::gfx::renderer);

        GPU_Quit();
        SDL_Quit();
    }
}
