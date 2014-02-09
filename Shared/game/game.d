module game.game;

import game;
import util.profile;
import core.time, std.datetime,
	core.thread, std.algorithm,
	content, std.uuid, collections.list;

import network.server;
import network.router;

import allocation.common;
import graphics;

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

struct GameConfig
{
	uint maxStates;
	uint maxWindows;
	uint initialRenderSize;
	ContentConfig contentConfig;
	WindowConfig  windowConfig;
	ServerConfig  serverConfig;
}


struct Game
{
	static GameStateFSM gameStateMachine;
	static Window		window;
	static List!Player  players;

	private static Router* router;

	static Content*    content;
	static Renderer*   renderer;
	static Server*     server;

	static void init(A)(ref A allocator, GameConfig config)
	{
		content = allocator.allocate!Content(allocator, config.contentConfig);
		server  = allocator.allocate!Server(allocator, config.serverConfig);
		router  = allocator.allocate!Router(allocator, *server);

		router.connectionHandlers    ~= (x) => onConnect(x);
		router.reconnectionHandlers  ~= (x) => onConnect(x);
		router.disconnectionHandlers ~= (x) => onDisconnect(x);


		players = List!Player(allocator, config.serverConfig.maxConnections);
		Phone.init(allocator, config.serverConfig.maxConnections, *router);


		WindowManager.init(allocator, config.maxWindows);
		gameStateMachine = GameStateFSM(allocator, config.maxStates);
		window			 = WindowManager.create(config.windowConfig);

		renderer     = allocator.allocate!Renderer(allocator, 100, config.initialRenderSize);
	}

	static void shutdown()
	{
		window.obliterate();
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

		import logging;
		auto testLog = LogChannel("Test");

		while(!window.shouldClose)
		{
			auto curr = watch.peek();
			Time._delta = cast(Duration)(curr - last);
			Time._total += Time._delta;
			last = curr;

			{
				auto p = StackProfile("Server / Message Handling");
				server.update(Time.delta);
			}

			window.update(); //Process windowing events.

			{
				auto p = StackProfile("Update");
				gameStateMachine.update();
			}

			{
				auto p = StackProfile("Render");
				renderer.start();

				gameStateMachine.render();

				import math;
				mat4 proj = mat4.CreateOrthographic(0,window.fboSize.x,window.fboSize.y,0,1,-1);
				renderer.end(proj);
			}

			window.swapBuffer();

			ContentReloader.processReloadRequests();
			if(timestep == Timestep.fixed) {
				auto frametime = watch.peek() - last;
				Duration sleeptime = max(0.msecs, target - frametime);
				Thread.sleep(sleeptime);
			}
		}
	}
}