module network_types;

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
	uint color;
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
	ubyte type;
	ubyte index;
	ubyte basic;
	ubyte upgradeIndex0;
	ubyte upgradeIndex1;
	ubyte upgradeIndex2;
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