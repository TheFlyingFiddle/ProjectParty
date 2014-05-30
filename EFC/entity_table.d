module entity_table;
import std.traits;

struct TableIndex
{
	ushort index; 
	ushort refcount;
}

//The handle returned from comp collection should have
//a type baked into it. This might seem obvious but apperently it wasnt :) 
//This type is how you identify the system from each other. (IF needed?) 
//The exact method of identification can be 
nothrow @nogc:

template ComponentType(T) if(isInstanceOf!(AOS, T) ||  isInstanceOf!(SOA, T))
{
	static if(is(T t == SOA!U, U))
		alias ComponentType = U;
	else static if(is(T t == AOS!U, U))
		alias ComponentType = U;
	else 
		static assert(0, "Something is wierd");

}

template isComponent(T)
{
	import std.traits;
	enum isComponent = !hasIndirections!T;
}

template componentHash(T)// if(isComponent!T)
{
	import util.hash;
	enum hash = cHash!T;
	enum componentHash = cast(ushort)((hash >> 16 & 0xFFFF_0000) ^ (hash & 0x0000_FFFF));
}

struct SOA(T)
{		
	mixin (genArrays);
	size_t size;

	private static string genArrays()
	{
		import std.conv;
		string s = "";
		foreach(i, field; T.init.tupleof)
			s ~= "typeof(T.tupleof[" ~ i.to!string ~ "])* " ~ T.tupleof[i].stringof ~ ";\n";
		return s;
	}

	this(A)(ref A allocator, size_t size)
	{
		foreach(i, field; T.init.tupleof)
			mixin("this." ~ T.tupleof[i].stringof ~ " = allocator.allocate!(typeof(T.tupleof[i])[])(size).ptr;");
		
		this.size = size;
	}

	T opIndex(size_t index)
	{
		assert(index < size);
		T t;
		foreach(i, field; t.tupleof)
		{
			mixin("t." ~ T.tupleof[i].stringof ~ " = this." ~ T.tupleof[i].stringof ~ "[index];");
		}
		
		return t;
	}

	void opIndexAssign(T value, size_t index)
	{
		assert(index < size);
		foreach(i, field; value.tupleof)
		{
			mixin("this." ~ T.tupleof[i].stringof ~ "[index] = value." ~ T.tupleof[i].stringof ~ ";");
		}
	}
}

struct AOS(T)
{
	T[] items;
	this(A)(ref A allocator, size_t size)
	{
		items = allocator.allocate!(T[])(size);
	}

	ref T opIndex(size_t index)
	{
		return items[index];
	}

	ref T opIndexAssing(T value, size_t index)
	{
		return items[index] = value;
	}
}

struct CompHandle
{
	ushort index, type;
}

struct CompCollection(T) if(isInstanceOf!(AOS, T) ||  isInstanceOf!(SOA, T))
{
	TableIndex*	indecies; 
	ushort*		backref; 
	T				objects;

	ushort firstFree;
	ushort capacity;
	ushort numObjects;

	auto ref opDispatch(string s)()
	{
		return mixin("objects." ~ s);
	}

	this(A)(ref A allocator, ushort size)
	{
		this.indecies  = allocator.allocate!(TableIndex[])(size).ptr; 
		foreach(i; 0 .. size - 1)
			this.indecies[i] = TableIndex(cast(ushort)(i + 1), ushort.max);

		this.backref  = allocator.allocate!(ushort[])(size).ptr;
		this.objects  = T(allocator, size);

		this.firstFree  = 0;
		this.capacity   = size;
		this.numObjects = 0;
	}

	CompHandle create(Args...)(Args args)
	{
		assert(numObjects < capacity);

		TableIndex index = TableIndex(numObjects, 1);
		auto nextFree		= indecies[firstFree].index;
		
		indecies[firstFree]   = index;
		objects[numObjects]   = ComponentType!T(args);
		backref[numObjects++] = firstFree;		

		auto result = firstFree;
		firstFree = nextFree;
		return CompHandle(result, componentHash!(ComponentType!T));
	}

	bool active(CompHandle handle) 
	{	
		assert(handle.type == componentHash!(ComponentType!T));
		return indecies[handle.index].refcount != ushort.max;
	}

	void addRef(CompHandle handle) 
	{
		assert(active(handle));
		indecies[handle.index].refcount--;
	}

	bool removeRef(CompHandle handle)
	{
		assert(active(handle));
		indecies[handle.index].refcount--;
		
		if(indecies[handle.index].refcount == 0) {
			removeObject(handle.index);
			return true;
		}
		return false;
	}

	auto opIndex(CompHandle handle)
	{
		assert(active(handle));
		return objects[handle.index];
	}

	private void removeObject(ushort index) 
	{
		objects[index] = objects[numObjects - 1];
		indecies[backref[numObjects - 1]].index = index;
		backref[index] = backref[numObjects - 1];
		
		if(index < firstFree)
		{
			indecies[index] = TableIndex(firstFree, ushort.max);
			firstFree = index;
		}
		else 
		{
			indecies[index] = TableIndex(indecies[firstFree].index, ushort.max);
			indecies[firstFree].index = index;
		}

		numObjects--;
	}

	void swap(ushort index0, ushort index1)
	{
		import std.algorithm;
	
		auto tmp = objects[index0];
		objects[index0] = objects[index1];
		objects[index1] = tmp;

		indecies[index0].index = index1;
		indecies[index1].index = index0;
		swap(backref[index0], backref[index1]);
	}

	@disable this(this);
}