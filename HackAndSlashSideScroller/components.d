module components;

import namespace;
import window.gamepad;

struct Input
{
	PlayerIndex index;
}

struct Transform
{
	float2 position;
	float  rotation;
}

struct Sprite
{
	Color tint;
	string name;
}

import dbox;
struct Box2DPhysics
{
	b2Body* body_;

	@property float2 position()
	{
		return cast(float2)body_.GetPosition();
	}

	@property float2 position(float2 value)
	{
		float32 angle = body_.GetAngle();
		body_.SetTransform(cast(b2Vec2)value, angle);
		return cast(float2)body_.GetPosition();
	}

	@property float2 velocity()
	{
		return cast(float2)body_.GetLinearVelocity();
	}

	@property float2 velocity(float2 value)
	{
		body_.SetLinearVelocity(cast(b2Vec2)value);
		return cast(float2)body_.GetLinearVelocity;
	}

	@property float rotation()
	{
		return body_.GetAngle();
	}

	@property float rotation(float value)
	{
		body_.SetTransform(cast(b2Vec2)position, value);
		return value;
	}
}


struct Elevator
{
	float2 p0, p1;
	float  interval;
	float  elapsed;
}