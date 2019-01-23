#include <cstring>
#include <getopt.h>
#include <iostream>

#include "SDL_gpu/SDL_gpu.h"

#include "engine/audio.h"
#include "misc/consts.h"
#include "engine/fs.h"
#include "engine/gpu.h"
#include "luaMachine.h"
#include "engine/net.h"
#include "riko.h"
#include "shader.h"

#include "rikoProcess.h"

#ifdef __WINDOWS__

#include <windows.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <shellapi.h>
#include <dirent.h>

#else
#include <ftw.h>
#endif

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

    void parseCommands(int argc, char *argv[]) {
        while (true) {
            int optionIndex = 0;
            static option longOptions[] = {
                    {"noaud", no_argument,       nullptr, 0},
                    {"glsl",  optional_argument, nullptr, 'g'},
                    {"dir",   required_argument, nullptr, 'd'},
                    {nullptr, 0,                 nullptr, 0}
            };

            int c = getopt_long(argc, argv, "g::d:", longOptions, &optionIndex);
            if (c == -1) break;


            switch (c) {
                case 0:
                    if (std::string(longOptions[optionIndex].name) == "noaud") {
                        riko::audio::audioEnabled = false;
                    }
                    break;
                case 'd': {
                    strcat(optarg, "/.");
#ifdef __WINDOWS__
                    riko::fs::appPath = new char[MAX_PATH];
                    getFullPath(optarg, riko::fs::appPath);
#else
                    riko::fs::appPath = getFullPath(optarg, nullptr);
#endif
                    if (riko::fs::appPath) {
#ifdef __WINDOWS__
                        strcat(riko::fs::appPath, "\\");
#else
                        strcat(riko::fs::appPath, "/");
#endif
                        struct stat path_stat{};
                        stat(riko::fs::appPath, &path_stat);
                        if (!S_ISDIR(path_stat.st_mode)) {
                            delete riko::fs::appPath;
                            riko::fs::appPath = nullptr;
                        }
                    }
                    break;
                }
                case 'g':
                    if (optarg == nullptr) {
                        riko::shader::glslOverride = -1;
                    } else {
                        int newGLSLVersion = static_cast<int>(strtol(optarg, nullptr, 0));
                        if (newGLSLVersion == 0) {
                            riko::shader::glslOverride = -1;
                        } else if (newGLSLVersion > 0) {
                            riko::shader::glslOverride = newGLSLVersion;
                        } else {
                            std::cout << "Value '" << newGLSLVersion << "' is not a valid GLSL version number"
                                      << std::endl;
                        }
                    }
                    break;
                default:
                    fprintf(stderr, "Usage: %s [--noaud] [--glsl/-g [version]] [--dir/-d dir] \n", argv[0]);
                    exit(1);
            }
        }
    }

    int initLibs() {
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

        int netStatus = riko::net::init();
        if (netStatus != 0) return netStatus;

        return 0;
    }

    void parseConfig() {
        lua_State *configState = riko::lua::createConfigInstance("config.lua");

#ifdef __EMSCRIPTEN__
        int nArg = lua_resume(configState, nullptr, 0);
#else
        int nArg = lua_resume(configState, 0);
#endif
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
                riko::gfx::setPixelScale = static_cast<int>(lua_tointeger(configState, -1));
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

#ifdef __WINDOWS__

    bool is_dir(const char *path) {
        struct stat buf{};
        stat(path, &buf);
        return S_ISDIR(buf.st_mode);
    }

    void copyFile(const std::string &inDir, const std::string &outDir) {
        CopyFile(inDir.c_str(), outDir.c_str(), 1);
    }

    void copyDir(const char *inputDir, const std::string &outDir) {

        DIR *pDIR;
        struct dirent *entry;
        std::string tmpStr, tmpStrPath, outStrPath, inputDir_str = inputDir;

        if (!is_dir(inputDir)) {
            std::cout << "This is not a folder " << std::endl;
            return;
        }


        if ((pDIR = opendir(inputDir_str.c_str()))) {
            while ((entry = readdir(pDIR))) { // get folders and files names
                tmpStr = entry->d_name;
                if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
                    tmpStrPath = inputDir_str;
                    tmpStrPath.append("\\");
                    tmpStrPath.append(tmpStr);

                    std::cout << entry->d_name;
                    if (is_dir(tmpStrPath.c_str())) {
                        // Create Folder on the destination path
                        outStrPath = outDir;
                        outStrPath.append("\\");
                        outStrPath.append(tmpStr);
                        mkdir(outStrPath.c_str());

                        copyDir(tmpStrPath.c_str(), outStrPath);
                    } else {
                        // copy file on the destination path
                        outStrPath = outDir;
                        outStrPath.append("\\");
                        outStrPath.append(tmpStr);
                        copyFile(tmpStrPath, outStrPath);
                    }
                }
            }
            closedir(pDIR);
        }
    }

#endif

    int openScripts() {
#ifdef __EMSCRIPTEN__
        riko::fs::appPath = "/";
#else
        if (riko::fs::appPath == nullptr) {
            if (riko::useBundle) {
                riko::fs::appPath = SDL_GetBasePath();
            } else {
                riko::fs::appPath = SDL_GetPrefPath("riko4", "app");
            }
        }
#endif

        if (riko::fs::appPath == nullptr) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "Unable to open application directory, possibly out of free space?");
            return 2;
        }
        printf("Riko4 path: '%s'\n", riko::fs::appPath);


        riko::fs::scriptsPath = new char[strlen(riko::fs::appPath) + 8];
        sprintf(riko::fs::scriptsPath, "%sscripts", riko::fs::appPath);

        struct stat statbuf {};
        if (stat(riko::fs::scriptsPath, &statbuf) != 0) {
            // Create standard directory as first time setup
#ifdef __WINDOWS__
            mkdir(riko::fs::scriptsPath);
            copyDir(".\\scripts", riko::fs::scriptsPath);
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

        riko::window = SDL_CreateWindow(
                "Riko4",
                SDL_WINDOWPOS_CENTERED,
                SDL_WINDOWPOS_CENTERED,
                SCRN_WIDTH * riko::gfx::pixelScale,
                SCRN_HEIGHT * riko::gfx::pixelScale,
                SDL_WINDOW_OPENGL
        );

        GPU_SetInitWindow(SDL_GetWindowID(riko::window));
        riko::gfx::renderer = GPU_Init(
                static_cast<Uint16>(SCRN_WIDTH * riko::gfx::pixelScale),
                static_cast<Uint16>(SCRN_HEIGHT * riko::gfx::pixelScale),
                GPU_DEFAULT_INIT_FLAGS
        );

        SDL_GetWindowSize(riko::window, &riko::gfx::windowWidth, &riko::gfx::windowHeight);

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

        SDL_SetWindowIcon(riko::window, surface);

        return 0;
    }

    void cleanup() {
        riko::net::cleanup();

        SDL_free(riko::fs::appPath);

        riko::lua::shutdownInstance(riko::mainThread);

        GPU_FreeTarget(riko::gfx::renderer);

        GPU_Quit();
        SDL_Quit();
    }
}
