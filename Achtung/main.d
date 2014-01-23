module main;

import std.file;
import derelict.glfw3.glfw3;
import derelict.opengl3.gl3;

import logging;
import content.sdl;
import allocation;
import std.exception;
import graphics.common;
import achtung;
import game;
import math;

pragma(lib, "DerelictGLFW3.lib");
pragma(lib, "DerelictGL3.lib");
pragma(lib, "DerelictUtil.lib");
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
	DerelictGLFW3.load("..\\dll\\win32\\glfw3.dll");

	enforce(glfwInit(), "GLFW init problem");


    import allocation.gc;
    auto config = fromSDLFile!WindowConfig(GCAllocator.it, sdlPath);
    auto dim = config.dim;
    window = glfwCreateWindow(dim.x, dim.y, toCString(config.title), null, null);
	glfwMakeContextCurrent(window);
	DerelictGL3.reload();

	achtung.init(allocator, "Config.sdl");
}

void run()
{
	auto allocator = RegionAllocator(Mallocator.it, 1024 * 1024, 8);
	auto stack     = ScopeStack(allocator);

	init(stack, "Window.sdl");

	Game.shouldRun = &shouldRun;
	Game.update    = &update;
	Game.render    = &render;
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