#define LUA_LIB

#define PI 3.141592654
#define TAO PI * 2

#include "rikoAudio.h"

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_audio.h>

#include <stdlib.h>

#include <math.h>

extern bool audEnabled;

typedef struct {
    double totalTime;
    unsigned long long remainingCycles;
    double frequency;
    double frequencyShift;
    double attack;
    double release;
    float volume;
} Sound;

typedef struct node {
    Sound* data;
    struct node* next;
} node_t;

typedef struct queue {
    node_t* head;
    node_t* tail;
} queue_t;

queue_t* constructQueue() {
    queue_t* newQueue = (queue_t*)malloc(sizeof(queue_t));
    newQueue->head = NULL;
    newQueue->tail = NULL;
    return newQueue;
}

void pushToQueue(queue_t* wqueue, Sound* snd) {
    node_t* nxtNode = (node_t*)malloc(sizeof(node_t));
    nxtNode->data = snd;
    nxtNode->next = NULL;
    if (wqueue->head != NULL) 
          wqueue->head->next = nxtNode;
    else  wqueue->tail = nxtNode;
    wqueue->head = nxtNode;
}

Sound* popFromQueue(queue_t* wqueue) {
    if (wqueue->tail == NULL) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Attempt to pop from empty queue (%p)", (void*)wqueue);
        return NULL;
    }
    Sound* data = wqueue->tail->data;
    node_t* old = wqueue->tail;
    if (old == wqueue->head) {
        wqueue->head = NULL;
        wqueue->tail = NULL;
        free(old);
        return data;
    }
    wqueue->tail = wqueue->tail->next;
    free(old);

    return data;
}

void falloutQueue(queue_t* wqueue) {
    if (wqueue->tail == NULL) {
        if (wqueue->head != wqueue->tail) {
            puts("WARN: Queue has dangling head! Some elements may not be freed correctly!\n");
            free(wqueue->head);
        }
        return;
    }

    while (wqueue->tail->next != NULL) {
        Sound* snd = popFromQueue(wqueue);
        free(snd);

        if (wqueue->tail == NULL) {
            if (wqueue->head != wqueue->tail) {
                puts("WARN: Queue has dangling head! Some elements may not be freed correctly!\n");
                free(wqueue->head);
            }
            return;
        }
    }

    if (wqueue->head != wqueue->tail) {
        puts("WARN: Queue has dangling head/tail! Some elements may not be freed correctly!\n");
        free(wqueue->head);
    }

    free(wqueue->tail);
}

SDL_AudioSpec want, have;
SDL_AudioDeviceID dev;

static int sampleRate = 48000;
static int samples = 1024;
static int audDevChanCount = 1;

const int channelCount = 5;
const int queueSize = 512;
static queue* audioQueues[channelCount];
static Sound* playingAudio[channelCount];
static bool channelHasSnd[channelCount];
static double streamPhase[channelCount];
float lstRnd = 0;

void audioCallback(void *userdata, uint8_t *byteStream, int len) {
    float* floatStream = (float*) byteStream;

    for (int i = 0; i < channelCount; i++) {
        if (!channelHasSnd[i] && audioQueues[i]->tail != NULL) {
            playingAudio[i] = popFromQueue(audioQueues[i]);
            channelHasSnd[i] = true;
        }
    }

    for (int z = 0; z < samples * audDevChanCount; z++) {
        for (int cc = 0; cc < audDevChanCount; cc++) {
            floatStream[z] = 0;

            for (int i = 0; i < channelCount; i++) {
                if (!channelHasSnd[i]) {
                    if (audioQueues[i]->tail != NULL) {
                        playingAudio[i] = popFromQueue(audioQueues[i]);
                        channelHasSnd[i] = true;
                    } else {
                        continue;
                    }
                }

                if (playingAudio[i]->remainingCycles == 0) {
                    free(playingAudio[i]);

                    if (audioQueues[i]->tail != NULL) {
                        // Awesome got another sound queued up, so load it in
                        playingAudio[i] = popFromQueue(audioQueues[i]);
                    } else {
                        channelHasSnd[i] = false;
                    }
                }

                if (!channelHasSnd[i]) continue;

                double delta;
                double atC;
                double rlC;

                if (playingAudio[i]->attack == 0) {
                    atC = 1;
                } else {
                    atC = (playingAudio[i]->totalTime - ((double)playingAudio[i]->remainingCycles / sampleRate)) / playingAudio[i]->attack;
                    atC = atC > 1 ? 1 : atC;
                }

                rlC = playingAudio[i]->release - ((double)playingAudio[i]->remainingCycles / sampleRate);
                rlC = rlC > 0 ? 1 - rlC / playingAudio[i]->release : 1;
                double vol = playingAudio[i]->volume * atC * rlC;

                switch (i) {
                case 0:
                case 1:
                    // Pulse Wave
                floatStream[z] += (float)((fmod(streamPhase[i], TAO) > PI/4 ? -1 : 1) * vol);
                    streamPhase[i] += TAO * playingAudio[i]->frequency / sampleRate;
                    break;
                case 2:
                    // Triangle Wave
                floatStream[z] += (float)((1 - 4 * fabs(fmod(streamPhase[i], 1) - 0.5)) * vol);
                    streamPhase[i] += (double)playingAudio[i]->frequency / sampleRate;
                    break;
                case 3:
                    // Sawtooth Wave
                floatStream[z] += (float)((2 * fmod(streamPhase[i] - 0.5, 1) - 1) * vol);
                    streamPhase[i] += (double)playingAudio[i]->frequency / sampleRate;
                    break;
                case 4:
                    // Noise (Wave?)
                    delta = fmod((streamPhase[i] + 1), playingAudio[i]->frequency);
                    if (streamPhase[i] > delta) {
                        lstRnd = (float)((((float)rand() / (float)RAND_MAX) * 2 - 1) * vol);
                    }
                    streamPhase[i] = delta;
                    
                floatStream[z] += lstRnd;

                    break;
                }

                playingAudio[i]->remainingCycles--;
                
                playingAudio[i]->frequency += playingAudio[i]->frequencyShift;
            }
        }
    }
}

static int aud_play(lua_State *L) {
    int off = lua_gettop(L);
    if (off == 0) {
        luaL_error(L, "Expected table as first argument");
        return 0;
    }
    if (lua_type(L, -off) != LUA_TTABLE) {
        luaL_error(L, "Expected table as first argument");
        return 0;
    }

    lua_pushstring(L, "channel");
    lua_gettable(L, -1 - off);
    int chan = (int)luaL_checkinteger(L, -1);

    if (chan <= 0 || chan > channelCount) {
        luaL_error(L, "Channel must be between 1 and %d", channelCount);
    }

    lua_pushstring(L, "volume");
    lua_gettable(L, -2 - off);
    double vol;
    if (lua_isnil(L, -1)) {
        vol = 1;
    } else {
        vol = lua_tonumber(L, -1);
    }

    lua_pushstring(L, "frequency");
    lua_gettable(L, -3 - off);
    int freq = (int)luaL_checkinteger(L, -1);

    lua_pushstring(L, "shift");
    lua_gettable(L, -4 - off);
    int freqShft;
    if (lua_isnil(L, -1)) {
        freqShft = 0;
    } else {
        freqShft = (int)lua_tointeger(L, -1);
    }

    lua_pushstring(L, "time");
    lua_gettable(L, -5 - off);
    double time;
    if (lua_type(L, -1) != LUA_TNUMBER) {
        luaL_error(L, "bad argument 'time' to 'play' (number expected, got %s)", lua_typename(L, lua_type(L, -1)));
        return 0;
    } else {
        time = lua_tonumber(L, -1);
        if (time <= 0) {
            luaL_error(L, "bad argument 'time' to 'play' (number must be greater than 0)");
            return 0;
        }
    }

    lua_pushstring(L, "attack");
    lua_gettable(L, -6 - off);
    double atK = luaL_checknumber(L, -1);
    if (atK < 0) {
        luaL_error(L, "bad argument 'attack' to 'play' (number must be greater than or equal to 0)");
        return 0;
    }

    lua_pushstring(L, "release");
    lua_gettable(L, -7 - off);
    double rls = luaL_checknumber(L, -1);
    if (rls < 0) {
        luaL_error(L, "bad argument 'release' to 'play' (number must be greater than or equal to 0)");
        return 0;
    }

    Sound* puls = (Sound*)malloc(sizeof(Sound));
    if (chan == 5) {
        puls->frequency = (110 - (12 * (log(pow(2, 1 / 12) * freq / 16.35) / log(2))));
        puls->frequencyShift = ((110 - (12 * (log(pow(2, 1 / 12) * (freq + freqShft) / 16.35) / log(2)))) - puls->frequency) / (sampleRate * time);
    } else {
        puls->frequency = freq;
        puls->frequencyShift = (double)freqShft / (sampleRate * time);
    }
    
    puls->volume = vol < 0 ? 0 : (vol > 1 ? 1 : (float)vol);
    puls->totalTime = time;
    puls->attack = atK;
    puls->release = rls;
    puls->remainingCycles = (unsigned long long)(time * sampleRate);
    pushToQueue(audioQueues[chan - 1], puls);

    return 0;
}

static const luaL_Reg audLib[] = {
    { "play", aud_play },
    { NULL, NULL }
};

LUALIB_API int luaopen_aud(lua_State *L) {
    for (int i = 0; i < channelCount; i++) {
        audioQueues[i] = constructQueue();
        streamPhase[i] = 0;
    }

    if (audEnabled) {
        SDL_InitSubSystem(SDL_INIT_AUDIO);

        SDL_zero(want);
        want.freq = sampleRate;
        want.format = AUDIO_F32SYS;
        want.channels = audDevChanCount;
        want.samples = samples;
        want.callback = audioCallback;
        want.userdata = NULL;


        dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, SDL_AUDIO_ALLOW_ANY_CHANGE);
        if (dev == 0) {
            SDL_Log("Failed to open audio: %s", SDL_GetError());
        } else {
            sampleRate = have.freq;
            samples = have.samples;
            audDevChanCount = have.channels;

            if (have.format != want.format) { /* we can't let this one thing change. */
                SDL_Log("Unable to open Float32 audio.");
            } else {
                SDL_PauseAudioDevice(dev, 0); /* start audio playing. */
            }
        }
    }

    luaL_openlib(L, RIKO_AUD_NAME, audLib, 0);
    return 1;
}

void closeAudio() {
    if (dev != 0) {
        SDL_CloseAudioDevice(dev);
    }

    for (int i = 0; i < channelCount; i++) {
        falloutQueue(audioQueues[i]);
        free(audioQueues[i]);
    }
}
