module particle;

import graphics, game, content, math, content.sdl, allocation;
import std.stdio, graphics.emitter;
import extender;

class ParticleState : IGameState
{
	ParticleCollection collection;

	int fpsCounter;
	int fps = 60;
	float fpsElapsed = 0;

	float counter = 0;
	FontID font;
	
	this(A)(ref A allocator)
	{
		font = Game.content.loadFont("Blocked72");
		auto atlas = Game.content.loadTextureAtlas("particles");
		auto system = allocator.allocate!ParticleSystem(allocator, atlas, 1024 * 50);

		collection = new ParticleCollection(allocator, system, 1000);
		new ParticleEmitterExtender!ConeEmitter(allocator, collection);
		auto config = fromSDLFile!ParticleEffectConfig(GC.it, "emitter0.sdl");
		collection.addEffect(config, float2(Game.window.size/2));
	}

	void enter() 
	{
	}

	void exit() 
	{
	}

	void update()
	{
		if(Keyboard.isDown(Key.enter))
		{
			import std.random;
			while(collection.effects.length)
				collection.removeEffect(0);
			
			auto config0 = fromSDLFile!ParticleEffectConfig(GC.it, "emitter0.sdl");
			auto config1 = fromSDLFile!ParticleEffectConfig(GC.it, "emitter1.sdl");
			foreach(i; 0 .. 500)
			{
				float2 pos = float2(Game.window.size.x / 2 + uniform(-600, 600), 
									Game.window.size.y / 2 + uniform(-300, 150)); 
				if(dice(0.5, 0.5) == 0)
					collection.addEffect(config0, pos);
				else 
					collection.addEffect(config1, pos);

			}
		}

		collection.update(Time.delta);

		fpsCounter++;
		fpsElapsed += Time.delta;
		if(fpsElapsed >= 1.0f)
		{
			fpsElapsed -= 1.0f;
			fps = fpsCounter;
			fpsCounter = 0;
		}
	}

	void render()
	{
		gl.clearColor(0.5f, 0.5f, 0.5f, 1f);
		gl.clear(ClearFlags.color);
		gl.blendEquationSeparate(BlendEquation.add, BlendEquation.add);
		gl.blendFuncSeparate(BlendFactor.one, BlendFactor.oneMinusSourceAlpha, 
							 BlendFactor.one, BlendFactor.zero);


		mat4 proj = mat4.CreateOrthographic(0, Game.window.fboSize.x, Game.window.fboSize.y, 0, 1, -1);

		collection.render(proj);

		import util.strings;
		char[128] buffer;
		Game.renderer.addText(font, text(buffer, "FPS: ", fps), float2(0, Game.window.fboSize.y), Color.red);
		Game.renderer.addText(font, text(buffer, "Particles: ", collection.system.numActiveParticles), float2(0, Game.window.fboSize.y - 72), Color.red);

	}
}
