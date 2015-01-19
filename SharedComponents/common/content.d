module common.content;


import dbox;
import content.sdl;
import math.vector;

enum Box2DShapeType
{
	rect,
	polygon,
	circle,
	chain,
	edge
}

alias Opt = Optional;
struct Box2DBodyConfig
{
	@Opt(b2_dynamicBody) b2BodyType type;
	@Opt(0.0f)			 float linearDamping;
	@Opt(0.0f)			 float angularDamping;
	@Opt(true)			 bool  allowSleep;
	@Opt(false)			 bool  awake;
	@Opt(false)			 bool  fixedRotation;
	@Opt(false)			 bool  bullet;
	@Opt(true)			 bool  active;
	@Opt(1.0f)			 float gravityScale;
	@Opt(0.0f)			 float friction;
	@Opt(0.0f)			 float restitution;
	@Opt(1.0f)			 float density;
	@Opt(false)			 bool  sensor;

	string				 name;
	Box2DShape			 shape;
}

struct Box2DShape
{
	Box2DShapeType type;

	@Opt(1.0f)					float radius;
	@Opt(1.0f)					float hx;
	@Opt(1.0f)					float hy;
	@Opt(cast(float2[])null)	float2[] vertices;
}
