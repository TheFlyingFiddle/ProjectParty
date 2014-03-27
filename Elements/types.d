module types;
import math;

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
	deselect = 54
}

enum TileType : ubyte
{
	buildable = 0,
	nonbuildable = 1,
	standardTower = 2
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

struct Enemy
{
	float2 pos;
	uint index;
	float speed;
	int health;
	int worth;
}

struct Wave
{
	int nbrOfEnemies;
	float spawnRate;
}

struct Tower
{
	float range;
	float attackDmg;
	float attackSpeed;
	float deltaAttackTime;
	int cost;
	uint2 position;
	float2 pixelPos(uint2 tileSize)
	{
		return float2 (position.x * tileSize.x + tileSize.x/2, position.y * tileSize.y + tileSize.y/2);	
	}
}

struct Projectile
{
	float attackDmg;
	float2 position;
	int target;
}
