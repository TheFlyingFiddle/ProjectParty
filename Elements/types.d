module types;
import math;
import graphics;
import collections;
import content;
import allocation;

struct MapMessage
{
	enum ubyte id = ElementsMessages.map;
	enum maxSize = 8192;
	uint width;
	uint height;
	ubyte[] tiles;
}

struct SelectedMessage 
{
	enum ubyte id = ElementsMessages.selectRequest;
	uint x, y, color;
}

struct DeselectedMessage 
{
	enum ubyte id = ElementsMessages.deselect;
	uint x, y;
}

struct TowerBuiltMessage
{
	enum ubyte id = ElementsMessages.towerBuilt;
	uint x, y;
	ubyte towerType;
}

enum ElementsMessages : ubyte
{
	map = 50,
	towerRequest = 51,
	towerBuilt = 52,
	selectRequest = 53,
	deselect = 54,
	mapRequest = 55
}

enum TileType : ubyte
{
	buildable = 0,
	nonbuildable = 1,
	fireTower = 2,
	waterTower = 3,
	iceTower = 4,
	lightningTower = 5,
	windTower = 6,
	natureTower = 7
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
	SpawnerConfig[][] waves;
	EnemyConfig[] enemies;
	uint2[] path;
	uint2 tileSize;
	StatusConfig[] statuses;
	Projectile[] projectiles;
	TowerConfig[] towers;
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
	@Convert!pathConverter() Path path;
	uint2 tileSize;
	List!EnemyPrototype enemyPrototypes;
	List!StatusPrototype statusPrototypes;
	List!ProjectilePrototype projectilePrototypes;
	List!TowerPrototype towerPrototypes;
}

struct EnemyPrototype
{
	int worth;
	float maxHealth;
	float speed;
	@Convert!stringToFrame() Frame frame;
}

struct StatusPrototype
{
	float duration;
	ElementType type;
	@Optional(IceStatus()) IceStatus ice;
	@Optional(FireStatus()) FireStatus fire;
	@Optional(WaterStatus()) WaterStatus water;
	@Optional(LightningStatus()) LightningStatus lightning;
	@Optional(NatureStatus()) NatureStatus nature;
	@Optional(WindStatus()) WindStatus wind;
}

struct ProjectilePrototype
{
	float speed;
	float damage;
	ProjectileType type;
	int statusIndex;
}

struct TowerPrototype
{
	float range;
	int cost;

	TowerType type;
	@Optional(ProjectileTower()) ProjectileTower pTower;
	@Optional(ConeTower()) ConeTower cTower;
	@Optional(EffectTower()) EffectTower eTower;
}


auto stringToFrame(string ID)
{
	import game, graphics;
	return Frame(Game.content.loadTexture(ID));
}

Path pathConverter(PathConfig pc)
{
	return Path(GC.it, pc.tileSize, pc.wayPoints);
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

struct StatusConfig
{
	float duration;
	ElementType type;
	@Optional(0.0f) float common1;
	@Optional(0.0f) float common2;
	@Optional(0.0f) float common3;
}

struct TowerConfig
{
	float range;
	uint cost;
	TowerType type;
	@Optional(0.0f) float common1;
	@Optional(0.0f) float common2;
	@Optional(0) int common3;
	@Optional(0.0f) float common4;
	@Optional(0.0f) float common5;
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

struct Status
{
	int targetIndex;
	float duration;
	float elapsed;
	ElementType type;
	union
	{
		IceStatus ice;
		FireStatus fire;
		WaterStatus water;
		LightningStatus lightning;
		NatureStatus nature;
		WindStatus wind;
	}
	
	this(StatusPrototype prefab, int target)
	{
		this.targetIndex = target;
		this.duration = prefab.duration;
		this.elapsed = 0;
		this.type = prefab.type;
		final switch(this.type) with (ElementType)
		{
			case ice:
				this.ice = prefab.ice;
				break;
			case fire:
				this.fire = prefab.fire;
				break;
			case water:
				this.water = prefab.water;
				break;
			case lightning:
				this.lightning = prefab.lightning;
				break;
			case nature:
				this.nature = prefab.nature;
				break;
			case wind:
				this.wind = prefab.wind;
				break;
		}
	}
}

struct IceStatus
{
	float previousSpeed;
}

struct NatureStatus
{
	float amount;
}

struct FireStatus
{
	float amount;
	int numTicks;
	@Optional(0f) float elapsed;
}

struct WaterStatus
{
}

struct WindStatus
{
	float speed;
	@Optional(0f) float previousSpeed;
}

struct LightningStatus
{
	float jumpDistance;
	float damage;
	float reduction;
}

struct Enemy
{
	float distance;
	float speed;
	float health;
	float maxHealth;
	int worth;
	Frame frame;
	this(EnemyPrototype prefab)
	{
		this.distance = 0;
		this.speed = prefab.speed;
		this.health = prefab.maxHealth;
		this.maxHealth = prefab.maxHealth;
		this.worth = prefab.worth;
		this.frame = prefab.frame;
	}
}

struct Spawner
{
	int prototypeIndex;
	float startTime;
	float spawnInterval;
	int numEnemies;
	@Optional(0f) float elapsed;
}

struct Wave
{
	List!Spawner spawners;
}

enum TowerType
{
	projectile = 0,
	cone = 1,
	effect = 2
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
	int statusIndex;
	float reactivationTime;
	float activeTime;
	@Optional(0f) float elapsed;
}

struct EffectTower
{
	float attackSpeed;
	@Optional(0f) float deltaAttackTime;
	int statusIndex;
	float damage;
}

struct Tower
{
	float range;
	int cost;

	uint2 position;

	TowerType type;
	union
	{
		ProjectileTower pTower;
		ConeTower cTower;
		EffectTower eTower;
	}

	this(TowerPrototype prefab, uint2 position)
	{
		this.range = prefab.range;
		this.cost = prefab.cost;
		this.position = position;
		this.type = prefab.type;
		final switch(this.type) with (TowerType)
		{
			case projectile:
				this.pTower = prefab.pTower;
				break;
			case cone:
				this.cTower = prefab.cTower;
				break;
			case effect:
				this.eTower = prefab.eTower;
				break;
		}
	}

	float2 pixelPos(uint2 tileSize)
	{
		return float2 (position.x * tileSize.x + tileSize.x/2, position.y * tileSize.y + tileSize.y/2);	
	}
}

enum ProjectileType 
{
	normal = 0,
	splash  = 1,
}

struct Projectile
{
	float attackDmg;
	float speed;
	ProjectileType type;
	uint statusIndex;
	@Optional(float2.zero) float2 position;
	@Optional(-1) int target;

	this(ProjectilePrototype prefab, float2 position, int target)
	{
		this.attackDmg = prefab.damage;
		this.speed = prefab.speed;
		this.type = prefab.type;
		this.statusIndex = prefab.statusIndex;
		this.position = position;
		this.target = target;
	}
}
