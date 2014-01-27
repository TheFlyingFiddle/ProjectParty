module allocation.gc;

import core.memory;

struct GCAllocator
{
	size_t bytesAllocated;
	size_t numAllocations;


	void[] allocate(size_t bytes, size_t alignment)
	{
		bytesAllocated += bytes;
		numAllocations++;

		size_t aligner = alignment > 8 ? alignment : 8;

		void* allocated = GC.malloc(bytes + aligner);
		size_t addr = cast(size_t)allocated;

		allocated = cast(void*)((cast(size_t)allocated + aligner) & ~(aligner - 1));

		//Store ptr at begining of allocation block.
		size_t* ptr = cast(size_t*)allocated;
		*(--ptr) = addr;

		return allocated[0 .. bytes];
	}	

	void deallocate(void[] memory)
	{
		bytesAllocated -= memory.length;
		numAllocations--;

		size_t* ptr = cast(size_t*)(memory.ptr);
		void* toFree = cast(void*)(*(--ptr));
		GC.free(toFree);
	}


	__gshared static GCAllocator it;

}


