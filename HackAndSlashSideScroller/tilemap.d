module tilemap;

import namespace;
import entity;
import content;
import graphics;
import rendering;
import rendering.combined;

struct Map
{
	int tileSize;
	int width, height;
	int[] tiles;
	float2[] lines;
}

class MapRenderSystem : System
{
	Map map;
	AtlasHandle atlas;

	override bool shouldAddEntity(ref Entity entity) 
	{
		return false; 
	} 

	override void initialize()
	{
		import content.sdl;
		map = fromSDLFile!(Map)(Mallocator.it, "..\\resources\\hack_and_slash\\Map.sdl");

		auto loader = world.app.locate!(AsyncContentLoader);
		atlas = loader.load!TextureAtlas("Atlas");

		world.app.addService(&map);
	}

	override void step(Time time)
	{
		auto renderer = world.app.locate!(Renderer2D);
		renderer.begin();
		
		float row = 0;
		foreach(i; 0 .. map.height)
		{
			float column = 0;
			foreach(j; 0 .. map.width)
			{
				//if(map.tiles[i * map.width + j] != 5) 
					renderer.drawQuad(float4(column, row, column + map.tileSize, 
										 row + map.tileSize),
							 atlas[map.tiles[i * map.width + j]], Color.white);

				column += map.tileSize;
			}

			row +=  map.tileSize;
		}

		for(int i = 0; i < map.lines.length; i+=2)
		{
			renderer.drawLine(map.lines[i],
							  map.lines[i + 1],
							  1,
							  atlas["pixel"], Color.black);
		}


		renderer.end();
	}
}