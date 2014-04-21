module game.game;

import game;
import util.profile;
import core.time, std.datetime,
	core.thread, std.algorithm,
	content, std.uuid, collections.list,
	allocation, sound;

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
	bool ready;
}

struct TransitionMessage
{
	enum ubyte id = NetworkMessage.transition;
	enum maxSize = 128;
	string state;
}

struct GameConfig
{
	uint maxStates;
	uint maxWindows;
	uint initialRenderSize;

	WindowConfig  windowConfig;
	ServerConfig  serverConfig;
	ContentConfig contentConfig;
	SoundConfig	  soundConfig;

	Asset[] resources;
	@Convert!foldersToFiles() string[] phoneResources;

	string gameName;
}

string[] foldersToFiles(string[] folders)
{
	import std.file;
	import content;
	import std.path;
	import std.array;

	auto app = appender!(string[]);
	foreach(folder; folders)
	{
		foreach (DirEntry e; dirEntries(buildPath(resourceDir, folder), SpanMode.breadth))
		{
			auto s = e.name.replace("\\","/");
			s = s[resourceDir.length +1.. $];
			app.put(s);
		}
	}
	return app.data;
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
	SoundPlayer*    sound;
	Window			window;

	this(A)(ref A allocator, GameConfig config)
	{
		server  = allocator.allocate!Server(allocator, config.serverConfig);
		router  = allocator.allocate!Router(allocator, *server);
		
		router.connectionHandlers    ~= &onConnect;
		router.reconnectionHandlers  ~= &onReconnect;
		router.messageHandlers		 ~= &onMessage;
		router.disconnectionHandlers ~= &onDisconnect;


		players = List!Player(allocator, config.serverConfig.maxConnections);
		Phone.init(allocator, config.serverConfig.maxConnections, *router);

		gameStateMachine = allocator.allocate!GameStateFSM(allocator, config.maxStates);
		
		sound	= allocator.allocate!SoundPlayer(allocator, config.soundConfig);

		WindowManager.init(allocator, config.maxWindows);
		window		 = WindowManager.create(config.windowConfig);

		renderer     = allocator.allocate!Renderer(allocator, config.initialRenderSize);

		this.config = config;

		ContentReloader.onTrackedChanged = &onAssetReload;

		content = allocator.allocate!Content(allocator, config.contentConfig);
		foreach(asset ; config.resources)
			content.loadAsset(asset);

		foreach(asset ; config.phoneResources)
			ContentReloader.registerTracked(asset);
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

		sendAllAssetsSent(id);
	}

	void onReconnect(ulong id)
	{
		players ~= Player(id, "unknown");

		sendAllAssetsSent(id);
	}

	void onAssetReload(const(char)[] path)
	{
		import util.bitmanip,std.array;
		import std.path;
		auto p2 = path.replace("\\", "/");
		auto index = config.phoneResources.countUntil!(x => x == p2);
		if(index == -1) return;

		ubyte[0xFFFF] bytes = void;
		foreach(player; players)
			sendAsset(player.id, config.phoneResources[index], bytes);


		size_t offset = 2;
		auto msg = bytes[];
		msg.write!ubyte(NetworkMessage.fileReload, &offset);
		msg.write(p2, &offset);
		msg.write!ushort(cast(ushort)(offset - 2), 0);
		
		import logging;
		auto logChnl = LogChannel("GAME");
		logChnl.info("Offset:", offset);
		foreach(player; players)
			server.send(player.id, msg[0 .. offset]);
	}


	void sendAsset(ulong id, const(char)[] path, ubyte[] chunkBuffer)
	{
		import util.bitmanip;
		import std.path, content.common, std.file, std.stdio : File;

		string s = buildPath(resourceDir, path);
		assert(s.exists, format("The file : %s does not exist!", s));

		File file = File(s, "r");
		if(file.size == 0) return;

		ubyte[] first = chunkBuffer;

		size_t offset = 2;
		first.write!ubyte(NetworkMessage.file,&offset);

		//TODO: We should write the file type here.
		//first.write(type, &offset);
		
		first.write(path, &offset);

		auto size = file.size;
		first.write!ulong(size, &offset);

		first.write!ushort(cast(ushort)(offset - 2), 0);
		server.send(id, first[0 .. offset]);

		import logging;
		auto l = LogChannel("MSG");
		l.info("sendin asset of size ", size);

		while(!file.eof)
		{
			auto result = file.rawRead(chunkBuffer);
			server.send(id, result);
		}
	}

	void sendAllAssetsSent(ulong id)
	{
		ubyte[128] bytes = void;
 		import util.bitmanip;
		auto b = bytes[];
		size_t offset = 2;
		b.write!ubyte(cast(ubyte)NetworkMessage.allFilesSent, &offset);
		b.write(config.gameName, &offset);
		b.write!ushort(cast(ushort)(offset - 2), 0);
		server.send(id, b[0 .. offset]);
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
		} else if (message[0] == NetworkMessage.luaLog) {
			import logging;

			auto logChannel = LogChannel("lua");
			logChannel.info(cast(char[]) message[3..$]);
		}
	}

	void transitionTo(string newState)
	{
		import network.message;
		auto msg = TransitionMessage(newState);
		foreach (player ; players)
			server.sendMessage(player.id, msg);

		gameStateMachine.transitionTo(newState);
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