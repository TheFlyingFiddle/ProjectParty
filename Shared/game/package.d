module game;

public import game.time;
public import game.state;
public import game.window;
public import game.input;


import util.profile;
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
	static GameStateFSM gameStateMachine;
	static Window		window;

	static void init(A)(ref A allocator, size_t numStates, WindowConfig config)
	{
		gameStateMachine = GameStateFSM(allocator, numStates);
		window = WindowManager.create(config);
	}

	static void run(Timestep timestep, Duration target = 0.msecs)
	{

		StopWatch watch;
		watch.start();
		auto last = watch.peek();
		while(!window.shouldClose)
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
			
			window.swapBuffer();
			window.update();

			ContentReloader.processReloadRequests();
			if(timestep == Timestep.fixed) {
				auto frametime = watch.peek() - last;
				Duration sleeptime = max(0.msecs, target - frametime);
				Thread.sleep(sleeptime);
			}
		}
	}
}