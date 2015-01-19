module main;

import rendering;
import content;
import graphics, math, collections;
import allocation;

import concurency.task;
import content.sdl;
import content.reloading;
import mainscreen;
import framework;
import window.window;
import window.keyboard;

import external_libraries;
import log;

import core.sys.windows.windows;
import core.runtime;
import common;

void main()
{

	try
	{
		init_dlls();
		auto config = fromSDLFile!DesktopAppConfig(Mallocator.it, "config.sdl");
		logInfo("start");
		run(config);
	}
	catch(Throwable t)
	{
		logErr("Crash!\n", t);
		while(t.next) 
		{
			t = t.next;
			logErr(t);
		}

		import std.stdio;
		readln;
	}
}

void run(DesktopAppConfig config) 
{
	scratch_region = RegionAllocator(Mallocator.cit, 1024 * 1024);
	RegionAllocator region = RegionAllocator(Mallocator.cit, 1024 * 1024 * 5);
	auto stack = ScopeStack(region);

	auto app = createDesktopApp(stack, config);

	import screen.loading;
	auto endScreen     = stack.allocate!(MainScreen)();
	auto loadingScreen = stack.allocate!(LoadingScreen)(LoadingConfig(["Fonts.fnt", "Atlas.atlas"], "Fonts"), endScreen);

	FontRenderer renderer = FontRenderer(region, RenderConfig(0xFFFF, 3), vd_Source, fd_Source);
	app.addService(&renderer);

	auto s = app.locate!ScreenComponent;
	s.push(loadingScreen);

	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);


	try
	{
		app.run();
	}
	catch(Throwable t) 
	{
		logErr("Crash!\n", t);
		while(t.next) 
		{
			t = t.next;
			logErr(t);
		}

		import std.stdio;
		readln;
	}
}