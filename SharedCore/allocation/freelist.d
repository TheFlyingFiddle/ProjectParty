module allocation.freelist;

import std.conv;
public import allocation.common;

struct FreeList(T) if(is(T == struct))
{
	@nogc:
	
	struct Item
	{
		union
		{
			T value;
			uint next;
		}
	}

	Item[] items;
	uint free;

	this(T[] buffer)
	{
		this.items = items;
		this.free  = 0;
		foreach(i; 0 .. items.length - 1)
		{
			items[i].next = i + 1;
		}
	}


	auto allocate(Args...)(Args args)
	{
		assert(free != uint.max);

		uint newFree = items[free].next; 
		auto t = emplace!(T, Args)(&items[free]);
		free = newFree;
		return t;
	}

	void deallocate(T* toDeallocate)
	{
		static if(hasFinalizer!T)
			destructor!(T)(cast(void*)toDeallocate);

		size_t addr = cast(size_t)(cast(void*)toDeallocate);
		size_t bufferAddr = cast(size_t)(cast(void*)items.ptr);
		size_t index = (addr - bufferAddr) / Item.sizeof;
		
		assert(index < items.length);

		items[index] = Item.init;
		items[index].next = free;
		free = index;
	}
}

struct FreeList(T) if(is(T == class))
{
	enum tsize  = __traits(classInstanceSize, T);
		
	struct Item
	{
		uint next;
		ubyte[tsize] value;
	}

	Item[] items;
	uint free;

	this(A)(ref A allocator, size_t maxItems)
	{
		void[] buffer = allocator.allocate!(ubyte[])(Item.sizeof * maxItems, T.alignof);
		this(buffer);
	}

	this(void[] buffer)
	{
		assert(buffer.length % Item.sizeof == 0, "Not a propperbuffer!");
		assert(cast(size_t)(buffer.ptr) % T.alignof == 0, "Bad alignment for buffer!");

		items = cast(Item[])buffer;
		this.free  = 0;
		foreach(i; 0 .. items.length - 1)
		{
			items[i].next = i + 1;
		}
	}

	auto pureAllocate(Args...)(Args args) @trusted
	{
		static auto assumePureNothrowSafe(T)(T t)
		{
			import std.traits;
			enum attrs = functionAttributes!T | FunctionAttribute.pure_ | FunctionAttribute.nothrow_;
			return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs))t;
		}

		auto all = assumePureNothrowSafe(&allocate!Args);
		return all(args);
	}

	auto allocate(Args...)(Args args) 
	{
		static auto assumePureNothrowSafe(T)(T t)
		{
			import std.traits;
			enum attrs = functionAttributes!T | FunctionAttribute.pure_ | FunctionAttribute.nothrow_ | FunctionAttribute.safe;
			return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs))t;
		}
	
		assert(free != uint.max);

		uint newFree = items[free].next; 
		auto t = emplace!(T, Args)(items[free].value[], args);
		free = newFree;
		return t;
	}

	void deallocate(T toDeallocate)
	{
		static if(hasFinalizer!T)
			destructor!(T)(cast(void*)toDeallocate);

		size_t addr = cast(size_t)(cast(void*)toDeallocate);
		size_t bufferAddr = cast(size_t)(cast(void*)items.ptr);
		size_t index = (addr - bufferAddr) / Item.sizeof;

		assert(index < items.length);

		items[index] = Item.init;
		items[index].next = free;
		free = index;
	}
}