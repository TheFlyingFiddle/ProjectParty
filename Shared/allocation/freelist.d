module allocation.freelist;

import std.conv;

struct FreeList(T) if(is(T == struct))
{
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
		

	//You can never be sure that the writing to the memory
	//in value will not to horrible things apperently...
	//If your using sockets don't be allarmed when it 
	//suddenly starts to write all over the console and 
	//trigger sounds and whatnot... 
	struct Item
	{
		uint next;
		ubyte[tsize] value;
	}

	Item[] items;
	uint free;

	this(A)(ref A allocator, size_t maxItems)
	{
		void[] buffer = allocator.allocate(Item.sizeof * maxItems, T.alignof);
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


	auto allocate(Args...)(Args args)
	{
		assert(free != uint.max);

		uint newFree = items[free].next; 
		auto t = emplace!(T, Args)(items[free].value[]);
		free = newFree;
		return t;
	}

	void deallocate(T toDeallocate)
	{
		size_t addr = cast(size_t)(cast(void*)toDeallocate);
		size_t bufferAddr = cast(size_t)(cast(void*)items.ptr);

		size_t index = (addr - bufferAddr) / Item.sizeof;

		assert(index < items.length);

		items[index] = Item.init;
		items[index].next = free;
		free = index;
	}
}