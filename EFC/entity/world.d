module entity.world;
import entity.system;
import collections.list;

struct ServiceLocator
{
	import util.hash;
	struct Service
	{
		uint hash;
		void* ptr; 
	}	

	List!Service  services;
	this(A)(ref A allocator, size_t size)
	{
		services = List!Service(allocator, size);
	}

	void add(T)(T* service) if(is(T == struct))
	{
		services = Service(cHash!T, cast(void*)service);
	}

	T* find(T)() if(is(T == struct))
	{
		foreach(service; services)
		{
			if(cHash!T == service.hash)
				return cast(T*)service.ptr;
		}

		assert(0, "Failed to find service");
	}

	//In a sence this should maby work on Interfaces
	//Instead of on classes? Well you can always 
	//Template on the interface. 
	void add(T)(T service) if(is(T == class) || is(T == interface)) 
	{
		services ~= Service(cHash!T, cast(void*)service);
	}

	T find(T)() if(is(T == class) || is(T == interface))
	{
		foreach(service; services)
		{
			if(cHash!T == service.hash)
				return cast(T*)service.ptr;
		}

		assert(0, "Failed to find service");
	}
}

class World
{
	private List!ISystem systems;
	private List!IEntitySystem entitySystems;
	private ServiceLocator locator;

	this(A)(ref A allocator, 
			size_t maxSystems, 
			size_t maxEntitySystems, 
			size_t maxServices)
	{
		systems		  = List!ISystem(allocator, maxSystems);
		entitySystems = List!IEntitySystem(allocator, maxEntitySystems);
		locator		  = ServiceLocator(allocator, maxServices);
	}

	T* system(T)()
	{
		import util.hash;
		foreach(system; systems)
		{
			if(cHash!T == system.hash())
				return &(cast(System!T)system).wrapped;
		}

		assert(0, "Failed to find system etc");
	}

	T entitySystem(T)()
	{	
		import util.hash;
		foreach(es; entitySystems)
		{
			if(es.hash == cHash!T)
				return (cast(EntitySystem!T)es).wrapped;
		}

		assert(0, "Failed to find es etc.");
	}	

	T* locate(T)() if(is(T == struct))
	{
		return locator.find!T;
	}

	T locate(T)() if(is(T == class) || is(T == interface))
	{
		return locator.find!T;
	}

	void addSystem(T)(System!T system) 
	{
		systems ~= cast(ISystem)system;
	    import std.algorithm;
		sort!("a.order() < b.order()")(systems.buffer[0 .. systems.length]);
	} 

	void initialize() 
	{
		foreach(system; systems)
		{
			system.initialize(this);
		}
	}

	void update()
	{
		foreach(i, system; systems)
		{
			system.update();
		}
	}
}

//How does a slightly more advanced transformation system work?
//Local position -> Parent -> Global Position. 

//Transformation System 
// 20 bytes -> Local
// 20 bytes -> Global
// 4  bytes -> Parent
// 4  bytes -> Handle
// 2  bytes -> Backref
// 20 + 20 + 4 + 4 + 2 = 50 bytes

//4 * 64kb... Could be worse :) Could also be better. 
//A more realistic senario is 4 * 10_000 or even 4 * 200
//10k objects are not very likely.

//Hypothesis you might be able to do the following.
//CompCollection!(Transformation, "locals",  Transformation.init,
//						Transformation, "globals", Transformation.init
//						ushort,			 "parents", ushort.max);
//Default options? Yes no maby so?

//On each frame sort array like so. 
//What we want to do is the following. 
//collection.sort!("parents", (a, b) => a < b)();