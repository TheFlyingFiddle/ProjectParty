module common.bindings;

import util.traits;
import std.typetuple;
import common.components;
import graphics;
import collections.list;
import framework.entity;
public import content.sdl;

template id(T...)
{
	enum id = Identifier!T;
}

alias Components = Structs!(common.components);
static string[] ComponentIDs = [staticMap!(id, Components) ];

alias CompContext = DynmapContext!(Component, Components);

struct DynmapContext(T, Types...)
{
	U read(U, C)(SDLIterator!(C)* iter) if(is(U == T[]) || isListOf!(U, T))
	{
		auto all = iter.allocator;	
		auto index = iter.currentIndex;
		auto len   = iter.walkLength;
		U comps = U(all, len);

		iter.goToChild();
		foreach(i; 0 .. len)
		{
			auto obj = iter.over.root[iter.currentIndex];
			auto next = obj.nextIndex;
			auto name = iter.readName();

			bool found = false;
			foreach(type; Types)
			{
				enum id = __traits(identifier, type);
				if(id == name)
				{
					auto v = iter.as!(type);
					comps ~= T(v);
					found = true;
					break;
				}
			}

			assert(found, "Name not found " ~ name);
			iter.currentIndex = next;
		}

		return comps;
	}
}

unittest
{
	auto t = CompContext();
	t.read!(List!Component, CompContext*)(null);
}


Color stringToColor(string s)
{
	assert(0, "Do some magic here");
}

Color intToColor(uint color)
{
	return Color(color);
}

import math;
GrowingList!float2 listToGrowing(List!float2 f)
{
	import allocation;
	GrowingList!float2 growing = GrowingList!float2(Mallocator.cit, f.length);
	growing ~= f;
	return growing;
}

struct FromItems
{
	string name;
}