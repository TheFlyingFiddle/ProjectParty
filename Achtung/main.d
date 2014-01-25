module main;

import std.file;
import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;
import derelict.freeimage.freeimage;

import logging;
import content.sdl;
import allocation;
import std.exception;
import graphics.common;
import achtung;
import game;
import math;


version(X86) 
{
	enum dllPath = "..\\dll\\win32\\";
	enum libPath = "..\\lib\\win32\\";
}
version(X86_64) 
{
	enum dllPath = "..\\dll\\win64\\";
	enum libPath = "..\\lib\\win32\\";
}

pragma(lib, libPath ~ "DerelictGLFW3.lib");
pragma(lib, libPath ~ "DerelictGL3.lib");
pragma(lib, libPath ~ "DerelictUtil.lib");
pragma(lib, libPath ~ "DerelictFI.lib");
pragma(lib, "Shared.lib");

GLFWwindow* window;

RegionAllocator tlsAllocator ;

static this()
{
    tlsAllocator = RegionAllocator(Mallocator.it, 1024*1024, 8);
}

void main()
{
	logger = &writeLogger;

	try
	{	
		run();
	}
	catch(Throwable t)
	{
		error(t);
	}
}

void writeLogger(string chan, Verbosity v, string msg, string file, size_t line) nothrow
{
	import std.stdio;
	scope(failure) return; //Needed since writeln can potentially throw.
	writeln(chan, "   ", msg, "       ", file, "(", line, ")");
}



void init(Allocator)(ref Allocator allocator, string sdlPath)
{
    struct WindowConfig
	{
        uint2 dim;
        string title;
	}
	DerelictGL3.load();
	DerelictGLFW3.load(dllPath ~ "glfw3.dll");
	DerelictFI.load(dllPath ~ "FreeImage.dll");


	enforce(glfwInit(), "GLFW init problem");


    import allocation.gc;
    auto config = fromSDLFile!WindowConfig(GCAllocator.it, sdlPath);
    auto dim = config.dim;
    window = glfwCreateWindow(dim.x, dim.y, toCString(config.title), null, null);
	glfwMakeContextCurrent(window);

    try {
	DerelictGL3.reload();
	} catch (Throwable t) {
	    error(t); // Some errors thrown by derelict on 
	}
	achtung.init(allocator, "Config.sdl");
}

void run()
{
	auto allocator = RegionAllocator(Mallocator.it, 1024 * 1024, 8);
	auto stack     = ScopeStack(allocator);

	init(stack, "Window.sdl");

	Game.gameStateMachine = GameStateFSM(stack, 10);
	Game.gameStateMachine.addState(new AchtungGameState(), "Achtung");
	Game.gameStateMachine.transitionTo("Achtung");

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

final class AchtungGameState : IGameState
{
	void enter() { } 
	void exit()  { }
	void init()  { }
	void handleInput() { }

	void update()
	{
		achtung.update();
	}

	void render()
	{
		achtung.render();
	}
}