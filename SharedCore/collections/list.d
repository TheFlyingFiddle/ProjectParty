module collections.list;

import std.traits;
import allocation.common;
import std.conv;

struct List(T)
{
	import std.range : isInputRange, isForwardRange, isBidirectionalRange, isRandomAccessRange;
	
	static assert(isInputRange!(List!T));
	static assert(isForwardRange!(List!T));
	static assert(isBidirectionalRange!(List!T));
	static assert(isRandomAccessRange!(List!T));
	
	//This could potentially length + capacity at the begining of the buffer
	//instead. This would lead to reference like behaviour.
	T* buffer;
	uint length, capacity;

	@property const(T)[] array()
	{
		return buffer[0 .. length];
	}

	this(Allocator)(ref Allocator allocator, size_t capacity)
	{
		T[] buffer = allocator.allocate!(T[])(capacity);
		this(buffer);
	}

	this(T[] buffer)
	{
		this.buffer = buffer.ptr;
		this.length = 0;
		this.capacity = cast(uint)buffer.length;
	}

	this(T* buffer, uint length, uint capacity)
	{
		this.buffer   = buffer;
		this.length   = length;
		this.capacity = capacity; 
	}

	void deallocate(A)(ref A allocator)
	{
		//This is ofc only valid if allocated through a allocator
		//That accepts deallocate!
		allocator.deallocate(buffer[0 .. capacity]);
	}

	ref T opIndex(size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		return buffer[index];
	}

	void opOpAssign(string s : "~")(auto ref T value)
	{
		assert(length < capacity, "The list is full can no longer append!");
		buffer[length++] = value;
	}

	void opOpAssign(string s : "~", Range)(Range range)
	{
		put(range);
	}

	void opIndexAssign(ref T value, size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		buffer[index] = value;
	}

	void opIndexAssign(T value, size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		buffer[index] = value;
	}

	void opSliceAssign()(auto ref T value)
	{
		buffer[0 .. length] = value;
	}

	void opSliceAssign()(auto ref T value,
						 size_t x,
						 size_t y)
	{
		assert(x <= y && x < length && y < length, text("A list was siced outsize of it's bounds! Length: ",  length, " Slice: ", x ," ", y));
		buffer[x .. y] = value;
	}


	uint opDollar(size_t pos)()
	{
		return length;
	}

	bool opEquals(List!T other)
	{
		if(other.length != this.length)
			return false;

		foreach(i; 0 .. this.length) {
			if (this[i] != other[i])
				return false;
		}
		return true;
	}

	List!T opSlice()
	{
		return List!T(buffer, length, capacity);
	}

	List!T opSlice(size_t x, size_t y)
	{
		assert(x <= y && x <= length && y <= length, text("[", x, " .. ", y, "] Length: ", length));
		T* b = &buffer[x];
		uint length = cast(uint)(y - x);
		return List!T(b, length, length);
	}	

	int opApply(int delegate(ref T) dg)
	{
		int result;
		foreach(i; 0 .. length)
		{
			result = dg(buffer[i]);
			if(result) break;
		}
		return result;
	}

	int opApply(int delegate(uint, ref T) dg)
	{
		int result;
		foreach(i; 0 .. length)
		{
			result = dg(i, buffer[i]);
			if(result) break;
		}
		return result;
	}


	void clear()
	{
		this.length = 0;
	}
	
	void insert(size_t index, T value)
	{
		assert(length < capacity, text("Cannot insert outside of bounds! Length: ", length, " Index: ", index));

		foreach_reverse(i; index .. length)
			buffer[i + 1] = buffer[i];
		
		buffer[index] = value;
		length++;
	}

	void insert(size_t index, const(T)[] range)
	{
		assert(length + range.length <= capacity, text("Cannot insert outside of bounds! Length: ", length, " Index: ", index));

		foreach_reverse(i; index .. length + range.length)
			buffer[i + range.length] = buffer[i];

		buffer[index .. index + range.length] = cast(T[])range;
		length += range.length;
	}

	//Range interface
	@property List!T save() { return this; }
	@property bool empty() { return length == 0; }

	@property ref T front() { return *buffer; }
	@property ref T back()  { return buffer[length - 1]; }
	void popFront() {
		length--;
		buffer++;
	}
	void popBack() 
	{
		length--;
	}

	void put(T data)
	{
		this ~= data;
	}

	//Need to work around strings. (They are annoying)
	static if(is(T == char))
	{
		void put(dchar c)
		{
			import std.utf;
			Unqual!char[dchar.sizeof] arr;
			auto len = std.utf.encode(arr, c);
			put(arr[0 .. len]);
		}

		void put(string s)
		{
			foreach(char c; s)
				this ~= c;
		}

		void put(const(char)[] s)
		{
			foreach(char c; s)
				this ~= c;
		}
	}
}

import std.algorithm : SwapStrategy, countUntil, swap;
bool remove(SwapStrategy s = SwapStrategy.stable, T)(ref List!T list, auto ref T value) 
{	
	@nogc bool fn(T x) { return x == value; }
	return remove!(fn, s, T)(list);
}

bool removeAt(SwapStrategy s = SwapStrategy.stable, T)(ref List!T list, size_t index)
{
	assert(index < list.length, text("Cannot remove outsize of bounds! 
		   Length: ",  list.length, " Index: ", cast(ptrdiff_t)index)); 

	static if(s == SwapStrategy.unstable)
	{
		swap(list[list.length - 1], list[index]);
		list.length--;
	}
	else 
	{
		foreach(i; index .. list.length - 1)
			list[i] = list[i + 1];

		list.length--;
	}
	return true;
}

bool removeSection(SwapStrategy s = SwapStrategy.stable, T)(ref List!T list, size_t start, size_t end)
{
	foreach(i; start .. end)
		removeAt(list, start);

	return true;
}

bool remove(alias pred, SwapStrategy s = SwapStrategy.stable, T)(ref List!T list)
{
	import std.algorithm;
	auto index = list.countUntil!(pred)();
	if(index == -1) return false;

	static if(s == SwapStrategy.unstable)
	{
		swap(list[list.length - 1], list[index]);
		list.length--;
	}
	else 
	{
		foreach(i; index .. list.length - 1)
			list[i] = list[i + 1];

		list.length--;
	}

	return true;
}

void move(SwapStrategy s = SwapStrategy.stable, T)(ref List!T from, ref List!T to, uint index)
{
	auto item = from[index];
	removeAt!(s, T)(from, index);
	to ~= item;
}

unittest
{
	List!int i;
	foreach(j, ref item; i){ }
}

struct CircularList(T)
{
	T* buffer;
	uint start, end, length, capacity;

	this(Allocator)(ref Allocator allocator, size_t size)
	{
		this.buffer = allocator.allocate!(T[])(size);
		this.start  = 0;
		this.end    = 0;
		this.length = 0;
		this.capacity = size;
	}

	void push(ref T value)
	{
		end = (end + 1) % capacity;
		assert(end != start);
		buffer[end] = value;
		length++;
	}	

	void push(Range)(Range range) if(ElementType!Range == T)
	{
		foreach(ref elem; range)
			push(elem);
	}

	T pop() 
	{
		assert(length != 0);
		T t = buffer[end];
		end = (end + capacity - 1) % capacity;
		length--;
		return t;
	}

	void enqueue(ref T value)
	{
		start = (start + capacity - 1) % capacity;
		assert(end != start);
		buffer[start] = value;
		length++;
	}

	T dequeue(ref T value)
	{
		assert(length);
		T t = buffer[start];
		start = (start + 1) % capacity;
		return t;
	}

	ref T opIndex(size_t index)
	{
		assert(index < length);
		return buffer[(start + index) % capacity];
	}

	int opApply(int delegate(ref T) dg)
	{
		int result;
		if(end >= start)
		{
			foreach(i; start .. end)
			{
				result = dg(buffer[i]);
				if(result) return result;
			}
		} 
		else 
		{
			foreach(i; start .. capacity)
			{
				result = dg(buffer[i]);
				if(result) return result;
			}

			foreach(i; 0 .. end)
			{
				result = dg(buffer[i]);
				if(result) return result;
			}
		}
		return result;
	}

	int opApply(int delegate(uint, ref T) dg)
	{
		int result;
		uint index = 0;
		if(end >= start)
		{
			foreach(i; start .. end)
			{
				result = dg(index, buffer[i]);
				if(result) return result;
				index++;
			}
		} 
		else 
		{
			foreach(i; start .. capacity)
			{
				result = dg(index, buffer[i]);
				if(result) return result;
				index++;
			}

			foreach(i; 0 .. end)
			{
				result = dg(index, buffer[i]);
				if(result) return result;
				index++;
			}
		}
		return result;
	}


	CircularList!T save() { return this; }
	T front()    { return buffer[start]; }
	T back()     { return buffer[end]; }
	bool empty() { return length == 0; }

	void popFront()
	{
		dequeue();
	}
	void popBack() 
	{
		pop();
	}

	void put(T data)
	{
		push(data);
	}
}