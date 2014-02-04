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

	std.c.stdlib.exit(0);
}

void init(Allocator)(ref Allocator allocator)
{
	ContentReloader.init(allocator, 100, 50);
	TextureManager.init(allocator, 100);
	FontManager.init(allocator, Mallocator.cit, 100);
	WindowManager.init(allocator, 10);


	auto config = fromSDLFile!WindowConfig(GCAllocator.it, "Window.sdl");
	Game.init(allocator, 10, config, 1337, 7331);


	AchtungGameState ags = new AchtungGameState();

	ags.init(allocator, "Config.sdl");

	Game.gameStateMachine.addState(new MainMenu(), "MainMenu");
	Game.gameStateMachine.addState(ags, "Achtung");
	Game.gameStateMachine.addState(new GameOverGameState(), "GameOver");
	Game.gameStateMachine.transitionTo("MainMenu", Variant());

	Game.window.onPositionChanged = &positionChanged;
}


void positionChanged(int x, int y)
{
	auto logChnl = LogChannel("WINDOW");
	logChnl.info("Position changed!", x, " ", y);
}

void run()
{
	auto allocator = RegionAllocator(GCAllocator.cit, 1024 * 1024, 8);
	auto stack     = ScopeStack(allocator);

	init(stack);

	import std.datetime;
	Game.run(Timestep.fixed, 16.msecs);
}