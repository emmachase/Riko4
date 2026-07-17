#pragma once
// luagpu_bridge.h — integrates luaGPU compiled ShaderHandles into the
// Riko4 draw pipeline as per-draw-call materials.
//
// New Lua API (added to the existing `gpu` table):
//
//   gpu.setShader(handle)  — set active luaGPU shader for subsequent draws
//   gpu.setShader(nil)     — clear, revert to default rendering
//
// Performance design:
//   The shader program is activated ONCE per frame (on the first draw call
//   after gpu.setShader) and deactivated ONCE in gpu_swap before the blit.
//   Between draw calls only the two cheap per-draw uniforms (u_rect, u_color)
//   are re-uploaded.  Palette, time, resolution and user upvalue uniforms are
//   uploaded once per frame activation.
//
// Uniforms available in the shader:
//   uv           vec2     pixel coord within the draw primitive, (0,0)=top-left
//   u_color      vec3     palette RGB [0-1] of the draw-call colour index
//   u_rect       vec4     (x, y, w, h) of the draw call in canvas pixels
//   u_palette    vec3[16] full current palette, RGB [0-1]
//   u_time       float    elapsed seconds
//   u_resolution vec2     canvas resolution (always 320x180)
//   + user-defined upvalue uniforms from the shader() closure

#include "misc/luaIncludes.h"
#include "SDL2/SDL_gpu.h"

namespace riko::luagpu_bridge {
    // Register gpu.setShader into the `gpu` global table.
    void openLua(lua_State *L);

    // Returns true if a luaGPU shader is currently active.
    bool isActive();

    // Called once per frame (from gpu_swap, before any draw calls are flushed).
    // Activates the program and uploads frame-constant uniforms:
    //   palette, u_time, u_resolution, user upvalue uniforms.
    // No-op if no shader is active.
    void beginFrame(lua_State *L);

    // Called per draw call (immediately before the SDL_gpu draw command).
    // Uploads only the two cheap per-draw uniforms: u_rect and u_color.
    // No-op if no shader is active.
    void setDrawUniforms(int color,
                         float rx, float ry, float rw, float rh);

    // Called once per frame (from gpu_swap, after all draws, before GPU_Flip).
    // Deactivates the shader program.
    // No-op if no shader is active.
    void endFrame();
}
