module game.game;

import concurency.task;
import content.content;
import network.server;
import network.router;
import window.window;
import game.phone;
import collections.table;
import graphics.color;
import game.messages;
import std.datetime;
import allocation;

alias PlayerTable = Table!(ulong, Player, SortStrategy.sorted);

struct Player
{
	string name;
	Color  color;
}

enum TimeStep
{
	fixed,
	variable
}

struct GameConfig
{
	ContentConfig		contentConfig;
	ServerConfig		serverConfig;
	WindowConfig		windowConfig;
	ConcurencyConfig	concurencyConfig;
}

enum playerDefaultName = "Unkown";

struct Game
{
	PlayerTable players;
	AsyncContentLoader* content;
	Server* server;
	Router* router;
	//SoundPlayer* sound;
	Window window;

	void function(TickDuration, TickDuration) step;

	this(A)(ref A al, GameConfig config, void function(TickDuration, TickDuration) step)
	{
		players = PlayerTable(al, config.serverConfig.maxConnections);
		content = al.allocate!AsyncContentLoader(al, config.contentConfig);
		server = al.allocate!Server(al, config.serverConfig);
		router = al.allocate!Router(al, *server);
		window = WindowManager.create(config.windowConfig);
		Phone.init(al, config.serverConfig.maxConnections, *router);
		
		concurency.task.initialize(al, config.concurencyConfig);

		router.connections		~= &onConnect;
		router.reconnections	~= &onConnect;
		router.disconnections	~= &onDisconnect;
		router.messageHandlers  ~= &onMessage;
		router.setMessageHandler(&onAliasMessage);
		this.step = step;
	}	
	
	~this()
	{
		window.obliterate();
	}

	void onConnect(ulong id)	 
	{
		players[id] = Player(playerDefaultName, Color.white);
	}
	
	void onDisconnect(ulong id)	 
	{
		auto player = id in players;
		if(player.name != playerDefaultName)
			Mallocator.it.deallocate(cast(void[])player.name);

		players.remove(id);
	}

	void onMessage(ulong id, ubyte[] msg)
	{
		import util.bitmanip;
		ubyte msgid = msg.read!ubyte;
		if(msgid == Incoming.alias_.id)
		{
			onAliasMessage(id, AliasMessage(cast(string)msg));
		}
	}


	void onAliasMessage(ulong id, AliasMessage alias_)
	{
		auto player = id in players;
		if(player.name != playerDefaultName)
			Mallocator.it.deallocate(cast(void[])player.name);

		auto name = Mallocator.it.allocate!(char[])(alias_.alias_.length);
		name[] = alias_.alias_[];
		player.name = cast(string)name;
	}

	void run(TimeStep timestep = TimeStep.fixed, Duration frameDur = 16_667.usecs)
	{
		import std.datetime;
		StopWatch watch; watch.start();
		auto last  = watch.peek;
		auto total = last;

		while(!window.shouldClose)
		{
			auto curr  = watch.peek;
			auto delta = curr - last;
			total += delta;
			last = curr;

			server.update(delta.msecs / 1000.0f);
			window.update();
			step(total, delta);
			consumeTasks(); 

			window.swapBuffer();

		
			if(timestep == TimeStep.fixed)
			{
				waitUntilNextFrame(watch, cast(Duration)(watch.peek - last), frameDur);
			}
		}
	}

	private void waitUntilNextFrame(ref StopWatch watch, 
									Duration frametime, 
									Duration target)
	{
		import std.algorithm : max;

		auto sleeptime = max(0.msecs, target - frametime);
		auto now_ = watch.peek;
		while(sleeptime > 1.msecs)
		{
			import core.thread;
			Thread.sleep(1.msecs);
			auto tmp_ = watch.peek;
			sleeptime -= tmp_ - now_;
			now_ = tmp_;
		}

		now_ = watch.peek;
		while(sleeptime > 100.hnsecs)
		{
			auto tmp_ = watch.peek;
			sleeptime -= tmp_ - now_;
			now_ = tmp_;
		}
	}
}