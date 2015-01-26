module util.variant;

import util.hash;
import collections.table;

struct VariantN(size_t size)
{
	ubyte[size - TypeHash.sizeof] data;
	TypeHash id;

	this(T)(auto ref T t) if(T.sizeof <= size - TypeHash.sizeof)
	{
		this.id  = cHash!T;
		*cast(T*)(this.data.ptr) = t;
	}

	this(size_t N)(VariantN!(N) value) if(N <= size - TypeHash.sizeof)
	{
		this.id = value.id;
		this.data[0 .. N] = value.data[];
	}

	void opAssign(T)(auto ref T t)
	{
		this.id  = cHash!T;
		*cast(T*)(this.data.ptr) = t; 
	}

	void opAssign(size_t N)(Variant!N other) if(N <= size - TypeHash.sizeof)
	{
		this.data[0 .. N] = other.data[];
		this.id			  = other.id;
	}

	ref T get(T)()
	{
		import std.conv;
		assert(cHash!T == id, text("Wrong typeid id! Expected: ", cHash!T, "Actual: ", id));

		auto ptr = peek!T;
		assert(ptr);
		return *ptr;
	}

	T* peek(T)()
	{
		if(cHash!T == id) return cast(T*)(data.ptr);
		else return null;
	}
}

VariantN!(size) variant(size_t size, T)(T t)
{
	return VariantN!size(t);
}

struct VariantTable(size_t size)
{
	private Table!(HashID, VariantN!size) _rep;
	this(A)(ref A allocator, size_t count)
	{
		_rep = Table!(HashID, VariantN!size)(allocator, count);
	}

	ref VariantN!size opIndex(string name)
	{
		import std.conv;

		auto ptr = bytesHash(name) in _rep;
		assert(ptr, text("Value not present in table! ", name));
		return *ptr;
	}

	ref VariantN!size opIndex(HashID hash)
	{
		import std.conv;
		auto ptr = hash in _rep;
		assert(ptr, text("Hash not present in table! ", hash));
		return *ptr;
	}

	void clear()
	{
		_rep.clear();
	}

	void opIndexAssign(T)(auto ref T value, string name)
	{
		this[bytesHash(name)] = value;
	}	

	void opIndexAssign(T)(auto ref T value, HashID id)
	{
		_rep[id] = VariantN!size(value);
	}

	ref VariantN!size opDispatch(string name)()
	{
		enum id = bytesHash(name);
		return _rep[id];
	}

	void opDispatch(string name, T)(auto ref T t)
	{
		enum id  = bytesHash(name);
		_rep[id] = VariantN!size(t);
	}

	void add(T)(string name, auto ref T t)
	{
		_rep[bytesHash(name)] = VariantN!size(t);
	}


	void add(string name, VariantN!size t)
	{
		_rep[bytesHash(name)] = t;
	}
}

unittest
{
	import allocation;
	VariantTable!(64) variant = VariantTable!(64)(Mallocator.it, 100);
	variant.button = 32;

	auto s = variant.button;
}