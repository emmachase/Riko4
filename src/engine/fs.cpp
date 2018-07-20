#pragma clang diagnostic push
#pragma ide diagnostic ignored "OCUnusedMacroInspection"
#define _CRT_SECURE_NO_WARNINGS

#if defined(_WIN32) || defined(_WIN64) || defined(__WIN32__) \
 || defined(__TOS_WIN__) || defined(__WINDOWS__)
/* Compiling for Windows */
#ifndef __WINDOWS__
#define __WINDOWS__
#endif
#  include <Windows.h>
#endif /* Predefined Windows macros */

#include <cstdlib>
#include <cstdio>
#include <cstring>

#ifndef __WINDOWS__
#  include <unistd.h>
#  include <dirent.h>
#  define f_mkdir mkdir
#else
#  include <direct.h>
#  define f_mkdir(a, b) _mkdir(a)
#endif

#ifdef __WINDOWS__
#  define getFullPath(a, b) GetFullPathName(a, MAX_PATH, b, NULL)
#  define rmdir(a) _rmdir(a)
#else
#  define getFullPath(a, b) realpath(a, b)
#endif

#include <cerrno>
#include <sys/types.h>
#include <sys/stat.h>

#include "SDL_gpu/SDL_gpu.h"

#include "consts.h"
#include "luaIncludes.h"

#include "fs.h"

#define checkPath(luaInput, varName)                                                                                      \
    do {                                                                                                                  \
        char* workingFront = ((luaInput)[0] == '\\' || (luaInput)[0] == '/') ? scriptsPath : currentWorkingDirectory;     \
                                                                                                                          \
        auto scriptsPathLen = (int)strlen(scriptsPath);                                                                   \
                                                                                                                          \
        auto ln = (int)(strlen(luaInput) + strlen(workingFront) + 2);                                                     \
        char concatStr[ln];                                                                                               \
        sprintf(concatStr, "%s/%s", workingFront, luaInput);                                                              \
                                                                                                                          \
        auto* ptrz = (char*)getFullPath(concatStr, varName);                                                              \
        if (ptrz == NULL && errno == ENOENT) {                                                                            \
            sprintf(varName, "%s", concatStr);                                                                            \
        } else {                                                                                                          \
            auto varNameLen = (int)strlen(varName);                                                                       \
                                                                                                                          \
            if (varNameLen + 1 == scriptsPathLen) {                                                                       \
                char tmp = scriptsPath[scriptsPathLen - 1];                                                               \
                scriptsPath[scriptsPathLen - 1] = 0;                                                                      \
                if (strcmp(varName, scriptsPath) == 0) {                                                                  \
                    scriptsPath[scriptsPathLen - 1] = tmp;                                                                \
                } else {                                                                                                  \
                    scriptsPath[scriptsPathLen - 1] = tmp;                                                                \
                    return luaL_error(L, "attempt to access file beneath root");                                          \
                }                                                                                                         \
            } else if (varNameLen > scriptsPathLen) {                                                                     \
                char tmp = (varName)[scriptsPathLen];                                                                     \
                (varName)[scriptsPathLen] = 0;                                                                            \
                if (strcmp(varName, scriptsPath) == 0) {                                                                  \
                    (varName)[scriptsPathLen] = tmp;                                                                      \
                } else {                                                                                                  \
                    return luaL_error(L, "attempt to access file beneath root");                                          \
                }                                                                                                         \
            } else if (varNameLen == scriptsPathLen) {                                                                    \
                if (strcmp(varName, scriptsPath) != 0) {                                                                  \
                    return luaL_error(L, "attempt to access file beneath root");                                          \
                }                                                                                                         \
            } else {                                                                                                      \
                return luaL_error(L, "attempt to access file beneath root");                                              \
            }                                                                                                             \
        }                                                                                                                 \
    } while (0);

namespace riko::fs {
    char* appPath;
    char* scriptsPath;

    char currentWorkingDirectory[MAX_PATH];
    char lastOpenedPath[MAX_PATH];

    struct fileHandleType {
        FILE *fileStream;
        bool open;
        bool canWrite;
        bool eof;
    };

    static fileHandleType *checkFsObj(lua_State *L) {
        void *ud = luaL_checkudata(L, 1, "Riko4.fsObj");
        luaL_argcheck(L, ud != nullptr, 1, "`FileHandle` expected");
        return (fileHandleType *) ud;
    }

    static int fsGetAttr(lua_State *L) {
        char filePath[MAX_PATH + 1];
        checkPath(luaL_checkstring(L, 1), filePath);

        if (filePath[0] == 0) {
            lua_pushinteger(L, 0b11111111);
            return 1;
        }

#ifdef __WINDOWS__
        unsigned long attr = GetFileAttributes(filePath);

        if (attr == INVALID_FILE_ATTRIBUTES) {
            lua_pushinteger(L, 0b11111111);

            return 1;
        }

        int attrOut = ((attr & FILE_ATTRIBUTE_READONLY)  != 0) * 0b00000001 +
                      ((attr & FILE_ATTRIBUTE_DIRECTORY) != 0) * 0b00000010;

        lua_pushinteger(L, attrOut);

        return 1;
#else
        struct stat statbuf{};
        if (stat(filePath, &statbuf) != 0) {
            lua_pushinteger(L, 0b11111111);
            return 1;
        }

        int attrOut = ((access(filePath, W_OK) * 0b00000001) +
                       (S_ISDIR(statbuf.st_mode) * 0b00000010));

        lua_pushinteger(L, attrOut);
        return 1;
#endif
    }

    static int fsList(lua_State *L) {
        char filePath[MAX_PATH + 1];
        checkPath(luaL_checkstring(L, 1), filePath);

        if (filePath[0] == 0) {
            return 0;
        }

#ifdef __WINDOWS__
        WIN32_FIND_DATA fdFile;
        HANDLE hFind = NULL;

        char sPath[2048];

        //Specify a file mask. *.* = We want everything!
        sprintf(sPath, "%s\\*.*", filePath);

        if ((hFind = FindFirstFile(sPath, &fdFile)) == INVALID_HANDLE_VALUE) {
            return 0;
        }

        lua_newtable(L);
        int i = 1;

        lua_pushinteger(L, i);
        lua_pushstring(L, ".");
        lua_rawset(L, -3);
        i++;

        lua_pushinteger(L, i);
        lua_pushstring(L, "..");
        lua_rawset(L, -3);
        i++;

        do {
            //Build up our file path using the passed in

            if (strcmp(fdFile.cFileName, ".") != 0
                && strcmp(fdFile.cFileName, "..") != 0) {
                lua_pushinteger(L, i);
                lua_pushstring(L, fdFile.cFileName);
                lua_rawset(L, -3);
                i++;
            }
        }
        while (FindNextFile(hFind, &fdFile)); //Find the next file.

        FindClose(hFind); //Always, Always, clean things up!

        return 1;
#else
        DIR *dp;
        struct dirent *ep;

        dp = opendir(filePath);
        if (dp != nullptr) {
            lua_newtable(L);
            int i = 1;

            while ((ep = readdir(dp))) {
                lua_pushinteger(L, i);
                lua_pushstring(L, ep->d_name);
                lua_rawset(L, -3);
                i++;
            }
            closedir(dp);

            return 1;
        } else {
            return 0;
        }
#endif
    }

    static int fsOpenFile(lua_State *L) {
        char filePath[MAX_PATH + 1];
        checkPath(luaL_checkstring(L, 1), filePath);

        if (filePath[0] == 0) {
            return 0;
        }

        const char *mode = luaL_checkstring(L, 2);

        FILE *fileHandle_o;
        if (mode[0] == 'w' || mode[0] == 'r' || mode[0] == 'a') {
            if (mode[1] == '+') {
                if (mode[2] == 'b' || mode[2] == 0) {
                    fileHandle_o = fopen(filePath, mode);
                } else {
                    return luaL_error(L, "invalid file mode");
                }
            } else if (mode[1] == 'b' && strlen(mode) == 2) {
                fileHandle_o = fopen(filePath, mode);
            } else if (strlen(mode) == 1) {
                fileHandle_o = fopen(filePath, mode);
            } else {
                return luaL_error(L, "invalid file mode");
            }
        } else {
            return luaL_error(L, "invalid file mode");
        }

        if (fileHandle_o == nullptr)
            return 0;

        strcpy((char *) &lastOpenedPath, filePath + strlen(scriptsPath));
        for (int i = 0; lastOpenedPath[i] != '\0'; i++) {
            if (lastOpenedPath[i] == '\\')
                lastOpenedPath[i] = '/';
        }

        size_t nbytes = sizeof(fileHandleType);
        auto *outObj = (fileHandleType *) lua_newuserdata(L, nbytes);

        luaL_getmetatable(L, "Riko4.fsObj");
        lua_setmetatable(L, -2);

        outObj->fileStream = fileHandle_o;
        outObj->open = true;
        outObj->canWrite = mode[0] != 'r';
        outObj->eof = false;

        return 1;
    }

    static int fsLastOpened(lua_State *L) {
        lua_pushstring(L, (char *) &lastOpenedPath);

        return 1;
    }

    static int fsObjWrite(lua_State *L) {
        fileHandleType *data = checkFsObj(L);

        if (!data->open)
            return luaL_error(L, "file handle was closed");

        if (!data->canWrite)
            return luaL_error(L, "file is not open for writing");

        size_t strSize;
        const char *toWrite = luaL_checklstring(L, 2, &strSize);

        size_t written = fwrite(toWrite, 1, strSize, data->fileStream);

        lua_pushboolean(L, written == strSize);

        return 1;
    }

    long lineStrLen(const char *s, long max) {
        for (long i = 0; i < max; i++) {
            if (s[i] == '\n' || s[i] == '\r') {
                return i + 1;
            }
        }

        return max;
    }

    static int fsObjRead(lua_State *L) {
        fileHandleType *data = checkFsObj(L);

        if (!data->open)
            return luaL_error(L, "file handle was closed");

        if (data->canWrite)
            return luaL_error(L, "file is open for writing");

        if (data->eof) {
            lua_pushnil(L);
            return 1;
        }

        if (feof(data->fileStream)) {
            data->eof = true;
            lua_pushnil(L);
            return 1;
        }

        int num = lua_gettop(L);
        if (num == 0) {
            // Read line

            size_t bufLen = sizeof(char) * (FS_LINE_INCR + 1);
            auto *dataBuf = new char[bufLen];

            long st = ftell(data->fileStream);

            if (fgets(dataBuf, FS_LINE_INCR, data->fileStream) == nullptr) {
                lua_pushstring(L, "");
                delete[] dataBuf;
                return 1;
            }

            long dataBufLen = lineStrLen(dataBuf, FS_LINE_INCR);
            if (feof(data->fileStream)) {
                data->eof = true;
                dataBufLen = ftell(data->fileStream);
                lua_pushlstring(L, dataBuf, static_cast<size_t>(dataBufLen - st));
                delete[] dataBuf;
                return 1;
            } else if (dataBuf[dataBufLen - 1] == '\n' || dataBuf[dataBufLen - 1] == '\r') {
                lua_pushlstring(L, dataBuf, static_cast<size_t>(dataBufLen - 1));
                delete[] dataBuf;
                return 1;
            }

            for (int i = 1;; i++) {
                bufLen += sizeof(char) * FS_LINE_INCR;
                dataBuf = (char *) realloc(dataBuf, bufLen);
                if (dataBuf == nullptr) return luaL_error(L, "unable to allocate enough memory for read operation");

                st = ftell(data->fileStream);

                if (fgets(dataBuf + i * (FS_LINE_INCR - 1) * sizeof(char), FS_LINE_INCR, data->fileStream) == nullptr) {
                    lua_pushstring(L, "");
                    delete[] dataBuf;
                    return 1;
                }

                dataBufLen = lineStrLen(dataBuf, bufLen / sizeof(char));
                if (feof(data->fileStream)) {
                    data->eof = true;
                    dataBufLen = ftell(data->fileStream);
                    lua_pushlstring(L, dataBuf, static_cast<size_t>(dataBufLen - st));
                    delete[] dataBuf;
                    return 1;
                } else if (dataBuf[dataBufLen - 1] == '\n') {
                    lua_pushlstring(L, dataBuf, static_cast<size_t>(dataBufLen - 1));
                    delete[] dataBuf;
                    return 1;
                }
            }
        }

        int type = lua_type(L, 1 - num);
        if (type == LUA_TSTRING) {
            const char *mode = luaL_checkstring(L, 2);

            if (mode[0] == '*') {
                if (mode[1] == 'a') {
                    // All

                    fseek(data->fileStream, 0, SEEK_END);
                    long lSize = ftell(data->fileStream);
                    rewind(data->fileStream);

                    auto *dataBuf = new char[lSize + 1];

                    size_t result = fread(dataBuf, 1, static_cast<size_t>(lSize), data->fileStream);

                    dataBuf[result] = 0;

                    lua_pushlstring(L, dataBuf, result);

                    data->eof = true;

                    delete[] dataBuf;

                    return 1;
                } else if (mode[1] == 'l') {
                    // Read line

                    size_t bufLen = sizeof(char) * (FS_LINE_INCR + 1);
                    auto *dataBuf = new char[bufLen];

                    long st = ftell(data->fileStream);

                    if (fgets(dataBuf, FS_LINE_INCR, data->fileStream) == nullptr) {
                        lua_pushstring(L, "");
                        delete[] dataBuf;
                        return 1;
                    }

                    long dataBufLen = lineStrLen(dataBuf, FS_LINE_INCR);
                    if (feof(data->fileStream)) {
                        data->eof = true;
                        dataBufLen = ftell(data->fileStream);
                        lua_pushlstring(L, dataBuf, static_cast<size_t>(dataBufLen - st));
                        delete[] dataBuf;
                        return 1;
                    } else if (dataBuf[dataBufLen - 1] == '\n' || dataBuf[dataBufLen - 1] == '\r') {
                        lua_pushlstring(L, dataBuf, static_cast<size_t>(dataBufLen - 1));
                        delete[] dataBuf;
                        return 1;
                    }

                    for (int i = 1;; i++) {
                        bufLen += sizeof(char) * FS_LINE_INCR;
                        dataBuf = (char *) realloc(dataBuf, bufLen);
                        if (dataBuf == nullptr)
                            return luaL_error(L, "unable to allocate enough memory for read operation");

                        st = ftell(data->fileStream);

                        if (fgets(dataBuf + i * (FS_LINE_INCR - 1) * sizeof(char), FS_LINE_INCR, data->fileStream) ==
                            nullptr) {
                            lua_pushstring(L, "");
                            delete[] dataBuf;
                            return 1;
                        }

                        dataBufLen = lineStrLen(dataBuf, bufLen / sizeof(char));
                        if (feof(data->fileStream)) {
                            data->eof = true;
                            dataBufLen = ftell(data->fileStream);
                            lua_pushlstring(L, dataBuf, static_cast<size_t>(dataBufLen - st));
                            delete[] dataBuf;
                            return 1;
                        } else if (dataBuf[dataBufLen - 1] == '\n' || dataBuf[dataBufLen - 1] == '\r') {
                            lua_pushlstring(L, dataBuf, static_cast<size_t>(dataBufLen - 1));
                            delete[] dataBuf;
                            return 1;
                        }
                    }
                } else {
                    return luaL_argerror(L, 2, "invalid mode");
                }
            } else {
                return luaL_argerror(L, 2, "invalid mode");
            }
        } else if (type == LUA_TNUMBER) {
            auto len = (int) (luaL_checkinteger(L, 2));

            // Read 'len' bytes

            auto *dataBuf = new char[len + 1];

            size_t result = fread(dataBuf, sizeof(char), static_cast<size_t>(len), data->fileStream);

            dataBuf[result] = 0;

            lua_pushlstring(L, dataBuf, result);

            delete[] dataBuf;

            return 1;
        } else {
            const char *typeN = lua_typename(L, type);
            size_t len = 16 + strlen(typeN);
            auto *eMsg = new char[len];
            sprintf(eMsg, "%s was unexpected", typeN);
            delete[] eMsg;

            return luaL_argerror(L, 2, eMsg);
        }
    }

    static int fsMkDir(lua_State *L) {
        char filePath[MAX_PATH + 1];
        checkPath(luaL_checkstring(L, 1), filePath);

        if (filePath[0] == 0) {
            lua_pushboolean(L, false);
            return 1;
        }

        lua_pushboolean(L, f_mkdir(filePath, 0777) + 1);
        return 1;
    }

    static int fsMv(lua_State *L) {
        char filePath[MAX_PATH + 1];
        checkPath(luaL_checkstring(L, 1), filePath);

        if (filePath[0] == 0) {
            lua_pushboolean(L, false);
            return 1;
        }

        char endPath[MAX_PATH + 1];
        checkPath(luaL_checkstring(L, 2), endPath);

        if (endPath[0] == 0) {
            lua_pushboolean(L, false);
            return 1;
        }

        lua_pushboolean(L, rename(filePath, endPath) + 1);
        return 1;
    }

    static int fsDelete(lua_State *L) {
        char filePath[MAX_PATH + 1];
        checkPath(luaL_checkstring(L, 1), filePath);

        if (filePath[0] == 0) {
            lua_pushboolean(L, false);
            return 1;
        }

        if (remove(filePath) == 0)
            lua_pushboolean(L, true);
        else
            lua_pushboolean(L, rmdir(filePath) + 1);

        return 1;
    }

    static int fsObjCloseHandle(lua_State *L) {
        fileHandleType *data = checkFsObj(L);

        if (data->open)
            fclose(data->fileStream);

        data->open = false;

        return 0;
    }

    static int fsGetCWD(lua_State *L) {
        lua_pushstring(L, currentWorkingDirectory + strlen(scriptsPath));

        return 1;
    }

    static int fsSetCWD(lua_State *L) {
        const char *nwd = luaL_checkstring(L, 1);

        if (nwd[0] == '\\' || nwd[0] == '/') {
            size_t nwdLen = strlen(nwd);

            size_t ln = (int) (strlen(scriptsPath) + nwdLen + 2);
            auto *concatStr = new char[ln];
            sprintf(concatStr, "%s/%s", scriptsPath, nwd);

            auto *fPath = new char[MAX_PATH];

            getFullPath(concatStr, fPath);

            delete[] concatStr;

            if (strlen(fPath) < MAX_PATH) {
                strncpy(currentWorkingDirectory, fPath, strlen(fPath));
                currentWorkingDirectory[strlen(fPath)] = 0;
            }

            delete[] fPath;
        } else {
            size_t nwdlen = strlen(nwd);

            auto ln = strlen(currentWorkingDirectory) + nwdlen + 2;
            auto *concatStr = new char[ln];
            sprintf(concatStr, "%s/%s", currentWorkingDirectory, nwd);

            auto *fPath = new char[MAX_PATH];

            getFullPath(concatStr, fPath);

            delete[] concatStr;

            if (strlen(fPath) < MAX_PATH) {
                strncpy(currentWorkingDirectory, fPath, strlen(fPath));
                currentWorkingDirectory[strlen(fPath)] = 0;
            }

            delete[] fPath;
        }

        return 0;
    }

    static int fsGetClipboardText(lua_State *L) {
        if (SDL_HasClipboardText()) {
            char *text = SDL_GetClipboardText();

            lua_pushstring(L, text);

            SDL_free(text);
        } else {
            lua_pushnil(L);
        }

        return 1;
    }

    static int fsSetClipboardText(lua_State *L) {
        const char *text = luaL_checkstring(L, 1);

        SDL_SetClipboardText(text);

        return 0;
    }

    static const luaL_Reg fsLib[] = {
            {"getAttr",      fsGetAttr},
            {"open",         fsOpenFile},
            {"list",         fsList},
            {"delete",       fsDelete},
            {"mkdir",        fsMkDir},
            {"move",         fsMv},
            {"setCWD",       fsSetCWD},
            {"getCWD",       fsGetCWD},
            {"getLastFile",  fsLastOpened},
            {"getClipboard", fsGetClipboardText},
            {"setClipboard", fsSetClipboardText},
            {nullptr,        nullptr}
    };

    static const luaL_Reg fsLib_m[] = {
            {"read",  fsObjRead},
            {"write", fsObjWrite},
            {"close", fsObjCloseHandle},
            {nullptr, nullptr}
    };

    LUALIB_API int openLua(lua_State *L) {
        auto *fPath = new char[MAX_PATH];
        getFullPath(scriptsPath, fPath);

        if (strlen(fPath) < MAX_PATH)
            strncpy(currentWorkingDirectory, fPath, strlen(fPath));
        else {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Unable to initialize cwd");
            return 2;
        }

        delete[] fPath;

        luaL_newmetatable(L, "Riko4.fsObj");

        lua_pushstring(L, "__index");
        lua_pushvalue(L, -2);  /* pushes the metatable */
        lua_settable(L, -3);  /* metatable.__index = metatable */
        lua_pushstring(L, "__gc");
        lua_pushcfunction(L, fsObjCloseHandle);
        lua_settable(L, -3);

        luaL_openlib(L, nullptr, fsLib_m, 0);

        luaL_openlib(L, RIKO_FS_NAME, fsLib, 0);
        return 1;
    }
}

#pragma clang diagnostic pop
