// luagpu_bridge.cpp
//
// See luagpu_bridge.h for design notes.

#include "luagpu_bridge.h"

#include <string>
#include <chrono>
#include <cstring>
#include <iostream>

#include "SDL2/SDL_gpu.h"

#include "misc/luaIncludes.h"
#include "misc/consts.h"
#include "engine/gpu.h"
#include "engine/fs.h"

// luaGPU host/compiler headers (submodule)
#include "ShaderCompiler.h"
#include "Compiler.h"        // UniformDesc, GlslType

// palette lives in gpu.cpp
namespace riko::gfx {
    extern Uint8 palette[COLOR_LIMIT][3];
}

// ── Internal state ────────────────────────────────────────────────────────────

namespace {
    Uint32          g_program = 0;
    GPU_ShaderBlock g_block   = {-1, -1, -1, -1};

    // Whether the program has been activated this frame already.
    bool g_frame_active = false;

    // LuaJIT registry ref keeping the ShaderHandle userdata alive.
    int           g_handle_ref = LUA_NOREF;
    ShaderHandle *g_handle_ptr = nullptr;

    // Cached uniform locations (queried once after link).
    int g_loc_rect       = -1;
    int g_loc_color      = -1;
    int g_loc_palette    = -1;
    int g_loc_time       = -1;
    int g_loc_resolution = -1;

    using Clock = std::chrono::steady_clock;
    const Clock::time_point g_start = Clock::now();

    // ── GLSL adaptation ───────────────────────────────────────────────────────

    static void replaceAll(std::string &s,
                           const std::string &from,
                           const std::string &to) {
        size_t pos = 0;
        while ((pos = s.find(from, pos)) != std::string::npos) {
            s.replace(pos, from.size(), to);
            pos += to.size();
        }
    }

    // Adapt luaGPU-emitted GLSL for the SDL_gpu pipeline.
    // The emitter now outputs only: user uniforms, structs, helper functions,
    // and shader_main — no #version, no built-in uniforms, no void main().
    // We prepend #version 150, rename shader_main → _luagpu_main, then
    // append the SDL_gpu-compatible wrapper with palette quantization.
    static std::string adaptGlsl(const std::string &raw) {
        // Preamble: everything the shader body may reference goes BEFORE the
        // emitted user code so that shader_main (renamed _luagpu_main) can
        // freely use u_rect, u_color, u_time, u_resolution, u_palette, etc.
        static const char *kPreamble = R"GLSL(#version 150

// ── SDL_gpu varyings ──────────────────────────────────────────────────────────
in vec4 color;
in vec2 texCoord;
out vec4 fragColor;

// ── Per-frame uniforms ────────────────────────────────────────────────────────
uniform vec3  u_palette[16];
uniform float u_time;
uniform vec2  u_resolution;

// ── Per-draw uniforms ─────────────────────────────────────────────────────────
// uniform vec4  u_rect;    // (x, y, w, h) in canvas pixels, top-left origin
// uniform vec3  u_color;   // palette RGB [0,1] of the draw-call colour index

// ── Palette quantization (callable from shader_main) ─────────────────────────
vec3 _quantize(vec3 c) {
    float best = 1e9;
    vec3  col  = u_palette[0];
    for (int i = 0; i < 16; ++i) {
        vec3  d = c - u_palette[i];
        float e = dot(d, d);
        if (e < best) { best = e; col = u_palette[i]; }
    }
    return col;
}

)GLSL";

        // Postamble: void main() that calls _luagpu_main with the computed uv.
        static const char *kPostamble = R"GLSL(
void main(void) {
    // UV within the draw primitive, [0,1]^2, top-left origin.
    // gl_FragCoord.y is bottom-up; u_rect.y is top-down canvas coords.
    vec2 fragCanvas = vec2(
        gl_FragCoord.x - u_rect.x,
        (u_resolution.y - gl_FragCoord.y) - u_rect.y
    );
    vec2 uv = fragCanvas / max(u_rect.zw, vec2(1.0));

    vec4 raw = _luagpu_main(uv);

    fragColor = vec4(_quantize(raw.rgb), step(0.5, raw.a));
}
)GLSL";

        std::string src = raw;
        // Rename the entry point so void main() can call it.
        replaceAll(src, "shader_main", "_luagpu_main");

        return std::string(kPreamble) + src + kPostamble;
    }

    static void cacheUniformLocations() {
        g_loc_rect       = GPU_GetUniformLocation(g_program, "u_rect");
        g_loc_color      = GPU_GetUniformLocation(g_program, "u_color");
        g_loc_palette    = GPU_GetUniformLocation(g_program, "u_palette");
        g_loc_time       = GPU_GetUniformLocation(g_program, "u_time");
        g_loc_resolution = GPU_GetUniformLocation(g_program, "u_resolution");
    }

    static void uploadFrameUniforms(lua_State *L) {
        // u_palette
        if (g_loc_palette >= 0) {
            float pal[COLOR_LIMIT * 3];
            for (int i = 0; i < COLOR_LIMIT; ++i) {
                pal[i*3+0] = riko::gfx::palette[i][0] / 255.f;
                pal[i*3+1] = riko::gfx::palette[i][1] / 255.f;
                pal[i*3+2] = riko::gfx::palette[i][2] / 255.f;
            }
            GPU_SetUniformfv(g_loc_palette, 3, COLOR_LIMIT, pal);
        }

        // u_time
        if (g_loc_time >= 0) {
            float t = std::chrono::duration<float>(Clock::now() - g_start).count();
            GPU_SetUniformf(g_loc_time, t);
        }

        // u_resolution
        if (g_loc_resolution >= 0) {
            float res[2] = { (float)SCRN_WIDTH, (float)SCRN_HEIGHT };
            GPU_SetUniformfv(g_loc_resolution, 2, 1, res);
        }

        // user upvalue uniforms
        if (!L || !g_handle_ptr || g_handle_ref == LUA_NOREF) return;
        if (g_handle_ptr->lua_closure_ref == LUA_NOREF) return;

        for (const UniformDesc &u : g_handle_ptr->uniforms) {
            int loc = (int)GPU_GetUniformLocation(g_program, u.name.c_str());
            if (loc < 0) continue;

            lua_rawgeti(L, LUA_REGISTRYINDEX, g_handle_ptr->lua_closure_ref);
            const char *uvname = lua_getupvalue(L, -1, u.upvalue_index);
            lua_remove(L, -2);
            if (!uvname) { lua_pop(L, 1); continue; }

            int ltype = lua_type(L, -1);
            GlslType gt = u.type.tag;

            if (ltype == LUA_TUSERDATA) {
                float *fp = static_cast<float *>(lua_touserdata(L, -1));
                switch (gt) {
                    case GlslType::Float: GPU_SetUniformf(loc, fp[0]); break;
                    case GlslType::Int:   GPU_SetUniformi(loc, (int)fp[0]); break;
                    case GlslType::Bool:  GPU_SetUniformi(loc, fp[0] != 0.f ? 1 : 0); break;
                    case GlslType::Vec2:  GPU_SetUniformfv(loc, 2, 1, fp); break;
                    case GlslType::Vec3:  GPU_SetUniformfv(loc, 3, 1, fp); break;
                    case GlslType::Vec4:  GPU_SetUniformfv(loc, 4, 1, fp); break;
                    case GlslType::Mat2:  GPU_SetUniformMatrixfv(loc, 1, 2, 2, false, fp); break;
                    case GlslType::Mat3:  GPU_SetUniformMatrixfv(loc, 3, 3, 3, false, fp); break;
                    case GlslType::Mat4:  GPU_SetUniformMatrixfv(loc, 6, 4, 4, false, fp); break;
                    default: break;
                }
            } else if (ltype == LUA_TNUMBER) {
                GPU_SetUniformf(loc, (float)lua_tonumber(L, -1));
            } else if (ltype == LUA_TBOOLEAN) {
                GPU_SetUniformi(loc, lua_toboolean(L, -1));
            } else if (ltype == LUA_TTABLE) {
                float vals[16] = {};
                lua_rawgeti(L, -1, 1);
                bool nested = lua_istable(L, -1);
                lua_pop(L, 1);
                if (nested) {
                    int rows = (int)lua_objlen(L, -1);
                    for (int r = 1; r <= rows && r <= 4; ++r) {
                        lua_rawgeti(L, -1, r);
                        int cols2 = (int)lua_objlen(L, -1);
                        for (int c = 1; c <= cols2 && c <= 4; ++c) {
                            lua_rawgeti(L, -1, c);
                            vals[(c-1)*rows+(r-1)] = (float)lua_tonumber(L, -1);
                            lua_pop(L, 1);
                        }
                        lua_pop(L, 1);
                    }
                    switch (gt) {
                        case GlslType::Mat2: GPU_SetUniformMatrixfv(loc,1,2,2,false,vals); break;
                        case GlslType::Mat3: GPU_SetUniformMatrixfv(loc,3,3,3,false,vals); break;
                        case GlslType::Mat4: GPU_SetUniformMatrixfv(loc,6,4,4,false,vals); break;
                        default: break;
                    }
                } else {
                    int len = (int)lua_objlen(L, -1);
                    for (int j = 1; j <= len && j <= 4; ++j) {
                        lua_rawgeti(L, -1, j);
                        vals[j-1] = (float)lua_tonumber(L, -1);
                        lua_pop(L, 1);
                    }
                    switch (gt) {
                        case GlslType::Vec2: GPU_SetUniformfv(loc, 2, 1, vals); break;
                        case GlslType::Vec3: GPU_SetUniformfv(loc, 3, 1, vals); break;
                        case GlslType::Vec4: GPU_SetUniformfv(loc, 4, 1, vals); break;
                        default: break;
                    }
                }
            }

            lua_pop(L, 1);
        }
    }

    static void freeProgram() {
        if (g_program) {
            // Deactivate before freeing — ensures draws after setShader(nil)
            // within the same frame revert to SDL_gpu's default pipeline
            // immediately, not just on the next swap.
            GPU_DeactivateShaderProgram();
            GPU_FreeShaderProgram(g_program);
            g_program = 0;
            g_block   = {-1, -1, -1, -1};
            g_loc_rect = g_loc_color = g_loc_palette =
                g_loc_time = g_loc_resolution = -1;
        }
        g_frame_active = false;
    }

}  // anonymous namespace

// ── Public API ────────────────────────────────────────────────────────────────

namespace riko::luagpu_bridge {

    static int gpu_set_shader(lua_State *L) {
        if (g_handle_ref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, g_handle_ref);
            g_handle_ref = LUA_NOREF;
            g_handle_ptr = nullptr;
        }
        freeProgram();

        if (lua_isnoneornil(L, 1)) return 0;

        ShaderHandle *h = static_cast<ShaderHandle *>(
            luaL_checkudata(L, 1, "luagpu.ShaderHandle"));

        std::string fragSrc = adaptGlsl(h->glsl);

        static const char *vertSrc =
            "#version 150\n"
            "in vec2 gpu_Vertex;\n"
            "in vec2 gpu_TexCoord;\n"
            "in vec4 gpu_Color;\n"
            "uniform mat4 gpu_ModelViewProjectionMatrix;\n"
            "out vec4 color;\n"
            "out vec2 texCoord;\n"
            "void main(void) {\n"
            "    color    = gpu_Color;\n"
            "    texCoord = vec2(gpu_TexCoord);\n"
            "    gl_Position = gpu_ModelViewProjectionMatrix\n"
            "                  * vec4(gpu_Vertex, 0.0, 1.0);\n"
            "}\n";

        Uint32 vs = GPU_CompileShader(GPU_VERTEX_SHADER, vertSrc);
        if (!vs) {
            luaL_error(L, "gpu.setShader: vertex compile failed: %s",
                       GPU_GetShaderMessage());
            return 0;
        }

        Uint32 fs = GPU_CompileShader(GPU_FRAGMENT_SHADER, fragSrc.c_str());
        if (!fs) {
            GPU_FreeShader(vs);
            std::cerr << "=== Adapted GLSL ===\n" << fragSrc << "\n=== End GLSL ===\n";
            std::cerr << "Error message from GPU: " << GPU_GetShaderMessage() << "\n";
            luaL_error(L,
                "gpu.setShader: fragment compile failed: %s\n\n",
                // "--- adapted GLSL ---\n%s\n--- end ---",
                GPU_GetShaderMessage());
            return 0;
        }

        Uint32 prog = GPU_LinkShaders(vs, fs);
        GPU_FreeShader(vs);
        GPU_FreeShader(fs);
        if (!prog) {
            luaL_error(L, "gpu.setShader: link failed: %s",
                       GPU_GetShaderMessage());
            return 0;
        }

        g_block = GPU_LoadShaderBlock(prog,
            "gpu_Vertex", "gpu_TexCoord", "gpu_Color",
            "gpu_ModelViewProjectionMatrix");

        g_program    = prog;
        g_handle_ptr = h;

        cacheUniformLocations();

        lua_pushvalue(L, 1);
        g_handle_ref = luaL_ref(L, LUA_REGISTRYINDEX);

        return 0;
    }

    void openLua(lua_State *L) {
        // Register VFS path resolver so luaGPU can open files by their
        // virtual engine paths (e.g. /home/demos/foo.lua → real host path).
        set_path_resolver([](const char *vpath, char *out, size_t outsz) -> bool {
            return !riko::fs::checkPath(vpath, out, outsz);  // checkPath: false = success
        });

        set_injected_uniforms({
            {"u_rect", GlslType::Vec4},
            {"u_color", GlslType::Vec3},
        });

        lua_getglobal(L, "gpu");
        if (lua_isnil(L, -1)) {
            lua_pop(L, 1);
            lua_newtable(L);
            lua_pushvalue(L, -1);
            lua_setglobal(L, "gpu");
        }
        lua_pushcfunction(L, gpu_set_shader);
        lua_setfield(L, -2, "setShader");
        lua_pop(L, 1);
    }

    bool isActive() {
        return g_program != 0;
    }

    void beginFrame(lua_State *L) {
        if (!g_program) return;
        if (g_frame_active) return;  // already activated this frame
        GPU_ActivateShaderProgram(g_program, &g_block);
        uploadFrameUniforms(L);
        g_frame_active = true;
    }

    void setDrawUniforms(int color,
                         float rx, float ry, float rw, float rh) {
        if (!g_frame_active) return;

        if (g_loc_rect >= 0) {
            float r[4] = { rx, ry, rw, rh };
            GPU_SetUniformfv(g_loc_rect, 4, 1, r);
        }
        if (g_loc_color >= 0) {
            float c[3] = {
                riko::gfx::palette[color][0] / 255.f,
                riko::gfx::palette[color][1] / 255.f,
                riko::gfx::palette[color][2] / 255.f
            };
            GPU_SetUniformfv(g_loc_color, 3, 1, c);
        }
    }

    void endFrame() {
        if (!g_frame_active) return;
        GPU_DeactivateShaderProgram();
        g_frame_active = false;
    }

}  // namespace riko::luagpu_bridge
