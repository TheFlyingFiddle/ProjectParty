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

T read(T)(ref ubyte[] range) if(isArray!T)
{
	ushort length = range.read!ushort;
	T items = cast(T)range[0 .. length * T.sizeof];
	range = range[length * T.sizeof .. $];
	return items;
}

void write(T)(ubyte[] range, T value, size_t* offset) if(is(T == struct) && !hasIndirections!T)
{
	assert(range.length + *offset >= T.sizeof);

	T* t = cast(T*)(&range[*offset]);
	*t = value;
	*offset += T.sizeof;
}

void write(T)(ubyte[] range, T arr, size_t* offset) if(isArray!T)
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