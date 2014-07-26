module main;

import rendering;
import content;
import graphics, math, collections;
import allocation;

import concurency.task;
import content.sdl;
import content.reloading;
import framework;
import window.window;
import window.keyboard;

import external_libraries;
import log;

void main()
{
	import std.stdio;

	init_dlls();
	initializeRemoteLogging("TowerDefence");
	scope(exit) termRemoteLogging();

	try
	{
		auto config = fromSDLFile!PhoneGameConfig(Mallocator.it, "config.sdl");
		run(config);
	}
	catch(Throwable t) {
		logErr("Crash!\n", t);
		while(t.next) {
			t = t.next;
			logErr(t);
		}

	}
}

void run(PhoneGameConfig config) 
{
	RegionAllocator region = RegionAllocator(Mallocator.cit, 1024 * 1024 * 10);
	auto stack = ScopeStack(region);

	auto game = createPhoneGame(stack, config);

	import screen.loading;
	auto endScreen     = stack.allocate!(Screen1)();
	auto loadingScreen = stack.allocate!(LoadingScreen)(LoadingConfig(["ComicSans32.fnt"], "ComicSans32"), endScreen);
	
	auto s = game.locate!ScreenComponent;
	s.push(loadingScreen);

	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	try
	{
		game.run();
	}
	catch(Throwable t) {
		logErr("Crash!\n", t);
		while(t.next) {
			t = t.next;
			logErr(t);
		}
	}
}
	
class Screen1 : Screen
{
	import network.server;
	import network.router;
	import network.message;
	import network_types;

	FontHandle font;
	AtlasHandle atlas;
	FontRenderer* renderer;

	this() { super(false, false); }

	float rotation = 0;
	override void initialize() 
	{
		auto loader = game.locate!AsyncContentLoader;

		font	= loader.load!Font("consola");
		atlas	= loader.load!TextureAtlas("Atlas");

		auto router = game.locate!Router;
		router.setMessageHandler(&handleTestMessageA);	

		renderer = Mallocator.it.allocate!FontRenderer(Mallocator.it, RenderConfig(0xFFFF, 3), vd_Source, fd_Source);
	}

	void handleTestMessageA(ulong id, TestMessageA message)
	{
		logInfo("Received message: ", message);
	}

	override void update(GameTime time) 
	{	
		rotation += time.delta.to!("seconds", float);	

		auto keyboard = game.locate!Keyboard;	
		if(keyboard.isDown(Key.enter))
		{
			auto s = Mallocator.it.allocate!(Screen2)();
			owner.push(s);
		}
		else if(keyboard.isDown(Key.q))
			thresh.x += 0.01;
		else if(keyboard.isDown(Key.w))
			thresh.x -= 0.01;
		else if(keyboard.isDown(Key.a))
			thresh.y += 0.01;
		else if(keyboard.isDown(Key.s))
			thresh.y -= 0.01;
		else if(keyboard.isDown(Key.z))
			thresh.z += 0.01;
		else if(keyboard.isDown(Key.x))
			thresh.z -= 0.01;

		import std.algorithm;

		


		thresh.x = clamp(thresh.x,0,1);
		thresh.y = clamp(thresh.y,0,1);
		thresh.z = clamp(thresh.z,0,1);

		auto server = game.locate!Server;
		if(server.activeConnections.length > 0)
		{
			server.sendMessage(server.activeConnections[0].id, TestMessageB(10, 100.0));
		}
	}

	float3 thresh = float3(0,0,1);
	override void render(GameTime time)
	{

		
		auto chnl = LogChannel("Lame");
	
		auto screen = game.locate!Window;
		renderer.viewport(float2(screen.size));


		renderer.begin();

		import util.strings;
		int y = 10;
		foreach(i; 1 .. 30)
		{
			Color c;
			//c.r = i * 0.1;
			//c.b = i * 0.1;
			c.g = i * (1 / 30.0);
			c.b = 0.5  + i * (1 / 60.0);
			c.a = 1;


			renderer.drawText("The quick brown fox jumped over the lazy dog[p]'\\\";ö'äöå¨p!#¤%&/()=QWERTYUIOPASDFGHJKLÖÄ>ZXCVBNM;:", float2(0,  screen.size.y - 10 - y), i * 5, font.asset, Color.black,thresh);
			y += 5 + i * 5;
		}

		renderer.end();

		auto rend = game.locate!SpriteRenderer;
		//rend.drawQuad(float4(100,100,500,500), atlas.asset.orange, Color.white);
	}
}

class Screen2 : Screen
{
	this() { super(true, false); }
}