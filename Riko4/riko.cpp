#pragma once

#include <iostream>

#include <stdio.h>
#include <stdlib.h>

#include <SDL2/SDL.h>
#include <GL/glew.h>

#include <LuaJIT/lua.hpp>
#include <LuaBridge/LuaBridge.h>

#include <LFS/lfs.h>

#include <rikoGPU.h>
#include <rikoAudio.h>
#include <rikoImage.h>

SDL_Window *window;

lua_State *mainThread;

void printLuaError(int result) {
	if (result != 0) {
		switch (result) {
			case LUA_ERRRUN:
				SDL_Log("Lua Runtime error");
				//SDL_Log(luaL_checkstring(mainThread, 1));
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

void createLuaInstance(const char* filename) {
	lua_State *state = luaL_newstate();

	// Make standard libraries available in the Lua object
	luaL_openlibs(state);

	//luaopen_lfs(state);

	luaopen_gpu(state);
	luaopen_aud(state);
	luaopen_image(state);

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
		"Riko4",
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
	surface = SDL_LoadBMP("icon.ico");

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
	int mult;

	int exitCode = 0;

	while (running) {
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
				case SDL_MOUSEWHEEL:
					lua_pushstring(mainThread, "mouseWheel");
					mult = (event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED) ? -1 : 1;
					
					lua_pushnumber(mainThread, event.wheel.y * mult);
					lua_pushnumber(mainThread, event.wheel.x * mult);
					pushedArgs = 3;
					break;
				case SDL_MOUSEMOTION:
					cx = event.motion.x / 3;
					cy = event.motion.y / 3;
					if (cx != lastMoveX || cy != lastMoveY) {
						lua_pushstring(mainThread, "mouseMoved");
						lua_pushnumber(mainThread, cx);
						lua_pushnumber(mainThread, cy);
						lua_pushnumber(mainThread, cx - lastMoveX);
						lua_pushnumber(mainThread, cy - lastMoveY);
						lastMoveX = cx;
						lastMoveY = cy;
						pushedArgs = 5;
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

			if (result == 0) {
				printf("Script finished!\n");
				canRun = false;
			} else if (result != LUA_YIELD) {
				printLuaError(result);
				canRun = false;
				exitCode = 1;
			}
		}	

		pushedArgs = 0;
		SDL_Delay(1);
	}

	SDL_GL_DeleteContext(glcontext);
	SDL_DestroyWindow(window);

	SDL_Quit();
	return exitCode;
}