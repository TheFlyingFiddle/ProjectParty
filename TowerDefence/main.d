module main;

import glue;
import rendering;
import content;
import graphics, math, collections;
import allocation;

import concurency.task;
import content.sdl;
import content.reloading;
import game.game;

void writer(string msg, int number)
{
	import std.stdio;
	writeln("Writer recieived message : ", msg);
	writeln("Number of the message was : ", number);
}

void main()
{
	import std.stdio;

	init_dlls();
	try
		run();
	catch(Throwable t)
		writeln(t);

	readln;
}

void run()
{
	auto config = fromSDLFile!GameConfig(Mallocator.it, "config.sdl");
	g = Game(Mallocator.it, config, &step);

	rend = Mallocator.it.allocate!Renderer(Mallocator.it, 1024, 3);
	rend.viewport = g.window.size;

	g.content.asyncLoad!TextureAtlas("Atlas");
	g.content.asyncLoad!Font("ComicSans32");

	setupReloader(12345, g.content);

	screen = LoadingScreen(rend, &g);

	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	g.run();
}

import std.datetime;
Game g;
Renderer* rend;
LoadingScreen screen;

void step(TickDuration total, TickDuration delta)
{
	screen.draw();

	if(g.content.areAllLoaded())
	{
	    auto atlas = g.content.item!TextureAtlas("Atlas"),
	         font  = g.content.item!Font("ComicSans32");
	
	    draw(*rend, atlas.asset, font.asset);
	}
	else 
	{
	    //taskpool.doTask!writer("Mofasa", i++);	
	}
}
	

void draw(ref Renderer renderer, 
		  ref TextureAtlas atlas,
		  ref Font font)
{
	gl.clearColor(0.2,0.2,0.2,1);
	gl.clear(ClearFlags.color);

	import rendering.shapes;
	renderer.begin();
	
	foreach(i, frame; atlas)
	{
		renderer.drawQuad(float4(100 * i + 50, 50, 100 * i + 150, 150), 
						  frame, Color.white);
	}

	renderer.drawText("Hello World!", float2(50, 300), font, Color.white);
	renderer.end();
}


struct LoadingScreen
{
	Renderer* renderer;
	Game* game;

	this(Renderer* renderer, Game* game)
	{
		this.renderer = renderer;
		this.game     = game;
	}

	void draw()
	{
		import rendering.shapes;
		auto font = game.content.load!Font("ComicSans32");	

		renderer.begin();
		renderer.drawText("Loading stuff\nSo much stuff", 
						  float2(0, 32), 
						  font.asset, 
						  Color.white);
		renderer.end();
	}
}
