#define LUA_LIB

#define PI 3.141592654

#include <rikoAudio.h>

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_audio.h>

#include <stdlib.h>

#include <math.h>

SDL_AudioSpec want, have;
SDL_AudioDeviceID dev;

const double tao = 2*PI;
const int sampleRate = 48000;
const int samples = 1024;

int sineCounter = 0;
double freq = 500; // in Hz
double phi = tao * freq * sineCounter / sampleRate;
double time = 0.1;
double freqEnd = 500;
void sinWaveCallback(void *userdata, uint8_t *stream, int len) {
	

	// (x*(-2*x2*y1 + x*(y1 - y2) + 2*x1*y2))/(2*(x1 - x2))
	
	//int y1 = 528;
	

	//(x*(-2 * x2*y1 + x*(y1 - y2) + 2 * x1*y2)) / (2 * (x1 - x2))


	double delta = tao * freq / sampleRate;
	double f_delta = (freqEnd - freq) / ((sampleRate * time));
	int p1 = (freqEnd - freq);
	int p2 = ((sampleRate * time));
	double p3 = (double) p1 / (double) p2;

	printf("%d %d %f", p1, p2, p3);

	for (int z = 0; z < len; z++) {
		stream[z] = (uint8_t)(sin(phi) * 127 + 127);
		phi += delta;
		//freq += p3;
		//delta = tao * freq / sampleRate;
	}
}

int sawCounter = 0;
void sawWaveCallback(void *userdata, uint8_t *stream, int len) {
	for (int z = 0; z < len; z++) {
		stream[z] = (uint8_t)((++sawCounter / 16) % 256 - 127);
	}
}

int triCounter = 0;
void triWaveCallback(void *userdata, uint8_t *stream, int len) {
	for (int z = 0; z < len; z++) {
		stream[z] = (uint8_t)abs((++triCounter % 255) - 127) * 2;
	}
}

int pulseCounter = 0;
void pulseWaveCallback(void *userdata, uint8_t *stream, int len) {
	int hz = 500;
	for (int z = 0; z < len; z++) {
		double innerSin = hz * PI * (++pulseCounter) / sampleRate;
		//if (z < len / 16) {
		//	printf("%d\n", (uint8_t)(floor(sin(innerSin) * 0.5) + 1) * 256);
		//}
		stream[z] = (uint8_t)(floor(sin(innerSin) * 0.5) + 1) * 127 + 127;
	}
}

bool sinq = false;
int count = 0;
double phase = 0;
float phase_inc = 380.0 / (float) sampleRate;
int cnt = 0;
float lstRnd = 0;
float rndCt = 50;
void audioCallback(void *userdata, uint8_t *byteStream, int len) {
	float* floatStream = (float*) byteStream;
	double delta = tao * freq / sampleRate;
	double f_delta = (freqEnd - freq) / ((sampleRate * time));

	for (int z = 0; z < samples; z++) {
		if (sinq) {
			//floatStream[z] = phase >= 0.5 ? 0.1 : -0.1;
			//floatStream[z] = (float)(sin(phase) * 0.001);
			//phase += phase_inc;
			if (cnt == 0) {
				lstRnd = ((float)rand() / (float)RAND_MAX) * 0.03;
			}
			cnt = fmod((cnt + 1), rndCt);
			rndCt -= 0.001;
			floatStream[z] = lstRnd;
			//phase = fmod(phase + phase_inc, 1.0f);
			phase_inc += 0.000001;
			//phi += delta;
		} else {
			count = ++count;
			floatStream[z] = 0;
		}
	}
}

static int aud_play(lua_State *L) {
	puts("Commencing playback of payload");

	int f = luaL_checknumber(L, 1);

	sineCounter = 0;
	freq = f; // in Hz
	time = luaL_checknumber(L, 2); // in seconds
	phi = tao * freq * sineCounter / sampleRate;

	//play();
	sinq = true;
	return 0;
}

static const luaL_Reg audLib[] = {
	{ "play", aud_play },
	{ NULL, NULL }
};

LUALIB_API int luaopen_aud(lua_State *L) {
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

	//dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, SDL_AUDIO_ALLOW_ANY_CHANGE);
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
}