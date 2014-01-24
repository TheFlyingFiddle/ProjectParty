module game;

public import game.time;
public import game.state;

import core.time, std.datetime,
	core.thread, std.algorithm;

enum Timestep
{
	variable,
	fixed
}

alias GameStateFSM = FSM!(IGameState, string);

struct Game
{
	static void function() swap;
	static bool function() shouldRun;
	static GameStateFSM gameStateMachine;
		
	static void run(Timestep timestep, Duration target = 0.msecs)
	{
		assert(swap && shouldRun, "Need to specify functions the game should run");

		StopWatch watch;
		watch.start();
		auto last = watch.peek();
		while(shouldRun())
		{
			auto curr = watch.peek();
			Time._delta = cast(Duration)(curr - last);
			Time._total += Time._delta;
			last = curr;
			
			gameStateMachine.update();
			gameStateMachine.render();
			swap();

			if(timestep == Timestep.fixed) {
				auto frametime = watch.peek() - last;
				Duration sleeptime = max(0.msecs, target - frametime);
				Thread.sleep(sleeptime);
			}
		}
	}
}