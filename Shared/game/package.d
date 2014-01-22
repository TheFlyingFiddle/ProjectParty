module game;

import core.time, std.datetime,
	core.thread, std.algorithm,
	game.time;

enum Timestep
{
	variable,
	fixed
}

struct Game
{
	static void function() swap;
	static void function() update;
	static void function() render;
	static bool function() shouldRun;

	static void run(Timestep timestep, Duration target = 0.msecs)
	{
		assert(swap && update && render && shouldRun, "Need to specify functions the game should run");


		StopWatch watch;
		watch.start();
		auto last = watch.peek();
		while(shouldRun())
		{
			auto curr = watch.peek();
			Time._delta = cast(Duration)(curr - last);
			Time._total += Time._delta;
			last = curr;

			update();
			render();
			swap();

			if(timestep == Timestep.fixed) {
				auto frametime = watch.peek() - last;
				Duration sleeptime = max(0.msecs, target - frametime);
				Thread.sleep(sleeptime);
			}
		}
	}
}