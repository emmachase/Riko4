#pragma once

#include "SDL2/SDL_gpu.h"

namespace riko::shader {
    void initShader();
    void updateShader();
    //    void freeShader(Uint32 p);

    extern int glslOverride;
}  // namespace riko::shader
