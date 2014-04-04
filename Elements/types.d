module types;
import math;
import graphics;
import collections;
import content;
import allocation;
import vent;
import ballistic;
import gatling;

struct MapMessage
{
	enum ubyte id = OutgoingMessages.map;
	enum maxSize = 8192;
	uint width;
	uint height;
	ubyte[] tiles;
}

struct SelectedMessage 
{
	enum ubyte id = OutgoingMessages.selected;
	uint x, y, color;
}

struct DeselectedMessage 
{
	enum ubyte id = OutgoingMessages.deselected;
	uint x, y;
}

struct TowerBuiltMessage
{
	enum ubyte id = OutgoingMessages.towerBuilt;
	uint x, y;
	ubyte towerType;
	ubyte typeIndex;
	ubyte ownedByMe;
}

struct TowerEnteredMessage
{
	enum ubyte id = OutgoingMessages.towerEntered;
	uint x, y;
}

struct TowerExitedMessage
{
	enum ubyte id = OutgoingMessages.towerExited;
	uint x, y;
}

struct TowerSoldMessage
{
	enum ubyte id = OutgoingMessages.towerSold;
	uint x, y;
}

struct TowerInfoMessage
{
	enum ubyte id = OutgoingMessages.towerInfo;
	enum maxSize = 512;
	uint cost;
	float range;
	string phoneIcon;
	uint color;
	ubyte type;
	ubyte index;
	ubyte upgradeIndex;
}

struct TransactionMessage
{
	enum ubyte id = OutgoingMessages.transaction;
	int amount;
}

struct TowerRepairedMessage
{
	enum ubyte id = OutgoingMessages.towerRepaired;
	uint x, y;
}	

struct TowerBrokenMessage
{
	enum ubyte id = OutgoingMessages.towerBroken;
	uint x, y;
}

enum IncomingMessages : ubyte
{
	towerRequest = 50,
	selectRequest = 51,
	deselect = 52,
	mapRequest = 53,
	towerEntered = 54,
	towerExited = 55,
	ventValue = 56,
	ventDirection = 57,
	towerSell = 58,
	ballisticValue = 59,
	ballisticDirection = 60,
	ballisticLaunch = 61,
	upgradeTower = 62,
	towerRepaired = 63
}

enum OutgoingMessages : ubyte
{
	map = 50,
	towerBuilt = 51,
	selected = 52,
	deselected = 53,
	towerEntered = 54,
	towerExited = 55, 
	towerInfo = 56,
	transaction = 57,
	towerSold = 58,
	towerBroken = 59,
	towerRepaired = 60
}

enum TileType : ubyte
{
	buildable = 0,
	nonbuildable = 1,
	vent = 2, 
	rocket = 3,
	gatling = 4
}

struct MapConfig
{
	string map;
	SpawnerConfig[][] waves;
	EnemyConfig[] enemies;
	uint2[] path;
	uint2 tileSize;
}

struct PathConfig
{
	uint2[] wayPoints;
	uint2 tileSize;
}

struct Level
{
	@Convert!mapConverter() Grid!TileType tileMap;
	List!Wave waves;
	@Convert!pathConverter() List!Path paths;
	uint2 tileSize;
	uint startBalance;
	List!EnemyPrototype enemyPrototypes;
	List!VentTower		ventPrototypes;
	List!HomingProjectilePrefab		homingPrototypes;
	List!BallisticProjectilePrefab	ballisticProjectilePrototypes;
	List!BallisticTower				ballisticTowerPrototypes;

	List!AutoProjectilePrefab		autoProjectilePrototypes;
	List!GatlingProjectilePrefab	gatlingProjectilePrototypes;
	List!GatlingTower				gatlingTowerPrototypes;

	List!Tower			towers;
}

struct Tower
{
	uint cost;
	string phoneIcon;
	uint color;
	TileType type;
	ubyte typeIndex;
	float range;
	ubyte upgradeIndex;
}

struct EnemyPrototype
{
	int worth;
	float maxHealth;
	float speed;
	@Convert!stringToFrame() Frame frame;
}

auto stringToFrame(string ID)
{
	import game, graphics;
	return Frame(Game.content.loadTexture(ID));
}

auto pathConverter(List!PathConfig pc)
{
	auto paths = List!Path(GC.it, pc.length);
	foreach(i;0 .. pc.length)
	{
		paths ~= Path(GC.it, pc[i].tileSize, pc[i].wayPoints);
	}
	return paths;
}

Grid!TileType mapConverter(string path)
{
	import derelict.freeimage.freeimage, util.strings;
	char* c_path = path.toCString();
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

struct SpawnerConfig
{
	float startTime;
	int prototypeIndex;
	float spawnInterval;
	int numEnemies;
}

struct EnemyConfig
{
	int health;
	float speed;
	int worth;
	string textureResource;
}


struct Path
{
	float2[] wayPoints;
	float[] distances;
	float endDistance;

	this(A)(ref A allocator, uint2 tileSize, uint2[] wayPoints)
	{
		this.wayPoints = allocator.allocate!(float2[])(wayPoints.length);
		this.distances = allocator.allocate!(float[])(wayPoints.length);
		float dist = 0;
		float2 oldWp = float2(wayPoints[0] * tileSize + tileSize/2);
		foreach(i, wayPoint; wayPoints)
		{
			import std.stdio;
			writeln(wayPoint);
			float2 wp = float2(wayPoint * tileSize + tileSize/2);
			this.wayPoints[i] = wp;
			float d = distance(wp, oldWp);
			dist+= d;
			distances[i] = dist;
			writeln(oldWp, wp);
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

struct Enemy
{
	static List!Path paths;
	float distance;
	float speed;
	float health;
	float maxHealth;
	uint pathIndex;
	int worth;
	Frame frame;
	this(EnemyPrototype prefab, uint pathIndex)
	{
		this.distance = 0;
		this.speed = prefab.speed;
		this.health = prefab.maxHealth;
		this.maxHealth = prefab.maxHealth;
		this.worth = prefab.worth;
		this.frame = prefab.frame;
		this.pathIndex = pathIndex;
	}

	@property float2 position()
	{
		return paths[pathIndex].position(distance);
	}
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
}


struct ProjectileTower
{
	float attackSpeed;
	@Optional(0f) float deltaAttackTime;
	int projectileIndex;
}

struct ConeTower
{
	float width;
	float dps;
	float reactivationTime;
	float activeTime;
	@Optional(0f) float elapsed;
}
