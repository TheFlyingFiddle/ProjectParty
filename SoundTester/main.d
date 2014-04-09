module main;

import derelict.sdl2.sdl;
import derelict.sdl2.mixer;
import derelict.ogg.ogg;
import derelict.ogg.vorbis;
import derelict.ogg.vorbisfile;
import derelict.util.exception;

version(X86) 
{
	enum dllPath = "..\\dll\\win32\\";
	enum libPath = "..\\lib\\win32\\";
}
version(X86_64) 
{
	enum dllPath = "..\\dll\\win64\\";
	enum libPath = "..\\lib\\win64\\";
}

enum SDL_PATH               = dllPath ~ "SDL2.dll";
enum SDL_MIXER_PATH			= dllPath ~ "SDL2_mixer.dll";
enum OGG_DLL_PATH			= dllPath ~ "libogg-0.dll";
enum VORBIS_DLL_PATH		= dllPath ~ "libvorbis-0.dll";
enum VORBISFILE_DLL_PATH	= dllPath ~ "libvorbisfile-3.dll";

bool missingSymFunc(string libName, string symName)
{
	import std.stdio;
	writeln(symName);

	return true;
}

void main()
{
	Derelict_SetMissingSymbolCallback(&missingSymFunc);



	int audio_rate = 22050;
	ushort audio_format = AUDIO_S16;
	int audio_channels = 2;
	int audio_buffers = 4096;

	SDL_Init(SDL_INIT_AUDIO);
	auto flags = Mix_Init(MIX_INIT_OGG);
	assert((flags & MIX_INIT_OGG) == MIX_INIT_OGG, "Failed to initialize audio loading!");
		

	auto err = Mix_OpenAudio(audio_rate, audio_format, audio_channels, audio_buffers);
	assert(!err, "Failed to open audio device!");

	music = Mix_LoadMUS("test.ogg");
	assert(music, "Failed to load music!");

	Mix_PlayMusic(music, 0);
	Mix_HookMusicFinished(&musicDone);
	while(!done) 
	{
		import core.thread;
		Thread.sleep(1.seconds);
	}

	Mix_CloseAudio();
	SDL_Quit();
	Mix_Quit();
}

shared bool done = false;
Mix_Music* music = null;

extern(C) void musicDone()
{
	Mix_HaltMusic();
	Mix_FreeMusic(music);
	music = null;
	done = true;
}