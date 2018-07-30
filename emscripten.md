# Emscripten Build Commands

## Riko4 Build
    em++ -DLUA_COMPAT_ALL -std=c++17 -Isrc/include -Ilibs/include -s BINARYEN_TRAP_MODE=clamp -s USE_SDL=2 ports/Lua/libLua.bc ports/sdl-gpu/libSDL2_gpu.bc src/riko.cpp src/core/* src/engine/audio.cpp src/engine/fs.cpp src/engine/gpu.cpp src/engine/image.cpp src/engine/net.cpp src/engine/userdata/ResponseHandle.cpp --preload-file data/ --preload-file scripts/ -o riko4.html

## SDL_gpu Build
    emcc \ -O2 \ -s USE_WEBGL2=1 \ -s USE_SDL=2 \ -DSDL_GPU_DISABLE_GLES_1 \ -DSDL_GPU_DISABLE_GLES_3 \ -DSDL_GPU_DISABLE_OPENGL \ -DSDL_GPU_USE_BUFFER_RESET \ -Iinclude \ -Isrc/externals/stb_image \ -Isrc/externals/stb_image_write \ src/externals/stb_image_write/stb_image_write.c \ src/SDL_gpu_shapes.c \ src/SDL_gpu_matrix.c \ src/renderer_GLES_2.c \ src/SDL_gpu_renderer.c \ src/SDL_gpu.c -o libSDL2_gpu.bc

## Lua Build
    emcc -DLUA_COMPAT_ALL -O2 lapi.c lauxlib.c lbaselib.c lbitlib.c lcode.c lcorolib.c lctype.c ldblib.c ldebug.c ldo.c ldump.c lfunc.c lgc.c linit.c liolib.c llex.c lmathlib.c lmem.c loadlib.c lobject.c lopcodes.c loslib.c lparser.c lstate.c lstring.c lstrlib.c ltable.c ltablib.c ltests.c ltm.c lundump.c lvm.c lzio.c -o libLua.bc