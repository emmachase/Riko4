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

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>
//
//#include <sys/types.h>
//#include <sys/stat.h>
//#include <unistd.h>

#include "rikoFs.h"

extern char* appPath;

static int fsIsDir(lua_State *L) {
	const char *f = luaL_checkstring(L, 1);
	puts(f);

#ifdef __WINDOWS__
	int ln = (int)(strlen(appPath) + strlen(f) + 2); // The +1 accounts for the NULL terminator
	char *concatStr = (char*)malloc(ln);
	sprintf(concatStr, "%s%s/", appPath, f);
	
	char pathStr[MAX_PATH + 1];
	unsigned long bLen = GetFullPathName(concatStr, MAX_PATH, pathStr, NULL);
	if (bLen > MAX_PATH) {
		return luaL_error(L, "path too long");
	}

	unsigned long attr = GetFileAttributes(concatStr);
	free(concatStr);

	if (attr == INVALID_FILE_ATTRIBUTES) {
		lua_pushboolean(L, false);
		return 1;
	}

	lua_pushboolean(L, ((attr & FILE_ATTRIBUTE_DIRECTORY) != 0));

	return 1;
#else
	return luaL_error(L, "filesystem unsupported");
#endif
}

static const luaL_Reg fsLib[] = {
	{ "isDir", fsIsDir },
	{ NULL, NULL }
};

LUALIB_API int luaopen_fs(lua_State *L) {
	luaL_openlib(L, RIKO_FS_NAME, fsLib, 0);
	return 1;
}