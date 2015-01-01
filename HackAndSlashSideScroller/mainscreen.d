module mainscreen;

import namespace;
import content;
import graphics;
import tilemap;
import systems;
import factories;
import components;
import window.gamepad;
import allocation;

import box2Dhelpers;
import box2Dintegration;

class MainScreen : Screen
{
	World w;

	this() { super(false, false); }

	override void initialize()
	{
		loadConstants();

		w = World(Mallocator.it, 20, 1024, app);
		w.addSystem!InputSystem(Mallocator.it, 1000, 1);
		w.addSystem!ElevatorSystem(Mallocator.it, 1000, 2);
		w.addSystem!Box2DPhys(Mallocator.it, 1000, 3);
		w.addSystem!Box2DRender(Mallocator.it, 1000, 4);

		w.initialize();
		w.createStartWorld();
		w.createBox2D(float2(5.0f, 5.5f), PlayerIndex.zero);
		w.createBox2D(float2(5.0f, 7f), PlayerIndex.one);
		w.createElevator(float2(2, 0.3),
						 float2(10, 0), float2(10, 5), 
						 4);
	}

	override void update( Time time) 
	{
		w.step(time);
	}
}
