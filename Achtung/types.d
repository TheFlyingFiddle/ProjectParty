module types;

import graphics, math, event, std.uuid, collections;

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