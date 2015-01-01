module factories;

import namespace;
import window.gamepad;
import components;

import box2Dhelpers;
			
import dbox;
void createBox2D(ref World world, float2 pos, PlayerIndex index)
{
	auto bworld = world.app.locate!(b2World);

	auto entity = world.entities.create();
	entity.addComp(Input(index));
	entity.addComp(Box2DPhysics(createCircle(bworld, pos, 0.3f)));
	
	world.addEntity(*entity);
}


void createElevator(ref World world,
					float2 halfWidth,
					float2 start,
					float2 end,
					float  time)
{
	auto bworld = world.app.locate!(b2World);
	auto entity = world.entities.create();
	
	entity.addComp(Elevator(start, end, time, 0));
	entity.addComp(Box2DPhysics(createBox(bworld, start, halfWidth, b2_kinematicBody)));
	
	world.addEntity(*entity);
}