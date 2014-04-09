

/*

import derelict.openal.al;
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

enum OGG_DLL_PATH			= dllPath ~ "libogg.dll";
enum VORBIS_DLL_PATH		= dllPath ~ "libvorbis.dll";
enum VORBISFILE_DLL_PATH	= dllPath ~ "libvorbisfile.dll";

enum BUFFER_SIZE = 32768;

ALCdevice* device;
ALCcontext* context;

bool missingSymFunc(string libName, string symName)
{
	import std.stdio;
	writeln(symName);

	return true;
}

int old_main(string[] argv)
{
	Derelict_SetMissingSymbolCallback(&missingSymFunc);
	try
	{
		DerelictOgg.load(OGG_DLL_PATH);
	} catch(Throwable t)
	{
		import std.stdio;
		writeln(t);
		readln;
	}


	DerelictVorbis.load(VORBIS_DLL_PATH);
	DerelictVorbisFile.load(VORBISFILE_DLL_PATH);
	DerelictAL.load();

	ALint state;
	ALuint bufferID;
	ALuint sourceID;
	ALenum format;
	ALsizei freq;
	
	ubyte[] buffer;

	//alutInit(&argc, argv) -- DO OpenAL initialization here!
	initOpenAL();

	alGenBuffers(1, &bufferID);
	alGenSources(1, &sourceID);

	alListener3f(AL_POSITION, 0.0f, 0.0f, 0.0f);
	alSource3f(sourceID, AL_POSITION, 0.0f, 0.0f, 0.0f);

	loadOgg("test.ogg", buffer, format, freq);

	alBufferData(bufferID, format, &buffer[0], buffer.length, freq);
	alSourcei(sourceID, AL_BUFFER, bufferID);

	alSourcePlay(sourceID);

	while(true)
	{
		alGetSourcei(sourceID, AL_SOURCE_STATE, &state);
		if(state == AL_STOPPED) break;
	}

	alDeleteBuffers(1, &bufferID);
	alDeleteSources(1, &sourceID);
	termOpenAL();


    return 0;
}

void initOpenAL()
{	
	device = alcOpenDevice(null);
	if(!device) 
	{
		throw new Exception("Failed to load the OpenAL device!");
	}

	context = alcCreateContext(device, null);
	if(!alcMakeContextCurrent(context))
	{
		throw new Exception("Failed to make OpenAL context current!");
	}
}

void termOpenAL()
{
	device = alcGetContextsDevice(context);
	alcMakeContextCurrent(null);
	alcDestroyContext(context);
	alcCloseDevice(device);
}

void loadOgg(string fileName, ref ubyte[] buffer, ref ALenum soundFormat, ref ALsizei freq)
{
	int endian = 0; //O for little endian 1 for big endian.
	int bitStream;
	long bytes;
	byte[BUFFER_SIZE] array;

	import std.c.stdio, std.string;

	FILE* file = fopen(fileName.toStringz(), "rb");
	vorbis_info* pInfo;
	OggVorbis_File oggFile;

	ov_open(file, &oggFile, null, 0);
	pInfo = ov_info(&oggFile, -1);

	if(pInfo.channels == 1)
		soundFormat = AL_FORMAT_MONO16;
	else
		soundFormat = AL_FORMAT_STEREO16;

	freq = pInfo.rate;
	
	while(true)
	{	
		bytes = ov_read(&oggFile, &array[0], BUFFER_SIZE, endian, 2, 1, &bitStream);
		buffer ~= array;

		if(bytes <= 0)
			break;
	}

	ov_clear(&oggFile);
}
*/