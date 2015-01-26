module common.components;

import common;
import window.gamepad;
import util.traits;
import ui.reflection;

struct Input
{
	PlayerIndex index;

	static Input ident()
	{
		return Input.init;
	}
}

struct Transform
{
	float2 position;
	float2 scale;
	@Optional(0.0f) float  rotation;

	static Transform ident()
	{
		return Transform(float2.zero, float2.one, 0);
	}
}

struct Sprite
{
	Color tint;
	@FromItems("images") string name;

	static Sprite ident()
	{
		return Sprite(Color.white);
	}
}

struct Emitter
{
	@FromItems("particleEffects") string effect;
	static Emitter ident()
	{
		return Emitter("");
	}
}

struct Elevator
{
	float2 destination;
	float  interval; 
	@Optional(true) bool active;

	@Optional(0.0f) @DontShow float  elapsed;

	static Elevator ident()
	{
		return Elevator(float2.zero, 0, false, 0);
	}
}

struct Box2DConfig
{
	@FromItems("bodies") string name;
	@FromItems("collisions") string collision;

	static Box2DConfig ident()
	{
		return Box2DConfig("", "");
	}
}

enum ShapeType
{
	circle,
	polygon
}

struct Shape
{
	static Shape ident()
	{
		Shape s;
		s.type   = ShapeType.circle;
		s.radius = 0;
		return s;
	}		

	ShapeType type;
	union
	{
		float  radius;
		string polygon;
	}
}

struct Chain
{
	static Chain ident()
	{
		Chain c;
		c.vertices = GrowingList!(float2)(Mallocator.cit, 10);
		return c;
	}

	@Convert!(listToGrowing) GrowingList!float2 vertices;

	Chain clone()
	{
		Chain c;
		c.vertices = GrowingList!(float2)(Mallocator.cit, this.vertices.capacity);
		c.vertices ~= this.vertices.array;

		return c;
	}
}