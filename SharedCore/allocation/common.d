module allocation.common;

import log;
import std.traits;
import std.conv;

auto logChnl = LogChannel("ALLOCATION");
auto destChnl = LogChannel("DESTRUCTOR ERROR");


void destructor(T)(void* ptr) if(is(T == struct))
{
	try
	{
		T* t = cast(T*)ptr;
		t.__dtor();
	}
	catch(Throwable t)
	{
		destChnl.info("Error while processing destructor : ", T.stringof, "\n", t);
	}
}

void destructor(T)(void* ptr) if(is(T == class))
{
	try
	{
		T  t = cast(T)ptr;
		t.__dtor();
	}
	catch(Throwable t)
	{
		destChnl.info("Error while calling destructor for: ", T.stringof, "\n", t);
	}
}

template hasFinalizer(T)
{
	static if(is(T == class))
		enum hasFinalizer = hasMember!(T, "__dtor");
	else 
		enum hasFinalizer = hasElaborateDestructor!T;
}

interface IAllocator
{
	void[] allocate_impl(size_t size, size_t alignment) @nogc;
	void   deallocate_impl(void[] memory) @nogc;
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
		_allocator.deallocate_impl(memory);
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

void deallocate(T,A)(ref A allocator, T item) if(is(T == class))
{
	void* ptr = cast(void*)item;
	void[] toDealloc = ptr[0 .. __traits(classInstanceSize, T)];
	allocator.deallocate_impl(toDealloc);
}

void deallocate(T,A)(ref A allocator, T* item) if(is(T == struct))
{
	static if(hasMember!(T, "deallocate"))
		item.deallocate(allocator);

	void* ptr = cast(void*)item;
	void[] toDealloc = ptr[0 .. T.sizeof];
	allocator.deallocate_impl(toDealloc);
}

void deallocate(T, A)(ref A allocator, T[] item) if(!is(T == void))
{
	allocator.deallocate_impl(cast(void[])item);
}

//Test if out of memory assertion works.
unittest
{
	import allocation;

	auto region = RegionAllocator(Mallocator.cit, 1024, 16);
	testFreshAllocations(region);

	auto mallocator = Mallocator.it;
	testFreshAllocations(mallocator);
}

unittest 
{
	import allocation;

	auto region = RegionAllocator(Mallocator.cit, 1024, 16);
	testAlignment(region);

	auto mallocator = Mallocator.it;
	testAlignment(mallocator);

	//TODO: These unittests were broken long ago (removal of GC.it, introduction of @nogc), but should eventually be fixed
	//auto gcAllocator = GC.it;
	//testAlignment(gcAllocator);
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