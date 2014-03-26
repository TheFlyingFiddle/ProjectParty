module gameplay;
import game, math, collections, content, graphics;
import derelict.freeimage.freeimage, util.strings;

enum TileType
{
	buildable = 0,
	nonbuildable = 1
}

enum ElementType
{
	nature = 0,
	fire = 1,
	water = 2,
	ice = 3,
	wind = 4,
	lightning = 5
}

struct MapConfig
{
	string map;
	TileConfig[] tiles;
	WaveConfig[] waves;
	uint2[] path;
	uint2 tileSize;
}

struct TileConfig
{
	uint color;
	TileType type;
	string texture;
}

struct WaveConfig
{
	uint count; 
	float rate;
	ElementType type;
	float speed;
	uint gold;
	uint hp;
}

struct Tile
{
	TextureID texture;
	TileType type;
}

struct Enemy
{
	float2 pos;
	uint index;
}

class GamePlayState : IGameState
{
	Grid!Tile tileMap;
	uint2[] path;
	uint2 tileSize;
	Enemy enemy;

	this(A)(ref A allocator, string configFile)
	{
		import std.algorithm;
		auto map = fromSDLFile!MapConfig(allocator, configFile);
		path = map.path;

		char* c_path = map.map.toCString();
		FREE_IMAGE_FORMAT format = FreeImage_GetFileType(c_path);
		if(format == FIF_UNKNOWN)
		{
			format = FreeImage_GetFIFFromFilename(c_path);
		}

		FIBITMAP* bitmap = FreeImage_Load(format, c_path, 0);
		scope(exit) FreeImage_Unload(bitmap);

		uint width  = FreeImage_GetWidth(bitmap);
		uint height = FreeImage_GetHeight(bitmap);
		uint bpp    = FreeImage_GetBPP(bitmap);
		uint[] mapBits = (cast(uint*)FreeImage_GetBits(bitmap))[0 .. width * height];

		tileMap = Grid!Tile(allocator, width, height);
		foreach(row; 0 .. height) {
			foreach(col; 0 .. width) {
				uint color = mapBits[row * width + col];
				auto tile  = map.tiles.find!(x => x.color == color);
				if(!tile.length == 0)
					tileMap[uint2(col, row)] = Tile(Game.content.loadTexture(tile[0].texture), tile[0].type);
			}
		}

		tileSize = map.tileSize;
	}

	void enter()
	{
		float2 tt = float2(path[0].x * tileSize.x + tileSize.x / 2, 
							    path[0].y * tileSize.y + tileSize.y / 2);
		enemy = Enemy(tt, 1);
	}

	void exit()
	{

	}

	void update()
	{
		float2 tt = float2(path[enemy.index].x * tileSize.x + tileSize.x / 2, 
								 path[enemy.index].y * tileSize.y + tileSize.y / 2);

		float2 dir = (tt - enemy.pos).normalized();
		
		enemy.pos += dir * Time.delta * 10;
		
		if(distanceSquared(enemy.pos, tt) < 2) 
		{
			enemy.index += 1;
		}
	}

	void render()
	{
		foreach(cell, item; tileMap) 
		{
			import std.stdio;
			writeln(item);
			auto frame = Frame(item.texture);
			Game.renderer.addFrame( frame, float4(cell.x * tileSize.x, cell.y * tileSize.y, tileSize.x, tileSize.y)); 
		}

		auto tex = Game.content.loadTexture("baws");
		auto frame = Frame(tex);

		Game.renderer.addFrame(frame, float4(enemy.pos.x - tileSize.x / 4, 
														 enemy.pos.y - tileSize.y / 4,
														 tileSize.x / 2, tileSize.x / 2));
	}
}