module systems;

import namespace;
import components;




import dbox;
class InputSystem : System
{
	import window.gamepad;
	GamePad* pad;

	override void initialize() 
	{
		pad = world.app.locate!GamePad;
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
				phys.velocity = float2(leftThumb.x * constants.playerSpeedMultiplier, phys.velocity.y);

				if(pad.wasPressed(input.index, GamePadButton.a))
				{
					phys.velocity = float2(phys.velocity.x, constants.jump);
				}
				else if(pad.wasPressed(input.index, GamePadButton.b))
				{
					pushbackStuff(phys);
				}
			}
		}
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

		auto bworld = world.app.locate!(b2World);
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
			
			float alpha = elevator.elapsed % (elevator.interval * 2);
			if(alpha < elevator.interval)
			{
				phys.velocity = (elevator.p1 - elevator.p0) / elevator.interval;
			}
			else 
			{
				phys.velocity = (elevator.p0 - elevator.p1) / elevator.interval;
			}

			elevator.elapsed += time.deltaSec;
		}
	}
}