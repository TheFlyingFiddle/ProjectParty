module state;

import game;
import std.json;
import std.file : readText;
import math;
import graphics;
import spriter.loader;
import spriter.types;
import spriter.renderer;

class TestState : IGameState
{
	SpriteInstance[10] instances;
	Mover[10]          movers;
	struct Mover
	{	
		float2 pos;
		float2 vel;
	}

	this()
	{
		import allocation;
		SpriteManager.init(GC.it, 10);
		auto id = SpriteManager.load("elements\\textures\\test0.scon");

		import std.random;
		foreach(ref instance; instances)
			instance = SpriteInstance(0, uniform(0.5, 5), 0, 0, id);

		foreach(ref mover ; movers)
			mover = Mover(float2(uniform(0,1000f), uniform(0f,1000f)), 
							  float2(uniform(-1f,1f), uniform(-1f,1f)));

		Game.sound.playMusic("test.ogg");
	}

	void enter()  { }
	void exit()   { }
	void update() 
	{ 
		foreach(ref instance; instances)
			instance.update(Time.delta);

		foreach(ref mover; movers)
			mover.pos += mover.vel;
	}

	void render() 
	{ 
		gl.clear(ClearFlags.color);

		foreach(i, ref instance; instances) {
			Game.renderer.addSprite(instance, movers[i].pos);
		}
	}
}