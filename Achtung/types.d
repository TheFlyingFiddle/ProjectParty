module types;

import graphics, math, event;

alias EventStream = EventStreamN!(uint);

struct Snake
{
	float2 pos;
	float2 dir;
	Color color;
}

struct Timer
{
	float time;
	Color color;
	bool visible;
}

struct SnakeControl
{
	Color color;
	uint leftKey, rightKey;
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
	Input input;
}