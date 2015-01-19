module particles.emiter;

import util.hash;
import util.variant;

enum MaxVariableSize = 32;

struct Interval
{
	float min, max;
}

struct ParticleVariable
{
	HashID	  id;
	TypeHash  type;
	size_t	  elementSize;
	void*     data;

	this(T, A)(ref A all, string name, size_t cap) 
	{
		static assert(T.sizeof <= MaxVariableSize, "Variable to large!");
		this.name	     = bytesHash(name);
		this.type	     = cHash!T;
		this.elementSize = T.sizeof; 
		this.data = all.allocate!(void[])(cap * elementSize);
	}

	T[] slice(T)(size_t a, size_t b)
	{
		return cast(T[])(data[elementSize * a .. elementSize * b]);
	}

	void swap(size_t a, size_t b)
	{
		void[MaxVariableSize] temp = void;	
	
		immutable start = a * elementSize;
		immutable end   = b * elementSize;
		
		temp[0 .. elementSize] = data[start .. start + elementSize];
		data[start .. start + elementSize] = data[end .. end + elementSize];
		data[end .. end + elementSize]	   = temp[0 .. elementSize];
	}
}
struct ParticleData
{
	ParticleVariable[] variables;

	size_t			   alive;				
	size_t			   capacity;
	
	this(A, T...)(ref A all, size_t cap)
	{
		variables = all.allocate!(ParticleVariable)(T.length / 2);
		foreach(i; staticIota!(0, T.length, 2))
		{
			variables[i % 2] = ParticleVariable!(T[i])(all, T[i + 1], cap);
		}

		alive    = 0;
		capacity = cap; 
	}
	
	this(ParticleVariable[] variables, size_t cap)
	{
		variables = variables;
		alive	  = 0;
		capacity  = cap;
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
				return v.slice(start, start + count);
			}
		}	
		
		assert(0, "Invalid variable! " ~ name ~ " of type " ~ T.stringof); 
	}
}

alias Generator = void function(float, ParticleData*, size_t, size_t);
alias Updator   = void function(float, ParticleData*);

struct ParticleSystem
{
	float emitRate;
	Generator[]			generators;
	Updator[]			updators;
	VariantTable!(32)	variables;
	ParticleData		particles;
	
	void variable(T, string name)(auto ref T data)
	{
		variables.opDispatch!(name, T)(value);
	}

	T variable(T, string name)()
	{
		return variables.opDispatch!(name)();
	}

	void update(float dt) //Systems can only really be updated
										   //In the context of a position.
	{
		size_t maxNewParticles = cast(size_t)(dt * emitRate);
		size_t count = min(maxNewParticles, data.capacity - data.alive);
		size_t start = data.spawn(count);

		foreach(ref gen; generators)
			gen(dt, p, start, count, this);

		foreach(ref u; updators)
			u(dt, p, this);
	}
}


unittest
{
	import allocation;
	ParticleData data = 
		ParticleData!(float2, "pos",
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
		alias staticIota = TypeTuple!(s, staticIota!(s + step, e));
	else 
		alias staticIota = TypeTuple!();
}