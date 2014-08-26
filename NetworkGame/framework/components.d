module framework.components;

import framework;
import concurency.task;
import network.server;
import network.router; 
import network.service;
import window.window;
import window.keyboard;
import window.mouse;
import window.clipboard;

import log;

class WindowComponent : IApplicationComponent
{


	private Window _window;
	private Keyboard _keyboard;
	private Mouse _mouse;
	private Clipboard _clipboard;

	this(WindowConfig config)
	{
		_window    = WindowManager.create(config);
		_keyboard  = Keyboard(&_window);
		_mouse	   = Mouse(&_window);
		_clipboard = Clipboard(&_window);
	}

	~this()
	{
		_window.obliterate();
	}

	override void initialize()
	{
		app.addService(&_window);
		app.addService(&_keyboard);
		app.addService(&_mouse);
		app.addService(&_clipboard);
	}

	override void step(Time time)
	{
		_window.update();
		if(_window.shouldClose)
			app.stop();

		_mouse.update();
		_keyboard.update();
	}

	override void postStep(Time time)
	{
		_mouse.postUpdate();
		_keyboard.postUpdate();
		_window.swapBuffer();
	}
}

class TaskComponent : IApplicationComponent
{
	this(A)(ref A al, ConcurencyConfig config)
	{
		concurency.task.initialize(al, config);	
	}

	override void step(Time time)
	{
		import concurency.task;
		consumeTasks();
	}
}

class NetworkComponent : IApplicationComponent
{
	Server* server;
	Router* router;
	NetworkServices* provider;

	private string resourceDir;

	this(A)(ref A al, ServerConfig config, string resourceDir)
	{
		import allocation;
		server   = al.allocate!Server(al, config);
		router   = al.allocate!Router(al, server);
		provider = al.allocate!NetworkServices(al, servicePort, 100);


		struct ServerServiceData
		{
			char[] gameName;
			uint ip;
			ushort tcpPort, udpPort;
			ushort contentPort;
		}
		
		//This should be all that is nessecary to provide the information for the broadcast.
		ServerServiceData data;
		data.gameName = cast(char[])"tower_defence"; //This line is wrong!
		data.ip = server.listenerAddress.addr;
		data.tcpPort = server.listenerAddress.port;
		data.udpPort = server.updAddress.port;
		data.contentPort = 13462; //BAD BAD BAD

		provider.add("SERVER_DISCOVERY_SERVICE", data);
		this.resourceDir = resourceDir;
	}

	override void initialize()
	{
		import network.file;
		app.addService(server);
		app.addService(router);
		app.addService(provider);

		auto ip = server.listenerAddress.addr;
		taskpool.doTask!(listenForFileRequests)(ip, cast(ushort)13462, resourceDir);
	}

	override void step(Time time)
	{
		server.update(time.delta.to!("seconds", float));
		provider.poll();
	}
}



class RenderComponent : IApplicationComponent
{
	import rendering.renderer;
	SpriteRenderer* renderer;
	this(A)(ref A al, RenderConfig config)
	{
		renderer = al.allocate!SpriteRenderer(al, config, v_Source, f_Source);
	}

	override void initialize()
	{
		app.addService(renderer);
	}

	override void preStep(Time time)
	{
		auto w = app.locate!Window;
		renderer.viewport = w.size;

		import graphics;

		gl.viewport(0,0, cast(uint)w.size.x, cast(uint)w.size.y);
		gl.clearColor(1,1,1,1);
		gl.clear(ClearFlags.color);

		renderer.begin();
	}

	override void postStep(Time time)
	{
		renderer.end();
	}
}

version(RELOADING)
{
	class ReloadingComponent : IApplicationComponent
	{
		override void initialize()
		{
			import content.content, content.reloading;
			auto loader = app.locate!AsyncContentLoader;
			setupReloader(12345, loader);
		}
	}
}