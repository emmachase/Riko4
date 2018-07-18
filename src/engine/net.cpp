#include <atomic>
#include <cstdlib>
#include <sstream>
#include <thread>

#include <curlpp/cURLpp.hpp>
#include <curlpp/Easy.hpp>
#include <curlpp/Multi.hpp>
#include <curlpp/Options.hpp>
#include <riko.h>

#include "events.h"
#include "luaIncludes.h"

#include "net.h"
#include "userdata/ResponseHandle.h"

Uint32 riko::events::NET_SUCCESS = 0;
Uint32 riko::events::NET_FAILURE = 0;

namespace riko::net {
    std::atomic<int> openThreads;

    int init() {
        cURLpp::initialize(CURL_GLOBAL_ALL);
        openThreads = 0;

        riko::events::NET_SUCCESS = SDL_RegisterEvents(2);
        riko::events::NET_FAILURE = riko::events::NET_SUCCESS + 1;
        if (riko::events::NET_SUCCESS == ((Uint32) - 1)) {
            return 2;
        }

        return 0;
    }

    void cleanup() {
        cURLpp::terminate();
    }

    void dispatchSuccessEvent(std::string *url, std::stringstream *dataStream) {
        SDL_Event successEvent;
        SDL_memset(&successEvent, 0, sizeof(successEvent));
        successEvent.type = riko::events::NET_SUCCESS;
        successEvent.user.data1 = new std::string(*url);
        successEvent.user.data2 = new ResponseHandle(dataStream);
        SDL_PushEvent(&successEvent);
    }

    void dispatchFailureEvent(std::string *url, const char *error) {
        SDL_Event failureEvent;
        SDL_memset(&failureEvent, 0, sizeof(failureEvent));
        failureEvent.type = riko::events::NET_FAILURE;
        auto *errorCopy = new std::string(error);
        failureEvent.user.data1 = new std::string(*url);
        failureEvent.user.data2 = errorCopy;
        SDL_PushEvent(&failureEvent);
    }

    void getThread(std::string *url) {
        try {
            cURLpp::Cleanup cleanup;

            cURLpp::Easy request;
            request.setOpt<cURLpp::options::Url>(*url);

            request.setOpt<cURLpp::options::FollowLocation>(true);
            request.setOpt<cURLpp::options::MaxRedirs>(16L);

            auto *dataStream = new std::stringstream;
            request.setOpt<cURLpp::options::WriteStream>(dataStream);

            request.perform();

            dispatchSuccessEvent(url, dataStream);
        } catch (cURLpp::RuntimeError &e) {
            dispatchFailureEvent(url, e.what());
        } catch (cURLpp::LogicError &e) {
            dispatchFailureEvent(url, e.what());
        }

        delete url;

        openThreads--;
    }

    static int netRequest(lua_State *L) {
        auto url = new std::string(luaL_checkstring(L, 1));

        if (openThreads >= MAX_CONCURRENT) {
            return luaL_error(L, "too many open requests");
        }

        openThreads++;
        std::thread requestThread(getThread, url);
        requestThread.detach();

        return 0;
    }

    static const luaL_Reg netLib[] = {
        {"request", netRequest},
        {nullptr, nullptr}
    };

    LUALIB_API int openLua(lua_State *L) {
        ResponseHandle::initMetatable(L);

        luaL_openlib(L, RIKO_NET_NAME, netLib, 0);
        return 1;
    }
}
