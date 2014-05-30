module circle;
import game, math, collections, 
		 entity_table, system, 
		 tree, graphics, world;

struct CircleComp
{
	CompHandle transform;
	Color color;
}

struct CircleRenderSystem
{
	mixin SystemBase!(CompCollection!(AOS!(CircleComp)), destructor);
	TreeTransformSystem* treeTransform;
	Frame frame;

	void initialize(World world)
	{	
		treeTransform = world.system!TreeTransformSystem;
		frame = Frame(Game.content.loadTexture("circle"));
	}

	CompHandle create(CompHandle transform, Color color)
	{
		auto handle = collection.create(transform, color);
		treeTransform.addRef(transform);
		return handle; 
	}

	void destructor(CircleComp comp)
	{
		treeTransform.removeRef(comp.transform);
	}

	void update()
	{
		import std.parallelism, std.range;
		auto impl = Game;

		foreach(i; taskPool.parallel(iota(0,collection.numObjects), 2048))
		{
			auto comp      = &collection.items[i];
			auto transform = &treeTransform.globals[comp.transform];
			impl.renderer.addFrame(i, frame, transform.position, comp.color, 
										  transform.scale, frame.dim / 2, 
										  transform.rotation);
		}
	}
}	