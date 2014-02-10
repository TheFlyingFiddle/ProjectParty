module game.game;

import game;
import util.profile;
import core.time, std.datetime,
	core.thread, std.algorithm,
	content, std.uuid, collections.list,
	allocation;

import network.server;
import network.router;

import allocation.common;
import graphics;

enum Timestep
{
	variable,
	fixed
}

interface IGameState
{
	void enter();
	void exit();

	void update();
	void render();
}

alias GameStateFSM = FSM!(IGameState, string);

struct Player 
{
	ulong id;
	string name;
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


static Game_Impl* Game;

struct Game_Impl
{
	List!Player  players;

	GameStateFSM*	gameStateMachine;
	Content*		content;
	Renderer*		renderer;
	Server*			server;
	Router*			router;
	Window			window;

	this(A)(ref A allocator, GameConfig config)
	{
		content = allocator.allocate!Content(allocator, config.contentConfig);
		server  = allocator.allocate!Server(allocator, config.serverConfig);
		router  = allocator.allocate!Router(allocator, *server);

		router.connectionHandlers    ~= &onConnect;
		router.reconnectionHandlers  ~= &onConnect;
		router.messageHandlers		 ~= &onMessage;
		router.disconnectionHandlers ~= &onDisconnect;


		players = List!Player(allocator, config.serverConfig.maxConnections);
		Phone.init(allocator, config.serverConfig.maxConnections, *router);

		gameStateMachine = allocator.allocate!GameStateFSM(allocator, config.maxStates);


		WindowManager.init(allocator, config.maxWindows);
		
		window		 = WindowManager.create(config.windowConfig);
		renderer     = allocator.allocate!Renderer(allocator, config.initialRenderSize);
	}

	~this()
	{
		window.obliterate();
	}


	void onConnect(ulong id)
	{
		players ~= Player(id, null);
	}

	void onDisconnect(ulong id)
	{
		auto index = players.countUntil!(x => x.id == id);
		if(players[index].name.length != 0) {
			Mallocator.it.deallocate((cast(void[])players[index].name));
			players[index].name = null;
		}
		
		players.removeAt(index);
	}

	void onMessage(ulong id, ubyte[] message)
	{
		if(message[0] == 0)
		{
			auto s = Mallocator.it.allocate!(ubyte[])(message.length - 1);
			s[] = message[1 .. $];

			auto index = players.countUntil!(x => x.id == id);
			
			if(players[index].name.length != 0)
				Mallocator.it.deallocate((cast(void[])players[index].name));

			players[index].name = cast(string)s;
		}
	}

	void run(Timestep timestep, Duration target = 0.msecs)
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
				import math;
				mat4 proj = mat4.CreateOrthographic(0,window.fboSize.x,window.fboSize.y,0,1,-1);
				renderer.start(proj);
				gameStateMachine.render();
				renderer.end();
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