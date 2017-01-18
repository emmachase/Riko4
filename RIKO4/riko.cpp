#pragma once

#include <iostream>

#include <stdio.h>
#include <stdlib.h>

#include <SDL2/SDL.h>
#include <GL/glew.h>

#include <LuaJIT/lua.hpp>
#include <LuaBridge/LuaBridge.h>

#include <rikoGPU.h>
#include <rikoAudio.h>

SDL_Window *window;

lua_State *mainThread;

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
				SDL_Log("Unknown lua error");
		}
	}
}

void createLuaInstance(const char* filename) {
	lua_State *state = luaL_newstate();

	// Make standard libraries available in the Lua object
	luaL_openlibs(state);

	luaopen_gpu(state);
	luaopen_aud(state);

	mainThread = lua_newthread(state);

	int result;

	// Load the program; this supports both source code and bytecode files.
	result = luaL_loadfile(mainThread, filename);

	if (result != 0) {
		printLuaError(result);
		return;
	}
}

int main(int argc, char* argv[]) {
	SDL_Init(SDL_INIT_VIDEO);

	window = SDL_CreateWindow(
		"RIKO 4",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		3 * 340,
		3 * 200,
		SDL_WINDOW_OPENGL
	);

	if (window == NULL) {
		printf("Could not create window: %s\n", SDL_GetError());
		return 1;
	}

	SDL_Surface *surface;     // Declare an SDL_Surface to be filled in with pixel data from an image file
	Uint16 pixels[16 * 16] = {  // ...or with raw pixel data:
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0aab, 0x0789, 0x0bcc, 0x0eee, 0x09aa, 0x099a, 0x0ddd,
		0x0fff, 0x0eee, 0x0899, 0x0fff, 0x0fff, 0x1fff, 0x0dde, 0x0dee,
		0x0fff, 0xabbc, 0xf779, 0x8cdd, 0x3fff, 0x9bbc, 0xaaab, 0x6fff,
		0x0fff, 0x3fff, 0xbaab, 0x0fff, 0x0fff, 0x6689, 0x6fff, 0x0dee,
		0xe678, 0xf134, 0x8abb, 0xf235, 0xf678, 0xf013, 0xf568, 0xf001,
		0xd889, 0x7abc, 0xf001, 0x0fff, 0x0fff, 0x0bcc, 0x9124, 0x5fff,
		0xf124, 0xf356, 0x3eee, 0x0fff, 0x7bbc, 0xf124, 0x0789, 0x2fff,
		0xf002, 0xd789, 0xf024, 0x0fff, 0x0fff, 0x0002, 0x0134, 0xd79a,
		0x1fff, 0xf023, 0xf000, 0xf124, 0xc99a, 0xf024, 0x0567, 0x0fff,
		0xf002, 0xe678, 0xf013, 0x0fff, 0x0ddd, 0x0fff, 0x0fff, 0xb689,
		0x8abb, 0x0fff, 0x0fff, 0xf001, 0xf235, 0xf013, 0x0fff, 0xd789,
		0xf002, 0x9899, 0xf001, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0xe789,
		0xf023, 0xf000, 0xf001, 0xe456, 0x8bcc, 0xf013, 0xf002, 0xf012,
		0x1767, 0x5aaa, 0xf013, 0xf001, 0xf000, 0x0fff, 0x7fff, 0xf124,
		0x0fff, 0x089a, 0x0578, 0x0fff, 0x089a, 0x0013, 0x0245, 0x0eff,
		0x0223, 0x0dde, 0x0135, 0x0789, 0x0ddd, 0xbbbc, 0xf346, 0x0467,
		0x0fff, 0x4eee, 0x3ddd, 0x0edd, 0x0dee, 0x0fff, 0x0fff, 0x0dee,
		0x0def, 0x08ab, 0x0fff, 0x7fff, 0xfabc, 0xf356, 0x0457, 0x0467,
		0x0fff, 0x0bcd, 0x4bde, 0x9bcc, 0x8dee, 0x8eff, 0x8fff, 0x9fff,
		0xadee, 0xeccd, 0xf689, 0xc357, 0x2356, 0x0356, 0x0467, 0x0467,
		0x0fff, 0x0ccd, 0x0bdd, 0x0cdd, 0x0aaa, 0x2234, 0x4135, 0x4346,
		0x5356, 0x2246, 0x0346, 0x0356, 0x0467, 0x0356, 0x0467, 0x0467,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff,
		0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff, 0x0fff
	};
	surface = SDL_CreateRGBSurfaceFrom(pixels, 16, 16, 16, 16 * 2, 0x0f00, 0x00f0, 0x000f, 0xf000);

	// The icon is attached to the window pointer
	SDL_SetWindowIcon(window, surface);


	SDL_GLContext glcontext = SDL_GL_CreateContext(window);

	if (glewInit() != GLEW_OK) {
		printf("Could not init GLEW");
		return 1;
	}

	// Dark blue background
	glClearColor(24.0/255.0f, 24.0 / 255.0f, 24.0 / 255.0f, 24.0 / 255.0f);


	SDL_Event event;

	// Clear the screen
	glClear( GL_COLOR_BUFFER_BIT );

	// Swap buffers
	createLuaInstance("scripts/boot.lua");

	if (SDL_GL_SetSwapInterval(-1) == -1) {
		SDL_GL_SetSwapInterval(1);
	}

	SDL_GL_SwapWindow(window);

	bool canRun = true;
	SDL_bool running = SDL_TRUE;
	int pushedArgs = 0;

	int lastMoveX = 0;
	int lastMoveY = 0;

	int cx;
	int cy;

	do {
		if (SDL_PollEvent(&event)) {
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
					lua_pushstring(mainThread, SDL_GetKeyName(event.key.keysym.sym));
					pushedArgs = 2;
					break;
				case SDL_MOUSEMOTION:
					cx = event.motion.x / 3;
					cy = event.motion.y / 3;
					if (cx != lastMoveX || cy != lastMoveY) {
						lua_pushstring(mainThread, "mouseMoved");
						lua_pushnumber(mainThread, cx);
						lastMoveX = cx;
						lua_pushnumber(mainThread, cy);
						lastMoveY = cy;
						pushedArgs = 3;
					}
					break;
				case SDL_MOUSEBUTTONDOWN:
					lua_pushstring(mainThread, "mousePressed");
					lua_pushnumber(mainThread, (int) event.button.x / 3);
					lua_pushnumber(mainThread, (int) event.button.y / 3);
					lua_pushnumber(mainThread, event.button.button);
					pushedArgs = 4;
					break;
				case SDL_MOUSEBUTTONUP:
					lua_pushstring(mainThread, "mouseReleased");
					lua_pushnumber(mainThread, (int)event.button.x / 3);
					lua_pushnumber(mainThread, (int)event.button.y / 3);
					lua_pushnumber(mainThread, event.button.button);
					pushedArgs = 4;
					break;
			}
		}

		if (event.type == SDL_QUIT) {
			break;
		}

		if (canRun) {
			int result = lua_resume(mainThread, pushedArgs);

			if (result == LUA_YIELD) {

			}
			else if (result == 0) {
				printf("Script finished!\n");
				canRun = false;
				//break;
			}
			else {
				printLuaError(result);
				canRun = false;
				return 1;
				//break;
			}
		}	

		pushedArgs = 0;
		SDL_Delay(1);
	}
	while(running);

	SDL_GL_DeleteContext(glcontext);
	SDL_DestroyWindow(window);

	SDL_Quit();
	return 0;
}