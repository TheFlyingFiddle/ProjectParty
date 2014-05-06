module types;

import graphics, math, event, std.uuid, collections;
import network.message;

alias EventStream = EventStreamN!(uint);

alias Table(V) = collections.Table!(Color, V, SortStrategy.unsorted);

struct Snake
{
	float2 pos;
	float2 dir;
	bool visible;
}

struct CollisionEvent
{
	Color color;
	uint numPixels;
}	

enum Input { Left = 0, Right = 1 }
struct InputEvent
{
	Color color;
	float input;
}

private alias Out = OutgoingNetworkMessage;
enum Outgoing : Out
{
	death = Out(50),
	color = Out(52),
	position = Out(53),
	win = Out(54)
}

private alias In = IncommingNetworkMessage;
enum IncomingMessages : In
{
	readyMessage = In(51)
}

@(Outgoing.death) struct DeathMessage
{
	ushort score;
}

@(Outgoing.win) struct WinMessage
{
	ushort score;
}

@(Outgoing.color) struct ColorMessage
{
	uint color;
}

@(Outgoing.position) struct PositionMessage
{
	ushort position;
}