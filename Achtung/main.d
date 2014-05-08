module main;

import logging, external_libraries,
	   allocation, game, achtung,
	   game_over,
	   achtung_game_data,
	   game.debuging, types;

version(X86) 
	enum libPath = "..\\lib\\win32\\";
version(X86_64) 
	enum libPath = "..\\lib\\win64\\";

pragma(lib, libPath ~ "DerelictGLFW3.lib");
pragma(lib, libPath ~ "DerelictGL3.lib");
pragma(lib, libPath ~ "DerelictUtil.lib");
pragma(lib, libPath ~ "DerelictFI.lib");
pragma(lib, libPath ~ "DerelictOGG.lib");
pragma(lib, libPath ~ "DerelictSDL2.lib");
pragma(lib, libPath ~ "dunit.lib");
pragma(lib, "Shared.lib");

auto logChnl = LogChannel("MAIN");

void main()
{
	import std.stdio;
	initializeTcpLogger("logger.sdl");
	init_dlls();
	try
	{	
		run();
	}
	catch(Throwable t)
	{
		writeln(t);
	}

	//This is bad. Don't do this okej? -- Basically background processes are preventing program to close. 
	readln;
	std.c.stdlib.exit(0);

}

void init(A)(ref A allocator)
{
	import content.sdl;

	auto config = fromSDLFile!GameConfig(GC.it, "Game.sdl");
	game.Game = allocator.allocate!Game_Impl(allocator, config);

	initDebugging("textures\\pixel.png");

	auto fsm = Game.gameStateMachine;
	auto agd = new AchtungGameData(allocator, config.serverConfig.maxConnections);

	fsm.addState(new AchtungGameState(allocator, "Config.sdl", agd), "Achtung");
	import game.states.lobby;
	fsm.addState(allocator.allocate!LobbyState(allocator, "lobby.sdl", "Achtung", IncomingMessages.readyMessage), "MainMenu");
	fsm.addState(allocator.allocate!GameOverGameState(agd, 10), "GameOver");
	Game.transitionTo("MainMenu");


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
	import core.memory;
	GC.disable();
	Game.run(Timestep.fixed, 16_667.usecs);	
}