module mainscreen;

import common;
import content;
import graphics;
import systems;
import components;
import window.gamepad;
import allocation;
import particle_system;
import bindings;
import box2Dintegration;

class MainScreen : Screen
{
	World w;
	//WorldData wData;
	//StartData sData;
	this() { super(false, false); }

	override void initialize()
	{
		loadConstants();

		w = World(Mallocator.it, 20, 20, 1024, app);
		w.addSystem!InputSystem(Mallocator.it, 1000, 1);
		w.addSystem!ElevatorSystem(Mallocator.it, 1000, 2);
		w.addSystem!Box2DPhys(Mallocator.it, 1000, 3);
		w.addSystem!Box2DRender(Mallocator.it, 1000, 5);
		w.addSystem!ParticleProcessSystem(Mallocator.it, 1000, 4);

		//w.addInitializer!Box2DInitializer(Mallocator.it);

		w.initialize();

		//setupWorld();
	}

	import window.keyboard;
	override void update( Time time) 
	{
		w.step(time);
		
		auto kboard = app.locate!(Keyboard);

		if(kboard.wasPressed(Key.enter))
		{
			//wData = fromSDLFile!WorldData(Mallocator.it, "worldData.sdl", ComponentContext());
			//sData = fromSDLFile!StartData(Mallocator.it, "startData.sdl");

			w.removeAllEntities();
			//setupWorld();		
		}
	}
	//
	//void setupWorld()
	//{
	//    import std.algorithm;
	//    foreach(ref entry; sData.startEntries)
	//    {
	//        auto arch = wData.archetypes.find!(x => x.name == entry.arch)[0];
	//        foreach(ref transform; entry.transforms)
	//        {
	//            w.createFromArch(transform, arch);
	//        }
	//    }
	//}
}

void createFromArch(ref World world, Transform t,  ref EntityArchetype arch)
{
	auto entity = world.entities.create(arch);
	entity.addComp(t);

	world.addEntity(*entity);
}
