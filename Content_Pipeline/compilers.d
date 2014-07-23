module compilers;

import derelict.freeimage.freeimage;
import derelict.freetype.ft;
import derelict.util.exception;

import main;
import std.stdio;
import content.sdl, util.hash, allocation, std.path, std.array;
import std.file;

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

enum FREE_IMAGE_DLL_PATH  = dllPath ~ "FreeImage.dll"; 
enum FREE_TYPE_DLL_PATH   = dllPath  ~ "freetype.dll"; 


bool missingSymFunc(string libName, string symName)
{
	import log;
	auto logChnl = LogChannel("MISSING SYMBOLS");
	logChnl.warn(libName,"   ", symName);
	return true;
}

extern(C) static nothrow void glfwError(int type, const(char)* msg)
{
	import log;
	auto logChnl = LogChannel("GLFW");
	logChnl.error("Got error from GLFW : Type", type, " MSG: ", msg);
}



ubyte[] buffer;
FT_Library ft_lib;


void initCompilers()
{

	Derelict_SetMissingSymbolCallback(&missingSymFunc);
	buffer = new ubyte[1024 * 1024 * 10];

	DerelictFI.load(FREE_IMAGE_DLL_PATH);
	FreeImage_Initialise();

	DerelictFT.load(FREE_TYPE_DLL_PATH);

	FT_Init_FreeType(&ft_lib);
}

void deinitCompilers()
{
	FreeImage_DeInitialise();
	FT_Done_FreeType(ft_lib);

	DerelictFI.unload();
	DerelictFT.unload();
}

struct CompiledItem
{
	string extension;
	void[] data;
}

struct CompiledFile
{
	CompiledItem[] items;
	string[] dependencies;
}	

struct ArrayHandle
{
	uint position;
	void[] array;
}

extern(Windows) uint readData(void* buffer, uint size, uint count, void* h) nothrow
{	
	import std.conv;

	auto handle = cast(ArrayHandle*)h;
	if(handle.array.length - handle.position >= size * count)
	{
		buffer[0 .. size * count] = handle.array[handle.position .. handle.position + size * count];
		handle.position += size * count;
		return size * count;
	} else {
		auto result = handle.array.length - handle.position;
		buffer[0 .. result] = handle.array[handle.position .. $];
		handle.position = handle.array.length;
		return result;
	}
}

extern(Windows) uint writeData(void* buffer, uint size, uint count, void* h) nothrow
{
	auto handle = cast(ArrayHandle*)h;
	assert(handle.array.length - handle.position >= size * count);
	handle.array[handle.position .. handle.position + size * count] = buffer[0 .. size * count];
	handle.position += size * count;
	return size * count;
}

extern(Windows) int seekData(void* handle, int offset, int origin) nothrow
{
	import std.c.stdio;

	auto aHandle = (cast(ArrayHandle*)handle);
	if(origin == SEEK_CUR)
		aHandle.position += offset;
	else if(origin == SEEK_END)
		aHandle.position = aHandle.array.length + offset;
	else 
		aHandle.position = offset;

	return 0;
}

extern(Windows) int tellData(void* handle) nothrow
{
	return (cast(ArrayHandle*)handle).position;
}


CompiledFile compileImage(void[] data, DirEntry file, ref Context context)
{
	FreeImageIO io;
	io.read_proc  = &readData;
	io.write_proc = &writeData;
	io.seek_proc  = &seekData;
	io.tell_proc  = &tellData;

	ArrayHandle handle = ArrayHandle(0, data);
	int format;
	switch(file.name.extension)
	{
		case ".psd":
			format = FIF_PSD;
			break;
		case ".jpg":
			format = FIF_JPEG;
			break;
		case ".png":
			format = FIF_PNG;
			break;
		default: 
			assert(0, "Don't know how to read image format: " ~ file.name.extension);
	}

	auto image = FreeImage_LoadFromHandle(format, &io, cast(fi_handle)&handle, 0);
	scope(exit) FreeImage_Unload(image);

	if(context.platform == Platform.phone)
	{
		auto width = FreeImage_GetWidth(image);
		auto height = FreeImage_GetHeight(image);
		auto bits = cast(uint[])(FreeImage_GetBits(image)[0 .. width * height * 4]);
		flipImage(bits, width, height);

	}

	auto saveHandle = ArrayHandle(0, buffer);
	FreeImage_SaveToHandle(FIF_PNG, image, &io, cast(fi_handle)&saveHandle, 0);

	return CompiledFile([CompiledItem(".png", buffer[0 .. saveHandle.position])]);
}

void flipImage(uint[] image, uint width, uint height)
{
	auto tmp = new uint[width];
	foreach(row; 0 .. height / 2)
	{
		auto startStart = row * width;
		auto startEnd   = row * width + width;
		auto endStart   = (height - row - 1) * width;
		auto endEnd     = (height - row - 1) * width + width;

		tmp[] = image[startStart .. startEnd];
		image[startStart .. startEnd] = image[endStart .. endEnd];
		image[endStart .. endEnd] = tmp[];
	}
}