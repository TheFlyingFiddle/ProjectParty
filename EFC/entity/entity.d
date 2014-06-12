module entity.entity;

struct Entity
{
	uint id;
	uint groups; 
	CompHandle[] components;
}


struct ES312
{
	@InGroup(Groups.BombThrowers)
	struct EComps
	{
		uint entity;
		ushort collisionIndex;
		ushort transform;
	}

	Queue* collisions;
	EComps[] entities;

	void update()
	{
		foreach(collision; collisions.all!Collisions)
		{
			auto index = entities.indexOf(x => x.collisionIndex == collision.a.index);
			if(index == -1) continue;
		}
	}
}