#define LUA_LIB

#define PI 3.141592654

#include <rikoAudio.h>

#include <LuaJIT/lua.hpp>
#include <LuaJIT/lauxlib.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_audio.h>

#include <math.h>

SDL_AudioSpec want, have;
SDL_AudioDeviceID dev;

const double tao = 2*PI;
const int sampleRate = 48000;

int sineCounter = 0;
double freq = 500; // in Hz
double phi = tao * freq * sineCounter / sampleRate;
double time = 0.1;
double freqEnd = 800;
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

void play(void)
{
	SDL_memset(&want, 0, sizeof(want)); /* or SDL_zero(want) */
	want.freq = 48000;
	want.format = AUDIO_U8;//AUDIO_F32;
	want.channels = 2;
	want.samples = 4028;
	want.callback = sinWaveCallback;

	dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, SDL_AUDIO_ALLOW_ANY_CHANGE);
	if (dev == 0) {
		SDL_Log("Failed to open audio: %s", SDL_GetError());
	}
	else {
		if (have.format != want.format) { /* we let this one thing change. */
			SDL_Log("We didn't get Float32 audio format.");
		}
		SDL_PauseAudioDevice(dev, 0); /* start audio playing. */
		SDL_Delay(time * 1000); /* let the audio callback play some sound for 5 seconds. */
		SDL_CloseAudioDevice(dev);
	}
}

static int aud_play(lua_State *L) {
	puts("Commencing playback of payload");

	int f = luaL_checknumber(L, 1);

	sineCounter = 0;
	freq = f; // in Hz
	time = luaL_checknumber(L, 2); // in seconds
	phi = tao * freq * sineCounter / sampleRate;

	play();
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

	luaL_openlib(L, RIKO_AUD_NAME, audLib, 0);
	return 1;
}