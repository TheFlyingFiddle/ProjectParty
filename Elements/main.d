import std.stdio;

import logging, external_libraries,
	allocation, game, gameplay,
	network_types,
	game.debuging, game.states.lobby, types, math;

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
	initializeTcpLogger("logger.sdl");
	init_dlls();
	try
	{	
		run();
	}
	catch(Throwable t)
	{
		writeln(t);
		//logChnl.error(t);
		while(t.next !is null) {
			logChnl.error(t.next);
			t = t.next;
		}

		readln;
	}
}

void init(A)(ref A allocator)
{
	import content.sdl;

	auto config = fromSDLFile!GameConfig(GC.it, "Game.sdl");
	game.Game = allocator.allocate!Game_Impl(allocator, config);

	initDebugging("textures\\pixel.png");

	auto fsm = Game.gameStateMachine;
	fsm.addState(allocator.allocate!GamePlayState(allocator, "gameconfig.sdl"), "GamePlay");
	fsm.addState(allocator.allocate!LobbyState(allocator, "lobby.sdl", "GamePlay", IncomingMessages.readyMessage), "Lobby");
	Game.transitionTo("GamePlay");

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
