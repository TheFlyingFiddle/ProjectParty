module game;

public import game.time;
public import game.state;

import core.time, std.datetime,
	core.thread, std.algorithm,
	content;

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
		import util.profile;

		StopWatch watch;
		watch.start();
		auto last = watch.peek();
		while(shouldRun())
		{
			auto curr = watch.peek();
			Time._delta = cast(Duration)(curr - last);
			Time._total += Time._delta;
			last = curr;
			
			{
				auto p = StackProfile("Update");
				gameStateMachine.update();
			}
			
			{
				auto p = StackProfile("Render");
				gameStateMachine.render();
			}

			swap();

			ContentReloader.processReloadRequests();

			if(timestep == Timestep.fixed) {
				auto frametime = watch.peek() - last;
				Duration sleeptime = max(0.msecs, target - frametime);
				//Thread.sleep(sleeptime);
			}
		}
	}
}