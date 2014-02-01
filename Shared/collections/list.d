module collections.list;


struct List(T)
{
	T* buffer;
	uint length, capacity;

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

	ref T opIndex(size_t index)
	{
		assert(index < length);
		return buffer[index];
	}

	void opOpAssign(string s)(auto ref T value) if(s == "~")
	{
		buffer[length++] = value;
	}

	void opIndexAssign(ref T value, size_t index)
	{
		assert(index < length);
		buffer[index] = value;
	}

	void opIndexAssign(T value, size_t index)
	{
		assert(index < length);
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
		assert(x <= y && x < length && y < length);
		buffer[x .. y] = value;
	}

	uint opDollar()()
	{
		return length;
	}

	List!T opSlice(size_t x, size_t y)
	{
		assert(x <= y && x <= length && y <= length);
		T* b = cast(T*)(cast(size_t)buffer + x * T.sizeof);
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
		assert(length < capacity);
		foreach_reverse(i; index .. length)
			buffer[i + 1] = buffer[i];
		
		buffer[index] = value;
	}

	import std.algorithm : SwapStrategy, countUntil;
	bool remove(SwapStrategy s = SwapStrategy.stable)(auto ref T value)
	{	
		return remove!(x => x == value, s)();
	}

	bool removeAt(SwapStrategy s = SwapStrategy.stable, T)(size_t index)
	{
		assert(index < list.length); 

		static if(s == SwapStrategy.unstable)
		{
			swap(list[$ - 1], list[index]);
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

	bool remove(alias pred, SwapStrategy s = SwapStrategy.stable)()
	{
		auto index = list.countUntil!(pred);
		if(index == -1) return false;

		static if(s == SwapStrategy.unstable)
		{
			swap(list[$ - 1], list[index]);
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

	//Range interface
	List!T save() { return this; }
	T front() { return *buffer; }
	T back()  { return buffer[length - 1]; }
	bool empty() { return length == 0; }
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
}

unittest
{
	List!int i;
	foreach(j, ref item; i){ }
}


struct CircularList(T)
{
	T* buffer;
	uint start, end, 
		length, capacity;

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