module main;

import std.file;
import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;
import derelict.freeimage.freeimage;

import logging;
import content;
import allocation;
import std.exception;
import std.concurrency;
import graphics.common;
import achtung;
import game;
import math;
import core.sys.windows.windows;
import std.datetime;
import game_over;
import main_menu;


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

pragma(lib, libPath ~ "DerelictGLFW3.lib");
pragma(lib, libPath ~ "DerelictGL3.lib");
pragma(lib, libPath ~ "DerelictUtil.lib");
pragma(lib, libPath ~ "DerelictFI.lib");
pragma(lib, "Shared.lib");

GLFWwindow* window;

void main()
{
	logger = &writeLogger;

	try
	{	
		run();
	}
	catch(Throwable t)
	{
		auto logChnl = LogChannel("MAIN");
		logChnl.error(t);
	}

	std.c.stdlib.exit(0);
}

void writeLogger(string chan, Verbosity v, string msg, string file, size_t line) nothrow
{
	import std.stdio;
	scope(failure) return; //Needed since writeln can potentially throw.
	writeln(chan, "   ", msg, "       ", file, "(", line, ")");
}


import derelict.util.exception;

bool missingSymFunc(string libName, string symName)
{
	auto logChnl = LogChannel("DERELICT");
	logChnl.warn(libName,"   ", symName);
	return true;
}


void init(Allocator)(ref Allocator allocator, string sdlPath)
{
    struct WindowConfig
	{
        uint2 dim;
        string title;
	}

	import derelict.util.exception;

	Derelict_SetMissingSymbolCallback(&missingSymFunc);

	DerelictGL3.load();
	DerelictGLFW3.load(dllPath ~ "glfw3.dll");

	DerelictFI.load(dllPath ~ "FreeImage.dll");
	FreeImage_Initialise();


	enforce(glfwInit(), "GLFW init problem");

    import allocation.gc;
    auto config = fromSDLFile!WindowConfig(GCAllocator.it, sdlPath);
    auto dim = config.dim;

	glfwWindowHint(GLFW_SAMPLES, 4);
    window = glfwCreateWindow(dim.x, dim.y, toCString(config.title), null, null);
	glfwMakeContextCurrent(window);

	DerelictGL3.reload();
}

void run()
{
	auto allocator = RegionAllocator(GCAllocator.it, 1024 * 1024, 8);
	auto stack     = ScopeStack(allocator);

	ContentReloader.init(stack, 100, 50);
	TextureManager.init(stack, 100);
	FontManager.init(stack, Mallocator.cit, 100);

	init(stack, "Window.sdl");

	AchtungGameState ags = new AchtungGameState();
	ags.init(stack, "Config.sdl");

	Game.gameStateMachine = GameStateFSM(stack, 10);
	Game.gameStateMachine.addState(new MainMenu(), "MainMenu");
	Game.gameStateMachine.addState(ags, "Achtung");
	Game.gameStateMachine.addState(new GameOverGameState(), "GameOver");
	Game.gameStateMachine.transitionTo("MainMenu", Variant());



	Game.shouldRun = &shouldRun;
	Game.swap      = &swapBuffers;

	import std.datetime;
	Game.run(Timestep.fixed, 16.msecs);
}

bool shouldRun()
{
	return !glfwWindowShouldClose(window);
}

void swapBuffers()
{
	glfwPollEvents();
	glfwSwapBuffers(window);
}


