module allocation;

public import allocation.native;
public import allocation.region;
public import allocation.stack;
public import allocation.gc;


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
T allocateT(A, T)(ref A allocator, size_t size) if (isArray!T)
{
    T t;
    return cast(T) allocator.allocate(size * typeof(t[0]).sizeof, typeof(t[0]).alignof);
}