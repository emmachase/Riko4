#pragma clang diagnostic push
#pragma ide diagnostic ignored "OCUnusedMacroInspection"
#define _CRT_SECURE_NO_WARNINGS

#include <iostream>
#include <cstring>
#include <string>

#include "SDL2/SDL_gpu.h"

#include "shader.h"

namespace riko::gfx {
    extern GPU_Target *renderer;
    extern bool shaderOn;
}  // namespace riko::gfx

namespace riko::shader {
    int glslOverride = 0;

    // Loads a shader and prepends version/compatibility info before compiling it.
    // Normally, you can just use GPU_LoadShader() for shader source files or GPU_CompileShader() for strings.
    // However, some hardware (certain ATI/AMD cards) does not let you put non-#version pre-processing at the top of the file.
    // Therefore, I need to prepend the version info here so I can support both GLSL and GLSLES with one shader file.
    Uint32 load_shader(GPU_ShaderEnum shader_type, const char *filename) {
        SDL_RWops *rwops;
        Uint32 shader;
        size_t header_size, file_size;
        std::string header = "";
        GPU_Renderer *renderer = GPU_GetCurrentRenderer();

        // Open file
        rwops = SDL_RWFromFile(filename, "rb");
        if (rwops == nullptr) {
            GPU_PushErrorCode("load_shader", GPU_ERROR_FILE_NOT_FOUND, "Shader file \"%s\" not found", filename);
            return 0;
        }

        // Get file size
        file_size = static_cast<size_t>(SDL_RWseek(rwops, 0, SEEK_END));
        SDL_RWseek(rwops, 0, SEEK_SET);

        // Get size from header
        if (renderer->shader_language == GPU_LANGUAGE_GLSL) {
            if (glslOverride == -1) {
                std::cout << "Maximum GLSL version is " << renderer->max_shader_version << std::endl;
            }

            int glslVersion;
            if (renderer->max_shader_version >= 150)
                glslVersion = 150;
            else
                glslVersion = 110;  // Maybe this is good enough?

            if (glslOverride > 0) {
                if (glslOverride > renderer->max_shader_version) {
                    std::cout << "Specified GLSL version '" << glslOverride
                              << "' is greater than maximum of " << renderer->max_shader_version << std::endl;
                    std::cout << "Defaulting to maximum value..." << std::endl;

                    glslVersion = renderer->max_shader_version;
                } else {
                    std::cout << "Using GLSL version " << glslOverride << std::endl;
                    glslVersion = glslOverride;
                }
            }

            header = "#version " + std::to_string(glslVersion) + "\n";
        } else if (renderer->shader_language == GPU_LANGUAGE_GLSLES)
            header = "#version 100\nprecision mediump int;\nprecision mediump float;\n";

        header_size = header.size();

        // Allocate source buffer
        std::string source;
        source.reserve(header_size + file_size + 1);

        // Prepend header
        source += header;

        // Read in source code
        SDL_RWread(rwops, (void *)(source.c_str() + strlen(source.c_str())), 1, file_size);
        source[header_size + file_size] = '\0';

        // Compile the shader
        shader = GPU_CompileShader(shader_type, source.c_str());

        // Clean up
        SDL_RWclose(rwops);

        return shader;
    }

    GPU_ShaderBlock loadShaderProgram(Uint32 *p, const char *vertex_shader_file, const char *fragment_shader_file) {
        Uint32 v, f;
        v = load_shader(GPU_VERTEX_SHADER, vertex_shader_file);

        if (!v)
            GPU_LogError("Failed to load vertex shader (%s): %s\n", vertex_shader_file, GPU_GetShaderMessage());

        f = load_shader(GPU_FRAGMENT_SHADER, fragment_shader_file);

        if (!f)
            GPU_LogError("Failed to load fragment shader (%s): %s\n", fragment_shader_file, GPU_GetShaderMessage());

        *p = GPU_LinkShaders(v, f);

        if (!*p) {
            GPU_ShaderBlock b = {-1, -1, -1, -1};
            GPU_LogError("Failed to link shader program (%s + %s): %s\n", vertex_shader_file, fragment_shader_file,
                         GPU_GetShaderMessage());
            return b;
        }

        GPU_ShaderBlock block = GPU_LoadShaderBlock(*p, "gpu_Vertex", "gpu_TexCoord", "gpu_Color",
                                                    "gpu_ModelViewProjectionMatrix");

#ifndef __APPLE__
        GPU_ActivateShaderProgram(*p, &block);
#endif

        return block;
    }

    //    void freeShader(Uint32 p) {
    //        GPU_FreeShaderProgram(p);
    //    }

    Uint32 screenShader;
    GPU_ShaderBlock screenBlock;

    void initShader() {
        screenBlock = loadShaderProgram(&screenShader, "data/shaders/common.vert", "data/shaders/common.frag");
        float res[] = {static_cast<float>(riko::gfx::renderer->base_w),
                       static_cast<float>(riko::gfx::renderer->base_h)};
        GPU_SetUniformfv(GPU_GetUniformLocation(screenShader, "resolution"), 2, 1, &res[0]);
        GPU_SetUniformi(GPU_GetUniformLocation(screenShader, "crteffect"), riko::gfx::shaderOn);
    }

    void updateShader() {
#ifndef __APPLE__
        GPU_DeactivateShaderProgram();
        GPU_ActivateShaderProgram(screenShader, &screenBlock);
#endif
    }
}  // namespace riko::shader

#pragma clang diagnostic pop
