#define PI 3.141592654
#define TAO (PI * 2)

#include <cstdlib>
#include <cmath>

#include "SDL2/SDL_gpu.h"

#include "misc/luaIncludes.h"

#include "audio.h"
#include "util/TableInterface.h"
#include "engine/userdata/sequence.h"

#ifdef __WINDOWS__
#define random() rand()
#endif

// NOTE_POW is the twelfth root of 2
#define NOTE_POW 1.059463094359

namespace riko::audio {
    bool audioEnabled = true;
    bool audioInitialized = false;

    struct Sound {
        double totalTime;
        unsigned long long totalCycles;
        unsigned long long remainingCycles;
        double frequency;
        double frequencyShift;
        double attack;
        double release;
        float volume;
        int arpSequence;
        int pitchSequence;
        int dutySequence;
        int volumeSequence;
        size_t arpIndex;
        size_t pitchIndex;
        size_t dutyIndex;
        size_t volumeIndex;
    };

    struct Node {
        Sound *data;
        struct Node *next;
    };

    struct Queue {
        Node *head;
        Node *tail;
    };

    Queue *constructQueue() {
        auto *newQueue = new Queue;
        newQueue->head = nullptr;
        newQueue->tail = nullptr;
        return newQueue;
    }

    void pushToQueue(Queue *wQueue, Sound *snd) {
        auto *nxtNode = new Node;
        nxtNode->data = snd;
        nxtNode->next = nullptr;
        if (wQueue->head != nullptr)
            wQueue->head->next = nxtNode;
        else
            wQueue->tail = nxtNode;
        wQueue->head = nxtNode;
    }

    Sound *popFromQueue(Queue *wQueue) {
        if (wQueue->tail == nullptr) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Attempt to pop from empty queue (%p)", (void *)wQueue);
            return nullptr;
        }
        Sound *data = wQueue->tail->data;
        Node *old = wQueue->tail;
        if (old == wQueue->head) {
            wQueue->head = nullptr;
            wQueue->tail = nullptr;
            delete old;
            return data;
        }
        wQueue->tail = wQueue->tail->next;
        delete old;

        return data;
    }

    void falloutQueue(Queue *wQueue) {
        if (wQueue->tail == nullptr) {
            if (wQueue->head != wQueue->tail) {
                puts("WARN: Queue has dangling head! Some elements may not be freed correctly!\n");
                delete wQueue->head;
            }
            return;
        }

        while (wQueue->tail->next != nullptr) {
            Sound *snd = popFromQueue(wQueue);
            delete snd;

            if (wQueue->tail == nullptr) {
                if (wQueue->head != wQueue->tail) {
                    puts("WARN: Queue has dangling head! Some elements may not be freed correctly!\n");
                    delete wQueue->head;
                }
                return;
            }
        }

        if (wQueue->head != wQueue->tail) {
            puts("WARN: Queue has dangling head/tail! Some elements may not be freed correctly!\n");
            delete wQueue->head;
        }

        delete wQueue->tail;
    }

    SDL_AudioSpec want, have;
    SDL_AudioDeviceID dev;

    static int sampleRate = 48000;
    static int sequenceRate = sampleRate / 60;
    static Uint16 samples = 1024;
    static Uint8 audDevChanCount = 1;

    const int channelCount = 5;
    const int sequenceCount = 64;
    // const int queueSize = 512;
    static Sequence *sequenceMap[sequenceCount];
    static Queue *audioQueues[channelCount];
    static Sound *playingAudio[channelCount];
    static bool channelHasSnd[channelCount];
    static double streamPhase[channelCount];
    float lstRnd = 0;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
    void audioCallback(void *userdata, uint8_t *byteStream, int len) {
        auto *floatStream = (float *)byteStream;

        for (int i = 0; i < channelCount; i++) {
            if (!channelHasSnd[i] && audioQueues[i]->tail != nullptr) {
                playingAudio[i] = popFromQueue(audioQueues[i]);
                channelHasSnd[i] = true;
            }
        }

        for (int z = 0; z < samples * audDevChanCount; z++) {
            for (int cc = 0; cc < audDevChanCount; cc++) {
                floatStream[z] = 0;

                for (int i = 0; i < channelCount; i++) {
                    if (!channelHasSnd[i]) {
                        if (audioQueues[i]->tail != nullptr) {
                            playingAudio[i] = popFromQueue(audioQueues[i]);
                            channelHasSnd[i] = true;
                        } else {
                            continue;
                        }
                    }

                    if (playingAudio[i]->remainingCycles == 0) {
                        delete playingAudio[i];

                        if (audioQueues[i]->tail != nullptr) {
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

                    if (playingAudio[i]->release == 0) {
                        rlC = 1;
                    } else {
                        rlC = playingAudio[i]->release - ((double)playingAudio[i]->remainingCycles / sampleRate);
                        rlC = rlC > 0 ? 1 - rlC / playingAudio[i]->release : 1;
                    }

                    double vol = playingAudio[i]->volume * atC * rlC;
                    if (playingAudio[i]->volumeSequence != -1) {
                        Sequence *volumeSequence = sequenceMap[playingAudio[i]->volumeSequence];
                        if (playingAudio[i]->totalCycles % sequenceRate == 0) {
                            playingAudio[i]->volumeIndex++;
                            if (playingAudio[i]->volumeIndex >= volumeSequence->getSize()) {
                                if (volumeSequence->doesLoop()) {
                                    playingAudio[i]->volumeIndex = volumeSequence->getLoopPoint();
                                } else {
                                    playingAudio[i]->volumeIndex--;
                                }
                            }
                        }

                        int bendValue = volumeSequence->getData()[playingAudio[i]->volumeIndex];
                        bendValue = bendValue > 15 ? 15 : (bendValue < 0 ? 0 : bendValue);
                        vol *= (static_cast<double>(bendValue) / 15);
                    }

                    double effectiveFrequency = playingAudio[i]->frequency;
                    if (playingAudio[i]->arpSequence != -1) {
                        Sequence *arpSequence = sequenceMap[playingAudio[i]->arpSequence];
                        if (playingAudio[i]->totalCycles % sequenceRate == 0) {
                            playingAudio[i]->arpIndex++;
                            if (playingAudio[i]->arpIndex >= arpSequence->getSize()) {
                                if (arpSequence->doesLoop()) {
                                    playingAudio[i]->arpIndex = arpSequence->getLoopPoint();
                                } else {
                                    playingAudio[i]->arpIndex--;
                                }
                            }
                        }

                        int arpValue = arpSequence->getData()[playingAudio[i]->arpIndex];
                        effectiveFrequency *= pow(NOTE_POW, arpValue);
                    }

                    if (playingAudio[i]->pitchSequence != -1) {
                        Sequence *pitchSequence = sequenceMap[playingAudio[i]->pitchSequence];
                        if (playingAudio[i]->totalCycles % sequenceRate == 0) {
                            playingAudio[i]->pitchIndex++;
                            if (playingAudio[i]->pitchIndex >= pitchSequence->getSize()) {
                                if (pitchSequence->doesLoop()) {
                                    playingAudio[i]->pitchIndex = pitchSequence->getLoopPoint();
                                } else {
                                    playingAudio[i]->pitchIndex--;
                                }
                            }

                            int bendValue = pitchSequence->getData()[playingAudio[i]->pitchIndex];
                            playingAudio[i]->frequency += bendValue;
                        }
                    }

                    double dutyFactor = PI / 4;
                    if (playingAudio[i]->dutySequence != -1) {
                        Sequence *dutySequence = sequenceMap[playingAudio[i]->dutySequence];
                        if (playingAudio[i]->totalCycles % sequenceRate == 0) {
                            playingAudio[i]->dutyIndex++;
                            if (playingAudio[i]->dutyIndex >= dutySequence->getSize()) {
                                if (dutySequence->doesLoop()) {
                                    playingAudio[i]->dutyIndex = dutySequence->getLoopPoint();
                                } else {
                                    playingAudio[i]->dutyIndex--;
                                }
                            }
                        }

                        int arpValue = dutySequence->getData()[playingAudio[i]->dutyIndex];
                        switch (arpValue) {
                            case 0:
                                dutyFactor = PI / 8;
                                break;
                            case 2:
                                dutyFactor = PI / 2;
                                break;
                            case 3:
                                dutyFactor = 3 * PI / 4;
                                break;
                            default:
                                break;
                        }
                    }

                    switch (i) {
                        case 0:
                        case 1:
                            // Pulse Wave
                            floatStream[z] += (float)((fmod(streamPhase[i], TAO) > dutyFactor ? -1 : 1) * vol);
                            streamPhase[i] += TAO * effectiveFrequency / sampleRate;
                            break;
                        case 2:
                            // Triangle Wave
                            floatStream[z] += (float)((1 - 4 * fabs(fmod(streamPhase[i], 1) - 0.5)) * vol);
                            streamPhase[i] += effectiveFrequency / sampleRate;
                            break;
                        case 3:
                            // Sawtooth Wave
                            floatStream[z] += (float)((2 * fmod(streamPhase[i] - 0.5, 1) - 1) * vol);
                            streamPhase[i] += effectiveFrequency / sampleRate;
                            break;
                        case 4:
                            // Noise (Wave?)
                            delta = fmod((streamPhase[i] + 1), effectiveFrequency);
                            if (streamPhase[i] > delta) {
                                lstRnd = (float)((((float)random() / (float)RAND_MAX) * 2 - 1) * vol);
                            }
                            streamPhase[i] = delta;

                            floatStream[z] += lstRnd;

                            break;
                        default:
                            break;
                    }

                    playingAudio[i]->remainingCycles--;
                    playingAudio[i]->totalCycles++;

                    playingAudio[i]->frequency += playingAudio[i]->frequencyShift;
                }
            }
        }
    }
#pragma clang diagnostic pop

    static int aud_stopChan(lua_State *L) {
        int chan = luaL_checkint(L, 1) - 1;
        if (chan < 0 || chan >= channelCount) {
            lua_pushboolean(L, false);
            return 1;
        }

        if (!channelHasSnd[chan]) {
            if (audioQueues[chan]->tail != nullptr) {
                playingAudio[chan] = popFromQueue(audioQueues[chan]);
                channelHasSnd[chan] = true;
            } else {
                lua_pushboolean(L, false);
                return 1;
            }
        }

        delete playingAudio[chan];

        while (audioQueues[chan]->tail != nullptr) {
            playingAudio[chan] = popFromQueue(audioQueues[chan]);
            delete playingAudio[chan];
        }

        channelHasSnd[chan] = false;

        streamPhase[chan] = 0;

        lua_pushboolean(L, true);
        return 1;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
    static int aud_stopAll(lua_State *L) {
        for (int i = 0; i < channelCount; i++) {
            if (!channelHasSnd[i]) {
                if (audioQueues[i]->tail != nullptr) {
                    playingAudio[i] = popFromQueue(audioQueues[i]);
                    channelHasSnd[i] = true;
                } else {
                    continue;
                }
            }

            delete playingAudio[i];

            while (audioQueues[i]->tail != nullptr) {
                playingAudio[i] = popFromQueue(audioQueues[i]);
                delete playingAudio[i];
            }

            channelHasSnd[i] = false;

            streamPhase[i] = 0;
        }

        return 0;
    }
#pragma clang diagnostic pop

    static int aud_play(lua_State *L) {
        try {
            TableInterface interface(L, 1);

            int chan = interface.getInteger("channel");
            if (chan <= 0 || chan > channelCount)
                interface.throwError("channel must be between 1 and " + std::to_string(channelCount));

            int freq = interface.getInteger("frequency");
            int freqShift = interface.getInteger("shift", 0);
            double vol = interface.getNumber("volume", 0.015);
            double time = interface.getNumber("time");
            if (time <= 0)
                interface.throwError("time must be greater than 0");

            double atK = interface.getNumber("attack", 0);
            if (atK < 0)
                interface.throwError("attack must be greater than or equal to 0");

            double rls = interface.getNumber("release", 0);
            if (rls < 0)
                interface.throwError("release must be greater than or equal to 0");

            int arpSequence = interface.getInteger("arpeggio", 0) - 1;
            if (arpSequence != -1) {
                if (arpSequence < 0 || arpSequence >= sequenceCount)
                    interface.throwError("arpeggio must be between 1 and " + std::to_string(sequenceCount));

                if (!sequenceMap[arpSequence])
                    interface.throwError("invalid sequence (loadSequence first)");
            }

            int pitchSequence = interface.getInteger("pitchBend", 0) - 1;
            if (pitchSequence != -1) {
                if (pitchSequence < 0 || pitchSequence >= sequenceCount)
                    interface.throwError("pitchBend must be between 1 and " + std::to_string(sequenceCount));

                if (!sequenceMap[pitchSequence])
                    interface.throwError("invalid sequence (loadSequence first)");
            }

            int dutySequence = interface.getInteger("duty", 0) - 1;
            if (dutySequence != -1) {
                if (dutySequence < 0 || dutySequence >= sequenceCount)
                    interface.throwError("duty must be between 1 and " + std::to_string(sequenceCount));

                if (!sequenceMap[dutySequence])
                    interface.throwError("invalid sequence (loadSequence first)");
            }

            int volumeSequence = interface.getInteger("volSlide", 0) - 1;
            if (volumeSequence != -1) {
                if (volumeSequence < 0 || volumeSequence >= sequenceCount)
                    interface.throwError("volSlide must be between 1 and " + std::to_string(sequenceCount));

                if (!sequenceMap[volumeSequence])
                    interface.throwError("invalid sequence (loadSequence first)");
            }

            auto *pulse = new Sound;
            if (chan == 5) {
                pulse->frequency = (110 - (12 * (log(pow(2, 1.0 / 12) * freq / 16.35) / log(2))));
                pulse->frequencyShift = ((110 - (12 * (log(pow(2, 1.0 / 12) * (freq + freqShift) / 16.35) / log(2)))) -
                                         pulse->frequency) /
                                        (sampleRate * time);
            } else {
                pulse->frequency = freq;
                pulse->frequencyShift = (double)freqShift / (sampleRate * time);
            }

            pulse->volume = vol < 0 ? 0 : (vol > 1 ? 1 : (float)vol);
            pulse->totalTime = time;
            pulse->attack = atK;
            pulse->release = rls;

            pulse->arpSequence = arpSequence;
            pulse->pitchSequence = pitchSequence;
            pulse->dutySequence = dutySequence;
            pulse->volumeSequence = volumeSequence;
            pulse->arpIndex = 0;
            pulse->pitchIndex = 0;
            pulse->dutyIndex = 0;
            pulse->volumeIndex = 0;

            pulse->remainingCycles = (unsigned long long)(time * sampleRate);
            pushToQueue(audioQueues[chan - 1], pulse);
        } catch (const LuaError &e) {
            luaL_error(L, e.what());
        }

        return 0;
    }

    static int loadSequence(lua_State *L) {
        try {
            auto *sequence = new Sequence(L, 1);

            int index = luaL_checkint(L, 2) - 1;
            if (index < 0 || index >= sequenceCount) {
                delete sequence;

                lua_pushboolean(L, false);
                return 1;
            }

            delete sequenceMap[index];
            sequenceMap[index] = sequence;
        } catch (const LuaError &e) {
            luaL_error(L, e.what());
        }

        lua_pushboolean(L, true);
        return 1;
    }

    static const luaL_Reg audLib[] = {
        {"play", aud_play},
        {"stopChannel", aud_stopChan},
        {"stopAll", aud_stopAll},
        {"loadSequence", loadSequence},
        {nullptr, nullptr}};

    int openLua(lua_State *L) {
        for (int i = 0; i < channelCount; i++) {
            audioQueues[i] = constructQueue();
            streamPhase[i] = 0;
        }

        if (riko::audio::audioEnabled && !audioInitialized) {
            SDL_InitSubSystem(SDL_INIT_AUDIO);

            SDL_zero(want);
            want.freq = sampleRate;
            want.format = AUDIO_F32SYS;
            want.channels = audDevChanCount;
            want.samples = samples;
            want.callback = audioCallback;
            want.userdata = nullptr;

            dev = SDL_OpenAudioDevice(nullptr, 0, &want, &have, SDL_AUDIO_ALLOW_ANY_CHANGE);  // NOLINT
            if (dev == 0) {
                SDL_Log("Failed to open audio: %s", SDL_GetError());
            } else {
                sampleRate = have.freq;
                sequenceRate = sampleRate / 60;

                samples = have.samples;
                audDevChanCount = have.channels;

                if (have.format != want.format) { /* we can't let this one thing change. */
                    SDL_Log("Unable to open Float32 audio.");
                } else {
                    SDL_PauseAudioDevice(dev, 0); /* start audio playing. */
                }
            }

            audioInitialized = true;
        }

        luaL_openlib(L, RIKO_AUD_NAME, audLib, 0);
        return 1;
    }

    void closeAudio() {
        if (dev != 0) {
            SDL_CloseAudioDevice(dev);
        }

        for (auto &audioQueue : audioQueues) {
            falloutQueue(audioQueue);
            delete audioQueue;
        }

        audioInitialized = false;
    }
}  // namespace riko::audio
