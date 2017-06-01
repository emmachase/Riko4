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
#include <string.h>

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>

#ifndef __WINDOWS__
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <limits.h>
#endif

#include "rikoFs.h"

extern char* appPath;

static int fsIsDir(lua_State *L) {
	const char *f = luaL_checkstring(L, 1);

#ifdef __WINDOWS__
	int ln = (int)(strlen(appPath) + strlen(f) + 2); // The +1 accounts for the NULL terminator
	char *concatStr = (char*)malloc(ln);
	sprintf(concatStr, "%s%s/", appPath, f);
	
	char pathStr[MAX_PATH + 1];
	unsigned long bLen = GetFullPathName(concatStr, MAX_PATH, pathStr, NULL);
	if (bLen > MAX_PATH) {
		return luaL_error(L, "path too long");
	}

	unsigned long attr = GetFileAttributes(pathStr);
	free(concatStr);

	if (attr == INVALID_FILE_ATTRIBUTES) {
		lua_pushboolean(L, false);
		return 1;
	}

	lua_pushboolean(L, ((attr & FILE_ATTRIBUTE_DIRECTORY) != 0));

	return 1;
#else
	int ln = (int)(strlen(appPath) + strlen(f) + 2); // The +1 accounts for the NULL terminator
	char *concatStr = (char*)malloc(ln);
	sprintf(concatStr, "%s%s/", appPath, f);

//        char pathStr[MAX_PATH + 1];
//        unsigned long bLen = GetFullPathName(concatStr, MAX_PATH, pathStr, NULL);
//        if (bLen > MAX_PATH) {
//                return luaL_error(L, "path too long");
//        }
	char pathStr[PATH_MAX];
	realpath(concatStr, pathStr);
	free(concatStr);

	struct stat statbuf;
	if (stat(pathStr, &statbuf) != 0) {
		lua_pushboolean(L, false);
		return 1;
	}
	
	lua_pushboolean(L, S_ISDIR(statbuf.st_mode));
	return 1;
#endif
}

static int fsList(lua_State *L) {
	const char *f = luaL_checkstring(L, 1);

#ifdef __WINDOWS__
	return luaL_error(L, "filesystem unsupported");
#else
	DIR *dp;
	struct dirent *ep;

	int ln = (int)(strlen(appPath) + strlen(f) + 2); // The +1 accounts for the NULL terminator
	char *concatStr = (char*)malloc(ln);
	sprintf(concatStr, "%s%s/", appPath, f);

	char pathStr[PATH_MAX];
	realpath(concatStr, pathStr);

	dp = opendir(pathStr);
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

static const luaL_Reg fsLib[] = {
	{ "isDir", fsIsDir },
	{ "list", fsList },
	{ NULL, NULL }
};

LUALIB_API int luaopen_fs(lua_State *L) {
	luaL_openlib(L, RIKO_FS_NAME, fsLib, 0);
	return 1;
}
