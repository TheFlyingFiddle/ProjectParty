module serialization.base;

import util.bitmanip;
import std.traits;


ubyte[] basicSerialize(T)(ref ubyte[] sink, auto ref T t)
{
	size_t offset = 0;
	foreach(i, field; t.tupleof)
	{
		sink.write(field, &offset);
	}

	return sink[0 .. offset];
}

ubyte[] serializeAllocate(A)(ref A allocator, auto ref T t)
{
	ubyte[0xFFFF] buffer = void;
	auto tmp = basicSerialize(buffer[], t);
	auto data = allocator.allocate!(ubyte[])(tmp.length);
	data[] = tmp[];
	return data;
}