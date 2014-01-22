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

pragma(lib, "DerelictGLFW3.lib");
pragma(lib, "DerelictGL3.lib");
pragma(lib, "DerelictUtil.lib");
pragma(lib, "Shared.lib");

GLFWwindow* window;

void main()
{
	logger = &writeLogger;

	try
	{	
		auto config = fromSDL(readText("Config.sdl"));
		run(config);
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



void init(Allocator)(ref Allocator allocator, SDLObject config)
{
	DerelictGL3.load();
	DerelictGLFW3.load("..\\dll\\win32\\glfw3.dll");

	enforce(glfwInit(), "GLFW init problem");

	auto w = cast(uint)config.map.width.integer,
		h = cast(uint)config.map.height.integer;

	window = glfwCreateWindow(w, h, toCString(config.title.string_), null, null);
	glfwMakeContextCurrent(window);
	DerelictGL3.reload();

	achtung.init(allocator, config);
}

void run(SDLObject config)
{
	auto allocator = RegionAllocator(Mallocator.it, 1024 * 1024, 8);
	auto stack     = ScopeStack(allocator);

	init(stack, config);

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