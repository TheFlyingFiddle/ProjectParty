module framework.entity;

import framework;
import std.algorithm;
import collections.list;
import util.hash;
import std.traits;

struct World
{
	Application* app;
	List!Initializer initializers;
	List!System systems;
	EntityCollection entities;

	private List!int	toRemove;

	this(A)(ref A all, 
			size_t maxSystems, 
			size_t maxInitializers, 
			size_t maxEntities, 
			Application* app)
	{
		this.app			= app;
		this.systems		= List!System(all, maxSystems);
		this.initializers	= List!Initializer(all, maxInitializers);	 
		this.entities		= EntityCollection(all, maxEntities, 20);
		this.toRemove		= List!int(all, maxEntities);
	}

	void addSystem(T, A)(ref A all, size_t numEntities, size_t order) if(is(T : System))
	{
		import allocation;

		T sys = all.allocate!(T)();
		sys.setup(all, &this, numEntities, order);
		this.systems ~= cast(System)sys;
	}

	void addInitializer(T, A)(ref A all) if(is(T : Initializer))
	{
		import allocation;

		T inits = all.allocate!(T)();
		inits.world = &this;
		initializers ~= cast(Initializer)inits;
	}

	void initialize()
	{
		foreach(s; systems)
		{
			s.preInitialize();
		}

		foreach(i; initializers)
		{
			i.initialize();
		}

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
		import log;
		logInfo("Entity added ", entity.id);

		foreach(inits; initializers)
		{
			inits.doInitializeEntity(entity);
		}

		foreach(s; systems)
		{
			s.entityAdded(entity);
		}
	}

	void removeEntity(EntityID id)
	{
		toRemove ~= id;
	}

	void removeAllEntities()
	{
		foreach(e; entities)
		{
			foreach(s; systems)
			{
				s.entityRemoved(e.id);
			}
		}
		entities.destroyAll(this);
		toRemove.clear();
	}

	Entity* findEntity(EntityID id)
	{
		return entities.findEntity(id);
	}

	private void removeEntites()
	{
		import std.algorithm;		
		foreach(id; toRemove)
		{
			foreach(s; systems)
			{
				s.entityRemoved(id);
			}

			entities.destroy(id, this);
		}

		toRemove.clear();
	}
}

class Initializer 
{
	World* world;

	private final void doInitializeEntity(ref Entity e)
	{
		if(shouldInitializeEntity(e))
			initializeEntity(e);
	}

	void initialize() { }

	abstract bool shouldInitializeEntity(ref Entity e);
	abstract void initializeEntity(ref Entity e);
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

	void preInitialize() { }
	void initialize() { }
	abstract bool shouldAddEntity(ref Entity entity);
}

struct Component
{
	TypeHash type;
	void function(ref Component, ref Entity, ref World) destructor;
	ubyte[32 - 8] data;

	this(T)(auto ref T t)
	{
		type = cHash!T;
		import std.c.string;
		memcpy(data.ptr, cast(void*)&t, T.sizeof);

		import std.traits;
		static if(hasMember!(T, "destructor"))
		{
			destructor = &T.destructor;
		}
		else 
		{
			destructor = null;
		}
	}

	T opCast(T)()
	{
		assert(cHash!T == type);
		return *cast(T*)(data.ptr);
	}
}

enum invalidID = 0;

alias EntityID = int;

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
		components ~= Component(t);
	}

	void addComp(ref Component c)
	{
		components ~= c;
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

	bool removeComp(T)() if(!hasMember!(T, "destructor"))
	{
		int index = -1;
		foreach(i, ref c; components)
		{
			if(c.type == cHash!T) 
			{
				index = i;
				break;
			}
		}


		if(index == -1) return false;
		components.removeAt(index);
		return true;
	}


	bool removeComp(T)(ref World world) 
	{
		int index = -1;
		foreach(i, ref c; components)
		{
			if(c.type == cHash!T) 
			{
				index = i;
				break;
			}
		}

		if(index == -1) return false;

		static if(hasMember!(T, "destructor"))
		{
			components[index].destructor(components[index],
										 this, 
										 world);
		}
	
		components.removeAt(index);
		world.entityChanged(this);
		return removeComp;
	}
}

struct EntityArchetype
{
	string name;
	int groups;
	Component[] components;
}

struct EntityCollection
{
	Entity[] entities;
	EntityID entityCount;
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

	Entity* create(EntityArchetype archetype)
	{
		auto e = create();
		e.groups = archetype.groups;
		foreach(ref c; archetype.components)
			e.addComp(c);
		return e;
	}

	Entity* findEntity(EntityID id)
	{
		auto index = entities[0 .. entityCount].countUntil!(x => x.id == id);
		if(index == -1) return null;
		return &entities[index];
	}

	int opApply(int delegate(ref Entity) dg)
	{
		int result;
		foreach(i; 0 .. entityCount)
		{
			result = dg(entities[i]);
			if(result) break;
		}
		return result;
	}

	int opApply(int delegate(uint, ref Entity) dg)
	{
		int result;
		foreach(i; 0 .. entityCount)
		{
			result = dg(i, entities[i]);
			if(result) break;
		}
		return result;
	}

	void destroyAll(ref World world)
	{
		foreach(i; 0 .. entityCount)
		{

			foreach(ref c; entities[i].components)
			{
				if(c.destructor !is null)
					c.destructor(c, entities[i], world);
			}

			entities[i].id = 0;
			entities[i].groups = 0;
			entities[i].components.clear();
		}

		entityCount = 0;
	}

	void destroy(EntityID id, ref World world)
	{
		import std.algorithm;
		int index = entities[0 .. entityCount].countUntil!(x => x.id == id);
		if(index != -1)
		{
			foreach(ref c; entities[index].components)
			{
				if(c.destructor !is null)
					c.destructor(c, entities[index], world);
			}

			entities[index].id = 0;
			entities[index].groups = 0;
			entities[index].components.clear();

			import std.algorithm;
			swap(entities[index], entities[entityCount - 1]);
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