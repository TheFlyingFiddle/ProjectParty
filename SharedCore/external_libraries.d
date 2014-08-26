module external_libraries;

import derelict.freeimage.freeimage;
import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;
import derelict.util.exception;
import derelict.sdl2.sdl;
import derelict.sdl2.mixer;
import derelict.ogg.ogg;
import derelict.ogg.vorbis;
import derelict.ogg.vorbisfile;

import std.exception;
import log;

version(X86) 
{
	enum dllPath = "..\\dll\\win32\\";
}
version(X86_64) 
{
	enum dllPath = "..\\dll\\win64\\";
}

enum GLFW_DLL_PATH          = dllPath ~ "glfw3.dll";
enum FREE_IMAGE_DLL_PATH    = dllPath ~ "FreeImage.dll"; 
enum SDL_PATH               = dllPath ~ "SDL2.dll";
enum SDL_MIXER_PATH			= dllPath ~ "SDL2_mixer.dll";
enum OGG_DLL_PATH			= dllPath ~ "libogg-0.dll";
enum VORBIS_DLL_PATH		= dllPath ~ "libvorbis-0.dll";
enum VORBISFILE_DLL_PATH	= dllPath ~ "libvorbisfile-3.dll";

void init_dlls()
{	
	Derelict_SetMissingSymbolCallback(&missingSymFunc);

	DerelictGL3.load();
	DerelictGLFW3.load(GLFW_DLL_PATH);
	DerelictFI.load(FREE_IMAGE_DLL_PATH);

	DerelictOgg.load(OGG_DLL_PATH);
	DerelictVorbis.load(VORBIS_DLL_PATH);
	DerelictVorbisFile.load(VORBISFILE_DLL_PATH);
	DerelictSDL2.load(SDL_PATH);
	DerelictSDL2Mixer.load(SDL_MIXER_PATH);

	FreeImage_Initialise();
	SDL_Init(SDL_INIT_AUDIO);
	Mix_Init(MIX_INIT_OGG);

	glfwSetErrorCallback(&glfwError);
	assert(glfwInit(), "GLFW did not initialize properly!");

	auto logChnl = LogChannel("EXTERNAL_LIBRARIES");
	logChnl.info("Setup complete");
}

void shutdown_dlls()
{
	FreeImage_DeInitialise();
	Mix_Quit();
	SDL_Quit();
	glfwTerminate();

	DerelictGLFW3.unload();
	DerelictFI.unload();
	DerelictGL3.unload();
	DerelictOgg.unload();
	DerelictVorbis.unload();
	DerelictVorbisFile.unload();
	DerelictSDL2.unload();
	DerelictSDL2Mixer.unload();
}

bool missingSymFunc(string libName, string symName)
{
	auto logChnl = LogChannel("MISSING SYMBOLS");
	logChnl.warn(libName,"   ", symName);
	return true;
}

extern(C) static nothrow void glfwError(int type, const(char)* msg)
{
	import std.conv;
	auto logChnl = LogChannel("GLFW");
	logChnl.error("Got error from GLFW : Type", type, " MSG: ", msg.to!string);
}