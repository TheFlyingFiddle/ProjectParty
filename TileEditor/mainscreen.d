module mainscreen;

import framework;
import ui;
import skin;
import graphics;

class MainScreen : Screen
{
	Gui gui;
	Map map;
	Menu m;

	int selected = 0;
	AtlasHandle atlas;

	this() { super(false, false); }

	override void initialize() 
	{
		import allocation;
		auto all = Mallocator.it;
		gui = loadGui(all, app, "guiconfig.sdl");


		auto loader = app.locate!AsyncContentLoader;
		atlas = loader.load!TextureAtlas("Atlas");


		int[] tiles = new int[20 * 100];
		foreach(i; 0 .. 20 * 100)
		{
			import std.random;
			tiles[i] = uniform(0, 5);
		}

		map = Map(32, 100, 20, tiles);

		m = Menu(all, 20);

		int file = m.addSubmenu("File");
		m.addItem("Save", &save, file);
		m.addItem("Load", &load, file);
	}

	void save()
	{
		import content.sdl;
		import std.array;
		import std.file;
		
		auto app = appender!(string);
		map.toSDL(app);

		write("Map.sdl", app.data);
	}

	void load()
	{
		import std.file;
		import content.sdl;
		import allocation;

		map = fromSDLFile!Map(Mallocator.it, "Map.sdl");
	}

	override void update(Time time)
	{

	}	

	override void render(Time time)
	{
		import window.window;

		auto w = app.locate!Window;
		gui.renderer.viewport(float2(w.size));


		gl.viewport(0,0, cast(int)w.size.x, cast(int)w.size.y);

		gui.area = Rect(0,0, w.size.x, w.size.y);
		gui.begin();

		import std.range : repeat, take;


		gui.tileview(Rect(w.size.x - 360, 400, 340, w.size.y - 480), selected, float2(32, 32), atlas.asset);
		gui.mapview(Rect(20, 20, w.size.x - 400, w.size.y - 100), map, atlas.asset, selected );


		gui.menu(m);

		gui.end();

	}
}

struct MapView
{
	struct State
	{	
		float2 scroll;
	}
}

struct TileView
{
	struct State
	{
		float2 scroll;
	}
}

void mapview(ref Gui gui, 
			 Rect rect, 
			 Map map, 
			 ref TextureAtlas atlas,
			 int selectedTile)
{
	auto hash  = HashID(rect, "mapview");
	auto state = gui.fetchState(hash, MapView.State(float2.zero)); 
	scope(exit) gui.state(hash, state);
	
	void del(ref Gui g)
	{
		int ts = map.tileSize * 2;
	

		float row = rect.y - state.scroll.y;
		foreach(i; 0 .. map.height)
		{
			float column = rect.x - state.scroll.x;
			foreach(j; 0 .. map.width)
			{
				gui.drawQuad(Rect(column, row, ts , ts),
							 atlas[map.tiles[i * map.width + j]], Color.white);

				column += ts;
			}

			row +=  ts;
		}

		if(gui.isDown(rect))
		{
			float2 screenLoc = gui.mouse.location - rect.xy;
			float2 worldLoc  = screenLoc + state.scroll;

			int tileX = cast(int)worldLoc.x / ts;
			int tileY = cast(int)worldLoc.y / ts;

			int tile  = tileY * map.width + tileX;
			if(tile <= map.tiles.length &&
			   tile >= 0) 
			{
				map.tiles[tile] = selectedTile;
			}
		}
	}
	
	gui.scrollarea(rect, state.scroll, &del, Rect(0,0,map.width * map.tileSize, map.height * map.tileSize));
}
