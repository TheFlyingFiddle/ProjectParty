module util.bitmanip;


import std.bitmanip, std.system, std.traits;

//Special version for reading structs from ranges.
T read(T)(ref ubyte[] range) if(is(T == struct) && !hasIndirections!T)
{
	assert(range.length >= T.sizeof);
	T* t = cast(T*)range.ptr;
	range = range[T.sizeof .. $];
	return *t;
}

void write(T)(ubyte[] range, T value, size_t* offset) if(is(T == struct) && !hasIndirections!T)
{
	assert(range.length + *offset >= T.sizeof);

	T* t = cast(T*)(&range[*offset]);
	*t = value;
	*offset += T.sizeof;
}

void write(R,T)(ref R range, T arr, size_t* offset) if(isArray!T)
{
	range.write!ushort(cast(ushort)arr.length, offset);
	foreach(elem; arr)
		range.write(elem, offset);
}

T read(T, R)(ref R range) if(isNumeric!T || isSomeChar!T)
{
	return std.bitmanip.read!(T, Endian.littleEndian, R)(range);
}

void write(T, R)(R range, T value, size_t offset) if(isNumeric!T || isSomeChar!T)
{
	std.bitmanip.write!(T, Endian.littleEndian, R)(range, value, offset);
}

void write(T, R)(R range, T value, size_t* offset) if(isNumeric!T || isSomeChar!T)
{
	std.bitmanip.write!(T, Endian.littleEndian, R)(range, value, offset);
}