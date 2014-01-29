module external_libraries;

import derelict.freeimage.freeimage;
import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;
import derelict.util.exception;
import std.exception;
import logging;

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

enum GLFW_DLL_PATH       = dllPath ~ "glfw3.dll";
enum FREE_IMAGE_DLL_PATH = dllPath ~ "FreeImage.dll"; 

pragma(lib, libPath ~ "DerelictGLFW3.lib");
pragma(lib, libPath ~ "DerelictGL3.lib");
pragma(lib, libPath ~ "DerelictUtil.lib");
pragma(lib, libPath ~ "DerelictFI.lib");

void init_dlls()
{	

	DerelictGLFW3.load(GLFW_DLL_PATH);
	DerelictFI.load(FREE_IMAGE_DLL_PATH);
	DerelictGL3.load();

	FreeImage_Initialise();


	glfwSetErrorCallback(&glfwError);
	enforce(glfwInit(), "GLFW did not initialize properly!");

	auto logChnl = LogChannel("EXTERNAL_LIBRARIES");
	logChnl.info("Setup complete");
}

void shutdown_dlls()
{
	glfwTerminate();
	DerelictGLFW3.unload();
	DerelictFI.unload();
	DerelictGL3.unload();
}

bool missingSymFunc(string libName, string symName)
{
	auto logChnl = LogChannel("DERELICT");
	logChnl.warn(libName,"   ", symName);
	return true;
}

extern(C) static nothrow void glfwError(int type, const(char)* msg)
{
	auto logChnl = LogChannel("GLFW");
	logChnl.error("Got error from GLFW : Type", type, " MSG: ", msg);
}