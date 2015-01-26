module commands;

import state;
import math.vector;
import std.conv;
import allocation;
import framework.entity;
import common.components;
import collections.list;

struct AddItem
{
	int    itemIndex;
	int	   oldSelected;
	WorldItem item;

	this(EditorState* state)
	{
		this.oldSelected = state.selected;
		this.item    = state.archetypes[state.archetype].clone();
	}

	void apply(EditorState* s)
	{
		s.items ~= item;
		this.itemIndex = s.items.length - 1;
		s.selected = itemIndex;
	}

	void revert(EditorState*  s)
	{ 
		auto item = s.item(itemIndex);
		s.items.removeAt(itemIndex);
		s.selected = oldSelected;
	}

	void clear()
	{
		item.deallocate();
	}
}

struct CopyItem
{
	WorldItem item;
	int copyIndex;
	int sel;

	this(EditorState* s)
	{
		sel  = s.selected;
		item = s.clipboard.item.clone();
	}

	void apply(EditorState* s)
	{
		s.items ~= item;
		copyIndex = s.items.length - 1;
		s.selected = copyIndex;
	}

	void revert(EditorState* s)
	{
		s.items.removeAt(copyIndex);
		s.selected = sel;
	}
}

struct RemoveItem
{
	int    itemIndex;
	WorldItem item;

	this(EditorState* state)
	{
		this.itemIndex = state.selected;
	}

	void apply(EditorState* s)
	{
		item = *s.item(itemIndex);
		s.items.removeAt(itemIndex);
		s.selected = -1;
	}

	void revert(EditorState*  s)
	{ 
		s.items.insert(itemIndex, item);
		s.selected = itemIndex;
	}
}

struct AddComponent
{
	int itemIndex;
	Component   component;

	this(T)(EditorState* s, T t)
	{
		this.itemIndex = s.selected;
		this.component = Component(t);
	}	

	void apply(EditorState* s)
	{
		auto item = s.item(itemIndex);
		item.components ~= component;
	}

	void revert(EditorState* s)
	{
		auto item = s.item(itemIndex);
		item.components.length--;
	}
}

struct RemoveComponent
{
	int itemIndex;
	int componentIndex;
	Component component;

	this(EditorState* s, int componentIndex)
	{
		itemIndex = s.selected;
		this.componentIndex = componentIndex;
		this.component = s.item(s.selected).components[componentIndex];
	}

	void apply(EditorState* s)
	{
		auto item = s.item(itemIndex);
		item.components.removeAt(componentIndex);
	}

	void revert(EditorState* s)
	{
		auto item = s.item(itemIndex);
		item.components.insert(componentIndex, component);
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