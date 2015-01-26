module state;

import do_undo;
import util.variant;
import collections.list;
import framework.entity;
import util.hash;
import allocation;
import math.vector;
import graphics;
import std.algorithm;
import ui.base : Rect;
import std.file, content.texture;

alias GlobalAlloc = Mallocator.it;

struct EditorStateContent
{
	string assetDir;

	//Variables Here
	List!WorldItem items;
	List!WorldItem archetypes;
}

struct EditorState
{
	VariantTable!(32) variables;
	DoUndoCommands!(EditorState*) doUndo;
	EditorClipboard clipboard;
	Camera camera;

	Rect worldRect;
	GrowingList!WorldItem items;
	GrowingList!WorldItem archetypes;
	List!(Frame*) images;
	int archetype;


	void delegate(EditorState*) selectedChanged;
	int selected_;

	this(void delegate(EditorState*) selectedChanged)
	{
		variables   = VariantTable!(32)(GlobalAlloc, 100);
		doUndo	    = DoUndoCommands!(EditorState*)(2000);
		clipboard   = EditorClipboard(true);
		camera	    = Camera(float2.zero);

		worldRect   = Rect.empty;
		archetypes  = GrowingList!WorldItem(Mallocator.cit, 20);
		items		= GrowingList!WorldItem(Mallocator.cit, 1000);
		images = List!(Frame*)(Mallocator.it, 100);
		this.selectedChanged = selectedChanged;
	}

	void initialize(EditorStateContent c)
	{
		selected_ = -1;
		archetype = 0;

		variables.clear();
		doUndo.clear();
		clipboard = EditorClipboard(true);
		camera = Camera(float2.zero);
	
		foreach(ref a; archetypes)
			a.deallocate();
		foreach(ref i; items)
			i.deallocate();
		foreach(ref img; images)
			FrameLoader.unload(Mallocator.cit, img);

		archetypes.clear();
		items.clear();
		images.clear();

		archetypes ~= c.archetypes;
		items	   ~= c.items.map!(x => x.clone());

		selected_ = -1;
		archetype = 0;
		this.selectedChanged = selectedChanged;

		string[] frameNames;

		auto dir = c.imageDir;
		import std.path;

		auto p = absolutePath(c.imageDir, dirName(thisExePath));
		foreach(entry; dirEntries(p, SpanMode.depth))
		{
			if(entry.name.extention == ".png")
			{
				frameNames ~= relativePath(p, entry.name);
				images     ~= FrameLoader.load(Mallocator.cit,  entry.name, false);
				
			}
		}

		variables.images		  = frameNames;
		variables.bodies		  = ["bodyA", "bodyB"];
		variables.particleEffects = ["systemA", "systemB"];
		variables.collisions	  = ["collisionA", "collisionB"];
	}

	ref int selected() @property
	{
		return selected_;
	}
	void selected(int value) @property
	{
		this.selected_ = value;
		if(selectedChanged !is null)
			selectedChanged(&this);
	}

	auto item(int idx)
	{
		if(idx < 0 || idx >= items.length) return null;
		return &items[idx];
	}

	auto itemNames()
	{
		import std.algorithm;
		return items.array.map!(x => x.name);
	}
}

struct EditorClipboard
{
	bool empty;
	WorldItem item;
}

struct Camera
{
	float2 offset;
}

struct WorldItem
{
	string name;
	List!Component components;
	
	this(string name)
	{
		this.name = name;
		components = List!Component(GlobalAlloc, 20);
	}

	void deallocate()
	{
		components.deallocate(GlobalAlloc);
	}

	WorldItem clone()
	{
		auto other = WorldItem(name);
		other.components ~= this.components;
		return other;
	}

	T* getComp(T)()
	{
		foreach(ref c; components)
		{
			if(c.type == cHash!T)
				return (cast(T*)c.data.ptr);
		}

		assert(0, "No Component found!");
	}

	bool hasComp(T)()
	{
		foreach(ref c; components)
		{
			if(c.type == cHash!T)
				return true;
		}

		return false;
	}


}