import std.stdio;

import logging, external_libraries,
	allocation, game,
	game.debuging,
	game.states.lobby;
import test_state;

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
	import std.datetime;

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
	}

	//This is bad. Don't do this okej? -- Basically background processes are preventing program to close. 
	import std.stdio;
	readln;
	std.c.stdlib.exit(0);

}

void init(A)(ref A allocator)
{
	import content.sdl;

	auto config = fromSDLFile!GameConfig(GC.it, "config.sdl");
	game.Game = allocator.allocate!Game_Impl(allocator, config);

	initDebugging("pictionary\\textures\\pixel.png");

	auto fsm = Game.gameStateMachine;
	fsm.addState(allocator.allocate!TestState("test.sdl"), "Test");
	Game.transitionTo("Test");

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
	Game.run(Timestep.fixed, 2.msecs);	
}
