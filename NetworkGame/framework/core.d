module framework.core;
import std.datetime;
import allocation;
import util.servicelocator;
import collections.list;
import std.traits;

enum TimeStep
{
	fixed,
	variable
}

struct GameTime
{
	TickDuration total;
	TickDuration delta;
}

class IGameComponent
{
	Game* game;

	void initialize() { }
	void preStep(GameTime time) { }
	void step(GameTime time) { }
	void postStep(GameTime time) { }
}

struct Game
{
	ServiceLocator services;
	List!IGameComponent components;
	private bool shouldRun;
	public const(char)[] name;

	T* locate(T)(string name = "") if(is(T == struct))
	{

		return services.find!(T)(name);
	}
	
	T locate(T)(string name = "") if(is(T == class))
	{
		T item;
		if(services.tryFind!(T)(item, name))
			return item;

		foreach(component; components)
		{
			if(typeid(component) == typeid(T))
				return cast(T)component;
		}
		assert(0, "Failed to find : " ~ T.stringof);
	}


	void addService(T)(T* service) if(is(T == struct))
	{
		services.add(service);
	}

	void addComponent(T)(T component) if(is(T : IGameComponent))
	{
		component.game = &this;
		component.initialize();
		components ~= cast(IGameComponent)component;
	}

	this(A)(ref A al, size_t numServices, size_t numComponents, const(char)[] name)
	{		
		services   = ServiceLocator(al, numServices);
		components = List!IGameComponent(al, numComponents);

		this.name = name;
		this.shouldRun = true;
	}

	void stop()
	{
		this.shouldRun = false;
	}
	
	void run(TimeStep timestep = TimeStep.fixed, Duration frameDur = 16_667.usecs)
	{
		import std.datetime;
		StopWatch watch; watch.start();
		auto last  = watch.peek;
		auto total = last;

		while(shouldRun)
		{
			auto curr  = watch.peek;
			auto delta = curr - last;
			total += delta;
			last = curr;

			foreach(component; components)
				component.preStep(GameTime(total, delta));
			foreach(component; components)
				component.step(GameTime(total, delta));
			foreach(component; components)
				component.postStep(GameTime(total, delta));
				
			if(timestep == TimeStep.fixed)
			{
				waitUntilNextFrame(watch, cast(Duration)(watch.peek - last), frameDur);
			}
		}
	}

	private void waitUntilNextFrame(ref StopWatch watch, 
									Duration frametime, 
									Duration target)
	{
		import std.algorithm : max;

		auto sleeptime = max(0.msecs, target - frametime);
		auto now_ = watch.peek;
		while(sleeptime > 1.msecs)
		{
			import core.thread;
			Thread.sleep(1.msecs);
			auto tmp_ = watch.peek;
			sleeptime -= tmp_ - now_;
			now_ = tmp_;
		}

		now_ = watch.peek;
		while(sleeptime > 100.hnsecs)
		{
			auto tmp_ = watch.peek;
			sleeptime -= tmp_ - now_;
			now_ = tmp_;
		}
	}
}