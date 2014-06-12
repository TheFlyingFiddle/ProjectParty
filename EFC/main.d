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

void main()
{
	import std.stdio;
	init_dlls();
	
	import core.thread;

	Thread self = Thread.getThis;
	self.priority = Thread.PRIORITY_MAX;

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
	import entity, systems, graphics, math, std.random;
	World w;

	CompHandle root;

	int fps = 0;
	float elapsed = 0;

	this(S)(ref S stack)
	{
		w = stack.allocate!(World)(stack, 10,10,10);
		auto t  = stack.allocate!(System!(TreeTransformSystem))(stack, 0xFFFF, 0);
		auto c  = stack.allocate!(System!(CircleRenderSystem)) (stack, 0xFFFF, 2);
		auto m  = stack.allocate!(System!(MoveSystem))		   (stack, 0xFFFF, 1);

		w.addSystem(t);
		w.addSystem(c);
		w.addSystem(m);

		w.initialize();

		root = t.wrapped.create(Transform(float2(Game.window.size / 2), float2(0.4f, 0.4f), 0));
		auto circle		= c.wrapped.create(root, Color.white);

		foreach(j; 0 .. 512)
		{
			float mag = 150 +  j;
			foreach(i; 0 .. 63)
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

class RenderState : IGameState
{
	import curve_renderer, graphics, math;

	Renderer renderer;

	float2[] points;
	float2[] control;
	float2[] innerPoints;
	float2[] innerControls;
	float2[] innerControls2;


	struct CircleStuff
	{
		int numEdges;
		float scale;
		float scale2;
	}

	struct RenderInfo
	{
		float2 a, b, c;
		float2 ta, tb, tc;
	}

	struct Circle
	{
		RenderInfo[] info;
	}

	CircleStuff[] stuff;

	Circle circle;
	


	this(S)(ref S stack)
	{
		renderer = Renderer(stack, 100);

	
	}

	void enter() { }
	void exit() { }

	float outer = 25;
	float inner = 10;

	void update()
	{ 
		stuff = [
			CircleStuff(12, 1.04, 1.07),
			CircleStuff(13, 1.022, 1.03),
			CircleStuff(14, 1.01, 1.02),
			CircleStuff(20, 1, 1)];


		outer = (outer + 1 * Time.delta) % 300;
		inner = (inner + 1 * Time.delta) % 250;
		float max = (outer - inner) / inner + 1;

		int x;
		float scale, scale2;

		foreach(st; stuff)
		{
			if(st.scale < max)
			{
				import std.stdio;
				writeln("Using ", st.numEdges, " edges.");
				x = st.numEdges;
				scale = st.scale;
				scale2 = st.scale2;
				break;
			}
		}

		float outerOffset = outer * scale;
		float innerOffset = inner * scale2;

		points.length = 0;
		control.length = 0;
		innerPoints.length = 0;
		innerControls.length = 0;
		circle.info.length	 = 0;

		float y = x;
		foreach(i; 0 .. x)
		{
			auto polar = Polar!(float)((i / y) * TAU, outer);
			auto point = polar.toCartesian;

			points ~= point;
			control ~= Polar!(float)(((i + 0.5f) / y) * TAU, outerOffset).toCartesian;

			innerPoints ~= Polar!(float)((i/ y) * TAU, inner).toCartesian;
			innerControls ~= Polar!(float)(((i + 0.5f) / y) * TAU, innerOffset).toCartesian;
		}


		foreach(i; 0 .. x)
		{
			float2 a = points[i],
				c = points[(i + 1) % points.length],
				b = control[i];

			float2 tc = float2(0, 0), tb = float2(0.5, 0), ta = float2(1, 1);

			circle.info ~= RenderInfo(c, b, a, tc, tb, ta);
			tb = float2.zero;

			circle.info ~= RenderInfo(a, innerPoints[i], innerControls[i], ta, tb, tc);
			circle.info ~= RenderInfo(innerControls[i], innerPoints[(i + 1) % points.length], c, ta, tb, tc);
			circle.info ~= RenderInfo(a, innerControls[i], c, ta, tb, tc);
			tb = float2(0.5, 0);
			circle.info ~= RenderInfo(innerPoints[i], innerControls[i], innerPoints[(i + 1) % points.length], ta, tb, tc);
		}
	}

	void render() 
	{
		gl.enable(Capability.blend);
		gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

		gl.clearColor(1,1,1,1);
		gl.clear(ClearFlags.color);
		auto window = Game.window;
		mat4 proj = mat4.CreateOrthographic(0,window.fboSize.x, window.fboSize.y, 0, 1,-1);
		

		float2 s = float2(window.size / 2);
		auto frame = Frame(Game.content.loadTexture("circle"));
		Game.renderer.addFrame(frame, float4(s.x - 200, s.y - 200, 400, 400), Color(0.5,0.5,0.5,0.2));

		renderer.matrix = proj;
		foreach(item; circle.info)
		{
			renderer.drawTriangle(item.a + s, item.b + s, item.c + s,
								  item.ta, item.tb, item.tc, 
								  Color.green);
		}

	}
}


class RenderState2 : IGameState
{
	import curve_renderer2, graphics, math, std.math;

	Renderer renderer;

	Line[] lines;
	this(S)(ref S stack)
	{
		renderer = Renderer(stack, 100);
		
		lines ~= Line(float2(344, 277), float2(207, 369),
					  float2(185, 185), float2(540, 110));

		auto center = float2(Game.window.size / 2);
		foreach(i; 0 ..4)
		{
			float2 start = Polar!(float)((i / 4.0f) * TAU, 100).toCartesian();
			float2 end   = Polar!(float)(((i + 1) % 4) / 4.0f * TAU, 100).toCartesian();
	
			float2 c1 = end.rotate(3 * TAU / 4).normalized() * 100 * 4 * (sqrt(2f) - 1)  / 3;
			float2 c2 = end.normalized() * 100 * 4 * (sqrt(2f) - 1)  / 3;

			start += center;
			end   += center;

			lines ~= Line(start, end, start + c2, end + c1);
		}
	}

	void enter() { }
	void exit() { }

	void update()
	{ 
	}

	void render() 
	{
		gl.enable(Capability.blend);
		gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

		gl.clearColor(1,0,1,1);
		gl.clear(ClearFlags.color);
		auto window = Game.window;
		mat4 proj = mat4.CreateOrthographic(0,window.fboSize.x, window.fboSize.y, 0, 1,-1);
		renderer.matrix = proj;

		renderer.drawPath(lines, Color.red);

	}
}



class RenderState3 : IGameState
{
	import distance_renderer, graphics, math, std.math;

	Renderer renderer;
	TextureID texture;
	this(S)(ref S stack)
	{
		renderer = Renderer(stack, 100);
		texture  = Game.content.loadTexture("circle");
		gl.generateMipmap(TextureTarget.texture2D);
	}

	void enter() { }
	void exit() { }

	void update()
	{ 
	}

	void render() 
	{
		gl.enable(Capability.blend);
		gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

		gl.clearColor(0.3,0.3,0.3,1);
		gl.clear(ClearFlags.color);
		auto window = Game.window;
		mat4 proj = mat4.CreateOrthographic(0,window.fboSize.x, window.fboSize.y, 0, 1,-1);
		renderer.transform = proj;

		renderer.effect = 0;
		renderer.drawRect(texture, float4(50, 200, 50 + 67 * 0.25, 200 + 82 * 0.25), Color.white);
		renderer.drawRect(texture, float4(50, 100, 50 + 67 * 0.5, 100 + 82 * 0.5), Color.white);
		renderer.drawRect(texture, float4(100, 100, 100 + 67 * 1, 100 + 82 * 1), Color.white);
		renderer.drawRect(texture, float4(150, 100, 150 + 67 * 2, 100 + 82 * 2), Color.white);
		renderer.drawRect(texture, float4(250, 100, 250 + 67 * 3, 100 + 82 * 3), Color.white);
		renderer.drawRect(texture, float4(350, 100, 350 + 67 * 4, 100 + 82 * 4), Color.white);
		renderer.drawRect(texture, float4(500, 100, 500 + 67 * 8, 100 + 82 * 8), Color.white);

		//renderer.effect = 1;
		//renderer.drawRect(texture, float4(50, 300, 50 + 67 * 0.25, 300 + 82 * 0.25), Color.white);
		//renderer.drawRect(texture, float4(50, 300, 50 + 67 * 0.5, 300 + 82 * 0.5), Color.white);
		//renderer.drawRect(texture, float4(100, 300, 100 + 67 * 1, 300 + 82 * 1), Color.white);
		//renderer.drawRect(texture, float4(150, 300, 150 + 67 * 2, 300 + 82 * 2), Color.white);
		//renderer.drawRect(texture, float4(250, 300, 250 + 67 * 3, 300 + 82 * 3), Color.white);
		//renderer.drawRect(texture, float4(350, 300, 350 + 67 * 4, 300 + 82 * 4), Color.white);
		//renderer.drawRect(texture, float4(500, 300, 500 + 67 * 8, 300 + 82 * 8), Color.white);
	}
}


class RenderState4 : IGameState
{
	import renderer, shapes,  graphics, math, std.math;

	Renderer rend;
	Texture2D texture;
	int fps = 0;
	float elapsed = 0;

	this(S)(ref S stack)
	{
		rend = Renderer(stack, 1024 * 128 * 7, 3);
		texture = Game.content.loadTexture("circle").texture;
	}

	void enter() { }
	void exit() { }

	void update()
	{ 

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
		gl.enable(Capability.blend);
		gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

		gl.clearColor(0.3,0.3,0.3,1);
		gl.clear(ClearFlags.color);
		auto window = Game.window;
		rend.viewport = float2(window.size);

		rend.begin();
		
		foreach(i; 0 .. 1)
		{
			float2 origin = float2(150, 150); //uniform(50, window.size.x - 50.0f), 
								   //uniform(50, window.size.y - 50.0f));

			rend.drawBezier!25(float2(200, 500), float2(400, 600), float2(240, 200), float2(190, 580), 10, texture, Color.green);
			rend.drawBezier!25(float2(800, 300), float2(800, 400), float2(1000, 200), float2(800, 600), 10, texture, Color.green);
			rend.drawTriangle(float2(150, 150), float2(200, 150), float2(175, 200), texture, Color.white);
			rend.drawNGonOutline!(6)(origin, 48, 50, texture, Color.white);

			rend.drawLine(float2(400,400), float2(500, 400), 5, texture, Color.white);
			rend.drawCircleSection!10(float2(600, 200), 50, 0, TAU / 2, texture, Color(0xFFacea88));
			rend.drawNGon!25(float2(600, 300), 50, texture, Color.white);


			rend.drawPath([float2(100, 100), float2(150, 100), float2(100, 300), float2 (200, 100), 
						  float2(300, 200), float2(241, 0), float2(350, 50)],
							  10, texture, Color(0xFF0033aa));

		//	rend.drawBezier!6(float2(100, 500), float2(300, 600), float2(140, 200), float2(90, 580), 10, texture, Color.green);
		}

		rend.end();
	}
}