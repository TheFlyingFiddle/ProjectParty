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

	WindowConfig  windowConfig;
	ServerConfig  serverConfig;
	ContentConfig contentConfig;

	Asset[] resources;
	Asset[] phoneResources;
}


static Game_Impl* Game;

struct Game_Impl
{
	GameConfig config;

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

		this.config = config;

		ContentReloader.onReload = &onAssetReload;

		foreach(asset ; config.resources)
			content.loadAsset(asset);
	}

	~this()
	{
		window.obliterate();
	}


	void onConnect(ulong id)
	{
		players ~= Player(id, "unknown");

		ubyte[1024 * 16] bytes = void;
		foreach(asset; config.phoneResources)
		{
			sendAsset(id, asset, bytes);
		}
	}

	void onAssetReload(AssetType type, const(char)[] path)
	{
		import std.path;
		auto index = config.phoneResources.countUntil!((x)
		{
			if(x.path.length != path.length) return false;
			foreach(i, c; x.path)
				if(c != path[i]) return false;
			return true;
		});
		
		
		if(index == -1) return;
		ubyte[1024 * 16] bytes = void;
		foreach(player; players)
			sendAsset(player.id, config.phoneResources[index], bytes);
	}


	void sendAsset(ulong id, Asset asset, ubyte[] chunkBuffer)
	{
		import util.bitmanip;
		import std.stdio, std.path, content.common, std.file;

		string s = buildPath(resourceDir, asset.path);
		assert(s.exists, format("The file : %s does not exist!", s));

		File file = File(buildPath(resourceDir, asset.path), "r");
		ubyte[] first = chunkBuffer;

		size_t offset = 0;
		first.write!ushort(cast(ushort)(ubyte.sizeof + ulong.sizeof), &offset);
		first.write!ubyte(NetworkMessage.file,&offset);
		first.write!ubyte(cast(ubyte)asset.type, &offset);
		first.write!ushort(cast(ushort)asset.path.length, &offset);
		foreach(c; asset.path)
			first.write!ubyte(c, &offset);

		auto size = file.size;
		first.write!ulong(size, &offset);
		server.send(id, first[0 .. offset]);

		while(!file.eof)
		{
			auto result = file.rawRead(chunkBuffer);
			server.send(id, result);
		}
	}


	void onDisconnect(ulong id)
	{
		auto index = players.countUntil!(x => x.id == id);
		if(players[index].name != "unknown") {
			Mallocator.it.deallocate((cast(void[])players[index].name));
			players[index].name = null;
		}
		
		players.removeAt(index);
	}

	void onMessage(ulong id, ubyte[] message)
	{
		if(message[0] == NetworkMessage.alias_)
		{
			auto s = Mallocator.it.allocate!(ubyte[])(message.length - 1);
			s[] = message[1 .. $];

			auto index = players.countUntil!(x => x.id == id);
			
			if(players[index].name != "unknown")
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