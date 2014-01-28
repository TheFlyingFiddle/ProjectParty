module allocation;

public import allocation.native;
public import allocation.region;
public import allocation.stack;
public import allocation.gc;

import logging;
auto logChnl = LogChannel("ALLOCATION");

interface IAllocator
{
	void[] allocate(size_t size, size_t alignment);
	void   deallocate(void[] memory);
}

final class CAllocator(T) : IAllocator
{
	T* _allocator;

	this(ref T allocator) 
	{
		this._allocator = &allocator; 
	}

	this(T* allocator)
	{
		this._allocator = allocator;
	}

	void[] allocate(size_t size, size_t alignment)
	{
		return _allocator.allocate(size, alignment);
	}

	void deallocate(void[] memory)
	{
		return _allocator.deallocate(memory);
	}
}

import std.traits;
T allocate(A, T)(ref A allocator, size_t size) if (isArray!T)
{
    T t;
    return cast(T) allocator.allocate(size * typeof(t[0]).sizeof, typeof(t[0]).alignof);
}

//Test if out of memory assertion works.
unittest
{
	auto region = RegionAllocator(Mallocator.it, 1024, 16);
	testFreshAllocations(region);

	auto mallocator = Mallocator.it;
	testFreshAllocations(mallocator);

	auto gcAllocator = GCAllocator.it;
	//testFreshAllocations(gcAllocator);
}

unittest 
{
	auto region = RegionAllocator(Mallocator.it, 1024, 16);
	testAlignment(region);

	auto mallocator = Mallocator.it;
	testAlignment(mallocator);

	auto gcAllocator = GCAllocator.it;
	testAlignment(gcAllocator);
}

unittest 
{
	auto region = RegionAllocator(Mallocator.it, 1024, 16);
	testOutOfMemory(region, 1025);
}


version(unittest)
{
	void testFreshAllocations(A)(ref A allocator)
	{
		ubyte[] first  = cast(ubyte[])allocator.allocate(128, 16);
		scope(exit) allocator.deallocate(first);
		ubyte[] second = cast(ubyte[])allocator.allocate(128, 16);
		scope(exit) allocator.deallocate(second);
		
		first[]  = 1;
		second[] = 2;

		foreach(i; 0 .. 128)
			assert(first[i] != second[i]);

	}

	void testAlignment(A)(ref A allocator)
	{
		import std.conv;
		uint[] alignments = [2,4,8,16,32,64, 128];
		foreach(elem; alignments) {
			ubyte[] d = cast(ubyte[])allocator.allocate(643, elem);
			assert(cast(size_t)(d.ptr) % elem == 0, d.ptr.to!string ~ " " ~ elem.to!string);
			allocator.deallocate(d);
		}
	}

	void testOutOfMemory(A)(ref A allocator, size_t toAllocate)
	{
		import std.exception, core.exception;
		assertThrown!(AssertError)(allocator.allocate(toAllocate, 16));
	}
}