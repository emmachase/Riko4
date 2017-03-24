#define LUA_LIB

#define PI 3.141592654
#define TAO PI * 2

#include <rikoAudio.h>

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_audio.h>

#include <stdlib.h>

#include <math.h>

typedef struct {
	unsigned long long remainingCycles;
	int frequency;
	int frequencyShift;
	double noiseFr;
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

const int sampleRate = 48000;
const int samples = 1024;

const int channelCount = 5;
const int queueSize = 512;
static queue* audioQueues[channelCount];
static Sound* playingAudio[channelCount];
static bool channelHasSnd[channelCount];
static double streamPhase[channelCount];

bool sinq = false;
int count = 0;
double phase = TAO;
double phase2 = 0;
float phase_inc = TAO * 261.6 / (float)sampleRate;
int cnt = 0;
float lstRnd = 0;
float rndCt = 50;
void audioCallback(void *userdata, uint8_t *byteStream, int len) {
	float* floatStream = (float*) byteStream;

	for (int i = 0; i < channelCount; i++) {
		if (!channelHasSnd[i] && audioQueues[i]->tail != NULL) {
			playingAudio[i] = popFromQueue(audioQueues[i]);
			channelHasSnd[i] = true;
		}
	}

	for (int z = 0; z < samples; z++) {
		//if (sinq) {
		//	////floatStream[z] = phase >= 0.5 ? 0.1 : -0.1;
		//	//floatStream[z] =  (float)(sin(phase)  * 1);
		//	////floatStream[z] += (float)(sin(phase2) * 0.5);
		//	//phase += phase_inc;
		//	//phase2 += phase_inc2;
		//	if (cnt == 0) {
		//		lstRnd = ((float)rand() / (float)RAND_MAX) * 0.03;
		//	}
		//	cnt = fmod((cnt + 1), rndCt);
		//	rndCt -= 0.001;
		//	floatStream[z] = lstRnd;
		//	//phase = fmod(phase + phase_inc, 1.0f);
		//	/*phase_inc += 0.000001;
		//	phase_inc2 += 0.000001;*/
		//	//phi += delta;
		//} else {
		//	count = ++count;
		//	floatStream[z] = 0;
		//}

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

			switch (i) {
			case 0:
			case 1:
				// Pulse Wave
				// TODO: Actually make it a pulse wave kek
				floatStream[z] += fmod(streamPhase[i], TAO) > PI/4 ? -0.5 : 0.5;//(float)sin(phase);
				streamPhase[i] += TAO * playingAudio[i]->frequency / sampleRate;
				break;
			case 2:
				// Triangle Wave
				// Period (in s) = 1 / f
				// Period (in cycles) = sampleRate / f
				/*floatStream[z] += (fabs(fmod(streamPhase[i] - (sampleRate / (4 * playingAudio[i]->frequency)),
					sampleRate / playingAudio[i]->frequency) - (sampleRate / (2 * playingAudio[i]->frequency))) 
					- (sampleRate / (4 * playingAudio[i]->frequency))) / (sampleRate / playingAudio[i]->frequency);*/
				floatStream[z] += 1 - 4 * fabs(fmod(streamPhase[i], 1) - 0.5);
				streamPhase[i] += (double)playingAudio[i]->frequency / sampleRate;
				break;
			case 3:
				// Sawtooth Wave
				floatStream[z] += 2 * fmod(streamPhase[i] - 0.5, 1) - 1;
				streamPhase[i] += (double)playingAudio[i]->frequency / sampleRate;
				break;
			case 4:
				// Noise (Wave?)
				delta = fmod((streamPhase[i] + 1), playingAudio[i]->noiseFr);
				if (streamPhase[i] > delta) {
					lstRnd = ((float)rand() / (float)RAND_MAX) * 0.03;
				}
				streamPhase[i] = delta;
				
				floatStream[z] += lstRnd;

				break;
			}

			playingAudio[i]->remainingCycles--;
		}
	}
}

static int aud_play(lua_State *L) {
	int off = lua_gettop(L);
	if (off == 0) {
		luaL_error(L, "Expected table as first argument");
		return 0;
	}
	if (lua_type(L, -off) != 5) {
		luaL_error(L, "Expected table as first argument");
		return 0;
	}

	lua_pushstring(L, "channel");
	lua_gettable(L, -1 - off);
	int chan = luaL_checkinteger(L, -1);

	if (chan <= 0 || chan > channelCount) {
		luaL_error(L, "Channel must be between 1 and %d", channelCount);
	}

	lua_pushstring(L, "frequency");
	lua_gettable(L, -2 - off);
	int freq = luaL_checkinteger(L, -1);

	lua_pushstring(L, "time");
	lua_gettable(L, -3 - off);
	double time = luaL_checknumber(L, -1);

	Sound* puls = (Sound*)malloc(sizeof(Sound));
	puls->frequency = freq;
	puls->noiseFr = (110 - (12 * (log(pow(2, 1 / 12) * freq / 16.35) / log(2))));
	puls->frequencyShift = 0;
	puls->remainingCycles = time * sampleRate;
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

	for (int i = 0; i < SDL_GetNumAudioDrivers(); ++i) {
		printf("Audio driver %d: %s\n", i, SDL_GetAudioDriver(i));
	}

	SDL_InitSubSystem(SDL_INIT_AUDIO);

	SDL_memset(&want, 0, sizeof(want)); /* or SDL_zero(want) */
	want.freq = sampleRate;
	want.format = AUDIO_F32SYS;
	want.channels = 1;
	want.samples = samples;
	want.callback = audioCallback;
	want.userdata = NULL;

	dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, SDL_AUDIO_ALLOW_ANY_CHANGE);
	if (dev == 0) {
		SDL_Log("Failed to open audio: %s", SDL_GetError());
	} else {
		if (have.format != want.format) { /* we let this one thing change. */
			SDL_Log("We didn't get Float32 audio format.");
		}
		SDL_PauseAudioDevice(dev, 0); /* start audio playing. */
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