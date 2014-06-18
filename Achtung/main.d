module main;

import log,
	   allocation, 
	   achtung,
	   game_over,
	   achtung_game_data,
	   types;


auto logChnl = LogChannel("MAIN");
void main()
{
	import std.stdio;
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

	auto fsm = Game.gameStateMachine;
	auto agd = new AchtungGameData(allocator, config.serverConfig.maxConnections);

	fsm.addState(new AchtungGameState(allocator, "Config.sdl", agd), "Achtung");
	import game.states.lobby;
	fsm.addState(allocator.allocate!LobbyState(allocator, "lobby.sdl", 
			     "Achtung", IncomingMessages.readyMessage), "MainMenu");
	fsm.addState(allocator.allocate!GameOverGameState(allocator, agd, 10), "GameOver");
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
	Game.run(Timestep.fixed, 16_667.usecs);	
}