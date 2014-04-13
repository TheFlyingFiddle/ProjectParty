module extender;
import graphics;
import math;
import collections;

final class ParticleCollection
{
	ParticleSystem system;
	List!ParticleEffect effects;
	List!IParticleExtender extenders;

	this(A)(ref A allocator, ParticleSystem sys, uint maxEffects)
	{
		effects = List!ParticleEffect(allocator, maxEffects);
		extenders = List!IParticleExtender(allocator, 10);
		system = sys;
	}

	void addEffect(ref ParticleEffectConfig config, float2 pos)
	{
		auto effect = ParticleEffect(pos);
		effects ~= effect;
		foreach(extender; extenders)
		{
			extender.addEffect(effects.length-1, config);
		}
	}

	void removeEffect(uint index)
	{
		auto effect = effects[index];
		effects.removeAt(index);
		foreach(extender; extenders)
		{
			extender.removeEffect(index, effect);
		}
	}

	void addExtender(T)(T t)
	{
		extenders ~= cast(IParticleExtender)t;
	}

	void update(float delta)
	{
		foreach(extender; extenders)
		{
			extender.update(delta);
		}
		system.update(delta);
	}

	void render(ref mat4 mat)
	{
		system.render(mat);
	}
}

interface IParticleExtender
{
	void update(float delta);
	void addEffect(uint index, ref ParticleEffectConfig config);
	void removeEffect(uint index, ParticleEffect effect);
}

final class ParticleEmitterExtender(Emitter) : IParticleExtender
{
	ParticleCollection collection;
	List!Emitter	emitters;
	List!uint		bases;


	this(A)(ref A allocator, ParticleCollection coll)
	{
		collection = coll;
		emitters = List!Emitter(allocator, coll.effects.capacity * 2);
		bases = List!uint(allocator, coll.effects.capacity * 2);
		collection.addExtender(this);
	}

	void update(float delta)
	{
		foreach(i, ref emitter; emitters)
		{
			emitter.update(delta, collection.system, collection.effects[bases[i]]);
		}
	}

	void addEffect(uint index, ref ParticleEffectConfig config)
	{
		foreach(ref emitter; config.emitters) if (emitter.type == Emitter.type)
		{
			emitters ~= Emitter(emitter, collection.system);
			bases ~= index;
		}
	}

	void removeEffect(uint index, ParticleEffect effect)
	{
		for(int i = emitters.length - 1; i >= 0; i--)
		{
			if(bases[i] == index)
			{
				bases.removeAt(i);
				emitters.removeAt(i);
			}
			else if(bases[i] > index)
			{
				bases[i]--;
			}
		}
	}
}

struct ParticleEffectConfig
{
	List!EmitterConfig emitters;
}