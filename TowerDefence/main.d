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
	try
	{
		auto config = fromSDLFile!PhoneGameConfig(Mallocator.it, "config.sdl");
		run(config);
	}
	catch(Throwable t) {
		logInfo("Crash!\n", t);
		readln;
	}

	import std.c.stdlib;
	exit(0);
}

void run(PhoneGameConfig config) 
{
	RegionAllocator region = RegionAllocator(Mallocator.cit, 1024 * 1024 * 10);
	auto stack = ScopeStack(region);

	initializeRemoteLogging("TowerDefence", 54321);
	scope(exit) termRemoteLogging();

	auto game = createPhoneGame(stack, config);

	import screen.loading;
	auto endScreen     = stack.allocate!(Screen1)();
	auto loadingScreen = stack.allocate!(LoadingScreen)(LoadingConfig(["Atlas.atlas", "ComicSans32.fnt"], "ComicSans32"), endScreen);
	
	auto s = game.locate!ScreenComponent;
	s.push(loadingScreen);

	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	game.run();
}
	
class Screen1 : Screen
{
	FontHandle font;
	AtlasHandle atlas;

	this() { super(false, false); }

	float rotation = 0;
	override void initialize() 
	{
		auto loader = game.locate!AsyncContentLoader;

		font	= loader.load!Font("ComicSans32");
		atlas	= loader.load!TextureAtlas("Atlas");
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
	}

	override void render(GameTime time)
	{
		auto renderer = game.locate!Renderer;

		auto chnl = LogChannel("Lame");
		chnl.info("There is a channel in the ocean!");

		import util.strings;
		renderer.drawText("Hello, World!", float2(0, 200), font.asset, Color.black);
		renderer.drawText(cast(string)text1024(time.delta.to!("seconds", float)), float2(0, 400), font.asset, Color.black);
		foreach(i, item; atlas.asset())
		{
			renderer.drawQuad(float4(100 * i + 50, 50, 100 * i + 150, 150), rotation, item, Color.white);
		}
	}
}

class Screen2 : Screen
{
	this() { super(true, false); }
}