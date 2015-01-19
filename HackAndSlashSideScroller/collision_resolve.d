module collision_resolve;

import common;
import components;
import std.algorithm;

struct CollisionResolves
{
	World* world;

	void playerCollision(Entity* player, Entity* other)
	{

	}

	void toggleElevators(Entity* toggle, Entity* other)
	{
		foreach(ref e; world.entities)
		{
			if(e.groups == 1 &&
			   e.hasComp!Elevator)
			{
				auto comp = e.getComp!(Elevator);
				comp.active = !comp.active;
			}
		}
	}	
}