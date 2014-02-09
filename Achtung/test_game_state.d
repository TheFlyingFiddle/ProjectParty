module test_game_state;


import game, math, graphics, content,
	   allocation, std.random;

final class TestGameState : IGameState
{
	FontID font;
	Frame frame;
	Renderer* renderer;


	void enter() 
	{
		auto texture = TextureManager.load("textures\\pixel.png");
		frame = Frame(texture);

		font = FontManager.load("fonts\\Arial32.fnt");

		import game.debuging;
		init_debugging("textures\\pixel.png");

		//Max num batches. (This is actually good since every batch is slow)
		renderer = GC.it.allocate!Renderer(GC.it, 100_000, 100_000);
	}

	void exit()  { }

	void update() 
	{ }
	
	void render() 
	{
		uint2 s = Game.window.size;
		gl.viewport(0,0, s.x, s.y);
		gl.clear(ClearFlags.color);
		mat4 proj = mat4.CreateOrthographic(0,s.x,s.y,0,1,-1);

		renderer.start();


		float x = 300;
		float y = 300;
		float r = uniform(0, TAU);

		import game.debuging;

		//float2 size = font.messure("This \nis a long sentence!");
		//foreach(i; 0 .. 6)
		//{
		//    renderer.addText(font, "This \nis a long sentence!", float2(x,y),
		//                     Color.blue, float2(2,1), float2(0, size.y), i);	
		//    renderer.addRect(float4(x, y, size.x * 2, size.y), Color.red * 0.6, float2.zero, i);
		//
		//}


		renderer.addLine(float2(50,50), float2(123, 187), Color(0xFFcccc00), 10);

		renderer.addCircleOutline(float2(200, 150), 60, Color(0xFF00FF00), 3, 50);
		renderer.addCircleOutline(float2(400, 150), 60, Color(0xFF00FF00), 3, 7);

		foreach(i; 0 .. 6)
			renderer.addRectOutline(float4(300, 300, 100, 100), Color.red, 2.3, float2(50,50), TAU * i / 6.0f);


		renderer.addText(font, "This \nis a long se\nntence!", float2(0,Game.window.size.y));	

		//enum hej = "Hej!";
		//
		//char[1024] items;
		//foreach(i, ref item; items)
		//    if(i % (1024 / 8) == 0) item = '\n';
		//    else item = uniform('a' , 'z');
		//
		//foreach(i; 0 .. 100_000 / 1024)
		//{
		//    float x = uniform(0, Game.window.size.x - 50.0f);
		//    float y = uniform(0, Game.window.size.y - 50.0f);
		//    float sc = uniform(0.1, 0.2);
		//    renderer.addText(font, items, float2(x,y));
		//}

		//float x = uniform(50f, Game.window.size.x - 50.0f);
		//float y = uniform(50f, Game.window.size.y - 50.0f);
		//float sc = uniform(1, 2);
		//Color color = Color(uniform(0, 0xFFFFFF) | 0xFF000000);
		//float r = uniform(0.0f, TAU);
		//
		//foreach(i; 0 .. 100_000)
		//{
		//    renderer.addFrame(frame, float2(x, y), color, float2(sc,sc), float2.zero, r);
		//}


		renderer.end(proj);

	}
}