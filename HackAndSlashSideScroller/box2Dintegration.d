module box2Dintegration;

import namespace;
import dbox;
import entity;
import graphics;
import rendering.combined;
import components;

class Box2DPhys : System
{
	b2World* boxWorld;
	override bool shouldAddEntity(ref Entity e)
	{
		return e.hasComp!Box2DPhysics &&
			   e.hasComp!Transform;
	}

	override void initialize()
	{
		//Create the world with a gravity of -10.
		boxWorld = Mallocator.it.allocate!(b2World)(b2Vec2(0.0, -10.0f));
		world.app.addService(boxWorld);

		b2ContactListener cListener;
		cListener.BeginContact = &onContactEnter;
		cListener.EndContact   = &onContactExit;

		boxWorld.SetContactListener(cListener);

	}

	void onContactEnter(b2Contact contact)
	{
		//From this entities should be calculated.
		//These entities can then decide what should be done if anyting!.
		import std.stdio;
		writeln("Contact has been made!");
	}

	void onContactExit(b2Contact contact)
	{
		//From this entities should be calculated.
		import std.stdio;
		writeln("Contact has been lost!");
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