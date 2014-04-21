module types;
import math;
import graphics;
import collections;
import content;
import allocation;
import vent;
import ballistic;
import gatling;
import spriter.types;

enum TileType : ubyte
{
	buildable = 0,
	nonbuildable = 1,
	vent = 2, 
	rocket = 3,
	gatling = 4
}

struct PathConfig
{
	float2[] wayPoints;
}

struct Level
{
	@Convert!mapConverter() Grid!TileType tileMap;
	List!Wave waves;
	@Convert!pathConverter() List!Path paths;
	uint2 tileSize;
	uint startBalance;
	@Convert!stringToFrame() Frame image;

}

struct Prefabs
{
	List!EnemyPrefab enemyPrototypes;

	List!VentTower		ventPrototypes;

	List!BallisticProjectilePrefab	ballisticProjectilePrototypes;
	List!BallisticTower					ballisticTowerPrototypes;

	List!AutoProjectilePrefab			autoProjectilePrototypes;
	List!GatlingTower						gatlingTowerPrototypes;

	List!Tower			towers;
}

struct Tower
{
	uint cost;
	string phoneIcon;
	string name;
	string info;
	TileType type;
	float regenRate;
	float range;
	ubyte typeIndex;
	@Convert!stringToSprite() SpriteObjectID spriteID;
	@Optional(0f) float startPressure;
	@Optional(false) bool basic;
	@Optional(ubyte.max) ubyte upgradeIndex0;
	@Optional(ubyte.max) ubyte upgradeIndex1;
	@Optional(ubyte.max) ubyte upgradeIndex2;
}


struct EnemyPrefab
{
	int worth;
	float maxHealth;
	float speed;
	@Convert!stringToSprite() SpriteObjectID spriteID;

	@Optional(List!EnemyComponentPrefab.init) List!EnemyComponentPrefab components;
}

enum ComponentType
{
	speedup,
	heal,
	towerBreaker,
	statusRemover
}

struct EnemyComponentPrefab
{
	ComponentType type;

	@Optional(0.0f) float interval;
	@Optional(0.0f) float duration;
	@Optional(0.0f) float amount;
	@Optional(0.0f) float range;
	@Optional(StatusType.none) StatusType statusType;
}


auto stringToFrame(string ID)
{
	import game, graphics;
	return Frame(Game.content.loadTexture(ID));
}

auto stringToParticle(string ID)
{
	import game, content.common, std.path;
	return fromSDLFile!ParticleEffectConfig(GC.it, buildPath(resourceDir, ID));
}

auto stringToSound(string ID)
{
	import game;
	return Game.content.loadSound(ID);
}

auto stringToSprite(string ID)
{
	import game;
	return Game.content.loadSprite(ID);
}

auto pathConverter(List!PathConfig pc)
{
	auto paths = List!Path(GC.it, pc.length);
	foreach(i;0 .. pc.length)
	{
		import game;
		foreach(ref wayPoint; pc[i].wayPoints)
		{
			wayPoint.x *= Game.window.size.x/1920f;
			wayPoint.y *= Game.window.size.y/1080f;
		}
		paths ~= Path(GC.it, pc[i].wayPoints);
	}
	return paths;
}

Grid!TileType mapConverter(string path)
{
	import derelict.freeimage.freeimage, util.strings;
	char* c_path = path.toCString();
	FREE_IMAGE_FORMAT format = FreeImage_GetFileType(c_path);
	if(format == FIF_UNKNOWN)
		format = FreeImage_GetFIFFromFilename(c_path);

	FIBITMAP* bitmap = FreeImage_Load(format, c_path, 0);
	scope(exit) FreeImage_Unload(bitmap);

	uint width  = FreeImage_GetWidth(bitmap);
	uint height = FreeImage_GetHeight(bitmap);
	uint bpp    = FreeImage_GetBPP(bitmap);
	uint[] mapBits = (cast(uint*)FreeImage_GetBits(bitmap))[0 .. width * height];

	auto tileMap = Grid!TileType(GC.it, width, height);
	foreach(row; 0 .. height) {
		foreach(col; 0 .. width) {
			uint color = mapBits[row * width + col];
			if (color == Color.white.packedValue)
				tileMap[uint2(col, row)] = TileType.nonbuildable;
			else
				tileMap[uint2(col, row)] = TileType.buildable;
		}
	}
	return tileMap;
}

struct Path
{
	float2[] wayPoints;
	float[] distances;
	float endDistance;

	this(A)(ref A allocator, float2[] wayPoints)
	{
		this.wayPoints = allocator.allocate!(float2[])(wayPoints.length);
		this.distances = allocator.allocate!(float[])(wayPoints.length);
		float dist = 0;
		float2 oldWp = wayPoints[0];
		foreach(i, wayPoint; wayPoints)
		{
			float2 wp = wayPoint;
			this.wayPoints[i] = wp;
			float d = distance(wp, oldWp);
			dist+= d;
			distances[i] = dist;
			oldWp = wp;
		}
		endDistance = dist;
	}

	float2 position(float distance)
	{
		foreach(i, d; distances)
		{
			if(distance < d) 
			{
				float factor = (distance - distances[i-1])
							  /(distances[i] - distances[i - 1]);
				return (wayPoints[i] - wayPoints[i-1]) * factor + wayPoints[i-1];
			}
		}
		import std.conv;
		assert(0, text("Invalid distance ", distance, "."));
	}
}

enum StatusType
{
	none,
	watered,
	burning,
	oiled,
	cold
}

enum StatusEffect
{
	water,
	fire, 
	oil,
	liqNit
}

struct StatusConfig
{
	float duration;
	StatusEffect type;
	float value;
}	

struct Status
{
	float duration;
	StatusType type;
	float value;
}

struct Spawner
{
	int prototypeIndex;
	float startTime;
	float spawnInterval;
	int numEnemies;
	uint pathIndex;
	@Optional(0f) float elapsed;
}

struct Wave
{
	List!Spawner spawners;
	float pauseTime;
	@Optional(0.0f) float elapsed;
}