module moving;

import entity_table, system, math, tree, game.time, world;

struct MoveComponent
{
	float elapsed;
	float2 direction;
	CompHandle transform;
}


struct MoveSystem
{
	mixin SystemBase!(CompCollection!(AOS!(MoveComponent)), destructor);
	TreeTransformSystem* treeTransform;

	CompHandle create(CompHandle handle, float2 speed, float elapsed)
	{
		auto h = collection.create(elapsed, speed, handle);
		treeTransform.addRef(handle);
		return h;
	}

	void destructor(MoveComponent comp)
	{
		treeTransform.removeRef(comp.transform);
	}

	void initialize(World world)
	{
		treeTransform = world.system!TreeTransformSystem;
	}	

	void update()
	{
		import std.parallelism;

		immutable delta = Time.delta;
		auto items = collection.items[0 .. collection.numObjects];
		foreach(i, ref elem; taskPool.parallel(items, 2048))
		{
			auto trans = &treeTransform.locals[elem.transform];

			elem.elapsed += delta;
			auto movement = elem.elapsed % 1.0f;
			if(cast(uint)(elem.elapsed) % 2 == 1)
				movement = -movement;

			import std.math;
			trans.position +=  elem.direction * sin(movement * TAU / 2);
		}
	}
}