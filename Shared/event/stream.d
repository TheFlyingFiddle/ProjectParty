module event.stream;

import event.traits;
import std.exception;
import util.hash;
import std.conv : to;
import collections;
import logging;

auto chan = LogChannel("Event Stream");

struct EventStreamN(Integer) if(isIntegral!Integer)
{
	enum alignment = Integer.sizeof * 2;
	Blob blob;

	this(Allocator)(ref Allocator allocator, size_t size)
	{
		blob = Blob(allocator, size);
	}

	void push(T)(T item) if(isEvent!T)
	{
		static assert(alignment >= T.alignof);
		enum typeID = typeHash!T % (Integer.max);
		enum alignedOffset = (T.sizeof + alignment - 1) & ~(alignment - 1);

		blob.put!Integer(typeID);
		blob.put!Integer(alignedOffset);
		blob.putAligned!(T, alignment)(item);

		chan.info(cast(uint[])blob.buffer[0 .. 20]);
	}

	void clear()
	{
		blob.clear();
	}

	@disable this(this);
}

EventRange!(T, Integer) over(T, Integer)(ref EventStreamN!(Integer) stream) if(isEvent!T , isIntegral!Integer)
{
	return EventRange!(T, Integer)(stream);
}

EventRange!(Integer) all(Integer)(ref EventStreamN!(Integer) stream) if(isIntegral!(Integer))
{
	return EventRange!(Integer)(stream);
}

struct EventRange(T, Integer)
{	
	Blob blob;
	T front;
	bool empty = false;

	this(ref EventStreamN!(Integer) stream)
	{
		blob = stream.blob;
		popFront();
	}

	void popFront()
	{
		bool noEvent = true;
		while(!blob.empty)
		{
			auto id  = blob.read!Integer;
			auto len = blob.read!Integer;
			if(id == typeHash!(T)) {
				front = blob.readAligned!(T, EventStreamN!(Integer).alignment)();		
				noEvent = false;
				break;
			}
			blob.skip(len);
		}

		this.empty = noEvent;
	}	
}

struct EventRange(Integer) 
{
	Blob blob;
	Event!Integer front;
	bool empty = false;

	this(ref EventStreamN!(Integer) stream)
	{
		this.blob = stream.blob;
		this.popFront();
	}	

	void popFront()
	{
		if(blob.empty) 
		{
			empty = true;
			return;
		}

		auto id   = blob.read!Integer;
		auto len  = blob.read!Integer;
		auto data = blob.readBytes(len).ptr;
		front = Event!(Integer)(data, id, len);
	}
}

struct Event(Integer)
{	
	void* data;
	Integer id;
	Integer length;
}


version(unittest)
{
	import allocation;
}


unittest
{
	alias stream = EventStreamN!(ushort);
	auto linAlloc   = RegionAllocator(Mallocator.it, 1024);
	auto scopeStack = ScopeStack(linAlloc); 
	stream s = stream(scopeStack, 512);

	auto r   = s.over!InputEvent;
	auto r2  = s.all();
}

unittest
{
	import event.stream;
	alias stream = EventStreamN!(ushort);

	auto linAlloc   = RegionAllocator(Mallocator.it, 1024, 8);
	auto scopeStack = ScopeStack(linAlloc); 
	stream s = stream(scopeStack, 512);


	s.push(InputEvent());
	s.push(InputEvent());
	s.push(DoodleEvent());

	size_t inputCount  = 0;
	size_t doodleCount = 0;

	EventLoop!((InputEvent e) 
			   {
				   inputCount++;
			   },	
			   (DoodleEvent e)
			   {
				   doodleCount++;
			   }
			   )(s);

	assert(inputCount == 2);
	assert(doodleCount == 1);
}

version(unittest)
{
	struct InputEvent { }
	struct DoodleEvent { }
}

void EventLoop(T...)(ref EventStreamN!(ubyte) stream) 
if(areEventHandlers!T)
{
	EventLoop_Impl!(ubyte, T)(stream);
}

void EventLoop(T...)(ref EventStreamN!(ushort) stream) 
if(areEventHandlers!T)
{
	EventLoop_Impl!(ushort, T)(stream);
}

void EventLoop(T...)(ref EventStreamN!(uint) stream) 
if(areEventHandlers!T)
{
	EventLoop_Impl!(uint, T)(stream);
}

void EventLoop(T...)(ref EventStreamN!(ulong) stream) 
if(areEventHandlers!T)
{
	EventLoop_Impl!(ulong, T)(stream);
}

private void EventLoop_Impl(Integer, T...)(ref EventStreamN!(Integer) stream) 
if(areEventHandlers!T)
{
	mixin(imports!T);
	foreach(e; stream.all)
	{
		switch(e.id)
		{
			mixin(cases!(Integer,T));
			default:
				break;
		}
	}
}

template imports(T...)
{
	static if(T.length == 0)
		enum imports = "";
	else {
		alias ElementType = ParameterTypeTuple!(T[0])[0];
		enum imports = "import " ~ moduleName!(ElementType) ~ ";" 
			~   imports!(T[1 .. $]);
	}
}

string cases(Integer, T...)() 
{
	string s;
	foreach(i, t; T)
	{
		alias EventType = ParameterTypeTuple!(t)[0];
		s ~= "case " ~ (typeHash!EventType % Integer.max).to!string ~ ":
			auto evnt = cast(" ~ EventType.stringof ~ "*)e.data;
			T[" ~ i.to!string ~ "](*evnt);
			break;\n";
	}

	return s;
}
