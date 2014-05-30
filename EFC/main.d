module main;
import external_libraries, game, content;

version(X86) 
enum libPath = "..\\lib\\win32\\";
version(X86_64) 
enum libPath = "..\\lib\\win64\\";

pragma(lib, libPath ~ "DerelictGLFW3.lib");
pragma(lib, libPath ~ "DerelictGL3.lib");
pragma(lib, libPath ~ "DerelictUtil.lib");
pragma(lib, libPath ~ "DerelictFI.lib");
pragma(lib, libPath ~ "DerelictOGG.lib");
pragma(lib, libPath ~ "DerelictSDL2.lib");
pragma(lib, libPath ~ "dunit.lib");

void main()
{
	import std.stdio;
	init_dlls();
	try
		run();
	catch(Throwable t)
		writeln(t);

	readln;
}

void run()
{
	import allocation;
	auto region = RegionAllocator(Mallocator.cit, 1024 * 1024 * 100);
	auto stack  = ScopeStack(region);

	auto config = fromSDLFile!GameConfig(GC.it, "Game.sdl");
	game.Game = stack.allocate!Game_Impl(stack, config);

	auto fsm = Game.gameStateMachine;
	fsm.addState(new State(stack), "State");
	Game.transitionTo("State");

	import graphics; 
	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	import std.datetime;

	Game.run(Timestep.fixed, 16.msecs);
}

class State : IGameState
{
	import world, tree, circle, system, graphics, math, entity_table, moving, std.random;
	World w;

	CompHandle root;

	int fps = 0;
	float elapsed = 0;

	this(S)(ref S stack)
	{
		w = stack.allocate!(World)(stack, 10,10,10);
		auto t  = stack.allocate!(System!(TreeTransformSystem))(stack, 0xFFFF - 1, 0);
		auto c  = stack.allocate!(System!(CircleRenderSystem)) (stack, 0xFFFF - 1, 2);
		auto m  = stack.allocate!(System!(MoveSystem))			 (stack, 0xFFFF - 1, 1);

		w.addSystem(t);
		w.addSystem(c);
		w.addSystem(m);

		w.initialize();

		root = t.wrapped.create(Transform(float2(Game.window.size / 2), float2(0.4f, 0.4f), 0));
		auto circle		= c.wrapped.create(root, Color.white);

		foreach(j; 0 .. 512)
		{
			float mag = 150 +  j;
			foreach(i; 0 .. 127)
			{
				auto pos = Polar!float((i / 50f) * TAU, mag).toCartesian;
				auto transform = t.wrapped.create(Transform(pos, float2(uniform(0.1f, 0.3f), uniform(0.1f, 0.3f)), 0), root);
				m.wrapped.create(transform, Polar!float(uniform(0, TAU), uniform(-20,20)).toCartesian, uniform(0.0f, 1.0f));
				c.wrapped.create(transform, Color(0xFF000000 | uniform(0, 0xFFFFFF)));
			}
		}
	}

	void enter() { }
	void exit() { }

	void update()
	{ 
		auto sys = w.system!TreeTransformSystem;
		auto comp = &sys.locals[root];
		comp.rotation += Time.delta;
		
		elapsed += Time.delta;
		if(elapsed > 1.0f)
		{
			import std.stdio;
			writeln("FPS: ", fps);
			fps = 0;
			elapsed = 0.0f;
		} 
		fps++;
	}

	void render() 
	{
		gl.clearColor(1f, 0.5f, 1f, 1f);
		gl.clear(ClearFlags.color);
		w.update();
	}
}