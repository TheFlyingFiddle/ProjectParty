module systems.circle;
import game, math, collections, 
	   entity, systems, graphics;

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
		auto impl = Game;
		auto items = collection.items;
		auto transforms = treeTransform.globals;
		foreach(i, comp; items)
		{
			auto transform = &transforms[comp.transform];
			impl.renderer.addFrame(i, frame, transform.position, comp.color, 
								   transform.scale, frame.dim / 2, 
								   transform.rotation);
		}
	}
}	