module framework.messages;

import network.message;

alias In = IncommingNetworkMessage;
enum Incoming : In
{
	alias_		= In(0),
	sensor		= In(1),
	luaLog		= In(5),
	heartbeat	= In(7)
}

@(Incoming.alias_)
struct AliasMessage
{
	string alias_;
}

@(Incoming.sensor)
struct SensorMessage
{
	import math.vector;
	float3 accelerometer;
}

@(Incoming.luaLog)
struct LuaLogMessage
{
	string toLog;
}

@(Incoming.heartbeat)
struct HeartbeatMessage
{
}