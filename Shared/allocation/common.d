module allocation.common;

import logging;
import std.traits;
import std.conv;

auto logChnl = LogChannel("ALLOCATION");


interface IAllocator
{
	void[] allocate_impl(size_t size, size_t alignment);
	void   deallocate_impl(void[] memory);
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

	void[] allocate_impl(size_t size, size_t alignment)
	{
		return _allocator.allocate_impl(size, alignment);
	}

	void deallocate_impl(void[] memory)
	{
		return _allocator.deallocate_impl(memory);
	}
}

void[] allocateRaw(A)(ref A allocator, size_t size, size_t alignment)
{
	return allocator.allocate_impl(size, alignment);
}

void[] allocateRaw(A)(A* allocator, size_t size, size_t aligmnent)
{
	return allocator.allocate_impl(size, aligmnent);
}

void deallocate(A)(ref A allocator, void[] mem)
{
	allocator.deallocate_impl(mem);
}

void deallocate(A)(A* allocator, void[] mem)
{
	return allocator.deallocate_impl(mem);
}

T allocate(T, A)(ref A allocator, size_t size, size_t alignment = 8) if (isArray!T)
{
    T t;
    return cast(T) allocator.allocate_impl(size * typeof(t[0]).sizeof, alignment);
}

T* allocate(T, A, Args...)(ref A allocator, auto ref Args args) if(is(T == struct) || isNumeric!T)
{
	import std.conv;
	void[] buffer = allocator.allocate_impl(T.sizeof, T.alignof);
	return emplace!T(buffer, args);
}

T allocate(T, A, Args...)(ref A allocator, auto ref Args args) if(is(T == class))
{
	void[] buffer = allocator.allocate_impl(__traits(classInstanceSize, T), T.alignof);
	return emplace!T(buffer, args);
}

T allocate(T, A)(A* allocator, size_t size, size_t alignment = 8) if (isArray!T)
{
	return allocate!(T, A)(*allocator, size, alignment);
}

T* allocate(T, A, Args...)(A* allocator, auto ref Args args) if(is(T == struct) || isNumeric!T)
{
	return allocate!(T, A, Args)(*allocator, args);
}

T allocate(T, A, Args...)(A* allocator, auto ref Args args) if(is(T == class))
{
	return allocate!(T, A, Args)(*allocator, args);
}

//Test if out of memory assertion works.
unittest
{
	import allocation;

	auto region = RegionAllocator(Mallocator.cit, 1024, 16);
	testFreshAllocations(region);

	auto mallocator = Mallocator.it;
	testFreshAllocations(mallocator);

	auto gcAllocator = GCAllocator.it;
	//testFreshAllocations(gcAllocator);
}

unittest 
{
	import allocation;

	auto region = RegionAllocator(Mallocator.cit, 1024, 16);
	testAlignment(region);

	auto mallocator = Mallocator.it;
	testAlignment(mallocator);

	auto gcAllocator = GCAllocator.it;
	testAlignment(gcAllocator);
}

unittest 
{
	import allocation;
	auto region = RegionAllocator(Mallocator.cit, 1024, 16);
	testOutOfMemory(region, 1025);
}


version(unittest)
{
	void testFreshAllocations(A)(ref A allocator)
	{
		ubyte[] first  = allocator.allocate!(ubyte[])(128, 16);
		scope(exit) allocator.deallocate(first);
		ubyte[] second = allocator.allocate!(ubyte[])(128, 16);
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
			ubyte[] d = allocator.allocate!(ubyte[])(643, elem);
			assert(cast(size_t)(d.ptr) % elem == 0, d.ptr.to!string ~ " " ~ elem.to!string);
			allocator.deallocate(d);
		}
	}

	void testOutOfMemory(A)(ref A allocator, size_t toAllocate)
	{
		import std.exception, core.exception;
		assertThrown!(AssertError)(allocator.allocateRaw(toAllocate, 16));
	}
}