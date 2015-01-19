module particle_system;

import particles.system;
import particles.generators;
import particles.updaters;
import particles.bindings;
import common;

import rendering, content;
import rendering.combined;
import graphics;
import components;

class ParticleProcessSystem : System
{
	List!ParticleSystem effects;
	Renderer2D*     renderer;
	AtlasHandle	   atlas;

	override void initialize() 
	{
		alias al = Mallocator.it;
		effects = List!ParticleSystem(al, 20);
		
		//ParticleSystem system = ParticleSystem(al, 20);
		//
		//system.emitRate = 100; //100 per second
		//system.particles = particleData!(typeof(al), 
		//                                 PosVar,
		//                                 VelVar,
		//                                 ColorVar,
		//                                 StartColorVar,
		//                                 EndColorVar,
		//                                 LifeTimeVar)(al, 10000);
		//system.generators = [ &circlePosGen,
		//                      &circleVelGen,
		//                      &basicColorGen,
		//                      &basicTimeGen ];
		//
		//system.updators	  = [ &eulerUpdater,
		//                      &colorUpdater,
		//                      &timeUpdater ];
		//
		//system.variable!(CirclePosRadius)(0.5);
		//system.variable!(CircleSpeed)(Interval!float(0.2, 1.3));
		//system.variable!(StartColor)(Interval!Color(Color(0xEEFF0000), Color(0xEEFF0000)));
		//system.variable!(EndColor)(Interval!Color(Color(0x00000000), Color(0x00000000)));
		//system.variable!(LifeTime)(Interval!float(2, 7));

		effects ~= fromSDLFile!ParticleSystem(al, "particleTest.sdl", sdlContext);

		effects[0].particles.allocate(al);

		renderer = world.app.locate!Renderer2D;

		auto loader = world.app.locate!AsyncContentLoader;
		atlas		= loader.load!TextureAtlas("Atlas");
	}

	override bool shouldAddEntity(ref Entity entity) 
	{
		return entity.hasComp!(Emitter) &&
			   entity.hasComp!(Transform);
	}

	override void preStep(Time time) 
	{
		foreach(e; entities)
		{
			auto t  = e.getComp!Transform;
			auto em = e.getComp!Emitter;

			auto s = &effects[em.effectID];
			s.variable!(Origin)(t.position);
			s.update(time.deltaSec);
		}
	}

	override void postStep(Time time)
	{
		renderer.begin();
		foreach(s; effects)
		{
			auto pos = s.particles.variable!(PosVar);
			auto col = s.particles.variable!(ColorVar);

			foreach(i; 0 .. s.particles.alive)
			{
				float2 min = pos[i] - float2(0.1, 0.1);
				float2 max = pos[i] + float2(0.1, 0.1);

				min *= constants.worldScale;
				max *= constants.worldScale;

				renderer.drawQuad(float4(min.x, min.y, max.x, max.y),
									atlas["pixel"], col[i]);
			}
		}

		renderer.end();
	}
}