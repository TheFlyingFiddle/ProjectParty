module input;

import namespace;
import entity;
import components;

class InputSystem : System
{
	override bool shouldAddEntity(ref Entity entity)
	{
		return entity.hasComp!(Input) && 
			   entity.hasComp!(Box2DPhysics);
	}

	override void step(Time time)
	{
		import window.gamepad;
		auto gamePad = world.app.locate!GamePad;

		foreach(e; entities)
		{
			auto i = e.getComp!Input;
			auto p = e.getComp!Box2DPhysics;

			if(gamePad.isActive(i.index))
			{
				p.velocity = gamePad.leftThumb(i.index);
			}
		}
	}
}