module allocation.gc;

import core.memory;

struct GCAllocator
{
    __gshared static GCAllocator it;

    void[] allocate(size_t size, size_t alignment)
	{
		assert(alignment <= 8);
		return GC.malloc(size)[0..size];
	}

	void deallocate(void[] arr)
	{
		GC.free(arr.ptr);
	}

}


