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
	private string resourceDir;

	this(A)(ref A al, ServerConfig config, string resourceDir)
	{
		import allocation;
		server   = al.allocate!Server(al, config);
		router   = al.allocate!Router(al, server);
		this.resourceDir = resourceDir;
	}

	override void initialize()
	{
		import network.file;
		game.addService(server);
		game.addService(router);
		auto ip = server.listenerAddress.addr;
		taskpool.doTask!(listenForFileRequests)(ip, cast(ushort)13462, resourceDir);
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


class LuaLogComponent : IGameComponent
{
	this()
	{

	}

	override void initialize()
	{
		auto router = game.locate!Router;
		router.messageHandlers ~= &onMessage;
	}

	void onMessage(ulong id, ubyte[] msg)
	{
		import util.bitmanip;
		auto m = msg.read!ushort;
		if(m == 10)
		{
			import std.stdio;
			writeln(msg.read!(char[]));				
		}
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