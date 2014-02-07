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
		auto logChnl = LogChannel("MAIN");
		logChnl.error(t);
	}

	//This is bad. Don't do this okej? -- Basically background processes are preventing program to close. 
	std.c.stdlib.exit(0);
}

void init(Allocator)(ref Allocator allocator)
{
	ContentReloader.init(allocator, 100, 50);
	TextureManager.init(allocator, 100);
	FontManager.init(allocator, Mallocator.cit, 100);
	WindowManager.init(allocator, 10);

	auto config = fromSDLFile!WindowConfig(GC.it, "Window.sdl");
	Game.init(allocator, 10, config, 7331);

	AchtungGameState ags = allocator.allocate!AchtungGameState;

	ags.init(allocator, "Config.sdl");






	Game.gameStateMachine.addState(allocator.allocate!MainMenu("Achtung Main Menu"), "MainMenu");
	Game.gameStateMachine.addState(ags, "Achtung");
	Game.gameStateMachine.addState(allocator.allocate!GameOverGameState, "GameOver");
	
	
	Game.gameStateMachine.transitionTo("MainMenu");

	//TEMPORARY
	//Game.gameStateMachine.addState(allocator.allocate!TestGameState, "TEST");
	//Game.gameStateMachine.transitionTo("TEST");


	//Should this be part of an initial graphics rutine (Maby in Renderer?)
	import graphics; 
	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);
}

void run()
{
	auto allocator = RegionAllocator(GC.cit, 1024 * 1024, 8);
	auto ss        = ScopeStack(allocator);

	init(ss);

	import std.datetime;
	Game.run(Timestep.fixed, 16.msecs);
}