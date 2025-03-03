#pragma once

#include "SDL2/SDL_gpu.h"

namespace riko::events {
    char *sane_UCS4ToUTF8(Uint32 ch, char *dst);
    const char *sane_GetScancodeName(SDL_Scancode scancode);
    const char *cleanKeyName(SDL_Keycode key);

    void loop();

    extern Uint32 NET_SUCCESS;
    extern Uint32 NET_FAILURE;
    extern Uint32 NET_PROGRESS;

    extern bool ready;
}
