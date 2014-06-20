module collections.blob;
import std.traits, std.range;

struct Blob
{
	void* buffer;
	uint length, capacity;

	this(Allocator)(ref Allocator allocator, size_t capacity)
	{
		this.buffer   = allocator.allocate!(void[])(capacity).ptr;
		this.capacity = cast(uint)capacity;
		this.length   = 0;
	}

	this(void[] buffer)
	{
		this.buffer   = buffer.ptr;
		this.capacity = cast(uint)buffer.length;
		this.length   = 0;
	}
	
	this(void* buffer, size_t length, size_t capacity)
	{
		this.buffer   = buffer;
		this.length   = cast(uint)length;
		this.capacity = cast(uint)capacity;
	}

	void opOpAssign(string op, T)(auto ref T value) if(!hasIndirections!T &&  op == "~")
	{
		assert(T.sizeof + length <= capacity);
		auto ptr = cast(T*)(cast(size_t)buffer + length);
		*ptr = value;
		length += T.sizeof;
	}

	void opOpAssign(string op, T)(auto ref List!(T) list) if(op == "~")
	{
		import std.c.string;
		assert(list.length * T.sizeof + length <= capacity);

		memcpy(cast(void*)(cast(size_t)buffer + length),
			   cast(void*)list.buffer,
			   list.length * T.sizeof);
		this.length += list.length * T.sizeof;
	}

	void opOpAssign(string op)(auto ref Blob blob) if(op == "~")
	{
		import std.c.string;
		assert(blob.length * T.sizeof + length <= capacity);

		memcpy(cast(void*)(cast(size_t)buffer + length),
			   blob.buffer,
			   blob.length);

		this.length += blob,length;
	}

	void opOpAssign(string op, Range)(Range range) if(op == "~" && isInputRange!Range)
	{
		foreach(item; range) this ~= item;
	}

	void put(T)(auto ref T item)
	{
		this ~= item;
	}

	T read(T)()
	{
		assert(length >= T.sizeof);
		T* p   = cast(T*)buffer;
		skip(T.sizeof);
		return *p;
	}

	void skip(size_t numBytes)
	{
		buffer = cast(void*)(cast(size_t)buffer + numBytes);
		length -= numBytes;
	}

	bool empty() 
	{
		return length == 0;
	}

	void putAligned(T, size_t alignment)(auto ref T item)
	{
		this ~= item;
		length += alignedSize!(T, alignment) - T.sizeof;
	}


	T readAligned(T, size_t alignment)()
	{	
		enum alignedSize = alignedSize!(T, alignment);
		assert(length >= alignedSize);
		T t = read!(T);
		skip(alignedSize - T.sizeof);
		return t;
	}

	void[] readBytes(size_t count)
	{	
		assert(length >= count);
		void[] p = buffer[0 .. count];
		skip(count);
		return p;
	}

	void clear()
	{
		length = 0;
	}
}

size_t alignedSize(T, size_t alignment)()
{
	return (T.sizeof + alignment - 1) & ~(alignment - 1);
}
