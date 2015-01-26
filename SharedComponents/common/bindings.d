module common.bindings;

import util.traits, util.hash;
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

	void write(U, Sink)(ref U u, ref Sink sink, int level) if(is(U == T[]) || isListOf!(U,T))
	{
		import std.range;

		sink.put('\n');
		sink.put('\t'.repeat(level - 1));
		sink.put(objectOpener);

		foreach(ref t; u)
		{
			sink.put('\n');
			sink.put('\t'.repeat(level));
			bool found = false;
			foreach(type; Types)
			{
				enum id = __traits(identifier, type);
				if(cHash!type == t.type)
				{
					sink.put(type.stringof);
					sink.put("=");
					auto value = cast(type)t;
					toSDL(value, sink, &this, level + 1);
					found = true;
					break;
				}
			}

			assert(found, "Can't serialize component!");
		}


		sink.put('\n');
		sink.put('\t'.repeat(level - 1));
		sink.put(objectCloser);
	}
}

unittest
{
	auto t = CompContext();
	t.read!(List!Component, CompContext*)(null);

	struct Test 
	{
		Component[] s;
	}
	Test test;
	List!char s;
	t.write(test.s, s, 0); 
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