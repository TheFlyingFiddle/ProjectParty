module allocation.stack;

import std.traits;
import logging;
import allocation.region,
	   allocation : logChnl;

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

	T* allocate(T, Args...)(ref auto Args args) 
		if(hasElaborateDestructor!T && !isArray!T)
		{
			logChnl.info("Allocated RAII Object: Type = ", T.stringof);

			void[] mem = _allocator.allocate(T.sizeof + Finalizer.sizeof, T.alignof);
			auto obj = emplace!(T)(mem[Finalizer.sizeof .. $], args);
			auto fin = emplace!(Finalizer)(mem, &destructor!T, _chain);
			_chain = fin;
			return obj;
		}

	auto allocate(T, Args...)(ref auto Args args) 
		if(!hasElaborateDestructor!T && !isArray!T)
		{
			logChnl.info("Allocated POD: Type = ", T.stringof);

			static if(is(T == class))
				void[] mem = _allocator.allocate(__traits(classInstanceSize, T), T.alignof);
			else 
				void[] mem = _allocator.allocate(T.sizeof, T.alignof);

			auto obj = emplace!(T)(mem, args);
			return obj;
		}

	T allocate(T)(size_t size) if(isArray!T)
	{
		import std.range;
		alias E = ElementType!T;
		logChnl.info("Array: Type ", E.stringof, " Count = ", size);

		void[] mem = _allocator.allocate(E.sizeof * size, E.alignof);

		E* e = cast(E*)mem.ptr;
		return e[0 .. size];
	}

	void[] allocate(size_t size, size_t alignment)
	{
		return _allocator.allocate(size, alignment);
	}

	~this()
	{
		for(auto fin = _chain; fin; fin = fin.chain)
		{
			fin.destructor(fin + Finalizer.sizeof);
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
		auto a = RegionAllocator(Mallocator.it, 1024);
		auto stack = ScopeStack(a);
		stack.allocate!S();
	}

	assert(destructorCalls == 1);

	auto b = RegionAllocator(Mallocator.it, 1024);
	auto stack2 = ScopeStack(b);
}

