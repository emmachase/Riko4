#define LUA_LIB

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>
//
//#include <sys/types.h>
//#include <sys/stat.h>
//#include <unistd.h>

#include "rikoFs.h"

extern char* appPath;

static int fsIsDir(lua_State *L) {
	/*struct stat path_stat;
	stat(path, &path_stat);
	return S_ISREG(path_stat.st_mode);
*/
	return 0;
}

static const luaL_Reg gpuLib[] = {
	{ "isDir", fsIsDir },
	{ NULL, NULL }
};

LUALIB_API int luaopen_fs(lua_State *L) {
	luaL_openlib(L, RIKO_FS_NAME, gpuLib, 0);
	return 1;
}