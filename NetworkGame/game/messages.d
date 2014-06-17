module game.messages;

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