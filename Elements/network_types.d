module network_types;

import network.message;

alias In = IncommingNetworkMessage;
enum IncomingMessages : In
{
	readyMessage		= In(49),
	towerRequest		= In(50),
	selectRequest		= In(51),
	deselect			= In(52),
	mapRequest			= In(53),
	towerEntered		= In(54),
	towerExited			= In(55),
	ventValue			= In(56),
	ventDirection		= In(57),
	towerSell			= In(58),
	ballisticValue		= In(59),
	ballisticDirection	= In(60),
	ballisticLaunch		= In(61),
	upgradeTower		= In(62),
	towerRepaired		= In(63),
	gatlingValue		= In(64)
}

alias Out = OutgoingNetworkMessage;
enum OutgoingMessages : Out
{
	map				= Out(50),
	towerBuilt		= Out(51),
	selected		= Out(52),
	deselected		= Out(53),
	towerEntered	= Out(54),
	towerExited		= Out(55), 
	towerInfo		= Out(56),
	transaction		= Out(57),
	towerSold		= Out(58),
	towerBroken		= Out(59),
	towerRepaired	= Out(60),
	ventInfo		= Out(61),
	ballisticInfo	= Out(62),
	gatlingInfo		= Out(63),
	pressureInfo	= Out(64)
}


@(OutgoingMessages.map)
struct MapMessage
{
	uint width;
	uint height;
	ubyte[] tiles;
}

@(OutgoingMessages.selected)
struct SelectedMessage 
{
	uint x, y, color;
}

@(OutgoingMessages.deselected)
struct DeselectedMessage 
{
	uint x, y;
}

@(OutgoingMessages.towerBuilt)
struct TowerBuiltMessage
{
	uint x, y;
	ubyte towerType;
	ubyte typeIndex;
	ubyte ownedByMe;
	uint color;
	ubyte isBroken;
}

@(OutgoingMessages.towerEntered)
struct TowerEnteredMessage
{
	uint x, y;
}

@(OutgoingMessages.towerExited)
struct TowerExitedMessage
{
	uint x, y;
}

@(OutgoingMessages.towerSold)
struct TowerSoldMessage
{
	uint x, y;
}

@(OutgoingMessages.towerInfo)
struct TowerInfoMessage
{
	uint cost;
	float range;
	string phoneIcon;
	string name;
	string info;
	ubyte type;
	ubyte index;
	ubyte basic;
	ubyte upgradeIndex0;
	ubyte upgradeIndex1;
	ubyte upgradeIndex2;
}

@(OutgoingMessages.transaction)
struct TransactionMessage
{
	int amount;
}

@(OutgoingMessages.towerRepaired)
struct TowerRepairedMessage
{
	uint x, y;
}	

@(OutgoingMessages.towerBroken)
struct TowerBrokenMessage
{
	uint x, y;
}

@(OutgoingMessages.ventInfo)
struct VentInfoMessage
{
	float pressure;
	float maxPressure;
	float direction;
	float open;
}

@(OutgoingMessages.ballisticInfo)
struct BallisticInfoMessage
{
	float pressure;
	float maxPressure;
	float direction;
	float bigBoomCost;
	float smallBoomCost;
}

@(OutgoingMessages.gatlingInfo)
struct GatlingInfoMessage
{
	float pressure;
	float maxPressure;
}


@(OutgoingMessages.pressureInfo)
struct PressureInfoMessage
{
	float pressure;
}

static this()
{
	generateLuaCode!(mixin(__MODULE__));
}