module types;
import math;
import graphics;
import collections;

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

enum StatusType
{
	ice = 1,
	fire = 2,
	water = 3,
	nature = 4,
	wind = 5
}

struct Status
{
	int targetIndex;
	float duration;
	float elapsed;
	StatusType type;
	union
	{
		IceStatus ice;
		FireStatus fire;
		WaterStatus water;
		NatureStatus nature;
		WindStatus wind;
	}
}

struct IceStatus
{
	float amount;
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
}

struct Enemy
{
	float2 pos;
	uint index;
	float speed;
	float health;
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

struct Tower
{
	float range;
	float attackDmg;
	int projectileType;

	float attackSpeed;
	float deltaAttackTime;
	int cost;
	uint2 position;
	float2 pixelPos(uint2 tileSize)
	{
		return float2 (position.x * tileSize.x + tileSize.x/2, position.y * tileSize.y + tileSize.y/2);	
	}
}

enum ProjectileType 
{
	normal = 0,
	splash  = 1,
	slow   = 2,
	dot    = 4
}

struct Projectile
{
	float attackDmg;
	float2 position;
	int target;
	int type;
}
