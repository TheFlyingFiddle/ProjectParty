module graphics.particle.extender;

import graphics;
import math;
import collections;

struct Callback
{
	ulong id;
	void delegate() callback;
}

final class ParticleCollection
{
	ParticleSystem system;
	List!ParticleEffect effects;
	List!IParticleExtender extenders;
	ulong idCounter;

	List!Callback callbacks;
	
	float2 scale;

	this(A)(ref A allocator, ParticleSystem sys, uint maxEffects)
	{
		effects = List!ParticleEffect(allocator, maxEffects);
		extenders = List!IParticleExtender(allocator, 10);
		callbacks = List!Callback(allocator, 20);
		system = sys;
		idCounter = 0;
		scale = float2.one;
	}

	auto getExtender(T)()
	{
		foreach(extender; extenders)
		{
			auto obj = cast(T) extender;
			if(obj)
				return obj;
		}
		assert(0, "No extender of type "~T.stringof~" present in particle collection");
	}

	ulong addEffect(ref ParticleEffectConfig config, float2 pos, void delegate() callback = null)
	{
		auto id = idCounter++;
		auto effect = ParticleEffect(config, id, pos);
		effects ~= effect;
		foreach(extender; extenders)
		{
			extender.addEffect(effects.length-1, config);
		}

		if(callback)
			callbacks ~= Callback(id, callback);

		return id;
	}

	void removeAt(uint index)
	{
		auto effect = effects[index];
		effects.removeAt(index);
		foreach(extender; extenders)
		{
			extender.removeEffect(index, effect);
		}

		auto cindex = callbacks.countUntil!(x=>x.id == effect.id);
		if (cindex != -1)
		{
			auto callback = callbacks[cindex];
			callbacks.removeAt(cindex);
			callback.callback();
		}
	}

	void removeID(ulong id)
	{
		auto index = effects.countUntil!(e=>e.id == id);
		removeAt(index);
	}

	void addExtender(T)(T t)
	{
		extenders ~= cast(IParticleExtender)t;
	}

	void update(float delta)
	{
		for(int i = effects.length - 1; i >= 0; i--) if(effects[i].playing)
		{
			effects[i].elapsed += delta;
			if(effects[i].elapsed >= effects[i].time)
			{
				if(effects[i].looping)
					effects[i].elapsed -= effects[i].time;
				else
					removeAt(i);
			}
		}

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

	void play(ulong id)
	{
		auto index = effects.countUntil!(x=>x.id == id);
		if(index != -1)
			effects[index].playing = true;
	}

	void pause(ulong id)
	{
		auto index = effects.countUntil!(x=>x.id == id);
		if(index != -1)
			effects[index].playing = false;
	}

	auto ref opIndex(ulong id)
	{
		foreach(ref effect; effects) if(effect.id == id)
		{
			return effect;
		}
		assert(0, "Id not present");
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
		foreach(i, ref emitter; emitters) if(collection.effects[bases[i]].playing)
		{
			emitter.update(collection.system, collection.effects[bases[i]], delta);
		}
	}

	void addEffect(uint index, ref ParticleEffectConfig config)
	{
		foreach(ref emitter; config.emitters) if (emitter.type == Emitter.type)
		{
			emitters ~= Emitter(emitter, collection.system, collection.scale);
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

	ulong id(uint index)
	{
		return collection.effects[bases[index]].id;
	}
}
