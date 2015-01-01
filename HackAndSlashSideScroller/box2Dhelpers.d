module box2Dhelpers;

import dbox;
import namespace;
import entity;

void createStartWorld(ref World world)
{
	auto tempAlloc  = ScopeStack(scratch_region);
	auto bworld = world.app.locate!(b2World);

	//Ground
	createBox(bworld, float2(5.0, 1.0), float2(2.5f, 0.5f), b2_staticBody);
	
	foreach(i; 0 .. 40)
	{
		createBox(bworld, float2(3.0f + i * 0.2, 4.0f), float2(.4f, 0.2f), b2_dynamicBody);
	}

	float2[3] chain = [ float2.zero, float2(2, 1), float2(4, 1)];
	createChain(bworld, chain[]);
}

b2Body* createBox(b2World* world, 
				  float2 pos, 
				  float2 size,
				  b2BodyType type)
{
	auto tempAlloc  = ScopeStack(scratch_region);
	b2BodyDef bodyDef;
	bodyDef.type = type;
	bodyDef.position.Set(pos.x, pos.y);
	bodyDef.angle	= 0;
	b2Body* body_ = world.CreateBody(&bodyDef);

	auto dynamicBox = tempAlloc.allocate!(b2PolygonShape);
	dynamicBox.SetAsBox(size.x, size.y);

	b2FixtureDef fixtureDef;
	fixtureDef.shape    = dynamicBox;
	fixtureDef.density  = 1.0f;
	fixtureDef.friction = 0.3f;

	body_.CreateFixture(&fixtureDef);
	return body_;
}

b2Body* createCircle(b2World* world, float2 pos, float radius)
{
	auto tempAlloc  = ScopeStack(scratch_region);
	b2BodyDef bodyDef;
	bodyDef.type = b2_dynamicBody;
	bodyDef.position.Set(pos.x, pos.y);
	bodyDef.angle	= 1;
	b2Body* body_ = world.CreateBody(&bodyDef);

	auto dynamicBox = tempAlloc.allocate!(b2CircleShape);
	dynamicBox.m_radius = radius;

	b2FixtureDef fixtureDef;
	fixtureDef.shape    = dynamicBox;
	fixtureDef.density  = 1.0f;
	fixtureDef.friction = 0f;

	body_.CreateFixture(&fixtureDef);
	return body_;
}

b2Body* createChain(b2World* world, float2[] vertices)
{
	auto tempAlloc  = ScopeStack(scratch_region);
	b2Vec2[] vecs = cast(b2Vec2[])vertices;
	
	b2BodyDef bodyDef;
	bodyDef.type = b2_staticBody;
	bodyDef.position.Set(0, 0);
	bodyDef.angle  = 0;

	auto body_ = world.CreateBody(&bodyDef);
	
	auto chain = tempAlloc.allocate!(b2ChainShape);
	chain.CreateChain(vecs.ptr, vecs.length);
		
	b2FixtureDef fixtureDef;
	fixtureDef.shape	= chain;
	fixtureDef.friction = 0.3;

	body_.CreateFixture(&fixtureDef);
	return body_;
}