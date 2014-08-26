module entity.basic.timer;

import collections.heap;
import collections.list;
import framework.core;
import core.time;


//This is a basic delay system that makes it possible to delay items up to
//18 hours into the future.
//If i can live without cancel then i can prolly make due with 32 bits.
//Actually without cancel i can use even more bits for fun and profit. 
struct DelaySystem
{
	enum maxtime = 2^^24;
	enum maxgen  = 2^^8;

	static struct Delay
	{
		import std.bitmanip;
		mixin(bitfields!(uint, "generation", 8, uint, "time", 24));
		auto id() { return _generation_time; }

		void delegate() action;
		
		//Hack needed to make things work
		//Not possible to template 
		static uint sytemTime;
		int calcLength(uint a)
		{
			if( a > sytemTime) 
				return a - sytemTime;
			else 
				return a + (maxtime - sytemTime);
		}

		int opCmp(Delay other)
		{
			return calcLength(other.time) - calcLength(this.time);
		}
	}

	PQueue!(Delay) queue;
	uint oldTime;
	uint gencounter;
	uint resolution;

	this(A)(ref A all, size_t count, uint resolution = 16)
	{
		queue   = PQueue!(Delay)(all, count);
		oldTime	= 0;
		gencounter = 0;

		this.resolution = resolution;
	}

	bool inside(uint time, uint old, uint new_)
	{
		if(new_ < old)
			return time > old && time <= new_;
		else
			return time > old || time <= new_;
	}

	void update(Time time)
	{
		//Needed for heap to update properly!
		Delay.sytemTime = oldTime;

		auto newTime = (oldTime + time.delta.to!("msecs", uint) / resolution) % (maxtime);
		while(!queue.empty && inside(queue.front.time, oldTime, newTime))
		{
			auto item = queue.front;
			queue.removeFront();
			item.action();
		};

		oldTime = newTime;
	}

	auto delay(Duration dur, void delegate() action)
	{
		assert(dur.total!("msecs") / resolution <= maxtime);

		uint time = cast(uint)(dur.total!("msecs") / resolution + oldTime) % (maxtime);
		gencounter = (gencounter + 1) % (maxgen);

		Delay d;
		d.generation = gencounter;
		d.time		 = time;
		d.action	 = action;

		//Needed for heap to update properly!
		Delay.sytemTime = oldTime;
		queue.insert(d);

		return d.id;
	}

	auto cancel(uint delayID)
	{ 
		return queue.remove!(PQueue!Delay, x => x.id == delayID)();
	}
}