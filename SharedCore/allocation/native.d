module allocation.native;

public import allocation.common;


version(X86)
{
	struct Mallocator
	{
		import core.stdc.stdlib;

		size_t bytesAllocated;
		size_t numAllocations;

		package void[] allocate_impl(size_t bytes, size_t alignment) @nogc nothrow
		{
			bytesAllocated += bytes;
			numAllocations++;

			size_t aligner = alignment > 8 ? alignment : 8;

			void* allocated = malloc(bytes + aligner);
			void* mp = allocated;
			size_t addr = cast(size_t)allocated;

			allocated = cast(void*)((cast(size_t)allocated + aligner) & ~(aligner - 1));
			
			//Store ptr at begining of allocation block.
			size_t* ptr = cast(size_t*)allocated;
			*(--ptr) = addr;

			//logChnl.info(bytes + aligner," bytes allocated by Mallocator at " , cast(void*)addr);
			return allocated[0 .. bytes];
		}	

		package void deallocate_impl(void[] memory) nothrow @nogc
		{
			bytesAllocated -= memory.length;
			numAllocations--;

			size_t* ptr  = cast(size_t*)(memory.ptr);
			size_t addr  = *(--ptr);
			void* toFree = cast(void*)addr;
			free(toFree);

			//logChnl.info(cast(size_t)memory.ptr - addr + memory.length, " bytes deallocated by Mallocator at ", cast(void*)addr);
		}


		__gshared static Mallocator it;
		__gshared static CAllocator!Mallocator cit;
	}
} 

shared static this()
{
	Mallocator.cit = new CAllocator!Mallocator(Mallocator.it);
}

version(X86_64)
{
	version(Posix) extern(C) int posix_memalign(void**, size_t, size_t);
	version(Windows)
	{
		extern(C) void* _aligned_malloc(size_t,size_t);
		extern(C) void* _aligned_free(void* memblock);
	}

	struct Mallocator
	{
		import core.stdc.stdlib;	
		uint bytesAllocated;
		uint numAllocations;

		version(Posix)
			void[] allocate(size_t bytes, size_t alignment)
			{
				void* result;
				auto error = posix_memalign(&result, alignment, bytes);
				assert(code != ENOMEM);

				bytesAllocated += bytes;
				numAllocations++;

				return result[0 .. bytes];
			}
		else version(Windows) 
			void[] allocate_impl(size_t bytes, size_t alignment)
			{
				auto result  = _aligned_malloc(bytes, alignment);

				bytesAllocated += bytes;
				numAllocations++;

				return result ? result[0 .. bytes] : null;
			}

		version(Posix) 
			void dealocate(void[] data)
			{
				bytesAllocated -= data.length;
				numAllocations--;

				free(data.ptr);
			}
		else version(Windows)
			void deallocate_impl(void[] data)
			{
				bytesAllocated -= data.length;
				numAllocations--;

				_aligned_free(data.ptr);
			}

		__gshared static Mallocator it;
		__gshared static CAllocator!Mallocator cit;
	}
}


struct MallocAppender(T)
{
    T* _buffer;
    uint _capacity;
    uint _offset;

    size_t put(T value)
	{
        if (_offset == _capacity)
            grow();
        _buffer[_offset++] = value;
        return _offset - 1;
	}

    ref T opIndex(size_t index)
	{
        return _buffer[index];
	}

    this(size_t initialCapacity)
	{
        _buffer   = Mallocator.it.allocate!(T[])(initialCapacity).ptr;
        _capacity = cast(uint)initialCapacity;
        _offset = 0;
    }

    void grow()
	{
        auto b = Mallocator.it.allocate!(T[])((_capacity * 2 + 10)).ptr;
        b[0.._capacity] = _buffer[0.._capacity];
        Mallocator.it.deallocate(_buffer[0.._capacity]);
        _capacity = _capacity * 2 + 10;
        _buffer = b;
	}

    import collections.list;
    List!T data()
	{
        return List!T(_buffer[0.._offset]);
	}

	List!T take()
	{
		return List!T(_buffer, _offset, _capacity);
	}
    
    @disable this(this);

    ~this()
	{
        Mallocator.it.deallocate(_buffer[0.._capacity]);
	}
}