#include <map>

#include "SDL2/SDL.h"
#include "misc/luaIncludes.h"

#include "core/events.h"
#include "riko.h"

#include "timer.h"

namespace riko::timer {
    // Map to keep track of active timers
    static std::map<int, SDL_TimerID> activeTimers;
    static int nextTimerId = 1;

    // Callback function for SDL_AddTimer
    static Uint32 timerCallback(Uint32 interval, void *param) {
        int timerId = reinterpret_cast<intptr_t>(param);

        // Create and push the timer event
        SDL_Event timerEvent;
        SDL_memset(&timerEvent, 0, sizeof(timerEvent));
        timerEvent.type = riko::events::TIMER_EVENT;
        timerEvent.user.data1 = param;  // Pass the timer ID
        SDL_PushEvent(&timerEvent);

        // Remove the timer from active timers
        activeTimers.erase(timerId);

        // Return 0 to indicate this is a one-shot timer
        return 0;
    }

    // Lua function: os.setTimer(seconds)
    static int os_setTimer(lua_State *L) {
        double seconds = luaL_checknumber(L, 1);

        if (seconds <= 0) {
            lua_pushnil(L);
            lua_pushstring(L, "timer delay must be positive");
            return 2;
        }

        // Convert seconds to milliseconds
        Uint32 ms = static_cast<Uint32>(seconds * 1000);

        // Get a new timer ID
        int timerId = nextTimerId++;

        // Create the SDL timer
        SDL_TimerID sdlTimerId = SDL_AddTimer(
            ms,
            timerCallback,
            reinterpret_cast<void *>(static_cast<intptr_t>(timerId)));

        if (sdlTimerId == 0) {
            // Timer creation failed
            lua_pushnil(L);
            lua_pushstring(L, SDL_GetError());
            return 2;
        }

        // Store the timer
        activeTimers[timerId] = sdlTimerId;

        // Return the timer ID
        lua_pushinteger(L, timerId);
        return 1;
    }

    int init() {
        // Initialize the timer system
        nextTimerId = 1;
        activeTimers.clear();

        // Register timer event type
        riko::events::TIMER_EVENT = SDL_RegisterEvents(1);
        if (riko::events::TIMER_EVENT == ((Uint32)-1)) {
            return 1;  // Error registering event
        }

        return 0;
    }

    void cleanup() {
        // Remove all active timers
        for (const auto &[id, timerId] : activeTimers) {
            SDL_RemoveTimer(timerId);
        }
        activeTimers.clear();
    }

    int openLua(lua_State *L) {
        // Add os.setTimer function
        lua_getglobal(L, "os");
        lua_pushcfunction(L, os_setTimer);
        lua_setfield(L, -2, "setTimer");
        lua_pop(L, 1);

        return 0;
    }
}  // namespace riko::timer