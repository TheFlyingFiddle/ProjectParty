module tools;

import state;
import ui;
import common.components;
import commands;

class Tool
{
	EditorState* state;
	Gui*		 gui;

	abstract string name();
	abstract bool canUse();
	abstract void use();
}

class SelectTool : Tool
{
	mixin BaseImpl!();

	bool moving = false;
	override bool canUse()
	{
		return true;	
	}	

	override void use()
	{
		auto mouse = gui.mouse;

		if(!mouse.isDown(MouseButton.left))
			moving = false;

		if(mouse.wasPressed(MouseButton.left))
		{
			foreach(i, ref item; state.items)
			{
				if(item.hasComp!(Transform))
				{
					auto transform = item.getComp!(Transform);
					float2 loc = mouse.location - float2(200, 5);

					if(transform.position.distance(loc) < 40)
					{
						state.selected = i;
						moving = true;
						break;
					}
				}
			}
		}

		if(moving)
		{
			auto item = state.item(state.selected);
			if(item)
			{
				auto transform = item.getComp!(Transform);
				transform.position = mouse.location - float2(200, 5);
			}
		} 
	}
}

class ChainTool : Tool
{
	mixin BaseImpl!();

	override bool canUse()
	{
		auto item = state.item(state.selected);
		if(item)
		{
			return item.hasComp!(Chain);
		}
	
		return false;
	}

	override void use()
	{
		auto mouse = gui.mouse;
		auto item  = state.item(state.selected);
		auto chain = item.getComp!(Chain);

		if(mouse.wasPressed(MouseButton.left) && 
		   state.worldRect.contains(mouse.location))
		{
			float2 offset = state.camera.offset - state.worldRect.xy;
			float2 location = offset + mouse.location;
			if(gui.keyboard.isModifiersDown(KeyModifiers.control) &&
			   chain.vertices.length > 0)
			{ 
				float2 lastPos  = chain.vertices.back;
				float2 relative = location - lastPos;

				import std.math;
				if(abs(relative.x) > abs(relative.y))
				{
					location = lastPos + float2(relative.x, 0);
				}
				else 
				{
					location = lastPos + float2(0, relative.y);
				}
			}

			state.doUndo.apply(state, AddChainVertex(location, state));
		}
	}
}


mixin template BaseImpl()
{
	this(EditorState* s, Gui* gui)
	{
		this.state = s;
		this.gui   = gui;
	}

	override string name()
	{
		import util.traits;
		return Identifier!(typeof(this));
	}
}