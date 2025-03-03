#include <atomic>
#include <cstdlib>
#include <sstream>
#include <thread>
#include <set>

#ifndef __EMSCRIPTEN__
#  include <curlpp/cURLpp.hpp>
#  include <curlpp/Easy.hpp>
#  include <curlpp/Multi.hpp>
#  include <curlpp/Options.hpp>
#  include <functional>
#else
#  include "emscripten.h"
#endif
#include <riko.h>

#include "core/events.h"
#include "misc/luaIncludes.h"
#include "util/TableInterface.h"

#include "net.h"
#include "userdata/ResponseHandle.h"
#include "userdata/ProgressObject.h"

Uint32 riko::events::NET_SUCCESS = 0;
Uint32 riko::events::NET_FAILURE = 0;
Uint32 riko::events::NET_PROGRESS = 0;

namespace riko::net {
    int requestHandleCounter = 0;
    std::atomic<int> openThreads;
    std::set<int> activeThreadIDs;

    int init() {
#ifndef __EMSCRIPTEN__
        cURLpp::initialize(CURL_GLOBAL_ALL);
#endif
        openThreads = 0;
        activeThreadIDs = std::set<int>();

        riko::events::NET_SUCCESS = SDL_RegisterEvents(3);
        riko::events::NET_FAILURE = riko::events::NET_SUCCESS + 1;
        riko::events::NET_PROGRESS = riko::events::NET_SUCCESS + 2;
        if (riko::events::NET_SUCCESS == ((Uint32) - 1)) {
            return 2;
        }

        return 0;
    }

    void cleanup() {
#ifndef __EMSCRIPTEN__
        cURLpp::terminate();
#endif
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

    int progressCallback(int thread_id, std::string *url, double total, double now, double, double) {
        if (activeThreadIDs.count(thread_id) == 0) {
            return 1;
        }

        SDL_Event progressEvent;
        SDL_memset(&progressEvent, 0, sizeof(progressEvent));
        progressEvent.type = riko::events::NET_PROGRESS;
        progressEvent.user.data1 = new std::string(*url);
        progressEvent.user.data2 = new ProgressObject(now, total);
        SDL_PushEvent(&progressEvent);
        return 0;
    }

    void getThread(int thread_id, std::string *url, std::string *postData, std::list<std::string> *headers) {
        auto *dataStream = new std::stringstream;

#ifndef __EMSCRIPTEN__
        try {
            cURLpp::Cleanup cleanup;

            cURLpp::Easy request;
            request.setOpt<cURLpp::options::Url>(*url);

            if (postData != nullptr) {
                request.setOpt<cURLpp::options::PostFields>(*postData);
                request.setOpt<cURLpp::options::PostFieldSize>(postData->length());
            }

            if (headers != nullptr) {
                request.setOpt<cURLpp::options::HttpHeader>(*headers);
            }

            request.setOpt<cURLpp::options::UserAgent>("curl/7.61.0");

            request.setOpt<cURLpp::options::FollowLocation>(true);
            request.setOpt<cURLpp::options::MaxRedirs>(16L);

            request.setOpt<cURLpp::options::WriteStream>(dataStream);

            using namespace std::placeholders;
            cURLpp::types::ProgressFunctionFunctor progressFunctor(
                    [=](auto a, auto b, auto c, auto d) {
                        return progressCallback(thread_id, url, a, b, c, d);
                    });

            request.setOpt<cURLpp::options::ProgressFunction>(progressFunctor);
            request.setOpt<cURLpp::options::NoProgress>(false);

            request.perform();

            dispatchSuccessEvent(url, dataStream);
        } catch (cURLpp::RuntimeError &e) {
            dispatchFailureEvent(url, e.what());
        } catch (cURLpp::LogicError &e) {
            dispatchFailureEvent(url, e.what());
        }
#else
        // TODO
        // emscripten_wget(url->c_str(), dataStream->str().c_str());
        // dispatchSuccessEvent(url, dataStream);
        dispatchFailureEvent(url, "GET currently does not work in browser");
#endif

        delete url;
        delete postData;
        delete headers;

        openThreads--;
        activeThreadIDs.erase(thread_id);
    }

    static int netRequest(lua_State *L) {
        size_t urlLen;
        const char *urlData = luaL_checklstring(L, 1, &urlLen);
        auto url = new std::string(urlData, urlLen);

        std::string *postData = nullptr;
        if (lua_gettop(L) > 1) {
            size_t postLen;
            const char *postDataCStr = luaL_checklstring(L, 2, &postLen);
            postData = new std::string(postDataCStr, postLen);
        }

        std::list<std::string> *headers = nullptr;
        if (lua_gettop(L) > 2) {
            try {
                TableInterface headerTable(L, 3);

                headers = new std::list<std::string>;

                for (;;) {
                    headers->push_back(headerTable.getNextString());
                }
            } catch (const LuaError &e) {
                if (e.getErrorType() != LuaError::Type::NIL_ARG)
                    return luaL_error(L, e.what());
            }
        }

        if (openThreads >= MAX_CONCURRENT) {
            return luaL_error(L, "too many open requests");
        }

        openThreads++;
        int rid = requestHandleCounter++;
        activeThreadIDs.insert(rid);
        std::thread requestThread(getThread, rid, url, postData, headers);
        requestThread.detach();

        lua_pushinteger(L, rid);
        return 1;
    }

    static int netCancel(lua_State *L) {
        int rid = luaL_checkint(L, 1);
        lua_pushboolean(L, !!activeThreadIDs.count(rid));
        activeThreadIDs.erase(rid);

        return 1;
    }

    static const luaL_Reg netLib[] = {
        {"request", netRequest},
        {"cancel", netCancel},
        {nullptr, nullptr}
    };

    int openLua(lua_State *L) {
        ResponseHandle::initMetatable(L);

        luaL_openlib(L, RIKO_NET_NAME, netLib, 0);
        return 1;
    }
}
