module main;

import logging, external_libraries,
	   allocation, game, achtung,
	   main_menu, game_over;

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
		while(t.next !is null) {
			logChnl.error(t.next);
			t = t.next;
		}
	}

	//This is bad. Don't do this okej? -- Basically background processes are preventing program to close. 
	import std.stdio;
	readln;
	std.c.stdlib.exit(0);

}

void init(A)(ref A allocator)
{
	import content.sdl;

	auto config = fromSDLFile!GameConfig(GC.it, "Game.sdl");
	game.Game = allocator.allocate!Game_Impl(allocator, config);

	auto fsm = Game.gameStateMachine;
	fsm.addState(allocator.allocate!AchtungGameState(allocator, "Config.sdl"), "Achtung");
	fsm.addState(allocator.allocate!MainMenu("Achtung Main Menu"), "MainMenu");
	fsm.addState(allocator.allocate!GameOverGameState(10), "GameOver");
	fsm.transitionTo("MainMenu");


	import graphics; 
	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);
}

void run()
{
	auto allocator = RegionAllocator(GC.cit, 1024 * 1024 * 50, 8);	
	auto ss        = ScopeStack(allocator);

	init(ss);
	logChnl.info("Total Allocated is: ", allocator.bytesAllocated / 1024 , "kb");
	import std.datetime;
	Game.run(Timestep.fixed, 16.msecs);
	
}