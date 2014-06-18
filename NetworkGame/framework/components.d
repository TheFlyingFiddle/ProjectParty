module framework.components;

import framework;
import concurency.task;
import window.window;
import window.keyboard;
import network.server;
import network.router; 

class WindowComponent : IGameComponent
{
	private Window _window;
	private Keyboard _keyboard;

	this(WindowConfig config)
	{
		_window = WindowManager.create(config);
		_keyboard = Keyboard(&_window);
	}

	~this()
	{
		_window.obliterate();
	}

	override void initialize()
	{
		game.addService(&_window);
		game.addService(&_keyboard);
	}

	override void step(GameTime time)
	{
		_window.update();
		if(_window.shouldClose)
			game.stop();
	}

	override void postStep(GameTime time)
	{
		_window.swapBuffer();
	}
}

class TaskComponent : IGameComponent
{
	this(A)(ref A al, ConcurencyConfig config)
	{
		concurency.task.initialize(al, config);
	}

	override void step(GameTime time)
	{
		import concurency.task;
		consumeTasks();
	}
}

class NetworkComponent : IGameComponent
{
	Server* server;
	Router* router;

	this(A)(ref A al, ServerConfig config)
	{
		import allocation;
		server = al.allocate!Server(al, config);
		router = al.allocate!(Router)(al, server);
	
		router.connections ~= &onPlayerConnect;
	}

	override void initialize()
	{
		game.addService(server);
		game.addService(router);
	}

	void onPlayerConnect(ulong id)
	{
		import network.message, content.content, std.file;

		auto loader = game.locate!AsyncContentLoader;
		auto dir = loader.resourceFolder;

		@OutMessage static struct FileHeader
		{
			string name;
			ulong size;
		}
		
		@OutMessage static struct GameName
		{
			string name;
		}

		server.sendMessage(id, GameName("TowerDefence"));
		
		ubyte[0xFFFF] buffer;
		foreach(entry; dirEntries(dir, SpanMode.depth))
		{
			import std.stdio;
			auto file = File(entry.name, "rb");
			
			FileHeader header = FileHeader(entry.name[dir.length + 1 .. $], file.size);	
			server.sendMessage(id, header);
			
			auto read = 0;
			while(read < file.size)
			{
				auto buf = file.rawRead(buffer[]);
				server.send(id, buf);
				read += buf.length;
			}	
		}

		@OutMessage static struct AllFilesSent { }
		server.sendMessage(id, AllFilesSent());

	}

	


	override void step(GameTime time)
	{
		server.update(time.delta.to!("seconds", float));
	}
}

class RenderComponent : IGameComponent
{
	import rendering.renderer;
	Renderer* renderer;
	this(A)(ref A al, RenderConfig config)
	{
		renderer = al.allocate!Renderer(al, config);
	}

	override void initialize()
	{
		game.addService(renderer);
	}

	override void preStep(GameTime time)
	{
		auto w = game.locate!Window;
		renderer.viewport = w.size;

		import graphics;
		gl.viewport(0,0, cast(uint)w.size.x, cast(uint)w.size.y);
		gl.clearColor(1,0,1,1);
		gl.clear(ClearFlags.color);

		renderer.begin();
	}

	override void postStep(GameTime time)
	{
		renderer.end();
	}
}


version(RELOADING)
{
	class ReloadingComponent : IGameComponent
	{
		override void initialize()
		{
			import content.content, content.reloading;
			auto loader = game.locate!AsyncContentLoader;
			setupReloader(12345, loader);
		}
	}
}