module framework.entity;

import framework;
import std.algorithm;
import collections.list;
import util.hash;

struct World
{
	Application* app;
	List!System systems;
	EntityCollection entities;

	private List!int	toRemove;

	this(A)(ref A all, size_t maxSystems, size_t maxEntities, Application* app)
	{
		this.app = app;
		this.systems = List!System(all, maxSystems);
		this.entities = EntityCollection(all, maxEntities, 20);
		this.toRemove = List!int(all, maxEntities);
	}

	void addSystem(T, A)(ref A all, size_t numEntities, size_t order) if(is(T : System))
	{
		import allocation;

		T sys = all.allocate!(T)();
		sys.setup(all, &this, numEntities, order);
		this.systems ~= cast(System)sys;
	}

	void initialize()
	{
		foreach(s; systems)
		{
			s.initialize();
		}

		import std.algorithm;
		systems.sort!((a,b) => a.order < b.order);
	}

	void step(Time time)
	{
		foreach(s; systems)
		{
			s.preStep(time);
		}

		foreach(s; systems)
		{
			s.step(time);
		}

		foreach(s; systems)
		{
			s.postStep(time);
		}

		removeEntites();
	}


	void entityChanged(ref Entity entity)
	{
		foreach(s; systems)
		{
			s.entityChanged(entity);
		}
	}

	void addEntity(Entity entity)
	{
		foreach(s; systems)
		{
			s.entityAdded(entity);
		}
	}

	void removeEntity(int id)
	{
		toRemove ~= id;
	}

	private void removeEntites()
	{
		import std.algorithm;
		sort!("a > b")(toRemove);
		foreach(id; toRemove)
		{
			foreach(s; systems)
			{
				s.entityRemoved(id);
			}

			entities.destroy(id);
		}

		toRemove.clear();
	}
}

class System 
{
	List!Entity entities;
	World* world;
	size_t order;

	void setup(A)(ref A all, World* world, size_t numEntities, size_t order)
	{
		this.entities = List!Entity(all, numEntities);
		this.world	  = world;
		this.order    = order;
	}

	void entityAdded(ref Entity entity)
	{
		if(shouldAddEntity(entity))
		{
			entities ~= entity;
		}
	}

	void entityChanged(ref Entity entity)
	{
		import std.algorithm;

		int index = entities.countUntil!(x => x.id == entity.id);
		if(index == -1 && shouldAddEntity(entity))
			entities ~= entity;
		else if(index != -1 && !shouldAddEntity(entity))
			entities.removeAt(index);
	}

	void entityRemoved(int entity)
	{
		import std.algorithm;
		int index = entities.countUntil!(x => x.id == entity);
		if(index != -1) 
			entities.removeAt(index);
	}

	void preStep(Time time) { }
	void postStep(Time time) { }
	void step(Time time)	 { }

	void initialize() { }
	abstract bool shouldAddEntity(ref Entity entity);
}



struct Component
{
	TypeHash type;
	ubyte[64] data;
}

enum invalidID = 0;

struct Entity
{
	int id;
	int groups;
	private List!Component components; 

	this(A)(ref A all, int groups, size_t maxComponents)
	{
		components	= List!Component(all, maxComponents);
		this.id		= invalidID;
		this.groups	= groups;
	}

	void addComp(T)(T t) if(is(T == struct))
	{
		Component comp;
		comp.type = cHash!T;
		import std.c.string;
		memcpy(comp.data.ptr, cast(void*)&t, T.sizeof);

		components ~= comp;
	}
	T* getComp(T)()
	{
		foreach(ref c; components)
		{
			if(c.type == cHash!T)
				return (cast(T*)c.data.ptr);
		}

		assert(0, "No Component found!");
	}

	bool hasComp(T)()
	{
		foreach(ref c; components)
		{
			if(c.type == cHash!T)
				return true;
		}

		return false;
	}
}

struct EntityCollection
{
	Entity[] entities;
	int entityCount;
	int id;

	this(A)(ref A all, size_t size, size_t maxComponents)
	{	
		import allocation;

		entities    = all.allocate!(Entity[])(size);
		entityCount = 0;
		id			= 1;

		foreach(ref e; entities)
		{
			e = Entity(all, 0, maxComponents);
		}
	}

	Entity* create()
	{
		entities[entityCount].groups = 0;
		entities[entityCount].id	 = id++;
		entities[entityCount].components.clear();

		return &entities[entityCount++];
	}

	ref Entity opIndex(int id)
	{
		return entities[entities.countUntil!(x => x.id == id)];
	}


	void destroy(int id)
	{
		import std.algorithm;
		int index = entities.countUntil!(x => x.id == id);
		if(index != -1)
		{
			entities[index] = entities[entityCount - 1];
			entityCount--;
		}
	}

}

unittest
{
	import allocation;
	Entity e = Entity(Mallocator.it, 0, 10);

	struct S
	{
		int x;
	}

	e.addComp!S(S(3));
	auto s = e.getComp!S;
	assert(s.x == 3);
	s.x = 25;
	s = e.getComp!S;
	assert(s.x == 25);
}