module types;
import math;
import graphics;
import collections;
import content;

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
	TileConfig[] tiles;
	SpawnerConfig[][] waves;
	EnemyConfig[] enemies;
	uint2[] path;
	uint2 tileSize;
	StatusConfig[] statuses;
	Projectile[] projectiles;
	TowerConfig[] towers;
}

struct TileConfig
{
	uint color;
	TileType type;
	string texture;
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
	float elapsed;
}

struct WaterStatus
{
}

struct WindStatus
{
	float speed;
	float previousSpeed;
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
}

struct Spawner
{
	int prototypeIndex;
	float startTime;
	float spawnInterval;
	int numEnemies;
	float elapsed;
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
	float deltaAttackTime;
	int projectileIndex;
}

struct ConeTower
{
	float width;
	float dps;
	int statusIndex;
	float reactivationTime;
	float activeTime;
	float elapsed;
}

struct EffectTower
{
	float attackSpeed;
	float deltaAttackTime;
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
	ProjectileType type;
	uint statusIndex;
	@Optional(float2.zero) float2 position;
	@Optional(-1) int target;
}
