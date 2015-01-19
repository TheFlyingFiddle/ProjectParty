module box2Dintegration;

import common;
import dbox;
import entity;
import graphics;
import rendering.combined;
import components;
import collision_resolve;


alias void delegate(Entity*, Entity*) collision;
struct Box2DPhysics
{
	b2Body* body_;
	collision onCollision;

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

	//Don't know how to resolve this.
	static void destructor(ref Component c,
				  		   ref Entity entity,
						   ref World world)
	{
		//Destrying the body of 

		auto phys = cast(Box2DPhysics)c;
		auto bworld = world.app.locate!(b2World);
		phys.body_.m_userData = null;
		bworld.DestroyBody(phys.body_);

		import log;
		logInfo("Destroyed the entity! ", entity.id, " ", cast(void*)phys.body_ ); 
	}

	static int i = 0;
}

/* Gotta fix this so that we have more POWER!!! 
class Box2DInitializer : Initializer
{

	b2World* bworld;
	CollisionResolves* resolves;
	WorldData*		   worldData;
	b2PolygonShape	  poShape;
	b2CircleShape	  ciShape;
	b2EdgeShape		  edShape;
	b2ChainShape	  chShape;

	override void initialize()
	{
		poShape = Mallocator.it.allocate!(b2PolygonShape);
		ciShape = Mallocator.it.allocate!(b2CircleShape);
		edShape = Mallocator.it.allocate!(b2EdgeShape);
		chShape = Mallocator.it.allocate!(b2ChainShape);
		resolves  = Mallocator.it.allocate!CollisionResolves(world);

		bworld	  = world.app.locate!(b2World);
		worldData = world.app.locate!(WorldData);
	}

	override bool shouldInitializeEntity(ref Entity e)
	{
		return e.hasComp!(Box2DConfig) && e.hasComp!(Transform);
	}

	override void initializeEntity(ref Entity e)
	{
		auto bwold = world.app.locate!(b2World);

		auto config = *e.getComp!(Box2DConfig);
		e.removeComp!(Box2DConfig);

		auto trans = e.getComp!Transform;

		b2Body* body_ = bodyFromConfig(config, trans);
		body_.SetUserData(cast(void*)e.id);
	
		collision col = collisionFromConfig(config);

		auto phys = Box2DPhysics(body_, col);
		e.addComp(phys);		
	}	

	b2Body* bodyFromConfig(ref Box2DConfig bConfig, Transform* trans)
	{
		auto index = worldData.bodies.countUntil!(x => x.name == bConfig.name);
		if(index != -1)
		{
			auto config = worldData.bodies[index];

			b2BodyDef bodyDef;
			bodyDef.type = config.type;
			bodyDef.position  = cast(b2Vec2)trans.position;
			bodyDef.linearDamping  = config.linearDamping;
			bodyDef.angularDamping = config.angularDamping;
			bodyDef.allowSleep	   = config.allowSleep;
			bodyDef.awake		   = config.awake;
			bodyDef.fixedRotation  = config.fixedRotation;
			bodyDef.bullet		   = config.bullet;
			bodyDef.active		   = config.active;
			bodyDef.gravityScale   = config.gravityScale;

			b2FixtureDef fixtureDef;
			fixtureDef.friction      = config.friction;
			fixtureDef.restitution   = config.restitution;
			fixtureDef.density	     = config.density;
			fixtureDef.isSensor	     = config.sensor;

			final switch(config.shape.type) with(Box2DShapeType)
			{
				case rect: 
					poShape.SetAsBox(config.shape.hx, config.shape.hy);
					fixtureDef.shape = poShape;
					break;
				case polygon:
					poShape.Set(cast(b2Vec2*)config.shape.vertices.ptr,
								config.shape.vertices.length);
					fixtureDef.shape = poShape;
					break;
				case circle:
					ciShape.m_radius = config.shape.radius;
					fixtureDef.shape = ciShape;
					break;
				case chain:
					chShape.CreateChain(cast(b2Vec2*)config.shape.vertices.ptr, 
										config.shape.vertices.length);
					fixtureDef.shape = chShape;
					break;
				case edge:
					edShape.Set(cast(b2Vec2)config.shape.vertices[0],
								cast(b2Vec2)config.shape.vertices[1]);
					fixtureDef.shape = edShape;
					break;
			}	

			auto body_ = bworld.CreateBody(&bodyDef);
			body_.CreateFixture(&fixtureDef);
			return body_;
		}

		assert(0, "Failed to find body " ~ bConfig.name);
	}

	collision collisionFromConfig(ref Box2DConfig bConfig)
	{
		import util.traits;
		alias funcs = Methods!(CollisionResolves);
		foreach(idx, fun; funcs)
		{
			enum id = __traits(identifier, fun);
			if(bConfig.collision == id)
			{
				mixin("return &resolves." ~ id ~ ";");
			}
		}
		
		return null;
	}
}
*/

class Box2DPhys : System
{
	b2World* boxWorld;
	List!Collision collisions;
	
	struct Collision
	{
		EntityID a, b;
	}

	override bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!Box2DPhysics && e.hasComp!Transform;
	}

	override void preInitialize()
	{
		//Create the world with a gravity of -10.
		boxWorld = Mallocator.it.allocate!(b2World)(b2Vec2(0.0, -10.0f));
		world.app.addService(boxWorld);

		b2ContactListener cListener;
		cListener.BeginContact = &onContactEnter;
		cListener.EndContact   = &onContactExit;

		boxWorld.SetContactListener(cListener);
		collisions = List!Collision(Mallocator.it, 1000);
	}

	void onContactEnter(b2Contact c)
	{
		//From this entities should be calculated.
		//These entities can then decide what should be done if anyting!.
		if(collisions.length <= collisions.capacity)
		{
			auto bodyA = c.m_fixtureA.GetBody();
			auto bodyB = c.m_fixtureB.GetBody();

			auto entityA = cast(int)bodyA.m_userData;
			auto entityB = cast(int)bodyB.m_userData;

			collisions ~= Collision(entityA, entityB);
		}			
		else 
		{
			import std.stdio;
			writeln("Collisions are full!");
		}
	}

	void onContactExit(b2Contact contact)
	{
	}

	override void step(Time time)
	{
		boxWorld.Step(time.deltaSec, 6, 2);
		foreach(ref e; entities)
		{
			auto t = e.getComp!(Transform);
			auto p = e.getComp!(Box2DPhysics);

			//This simply copies information into 
			//Transform used by all other systems.
			t.position = p.position;
			t.rotation = p.rotation;
		}

		foreach(ref c; collisions)
		{
			auto entityA = world.findEntity(c.a);
			auto entityB = world.findEntity(c.b);

			if(entityA !is null && entityA.hasComp!(Box2DPhysics))
			{
				auto physA = entityA.getComp!(Box2DPhysics);
				if(physA.onCollision !is null)
				{
					physA.onCollision(entityA, entityB);
				}
			}
		
			if(entityB !is null && entityB.hasComp!(Box2DPhysics))
			{
				auto physB = entityB.getComp!(Box2DPhysics);
				if(physB.onCollision !is null)
				{
					physB.onCollision(entityB, entityA);
				}
			}
		}


		collisions.clear();
	}
}

class Box2DRender : System
{
	import rendering, content;
	import rendering.combined;
	import graphics;

	Renderer2D*     renderer;
	AtlasHandle	   atlas;

	override void initialize()
	{
		renderer = world.app.locate!Renderer2D;

		auto loader = world.app.locate!AsyncContentLoader;
		atlas		= loader.load!TextureAtlas("Atlas");
	}

	override bool shouldAddEntity(ref Entity e)
	{
		return false;
	}

	override void step(Time time)
	{
		auto bworld = world.app.locate!(b2World);

		renderer.begin();
		for(auto b = bworld.GetBodyList(); b !is null; b = b.GetNext)
		{
			for(auto fix = b.GetFixtureList; fix !is null; fix = fix.GetNext)
			{
				auto shape = fix.GetShape();
				switch(shape.GetType) with(b2Shape.Type)
				{
				    case e_circle:
					renderCircle(cast(b2CircleShape)shape, b);
					break;
				    case e_edge:
					renderEdge(cast(b2EdgeShape)shape, b);
					break;
				    case e_polygon:
					renderPolygon(cast(b2PolygonShape)shape, b);
					break;
				    case e_chain:
					renderChain(cast(b2ChainShape)shape, b);
					break;
					default:
						import std.conv;
						assert(0, text("Invalid box2D shape", cast(int)shape.GetType()));
				}
			}
		}
		renderer.end();
	}

	void renderCircle(b2CircleShape shape, b2Body* b)
	{
		renderer.drawNGonOutline!(50)(cast(float2)b.GetPosition * constants.worldScale,
									  shape.m_radius * constants.worldScale - 1.5,
									  shape.m_radius * constants.worldScale + 0.5,
									  atlas["pixel"], Color.blue);
	}

	void renderEdge(b2EdgeShape shape, b2Body* b)
	{
		float2 v0 = cast(float2)(shape.m_vertex1);
		float2 v1 = cast(float2)(shape.m_vertex2);
		renderLine(v0, v1, b);
	}

	void renderChain(b2ChainShape shape, b2Body* b)
	{
		foreach(i; 0 .. shape.GetChildCount())
		{
			float2 v0 = cast(float2)(shape.m_vertices[i]);
			float2 v1 = cast(float2)(shape.m_vertices[i + 1]);
			renderLine(v0, v1, b);	
		}
	}

	void renderPolygon(b2PolygonShape shape, b2Body* b)
	{
		foreach(i; 0 .. shape.GetVertexCount())
		{
			float2 v0 = cast(float2)shape.GetVertex(i);
			float2 v1 = cast(float2)shape.GetVertex((i + 1) % shape.GetVertexCount);
			renderLine(v0, v1, b);
		}
	}

	void renderLine(float2 v0, float2 v1, b2Body* b)
	{
		mat2 rot = mat2.rotation(b.GetAngle());
		v0 = rot * v0;
		v1 = rot * v1;

		v0 += cast(float2)b.GetPosition();
		v1 += cast(float2)b.GetPosition();

		v0 *= constants.worldScale;
		v1 *= constants.worldScale;
		renderer.drawLine(v0, v1, 2, atlas["pixel"], Color.blue);
	}

}