#define LUA_LIB

#include <cstdlib>
#include <string.h>

#include "rikoImage.h"

#include "luaIncludes.h"
#include <SDL2/SDL.h>
#include "SDL_gpu/SDL_gpu.h"

#define clamp(v, min, max) (v < min ? min : (v > max ? max : v))

extern GPU_Target *bufferTarget;
extern GPU_Target *renderer;
extern int pixelSize;
extern int palette[16][3];
extern int paletteNum;

extern int drawOffX;
extern int drawOffY;

#define off(o, t) o - drawOffX, t - drawOffY

typedef struct {
    int width;
    int height;
    bool free;
    int clr;
    int lastRenderNum;
    int remap[16];
    bool remapped;
    char **internalRep;
    SDL_Surface *surface;
    GPU_Image *texture;
} imageType;

static float pWid = 1;
static float pHei = 1;

#if SDL_BYTEORDER == SDL_BIG_ENDIAN
    int rmask = 0xff000000;
    int gmask = 0x00ff0000;
    int bmask = 0x0000ff00;
    int amask = 0x000000ff;
#else
    int rmask = 0x000000ff;
    int gmask = 0x0000ff00;
    int bmask = 0x00ff0000;
    int amask = 0xff000000;
#endif

static int getColor(lua_State *L, int arg) {
    int color = (int)luaL_checkint(L, arg) - 1;
    return color == -2 ? -1 : (color < 0 ? 0 : (color > 15 ? 15 : color));
}

static Uint32 getRectC(imageType *data, int colorGiven) {
    int color = data->remap[colorGiven]; // Palette remapping
    return SDL_MapRGBA(data->surface->format, palette[color][0], palette[color][1], palette[color][2], 255);
}

static imageType *checkImage(lua_State *L) {
    void *ud = luaL_checkudata(L, 1, "Riko4.Image");
    luaL_argcheck(L, ud != NULL, 1, "`Image` expected");
    return (imageType *)ud;
}

bool freeCheck(lua_State *L, imageType *data) {
    if (data->free) {
        luaL_error(L, "Attempt to perform Image operation but Image was freed");
        return false;
    }
    return true;
}

static int newImage(lua_State *L) {
    int w = luaL_checkint(L, 1);
    int h = luaL_checkint(L, 2);
    size_t nbytes = sizeof(imageType);
    imageType *a = (imageType *)lua_newuserdata(L, nbytes);

    luaL_getmetatable(L, "Riko4.Image");
    lua_setmetatable(L, -2);

    a->width = w;
    a->height = h;
    a->free = false;
    a->clr = 0;
    a->lastRenderNum = paletteNum;
    for (int i = 0; i < 16; i++) {
        a->remap[i] = i;
    }

    a->internalRep = (char **) malloc(sizeof (char *) * w);
    for (int i = 0; i < w; i++) {
        a->internalRep[i] = (char *) malloc(sizeof (char) * h);
        memset(a->internalRep[i], -1, h);
    }

    a->surface = SDL_CreateRGBSurface(0, w, h, 32, rmask, gmask, bmask, amask);

    // Init to black color
    SDL_FillRect(a->surface, NULL, SDL_MapRGBA(a->surface->format, 0, 0, 0, 0));

    a->texture = GPU_CopyImageFromSurface(a->surface);
    GPU_SetImageFilter(a->texture, GPU_FILTER_NEAREST);
    GPU_SetSnapMode(a->texture, GPU_SNAP_NONE);

    return 1;
}

static int flushImage(lua_State *L) {
    imageType *data = checkImage(L);
    if (!freeCheck(L, data)) return 0;

    GPU_Rect rect = { 0, 0, data->width, data->height };
    GPU_UpdateImage(data->texture, &rect, data->surface, &rect);

    return 0;
}

static int renderImage(lua_State *L) {
    imageType *data = checkImage(L);
    if (!freeCheck(L, data)) return 0;

    if (data->lastRenderNum != paletteNum || data->remapped) {
        int rectcolor = SDL_MapRGBA(data->surface->format, 0, 0, 0, 0);
        SDL_FillRect(data->surface, NULL, rectcolor);

        for (int x = 0; x < data->width; x++) {
            for (int y = 0; y < data->height; y++) {
                SDL_Rect rect = { x, y, 1, 1 };
                int c = data->internalRep[x][y];
                if (c >= 0)
                    SDL_FillRect(data->surface, &rect, getRectC(data, c));
            }
        }

        GPU_Rect rect = { 0, 0, data->width, data->height };
        GPU_UpdateImage(data->texture, &rect, data->surface, &rect);

        data->lastRenderNum = paletteNum;
        data->remapped = false;
    }

    int x = luaL_checkint(L, 2);
    int y = luaL_checkint(L, 3);

    GPU_Rect rect = { off(x, y) };

    int top = lua_gettop(L);
    if (top > 7) {
        GPU_Rect srcRect = {
            luaL_checkint(L, 4),
            luaL_checkint(L, 5),
            clamp(luaL_checkint(L, 6), 0, data->width),
            clamp(luaL_checkint(L, 7), 0, data->height)
        };

        int scale = luaL_checkint(L, 8);

        rect.w = srcRect.w * scale;
        rect.h = srcRect.h * scale;

        GPU_BlitRect(data->texture, &srcRect, bufferTarget, &rect);
    } else if (top > 6) {
        GPU_Rect srcRect = {
            luaL_checkint(L, 4),
            luaL_checkint(L, 5),
            luaL_checkint(L, 6),
            luaL_checkint(L, 7)
        };

        rect.w = srcRect.w;
        rect.h = srcRect.h;

        GPU_BlitRect(data->texture, &srcRect, bufferTarget, &rect);
    } else if (top > 3) {
        GPU_Rect srcRect = { 0, 0, luaL_checkint(L, 4), luaL_checkint(L, 5) };

        rect.w = srcRect.w;
        rect.h = srcRect.h;

        GPU_BlitRect(data->texture, &srcRect, bufferTarget, &rect);
    } else {
        rect.w = data->width;
        rect.h = data->height;

        GPU_BlitRect(data->texture, NULL, bufferTarget, &rect);
    }

    return 0;
}

static int freeImage(lua_State *L) {
    imageType *data = checkImage(L);
    if (!freeCheck(L, data)) return 0;

    for (int i = 0; i < data->width; i++) {
        free(data->internalRep[i]);
    }
    free(data->internalRep);

    SDL_FreeSurface(data->surface);
    GPU_FreeImage(data->texture);
    data->free = true;

    return 0;
}

static void internalDrawPixel(imageType *data, int x, int y, char c) {
    if (x >= 0 && y >= 0 && x < data->width && y < data->height) {
        data->internalRep[x][y] = c;
    }
}

static int imageGetPixel(lua_State *L) {
    imageType *data = checkImage(L);

    int x = luaL_checkint(L, 2);
    int y = luaL_checkint(L, 3);

    if (x < data->width && x >= 0
        && y < data->height && y >= 0) {

        lua_pushinteger(L, data->internalRep[x][y] + 1);
    } else {
        lua_pushinteger(L, 0);
    }

    return 1;
}

static int imageRemap(lua_State *L) {
    imageType *data = checkImage(L);

    int oldColor = getColor(L, 2);
    int newColor = getColor(L, 3);

    data->remap[oldColor] = newColor;
    data->remapped = true;

    return 1;
}

static int imageDrawPixel(lua_State *L) {
    imageType *data = checkImage(L);
    if (!freeCheck(L, data)) return 0;

    int x = luaL_checkint(L, 2);
    int y = luaL_checkint(L, 3);

    int color = getColor(L, 4);

    if (color >= 0) {
        Uint32 rectcolor = getRectC(data, color);
        SDL_Rect rect = { x, y, 1, 1 };
        SDL_FillRect(data->surface, &rect, rectcolor);
        internalDrawPixel(data, x, y, color);
    }
    return 0;
}

static int imageDrawRectangle(lua_State *L) {
    imageType *data = checkImage(L);
    if (!freeCheck(L, data)) return 0;

    int x = luaL_checkint(L, 2);
    int y = luaL_checkint(L, 3);
    int w = luaL_checkint(L, 4);
    int h = luaL_checkint(L, 5);

    int color = getColor(L, 6);

    if (color >= 0) {
        Uint32 rectcolor = getRectC(data, color);
        SDL_Rect rect = { x, y, w, h };
        SDL_FillRect(data->surface, &rect, rectcolor);
        for (int xp = x; xp < x + w; xp++) {
            for (int yp = y; yp < y + h; yp++) {
                internalDrawPixel(data, xp, yp, color);
            }
        }
    }
    return 0;
}


static int imageBlitPixels(lua_State *L) {
    imageType *data = checkImage(L);
    if (!freeCheck(L, data)) return 0;

    int x = luaL_checkint(L, 2);
    int y = luaL_checkint(L, 3);
    int w = luaL_checkint(L, 4);
    int h = luaL_checkint(L, 5);

    unsigned long long amt = lua_objlen(L, -1);
    int len = (int)w*(int)h;
    if (amt < len) {
        luaL_error(L, "blitPixels expected %d pixels, got %d", len, amt);
        return 0;
    }

    for (int i = 1; i <= len; i++) {
        lua_pushnumber(L, i);
        lua_gettable(L, -2);
        if (!lua_isnumber(L, -1)) {
            luaL_error(L, "Index %d is non-numeric", i);
        }
        int color = (int)lua_tointeger(L, -1) - 1;
        if (color == -1) {
            continue;
        }

        color = color == -2 ? -1 : (color < 0 ? 0 : (color > 15 ? 15 : color));

        if (color >= 0) {
            int xp = ((i - 1) % (int)w);
            int yp = ((int)((i - 1) / (int)w));

            Uint32 rectcolor = getRectC(data, color);
            SDL_Rect rect = { x + xp, y + yp, 1, 1 };
            SDL_FillRect(data->surface, &rect, rectcolor);
            internalDrawPixel(data, x + xp, y + yp, color);
        }

        lua_pop(L, 1);
    }

    return 0;
}

static int imageClear(lua_State *L) {
    imageType *data = checkImage(L);
    if (!freeCheck(L, data)) return 0;

    int rectcolor = SDL_MapRGBA(data->surface->format, 0, 0, 0, 0);
    SDL_FillRect(data->surface, NULL, rectcolor);
    for (int xp = 0; xp < data->width; xp++) {
        for (int yp = 0; yp < data->height; yp++) {
            internalDrawPixel(data, xp, yp, 0);
        }
    }

    return 0;
}

static int imageCopy(lua_State *L) {
    imageType *src = checkImage(L);

    void *ud = luaL_checkudata(L, 2, "Riko4.Image");
    luaL_argcheck(L, ud != NULL, 1, "`Image` expected");
    imageType *dst = (imageType *)ud;

    int x = luaL_checkint(L, 3);
    int y = luaL_checkint(L, 4);
    int wi;
    int he;

    SDL_Rect srcRect;

    if (lua_gettop(L) > 4) {
        wi = luaL_checkint(L, 5);
        he = luaL_checkint(L, 6);
        //srcRect = { luaL_checkint(L, 7), luaL_checkint(L, 8), wi, he };
        srcRect.x = luaL_checkint(L, 7);
        srcRect.y = luaL_checkint(L, 8);
        srcRect.w = wi;
        srcRect.h = he;
    } else {
        //srcRect = { 0, 0, src->width, src->height };
        srcRect.x = 0;
        srcRect.y = 0;
        srcRect.w = src->width;
        srcRect.h = src->height;
        wi = src->width;
        he = src->height;
    }

    SDL_Rect rect = {x, y, wi, he};
    SDL_BlitSurface(src->surface, &srcRect, dst->surface, &rect);
    for (int xp = srcRect.x; xp < srcRect.x + srcRect.w; xp++) {
        for (int yp = srcRect.y; yp < srcRect.y + srcRect.h; yp++) {
            if (xp >= src->width || xp < 0 || yp >= src->height || yp < 0) {
                continue;
            }
            internalDrawPixel(dst, xp, yp, src->internalRep[xp][yp]);
        }
    }

    return 0;
}

static int imageToString(lua_State *L) {
    imageType *data = checkImage(L);
    if (data->free) {
        lua_pushstring(L, "Image(freed)");
    } else {
        lua_pushfstring(L, "Image(%dx%d)", data->width, data->height);
    }
    return 1;
}

static int imageGetWidth(lua_State *L) {
    imageType *data = checkImage(L);

    lua_pushinteger(L, data->width);
    return 1;
}

static int imageGetHeight(lua_State *L) {
    imageType *data = checkImage(L);

    lua_pushinteger(L, data->height);
    return 1;
}

static const luaL_Reg imageLib[] = {
    { "newImage", newImage },
    { NULL, NULL }
};

static const luaL_Reg imageLib_m[] = {
    { "__tostring", imageToString },
    { "free", freeImage },
    { "flush", flushImage },
    { "render", renderImage },
    { "clear", imageClear },
    { "drawPixel", imageDrawPixel },
    { "drawRectangle", imageDrawRectangle },
    { "blitPixels", imageBlitPixels },
    { "getPixel", imageGetPixel },
    { "remap", imageRemap },
    { "copy", imageCopy },
    { "getWidth", imageGetWidth },
    { "getHeight", imageGetHeight },
    { NULL, NULL }
};

LUALIB_API int luaopen_image(lua_State *L) {
    luaL_newmetatable(L, "Riko4.Image");

    lua_pushstring(L, "__index");
    lua_pushvalue(L, -2);  /* pushes the metatable */
    lua_settable(L, -3);  /* metatable.__index = metatable */
    lua_pushstring(L, "__gc");
    lua_pushcfunction(L, freeImage);
    lua_settable(L, -3);

    luaL_openlib(L, NULL, imageLib_m, 0);

    luaL_openlib(L, RIKO_IMAGE_NAME, imageLib, 0);

    return 1;
}