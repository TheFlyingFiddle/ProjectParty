module allocation.gc;

import core.memory;
import allocation.common;

struct GCAllocator
{
	size_t bytesAllocated;
	size_t numAllocations;

	package void[] allocate_impl(size_t bytes, size_t alignment)
	{
		bytesAllocated += bytes;
		numAllocations++;

		size_t aligner = alignment > 8 ? alignment : 8;

		void* allocated = GC.malloc(bytes + aligner);
		void* mp = allocated;
		size_t addr = cast(size_t)allocated;

		allocated = cast(void*)((cast(size_t)allocated + aligner) & ~(aligner - 1));

		//Store ptr at begining of allocation block.
		size_t* ptr = cast(size_t*)allocated;
		*(--ptr) = addr;

		logChnl.info(bytes + aligner," bytes allocated by GCAllocator at " , cast(void*)addr);
		return allocated[0 .. bytes];
	}	

	package void deallocate_impl(void[] memory)
	{
		bytesAllocated -= memory.length;
		numAllocations--;

		size_t* ptr  = cast(size_t*)(memory.ptr);
		size_t addr  = *(--ptr);
		void* toFree = cast(void*)addr;
		GC.free(toFree);

		logChnl.info(cast(size_t)memory.ptr - addr + memory.length, " bytes deallocated by GCAllocator at ", cast(void*)addr);
	}

	__gshared static GCAllocator it;
	__gshared static CAllocator!GCAllocator cit;
}

shared static this()
{
	GCAllocator.cit = new CAllocator!GCAllocator(GCAllocator.it);
}