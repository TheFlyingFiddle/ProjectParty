module commands;

import state;
import math.vector;
import std.conv;
import allocation;
import framework.entity;
import common.components;

struct AddItem
{
	int    itemIndex;
	//Need for revert.
	int	   oldSelected;
	
	this(EditorState* state)
	{
		this.oldSelected = state.selected;
	}

	void apply(EditorState* s)
	{
		auto item = WorldItem("000");
		//item.components ~= Component(Transform());
		s.world.items ~= item;

		this.itemIndex = s.world.items.length - 1;

		s.selected = itemIndex;
	}

	void revert(EditorState*  s)
	{ 
		auto item = s.item(itemIndex);
		s.world.items.removeAt(itemIndex);
		s.selected = oldSelected;

		item.deallocate();
	}
}

struct AddComponent(T)
{
	int itemIndex;
	T   component;

	this(EditorState* s, T t)
	{
		this.itemIndex = s.selected;
		this.component = t;
	}	

	void apply(EditorState* s)
	{
		auto item = s.item(itemIndex);
		item.components ~= Component(component);
	}

	void revert(EditorState* s)
	{
		auto item = s.item(itemIndex);
		item.components.length--;
	}
}

struct Changed
{
	int index;
	Component component;
}

struct ComponentsChanged
{
	int item;
	Changed[] changed;

	this(int item, Changed[] changed)
	{
		this.changed = changed;
		this.item	 = item;
	}

	void apply(EditorState* s)
	{
		auto item = s.item(this.item);
		foreach(ref chang; changed)
		{
			auto tmp = item.components[chang.index];
			item.components[chang.index] = chang.component;
			chang.component = tmp;
		}
	}

	void revert(EditorState* s)
	{
		auto item = s.item(this.item);
		foreach(ref chang; changed)
		{
			auto tmp = item.components[chang.index];
			item.components[chang.index] = chang.component;
			chang.component = tmp;
		}

		import log;
		logInfo("Reverted changed values!");
	}
}

struct AddChainVertex
{
	float2 vertex;
	int item;

	this(float2 vertex, EditorState* s)
	{
		this.vertex = vertex;
		this.item   = s.selected;
	}

	void apply(EditorState* s)
	{
		auto item  = s.item(this.item);
		auto chain = item.getComp!(Chain);
		chain.vertices ~= vertex;
	}

	void revert(EditorState* s)
	{
		auto item  = s.item(this.item);
		auto chain = item.getComp!(Chain);
		chain.vertices.length--;
	}
}

struct ChangeItemName
{
	int item;

	string oldName;
	string newName;

	this(EditorState* s, const(char[]) newName)
	{
		this.item = s.selected;

		auto tmp =  GlobalAlloc.allocate!(char[])(newName.length);	
		tmp[] = newName;
		this.newName = cast(string)tmp;
	}

	void apply(EditorState* s)
	{
		auto item  = s.item(this.item);
		oldName    = item.name;
		item.name  = newName;
	}

	void revert(EditorState* s)
	{
		auto item = s.item(this.item);
		item.name = oldName;
	}

	void clear()
	{
		GlobalAlloc.deallocate(newName);
	}
}