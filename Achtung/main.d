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
import test_game_state;
import external_libraries;

version(X86) 
	enum libPath = "..\\lib\\win32\\";
version(X86_64) 
	enum libPath = "..\\lib\\win64\\";


pragma(lib, libPath ~ "DerelictGLFW3.lib");
pragma(lib, libPath ~ "DerelictGL3.lib");
pragma(lib, libPath ~ "DerelictUtil.lib");
pragma(lib, libPath ~ "DerelictFI.lib");
pragma(lib, libPath ~ "dunit.lib");
pragma(lib, "Shared.lib");

auto logChnl = LogChannel("MAIN");

void main()
{
	initializeTcpLogger("logger.sdl");
	init_dlls();
	try
	{	
		run();
	}
	catch(Throwable t)
	{
		logChnl.error(t);
	}

	//This is bad. Don't do this okej? -- Basically background processes are preventing program to close. 
	import std.stdio;
	readln;
	std.c.stdlib.exit(0);

}

void init(Allocator)(ref Allocator allocator)
{
	auto config = fromSDLFile!GameConfig(GC.it, "Game.sdl");
	Game.init(allocator, config);

	AchtungGameState ags = allocator.allocate!AchtungGameState;
	ags.init(allocator, "Config.sdl");

	Game.gameStateMachine.addState(allocator.allocate!MainMenu("Achtung Main Menu"), "MainMenu");
	Game.gameStateMachine.addState(ags, "Achtung");
	Game.gameStateMachine.addState(allocator.allocate!GameOverGameState, "GameOver");
	Game.gameStateMachine.transitionTo("MainMenu");


	//Game.gameStateMachine.addState(allocator.allocate!TestGameState(), "TEST");
	//Game.gameStateMachine.transitionTo("TEST");

	import graphics; 
	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);
}

void run()
{
	auto allocator = RegionAllocator(GC.cit, 1024 * 1024 * 50, 8);
	{
		auto ss        = ScopeStack(allocator);

		init(ss);

		logChnl.info("Total Allocated is: ", allocator.bytesAllocated / 1024 , "kb");

		import std.datetime;
		Game.run(Timestep.fixed, 16.msecs);
	}
	Game.shutdown();
}