module allocation.region;

struct RegionAllocator
{
	void*  _buffer;
	void*  _offset;
	size_t _capacity;

	size_t bytesAllocated() @property
	{
		return cast(size_t)_offset - cast(size_t)_buffer;
	}

	size_t bytesRemaining() @property
	{
		return _capacity - bytesAllocated;
	}

	this(A)(A allocator, size_t capacity, size_t alignment = 8)
	{
		this(allocator.allocate(capacity, alignment));
	}

	this(void[] buffer)
	{
		this._buffer   = buffer.ptr;
		this._offset   = buffer.ptr;
		this._capacity = buffer.length;
	}
	
	void[] allocate(size_t size, size_t alignment)
	{
		auto alignedOffset = aligned(_offset, alignment);
		_offset = cast(void*)(cast(size_t)alignedOffset + size);
		
		assert(bytesAllocated <= _capacity, "Out of memory");
		return alignedOffset[0 .. size];
	}
	
	void rewind(void* rewindPos)
	{
		assert(cast(size_t)rewindPos <= cast(size_t)_offset);
		
		this._offset = rewindPos;
	}

	@disable this(this);
}

void* aligned(void* ptr, size_t alignment)
{
	return cast(void*)((cast(size_t)ptr + (alignment - 1)) & ~(alignment - 1));
}


//Shared memory bugg #0001
//The bugg caused allocations to 
//return to little memory 16 bytes for 
//any allocation.
unittest
{
	import allocation;
	auto region = RegionAllocator(Mallocator.it, 1024, 0);

	ubyte[] first  = cast(ubyte[])region.allocate(128, 16);
	ubyte[] second = cast(ubyte[])region.allocate(128, 16);

	first[]  = 1;
	second[] = 2;

	foreach(i; 0 .. 128)
		assert(first[i] != second[i]);
}


//Test if alignment is properly handled for good alignments.
unittest 
{
	import allocation, std.conv;
	auto region = RegionAllocator(Mallocator.it, 1024 * 1024, 0);
	uint[] alignments = [2,4,8,16,32,64, 128];
	foreach(elem; alignments) {
		ubyte[] d = cast(ubyte[])region.allocate(643, elem);
		assert(cast(size_t)(d.ptr) % elem == 0, d.ptr.to!string ~ " " ~ elem.to!string);
	}
}

//Test if out of memory assertion works.
unittest
{
	import allocation;
	import std.exception, core.exception;
	auto region = RegionAllocator(Mallocator.it, 1024, 0);
	assertThrown!(AssertError)(region.allocate(1025, 16));
}

unittest
{
	import allocation;
	auto region = RegionAllocator(Mallocator.it, 1024, 16);
	ubyte[] d = cast(ubyte[])region.allocate(1024, 16);

	assert(d.length == 1024);
	assert(region.bytesAllocated() == 1024);
	assert(region.bytesRemaining() == 0);
}


struct RegionAppender(T)
{
	import collections.list, std.range;

	RegionAllocator* _allocator;
	void*            _rewindPos;
	T*               _buffer;
	size_t           _capacity;
	size_t           _offset;

	this(ref RegionAllocator allocator)
	{
		this(&allocator);
	}

	this(RegionAllocator* allocator, size_t alignment = T.alignof)
	{
		this._allocator = allocator;
		
		size_t bytes = (allocator.bytesRemaining() / T.sizeof) * T.sizeof;
		T[] buffer = cast(T[])allocator.allocate(bytes, alignment);
		_capacity  = buffer.length;
		_buffer    = buffer.ptr;
		_offset    = 0;
		_rewindPos = this._allocator._offset; 
	}

	~this()
	{
		_allocator.rewind(_rewindPos);
	}	

	List!T data()
	{
		return List!T(_buffer, cast(uint)_offset, cast(uint)_offset);
	}

	List!T take()
	{
		auto list = List!T(_buffer, cast(uint)_offset, cast(uint)_offset);

		_rewindPos = &_buffer[_offset];
		_buffer    = cast(T*)_rewindPos;
		_offset    = 0;
		_capacity -= _offset;

		return list;
	}

	size_t put(T value)
	{
		assert(_offset < _capacity);
		_buffer[_offset++] = value;
        return _offset - 1;
	}

	void put(T[] value)
	{
		assert(_offset + value.length < _capacity);
		_buffer[_offset .. _offset + value.length] = value;
	}

	void put(Range)(Range range) if(isInputRange!Range && is(ElementType!Range : T))
	{
		foreach(ref elem; range)
			put(elem);
	}

	void clear()
	{
		_offset = 0;
	}

    ref T opIndex(size_t index)
	{
        assert(index < _capacity, "Index out of bounds");
        return _buffer[index];
	}

    void opIndexAssign(ref T value, size_t index)
	{
        assert(index < _capacity, "Index out of bounds");
        _buffer[index] = value;
	}

	@disable this(this);
}


//Can append.
unittest
{
	import allocation, collections.list;
	auto a = RegionAllocator(Mallocator.it, 1024 * 2, 16);
	auto app  = RegionAppender!(ushort)(a);

	foreach(ushort i; 0 .. 1024) {
		app.put(i);
	}

	auto list = app.data;
	foreach(ushort i; 0 .. 1024) {	
		assert(list[i] == i);
	}
}

//Crash on overflow.
unittest
{
	import allocation;
	import std.exception, core.exception;
	auto a = RegionAllocator(Mallocator.it, 1024 * 2, 16);
	auto app  = RegionAppender!(ushort)(a);
	foreach(ushort i; 0 .. 1024) app.put(i);

	assertThrown!AssertError(app.put(1));
}