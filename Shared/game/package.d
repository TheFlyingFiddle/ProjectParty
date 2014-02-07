module game;

public import game.time;
public import game.state;
public import game.window;
public import game.input;
public import game.rendering;

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

struct Game
{
	static GameStateFSM gameStateMachine;
	static Window		window;
	static List!Player  players;
	static Server  server;

	private static Router* router;

	//Temporary?
	static SpriteBuffer* spriteBuffer;
	static Renderer*     renderer;

	static void init(A)(ref A allocator, size_t numStates, WindowConfig config, ushort broadcastPort)
	{
		gameStateMachine = GameStateFSM(allocator, numStates);
		window			 = WindowManager.create(config);

		server = Server(allocator, 300, broadcastPort); //NOOO 100 is a number not a variable.
		router = allocator.allocate!Router(allocator, 300, server);
		
		router.connectionHandlers    ~= (x) => onConnect(x);
		router.reconnectionHandlers  ~= (x) => onConnect(x);
		router.disconnectionHandlers ~= (x) => onDisconnect(x);

		players = List!Player(allocator, 300);
		Phone.init(allocator, 300, *router);

		//There should really only be a single render. 
		//This render should allow adding a batch of preprocessed
		//objects aswell as single one shot items. Rendering
		//should be done by a call to draw(matrix) this will force 
		//a flush of the render que and later one can safly change
		//rendertargets etc. But for now we only need to implement
		//basic stuff.
		spriteBuffer = allocator.allocate!SpriteBuffer(100_000, allocator);
		renderer     = allocator.allocate!Renderer(allocator, 100, 100_000);
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
	
		import core.memory;
		GC.disable();

		while(!window.shouldClose)
		{
			auto curr = watch.peek();
			Time._delta = cast(Duration)(curr - last);
			Time._total += Time._delta;
			last = curr;

			testLog.info("Before server");
		
			server.update(Time.delta);

			testLog.info("Before update");
			window.update(); //Process windowing events.

			{
				auto p = StackProfile("Update");
				gameStateMachine.update();
			}

			testLog.info("Before render");
			{
				auto p = StackProfile("Render");
				testLog.info("After render");
				gameStateMachine.render();

			}


			testLog.info("Before swap");
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