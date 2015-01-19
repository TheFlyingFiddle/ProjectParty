module systems;

import common;
import components;
import box2Dintegration;

import dbox;
class InputSystem : System
{
	import window.gamepad;
	GamePad* pad;
	b2World* bworld;

	override void initialize() 
	{
		pad = world.app.locate!GamePad;
		bworld = world.app.locate!(b2World);
	}

	override bool shouldAddEntity(ref Entity entity) 
	{
		return entity.hasComp!Input &&
			   entity.hasComp!Box2DPhysics;
	}
	
	override void preStep(Time time) 
	{
		foreach(e; entities)
		{
			auto input     = e.getComp!Input;
			auto phys	   = e.getComp!Box2DPhysics;

			if(pad.isActive(input.index))
			{
				float2 leftThumb = pad.leftThumb(input.index);
				
				if(leftThumb.x > 0.1 || leftThumb.x < -0.1f)
					phys.velocity = float2(leftThumb.x * constants.playerSpeedMultiplier, phys.velocity.y);
				
				if(leftThumb.x > 0.1)
					input.direction = float2(1, 0);
				else if(leftThumb.x < -0.1)
					input.direction = float2(-1, 0);
				

				if(pad.wasPressed(input.index, GamePadButton.a))
				{
					phys.velocity = float2(phys.velocity.x, constants.jump);
				}
				else if(pad.wasPressed(input.index, GamePadButton.b))
				{
					pushbackStuff(phys);
				}
				else if(pad.wasPressed(input.index, GamePadButton.x))
				{
					shoot(phys, input.direction);
				}
			}
		}
	}

	void shoot(Box2DPhysics* phys, float2 dir)
	{
		//import log;
		//
		//auto bullet = createCircle(bworld, phys.position + dir * (1), 0.1);
		//bullet.SetGravityScale(0.0);
		//bullet.SetLinearVelocity(cast(b2Vec2)(dir * 10));
		//
		//
		//foreach(e; world.entities.entities[0 .. 
		//        world.entities.entityCount])
		//{
		//    if(e.hasComp!(Box2DPhysics) && (e.groups & EntityGroups.bullet) ==
		//        EntityGroups.bullet)
		//    {
		//        logInfo("Existing Entity Box2D ", e.id, 
		//                " ", e.getComp!(Box2DPhysics).body_ is bullet);
		//                    
		//    }	
		//}
		//
		//auto entity = world.entities.create();
		//entity.addComp(Box2DPhysics(bullet, &killBullet));
		//entity.groups |= EntityGroups.bullet;
		//bullet.m_userData = cast(void*)entity.id;
		//
		//logInfo("Created a bullet ", entity.id, " ", cast(void*)bullet); 
	}

	void killBullet(Entity* entity, Entity* other)
	{
		auto comp = entity.getComp!(Box2DPhysics);
		import log;
		logInfo("Killed a bullet ", entity.id, " ", cast(void*)comp.body_); 

		world.removeEntity(entity.id);
	}

	void pushbackStuff(Box2DPhysics* phys)
	{
		bool queryCallback(b2Fixture* fixture)
		{
			import std.stdio;
			writeln("CB:");

			auto b = fixture.GetBody();
			if(phys.body_ != fixture.GetBody())
			{
				float2 dir = cast(float2)b.GetPosition() - phys.position;
				b.ApplyForce(cast(b2Vec2)dir.normalized * 100, b.GetPosition(), true);
			}
			return true;
		}

		b2AABB aabb;
		aabb.lowerBound = cast(b2Vec2)(phys.position - float2(0.5, 0.5));
		aabb.upperBound = cast(b2Vec2)(phys.position + float2(0.5, 0.5));
		bworld.QueryAABB(&queryCallback, aabb);
	}
}

class ElevatorSystem : System
{
	override void initialize() 
	{
	}

	override bool shouldAddEntity(ref Entity entity) 
	{
		return	entity.hasComp!Elevator &&
				entity.hasComp!Box2DPhysics;
	}

	override void preStep(Time time) 
	{
		foreach(e; entities)
		{
			auto elevator  = e.getComp!Elevator;
			auto phys	   = e.getComp!Box2DPhysics;
			
			if(!elevator.active)
			{
				phys.velocity = float2.zero;
				continue;
			}
	
			float alpha = elevator.elapsed % (elevator.interval * 2);
			if(alpha < elevator.interval)
			{
				phys.velocity = elevator.destination / elevator.interval;
			}
			else 
			{
				phys.velocity = elevator.destination / -elevator.interval;
			}
			
			elevator.elapsed += time.deltaSec;
		}
	}
}