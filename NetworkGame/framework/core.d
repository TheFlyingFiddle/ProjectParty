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

struct Time
{
	TickDuration total;
	TickDuration delta;

	float deltaSec()
	{
		return delta.msecs / 1000.0f;
	}
}

struct Timer
{
	int		    id;
	float  elapsed;
	float  interval;

	void delegate() onTick;
}

struct TimeKeeper
{
	private List!Timer timers;
	private int count;

	void step(Time time)
	{
		foreach_reverse(i; 0 .. timers.length)
		{
			auto timer = &timers[i];
			timer.elapsed -= time.deltaSec;
			if(timer.elapsed <= 0)
			{
				timer.elapsed += timer.interval;
				timer.onTick();
			}
		}		
	}

	int startTimer(float interval, void delegate() tick)
	{
		timers ~= Timer(count, interval, interval, tick);
		return count++;
	}

	void stopTimer(int id)
	{
		import std.algorithm;
		auto idx = timers.countUntil!(x => x.id == id);
		if(idx != -1)
			timers.removeAt(idx);
	}
}


class IApplicationComponent
{
	Application* app;

	void initialize() { }
	void preStep(Time time) { }
	void step(Time time) { }
	void postStep(Time time) { }
}

struct Application
{
	//Max 3 msecs of GC per frame (Should pref be lower!)
	enum max_gc_time_msecs = 3;

	ServiceLocator services;
	List!IApplicationComponent components;
	private bool shouldRun;
	public string name;


	this(A)(ref A al, size_t numServices, size_t numComponents, string name)
	{		
		services   = ServiceLocator(al, numServices);
		components = List!IApplicationComponent(al, numComponents);

		this.name = name;
		this.shouldRun = true;
	}


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

	void addComponent(T)(T component) if(is(T : IApplicationComponent))
	{
		component.app = &this;
		component.initialize();
		components ~= cast(IApplicationComponent)component;
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
				component.preStep(Time(total, delta));
			foreach(component; components)
				component.step(Time(total, delta));
			foreach(component; components)
				component.postStep(Time(total, delta));
	

			//runGC(); 

			if(timestep == TimeStep.fixed)
			{
				waitUntilNextFrame(watch, cast(Duration)(watch.peek - last), frameDur);
			}
		}
	}

	private void runGC()
	{
		import core.memory, log;
		auto collectBegin = Clock.currSystemTick;
		GC.collect();
		auto collectEnd   = Clock.currSystemTick;

		auto collectDelta = collectEnd - collectBegin;
		logCondErr(collectDelta.msecs > max_gc_time_msecs, "GC overshot max limit in a collection!!!");
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