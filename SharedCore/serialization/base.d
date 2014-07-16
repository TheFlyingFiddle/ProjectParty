module serialization.base;

import util.bitmanip;
import std.traits;


ubyte[] basicSerialize(T)(ref ubyte[] sink, auto ref T t)
{
	size_t offset = 0;
	foreach(i, field; t.tupleof)
	{
		sink.write(t.tupleof[i], &offset);
	}

	return sink[0 .. offset];
}

ubyte[] serializeAllocate(A, T)(ref A allocator, auto ref T t)
{
	import allocation;
	ubyte[0xFFFF] buffer = void; ubyte[] buf = buffer[];
	auto tmp = basicSerialize(buf, t);
	auto data = allocator.allocate!(ubyte[])(tmp.length);
	data[] = tmp[];
	return data;
}