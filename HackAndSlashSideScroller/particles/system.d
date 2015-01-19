module particles.system;

import util.hash;
import util.variant;
import content.sdl;
import particles.bindings;
import allocation;

enum MaxVariableSize = 32;

struct Interval(T)
{
	T min, max;
}

struct LifeSpan
{
	float elapsed;
	float end;

	float relative()
	{
		return elapsed / end;
	}
}

struct ParticleVariable
{
	HashID	  id;
	TypeHash  type;
	size_t	  elementSize;
	void*     data;

	void allocate(A)(ref A a, size_t cap)
	{
		data = a.allocate!(void[])(cap * elementSize).ptr;
	}

	T[] slice(T)(size_t a, size_t b)
	{
		return cast(T[])(data[elementSize * a .. elementSize * b]);
	}

	void swap(size_t a, size_t b)
	{
		if(a == b) return;

		void[MaxVariableSize] temp = void;	

		immutable start = a * elementSize;
		immutable end   = b * elementSize;

		temp[0 .. elementSize] = data[start .. start + elementSize];
		data[start .. start + elementSize] = data[end .. end + elementSize];
		data[end .. end + elementSize]	   = temp[0 .. elementSize];
	}
}

ParticleVariable particleVariable(T, A)(ref A all, string name, size_t cap) 
{
	import allocation;
	static assert(T.sizeof <= MaxVariableSize, "Variable to large!");

	auto id		     = bytesHash(name);
	auto type	     = cHash!T;
	auto elementSize = T.sizeof; 
	auto data = all.allocate!(void[])(cap * elementSize);

	return ParticleVariable(id, type, elementSize, data.ptr);
}

struct ParticleData
{
	@Convert!(varConv) 
	ParticleVariable[] variables;

	size_t			   alive;				
	size_t			   capacity;

	void allocate(A)(ref A allocator)
	{
		foreach(ref var; variables)
		{
			var.allocate(allocator, capacity);
		}
	}

	size_t spawn(size_t count)
	{
		assert(alive + count <= capacity);

		size_t old = alive;
		alive += count;
		return old;
	}

	void kill(size_t who)
	{
		if(who < alive)
		{
			foreach(ref v; variables)
			{
				v.swap(who, --alive);
			}
		}
	}

	T[] variable(T, string name)(size_t start, size_t count)
	{
		enum id = bytesHash(name);
		foreach(ref v; variables)
		{
			if(id == v.id && cHash!T == v.type)
			{
				return v.slice!T(start, start + count);
			}
		}	

		assert(0, "Invalid variable! " ~ name ~ " of type " ~ T.stringof); 
	}


	T[] variable(T, string name)()
	{
		return variable!(T, name)(0, alive);
	}
}

ParticleData particleData(A, T...)(ref A all, size_t cap)
{
	import allocation;
	auto variables = all.allocate!(ParticleVariable[])(T.length / 2);
	foreach(i; staticIota!(0, T.length, 2))
	{
		variables[i / 2] = particleVariable!(T[i])(all, T[i + 1], cap);
	}

	return ParticleData(variables, 0, cap);
}


alias Generator = void function(ref ParticleSystem, float, size_t, size_t);
alias Updator   = void function(ref ParticleSystem, float);


struct ParticleSystem
{
	float emitRate;
	@Convert!(stringToFunc!(Generator, "particles.generators")) 
	Generator[]	generators;
	
	@Convert!(stringToFunc!(Updator,   "particles.updaters"))  
	Updator[]	updators;

	VariantTable!(32)	variables;
	ParticleData		particles;

	this(A)(ref A all, size_t cap)
	{
		variables = VariantTable!32(all, cap);
	}

	void variable(T, string name)(auto ref T data)
	{
		variables.opDispatch!(name, T)(data);
	}

	T variable(T, string name)()
	{
		return variables.opDispatch!(name)().get!T;
	}

	void update(float dt) 
	{
		import std.algorithm;
		size_t maxNewParticles = cast(size_t)(dt * emitRate);
		size_t count = min(maxNewParticles, particles.capacity - particles.alive);
		size_t start = particles.spawn(count);

		foreach(ref gen; generators)
			gen(this, dt, start, count);

		foreach(ref u; updators)
			u(this, dt);
	}
}


unittest
{
	import allocation, math, graphics;
	ParticleData data = 
		particleData!(Mallocator, 
					  float2, "pos",
					  float2, "scale",
					  Color , "color")(Mallocator.it, 100);

	ParticleSystem system;
	system.emitRate  = 100;
	system.particles = data; 

}


template staticIota(size_t s, size_t e, size_t step = 1)
{
	import std.typetuple : TypeTuple;
	static if(s < e)
		alias staticIota = TypeTuple!(s, staticIota!(s + step, e, step));
	else 
		alias staticIota = TypeTuple!();
}