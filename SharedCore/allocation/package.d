module allocation;

public import allocation.native;
public import allocation.region;
public import allocation.stack;
public import allocation.common;
public import allocation.freelist;

__gshared static Mallocator GlobalAllocator;

private static RegionAllocator p_scratch_alloc;
RegionAllocator* scratch_alloc()
{
	return &p_scratch_alloc;
}

void initializeScratchSpace(A)(ref A allocator, size_t spaceSize)
{
	auto mem = allocator.allocateRaw(spaceSize, 64);
	p_scratch_alloc = RegionAllocator(mem);
}