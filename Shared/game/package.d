module game;

public import game.time;
public import game.state;
public import game.window;
public import game.input;

import util.profile;
import core.time, std.datetime,
	core.thread, std.algorithm,
	content, std.uuid, collections.list;

import network.server;
import network.router;

import allocation.common;

enum Timestep
{
	variable,
	fixed
}

alias GameStateFSM = FSM!(IGameState, string);

struct Player 
{
	ulong id;
}

struct Game
{
	static GameStateFSM gameStateMachine;
	static Window		window;
	static List!Player  players;
	private static Server     server;
	private static Router*    router;

	static void init(A)(ref A allocator, size_t numStates, WindowConfig config, ushort broadcastPort)
	{
		gameStateMachine = GameStateFSM(allocator, numStates);
		window			  = WindowManager.create(config);

		server = Server(allocator, 100, broadcastPort); //NOOO 100 is a number not a variable.
		router = allocator.allocate!Router(allocator, 100, server);
		
		router.connectionHandlers    ~= (x) => onConnect(x);
		router.disconnectionHandlers ~= (x) => onConnect(x);
		router.disconnectionHandlers ~= (x) => onDisconnect(x);

		players = List!Player(allocator, 100);
		Phone.init(allocator, 100, *router);
	}

	static void onConnect(ulong id)
	{
		players ~= Player(id);
	}

	static void onDisconnect(ulong id)
	{
		players.remove(Player(id));
	}

	static void run(Timestep timestep, Duration target = 0.msecs)
	{
		StopWatch watch;
		watch.start();
		auto last = watch.peek();
		while(!window.shouldClose)
		{
			auto curr = watch.peek();
			Time._delta = cast(Duration)(curr - last);
			Time._total += Time._delta;
			last = curr;
		
			server.update(Time.delta);

			{
				auto p = StackProfile("Update");
				gameStateMachine.update();
			}
			
			{
				auto p = StackProfile("Render");
				gameStateMachine.render();
			}


			window.swapBuffer();
			window.update();


			ContentReloader.processReloadRequests();
			if(timestep == Timestep.fixed) {
				auto frametime = watch.peek() - last;
				Duration sleeptime = max(0.msecs, target - frametime);
				Thread.sleep(sleeptime);
			}
		}
	}
}