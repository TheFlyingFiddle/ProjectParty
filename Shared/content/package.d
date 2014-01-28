module content;

public import content.sdl;
public import content.texture;
public import content.reloading;
public import content.font;




string resourceDir = "..\\resources";

import logging;
auto logChnl = LogChannel("RESOURCE");

struct ResourceTable(Resource, alias obliterator)
{
	import util.hash, std.algorithm;
	enum noResource = 0x0;

	private Resource[] resources;
	private uint[]     ids;

	this(A)(ref A allocator, size_t capacity)
	{
		this.resources = allocator.allocate!(Resource[])(capacity);
		this.ids       = allocator.allocate!(uint[])(capacity);
		this.ids[]     = noResource;
	}

	uint add(Resource resource, const(char)[] path)
	{	
		auto id = bytesHash(path.ptr, path.length);

		auto index = ids.countUntil!(x => x == id);
		if(index != -1) return cast(uint)index;

		ContentReloader.registerResource(path);

		index = ids.countUntil!(x => x == noResource);
		assert(index != -1, "Out of space for resources!");

		resources[index] = resource;
		ids[index]       = id;
		return cast(uint)index;
	}

	bool remove(const(char)[] path)
	{
		auto id = bytesHash(path.ptr, path.length);
		auto index = ids.countUntil!(x => x == id);	
		if(index == -1) 
		{
			logChnl.warn("Trying to unload a resource that is not loaded! " ~ path);
			return false;
		}

		ContentReloader.unregisterResource(path);
		obliterator(resources[index]);
		resources[index] = Resource.init;
		ids[index]		 = noResource;
		return true;
	}

	uint replace(Resource resource, const(char)[] path)
	{
		auto id    = bytesHash(path.ptr, path.length);
		auto index = ids.countUntil!(x => x == id);
		if(index == -1) {
			return cast(uint)index;
		}

		obliterator(resources[index]);
		resources[index] = resource;
		return cast(uint)index;
	}

	uint indexOf(const(char)[] path)
	{
		auto id = bytesHash(path.ptr, path.length);
		return cast(uint)ids.countUntil!(x => x == id);
	}

	ref Resource opIndex(uint index)
	{
		return resources[index];
	}
}