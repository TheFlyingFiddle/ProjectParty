module allocation.stack;

import std.traits;
//import logging;
import allocation.region,
	   allocation.common;

struct Finalizer
{
	alias dest_t = void function(void*);

	private dest_t     destructor;
	private Finalizer* chain;

	this(dest_t destructor, Finalizer* chain)
	{
		this.destructor = destructor;
		this.chain      = chain;
	}
}

void destructor(T)(void* ptr)
{
	T* t = cast(T*)ptr;
	t.__dtor();
}

struct ScopeStack
{
	import std.conv;

	RegionAllocator* _allocator;
	Finalizer*       _chain;
	void*            _rewindPoint;

	this(ref RegionAllocator allocator)
	{
		this(&allocator);
	}

	this(RegionAllocator* allocator)
	{
		this._allocator   = allocator;
		this._rewindPoint = allocator._offset;
		this._chain       = null;
	}

	auto allocate(T, Args...)(auto ref Args args) 
		if(hasElaborateDestructor!T && !isArray!T)
	{
		//logChnl.info("Allocated RAII Object: Type = ", T.stringof);

		void[] mem = _allocator.allocateRaw(T.sizeof + Finalizer.sizeof, T.alignof);
		auto fin = emplace!(Finalizer)(mem, &destructor!T, _chain);
		_chain = fin;

		return emplace!(T)(mem[Finalizer.sizeof .. $], args);
	}

	auto allocate(T, Args...)(auto ref Args args) 
		if(!hasElaborateDestructor!T && !isArray!T)
	{
		//logChnl.info("Allocated POD: Type = ", T.stringof);
		return _allocator.allocate!T(args);
	}

	T allocate(T)(size_t size, size_t alignment = 8) if(isArray!T)
	{
		//logChnl.info("Allocated Array: Type = ", T.stringof, " ", size);
		return _allocator.allocate!T(size, alignment);
	}

	void[] allocate(size_t size, size_t alignment)
	{
		//logChnl.info("Allocated Raw: ", size);
		return _allocator.allocateRaw(size, alignment);
	}

	~this()
	{
		for(auto fin = _chain; fin; fin = fin.chain)
		{
			fin.destructor(fin + 1);
		}

		_allocator.rewind(_rewindPoint);
	}

	@disable this(this);
}


unittest 
{
	import allocation;

	static int destructorCalls = 0;
	struct S
	{
		~this()
		{
			destructorCalls++;
		}
	}

	{
		auto a = RegionAllocator(Mallocator.cit, 1024);
		auto stack = ScopeStack(a);
		stack.allocate!S();
	}

	assert(destructorCalls == 1);

	auto b = RegionAllocator(Mallocator.cit, 1024);
	auto stack2 = ScopeStack(b);
}

