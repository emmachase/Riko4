#define _CRT_SECURE_NO_WARNINGS
#define LUA_LIB

#if defined(_WIN32) || defined(_WIN64) || defined(__WIN32__) \
 || defined(__TOS_WIN__) || defined(__WINDOWS__)
/* Compiling for Windows */
#ifndef __WINDOWS__
#define __WINDOWS__
#endif
#  include <Windows.h>
#endif/* Predefined Windows macros */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <unistd.h>
#include <dirent.h>

#include <sys/types.h>
#include <sys/stat.h>

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>

#include "rikoFs.h"

#include "rikoConsts.h"

#ifdef __WINDOWS__
#define checkPath(luaInput, varName)                                                                                      \
    do {                                                                                                                  \
        int scriptsPathLen = (int)strlen(scriptsPath);                                                                    \
                                                                                                                          \
        int ln = (int)(scriptsPathLen + strlen(luaInput) + 1); /* The +1 accounts for the NULL terminator */              \
        char *concatStr = (char*)malloc(ln);                                                                              \
        sprintf(concatStr, "%s%s", scriptsPath, luaInput);                                                                \
                                                                                                                          \
        unsigned long bLen = GetFullPathName(concatStr, MAX_PATH, varName, NULL);                                         \
        free(concatStr);                                                                                                  \
                                                                                                                          \
        int varNameLen = (int)strlen(varName);                                                                            \
                                                                                                                          \
        if (varNameLen + 1 == scriptsPathLen) {                                                                           \
            char tmp = scriptsPath[scriptsPathLen - 1];                                                                   \
            scriptsPath[scriptsPathLen - 1] = 0;                                                                          \
            if (strcmp(varName, scriptsPath) == 0) {                                                                      \
                scriptsPath[scriptsPathLen - 1] = tmp;                                                                    \
            } else {                                                                                                      \
                scriptsPath[scriptsPathLen - 1] = tmp;                                                                    \
                return luaL_error(L, "attempt to access file outside fs sandbox");                                        \
            }                                                                                                             \
        } else if (varNameLen > scriptsPathLen) {                                                                         \
            char tmp = varName[scriptsPathLen];                                                                           \
            varName[scriptsPathLen] = 0;                                                                                  \
            if (strcmp(varName, scriptsPath) == 0) {                                                                      \
                varName[scriptsPathLen] = tmp;                                                                            \
            } else {                                                                                                      \
                return luaL_error(L, "attempt to access file outside fs sandbox");                                        \
            }                                                                                                             \
        } else {                                                                                                          \
            return luaL_error(L, "attempt to access file outside fs sandbox");                                            \
        }                                                                                                                 \
    } while (0);
#else
#define checkPath(luaInput, varName)                                                                                      \
    do {                                                                                                                  \
        int scriptsPathLen = (int)strlen(scriptsPath);                                                                    \
                                                                                                                          \
        int ln = (int)(scriptsPathLen + strlen(luaInput) + 2); /* The +1 accounts for the NULL terminator */              \
        char *concatStr = (char*)malloc(ln);                                                                              \
        sprintf(concatStr, "%s/%s", scriptsPath, luaInput);                                                               \
                                                                                                                          \
        realpath(concatStr, varName);                                                                                     \
        free(concatStr);                                                                                                  \
                                                                                                                          \
        int varNameLen = (int)strlen(varName);                                                                            \
                                                                                                                          \
        if (varNameLen + 1 == scriptsPathLen) {                                                                           \
                char tmp = scriptsPath[scriptsPathLen - 1];                                                               \
                scriptsPath[scriptsPathLen - 1] = 0;                                                                      \
                if (strcmp(varName, scriptsPath) == 0) {                                                                  \
                        scriptsPath[scriptsPathLen - 1] = tmp;                                                            \
                } else {                                                                                                  \
                        scriptsPath[scriptsPathLen - 1] = tmp;                                                            \
                        return luaL_error(L, "attempt to access file outside fs sandbox");                                \
                }                                                                                                         \
        } else if (varNameLen > scriptsPathLen) {                                                                         \
                char tmp = varName[scriptsPathLen];                                                                       \
                varName[scriptsPathLen] = 0;                                                                              \
                if (strcmp(varName, scriptsPath) == 0) {                                                                  \
                        varName[scriptsPathLen] = tmp;                                                                    \
                } else {                                                                                                  \
                        return luaL_error(L, "attempt to access file outside fs sandbox");                                \
                }                                                                                                         \
        } else {                                                                                                          \
                return luaL_error(L, "attempt to access file outside fs sandbox");                                        \
        }                                                                                                                 \
    } while (0);
#endif

extern char* scriptsPath;

typedef struct {
    FILE *fileStream;
    bool open;
    bool canWrite;
} fileHandleType;

static fileHandleType *checkFsObj(lua_State *L) {
    void *ud = luaL_checkudata(L, 1, "Riko4.fsObj");
    luaL_argcheck(L, ud != NULL, 1, "`FileHandle` expected");
    return (fileHandleType *)ud;
}

static int fsGetAttr(lua_State *L) {
    char filePath[MAX_PATH + 1];
    checkPath(luaL_checkstring(L, 1), filePath);

#ifdef __WINDOWS__
    unsigned long attr = GetFileAttributes(filePath);

    if (attr == INVALID_FILE_ATTRIBUTES) {
        lua_pushinteger(L, 0b11111110);
        
        return 1;
    }

    int attrOut = ((attr & FILE_ATTRIBUTE_READONLY)  != 0) * 0b00000011 +
                  ((attr & FILE_ATTRIBUTE_DIRECTORY) != 0) * 0b00000101;

    lua_pushinteger(L, attrOut);

    return 1;
#else
    struct stat statbuf;
    if (stat(filePath, &statbuf) != 0) {
        lua_pushinteger(L, 0b11111111);
        return 1;
    }

    int attrOut = ((access(filePath, W_OK)  * 0b00000001) +
                   (S_ISDIR(statbuf.st_mode) * 0b00000010));
    
    lua_pushinteger(L, attrOut);
    return 1;
#endif
}

static int fsList(lua_State *L) {
    char filePath[MAX_PATH + 1];
    checkPath(luaL_checkstring(L, 1), filePath);

#ifdef __WINDOWS__
    return luaL_error(L, "filesystem unsupported");
#else
    DIR *dp;
    struct dirent *ep;

    dp = opendir(filePath);
    if (dp != NULL) {
        lua_newtable(L);
        int i = 1;

        while (ep = readdir(dp)) {
            lua_pushinteger(L, i);
            lua_pushstring(L, ep->d_name);
            lua_rawset(L, -3);
            i++;
        }
        closedir(dp);

        return 1;
    } else {
        return luaL_error(L, "Couldn't open the directory");
    }
#endif
}

static int fsOpenFile(lua_State *L) {
    char filePath[MAX_PATH + 1];
    checkPath(luaL_checkstring(L, 1), filePath);

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

    if (fileHandle_o == NULL)
        return 0;

    size_t nbytes = sizeof(fileHandleType);
    fileHandleType *outObj = (fileHandleType *)lua_newuserdata(L, nbytes);

    luaL_getmetatable(L, "Riko4.fsObj");
    lua_setmetatable(L, -2);

    *outObj = {
        fileHandle_o, 
        true,
        mode[0] != 'r'
    };

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

static int fsObjRead(lua_State *L) {
    fileHandleType *data = checkFsObj(L);

    if (!data->open)
        return luaL_error(L, "file handle was closed");

    if (data->canWrite)
        return luaL_error(L, "file is open for writing");
    
    int num = lua_gettop(L);
    if (num == 0) {
        // Read line

        size_t bufLen = sizeof(char) * (FS_LINE_INCR + 1);
        char *dataBuf = (char*)malloc(bufLen);
        if (dataBuf == NULL) return luaL_error(L, "unable to allocate enough memory for read operation");

        fgets(dataBuf, FS_LINE_INCR, data->fileStream);

        size_t dataBufLen = strlen(dataBuf);
        if (dataBuf[dataBufLen - 1] == '\n') {
            lua_pushlstring(L, dataBuf, dataBufLen - 1);
            free(dataBuf);
            return 1;
        } else if (feof(data->fileStream)) {
            lua_pushlstring(L, dataBuf, dataBufLen);
            free(dataBuf);
            return 1;
        }

        for (int i = 1;; i++) {
            bufLen += sizeof(char) * FS_LINE_INCR;
            dataBuf = (char*)realloc(dataBuf, bufLen);
            if (dataBuf == NULL) return luaL_error(L, "unable to allocate enough memory for read operation");

            fgets(dataBuf + i * (FS_LINE_INCR - 1) * sizeof(char), FS_LINE_INCR, data->fileStream);

            size_t dataBufLen = strlen(dataBuf);
            if (dataBuf[dataBufLen - 1] == '\n') {
                lua_pushlstring(L, dataBuf, dataBufLen - 1);
                free(dataBuf);
                return 1;
            } else if (feof(data->fileStream)) {
                lua_pushlstring(L, dataBuf, dataBufLen);
                free(dataBuf);
                return 1;
            }
        }

        return 0;
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

                char *dataBuf = (char*)malloc(sizeof(char) * (lSize + 1));
                if (dataBuf == NULL) return luaL_error(L, "unable to allocate enough memory for read operation");

                size_t result = fread(dataBuf, 1, lSize, data->fileStream);
                if (result != lSize) return luaL_error(L, "unknown read error");

                dataBuf[result] = 0;

                lua_pushlstring(L, dataBuf, result);

                free(dataBuf);

                return 1;
            } else if (mode[1] == 'l') {
                // Read line

                size_t bufLen = sizeof(char) * (FS_LINE_INCR + 1);
                char *dataBuf = (char*)malloc(bufLen);
                if (dataBuf == NULL) return luaL_error(L, "unable to allocate enough memory for read operation");

                fgets(dataBuf, FS_LINE_INCR, data->fileStream);

                size_t dataBufLen = strlen(dataBuf);
                if (dataBuf[dataBufLen - 1] == '\n') {
                    lua_pushlstring(L, dataBuf, dataBufLen - 1);
                    free(dataBuf);
                    return 1;
                } else if (feof(data->fileStream)) {
                    lua_pushlstring(L, dataBuf, dataBufLen);
                    free(dataBuf);
                    return 1;
                }

                for (int i = 1;; i++) {
                    bufLen += sizeof(char) * FS_LINE_INCR;
                    dataBuf = (char*)realloc(dataBuf, bufLen);
                    if (dataBuf == NULL) return luaL_error(L, "unable to allocate enough memory for read operation");

                    fgets(dataBuf + i * (FS_LINE_INCR - 1) * sizeof(char), FS_LINE_INCR, data->fileStream);

                    size_t dataBufLen = strlen(dataBuf);
                    if (dataBuf[dataBufLen - 1] == '\n') {
                        lua_pushlstring(L, dataBuf, dataBufLen - 1);
                        free(dataBuf);
                        return 1;
                    } else if (feof(data->fileStream)) {
                        lua_pushlstring(L, dataBuf, dataBufLen);
                        free(dataBuf);
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
        int len = luaL_checkinteger(L, 2);

        // Read 'len' bytes

        char *dataBuf = (char*)malloc(sizeof(char) * (len + 1));
        if (dataBuf == NULL) return luaL_error(L, "unable to allocate enough memory for read operation");

        size_t result = fread(dataBuf, sizeof(char), len, data->fileStream);

        dataBuf[result] = 0;

        lua_pushlstring(L, dataBuf, result);

        free(dataBuf);

        return 1;
    } else {
        const char *typen = lua_typename(L, type);
        int len = 16 + strlen(typen);
        char *emsg = (char*)malloc(len);
        sprintf(emsg, "%s was unexpected", typen);
        return luaL_argerror(L, 2, emsg);
        free(emsg);
    }

    return 0;
}

static int fsObjCloseHandle(lua_State *L) {
    fileHandleType *data = checkFsObj(L);

    if (data->open)
        fclose(data->fileStream);

    data->open = false;

    return 0;
}

static const luaL_Reg fsLib[] = {
    { "getAttr", fsGetAttr },
    { "open", fsOpenFile },
    { "list", fsList },
    { NULL, NULL }
};

static const luaL_Reg fsLib_m[] = {
    { "read", fsObjRead },
    { "write", fsObjWrite },
    { "close", fsObjCloseHandle },
    { NULL, NULL }
};

LUALIB_API int luaopen_fs(lua_State *L) {
    luaL_newmetatable(L, "Riko4.fsObj");

    lua_pushstring(L, "__index");
    lua_pushvalue(L, -2);  /* pushes the metatable */
    lua_settable(L, -3);  /* metatable.__index = metatable */
    //lua_pushstring(L, "__gc");
    //lua_pushcfunction(L, freeImage);
    //lua_settable(L, -3);

    luaL_openlib(L, NULL, fsLib_m, 0);

    luaL_openlib(L, RIKO_FS_NAME, fsLib, 0);
    return 1;
}