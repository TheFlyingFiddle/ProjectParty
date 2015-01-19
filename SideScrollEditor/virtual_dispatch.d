module virtual_dispatch;

import util.traits;
import util.hash;
import collections.list;
import collections.table;

//Tag struct
struct Optional { }

struct DispatchData(size_t N)
{
	void[N - 1] data;
	ubyte		vtableIndex;	
}

//Should preffarably be created
//Statically but not sure how to!
struct Dispatcher(Interface, size_t N)
{
	enum maxFunctions = Methods!(Interface).length;

	template isDispatchable(T)
	{
		enum isDispatchable = T.sizeof <= N - 1;
	}

	template isOptional(alias method)
	{
		enum isOptional = exists!(Optional, __traits(getAttributes, method));
	}

	private List!(void*) vtable;
	private Table!(uint, ubyte) vtableLookup;

	this(A)(ref A all)
	{
		vtable       = List!(void*)(all, maxFunctions * 256);
		vtableLookup = Table!(uint, ubyte)(all, 256);
	}

	DispatchData!N data(T)(ref T t) if(isDispatchable!T)
	{
		auto thash = cHash!T;
		auto indexPtr = thash.value in vtableLookup;
		ubyte index;
		if(indexPtr is null)
		{
			index = addMethods!T(t);
		}
		else 
		{
			index = *indexPtr;
		}

		DispatchData!(N) data;
		data.vtableIndex = index;
		import std.c.string;
		memcpy(data.data.ptr, &t, T.sizeof);
		return data;
	}

	ubyte addMethods(T)(ref T t)
	{
		ubyte idx = cast(ubyte)(vtable.length / maxFunctions);
		vtableLookup[cHash!(T).value] = idx;

		alias methods = Methods!(Interface);
		foreach(method; methods)
		{
			enum id = Identifier!method;
			static if(isOptional!method)
			{
				static if(hasMember!(T, id))
					mixin("vtable ~= cast(void*)(&t." ~ id ~ ").funcptr;");
				else 
					vtable ~= cast(void*)null;
			}
			else 
			{
				mixin("vtable ~= cast(void*)(&t." ~ id ~ ").funcptr;");
			}
		}
		
		return idx;
	}

	auto ref dispatch(R, Args...)(ref DispatchData!N data, int functionIndex, Args args)
	{
		auto ptr = vtable[data.vtableIndex  * maxFunctions  + functionIndex];	
		if(ptr !is null)
		{
			alias del = R delegate(Args);
		
			del d;
			d.ptr	  = data.data.ptr;
			d.funcptr = cast(R function(Args))(ptr);
			return d(args);
		}
		else 
		{
			//Was an optional method do nothing!
		}
	}

	template methodIndex(string name)
	{
		template isName(T...)
		{
			enum id = Identifier!T;
			enum isName = id == name;
		}
		
		enum methodIndex = staticIndexOf!(true, staticMap!(isName, Methods!Interface));
	}

	auto ref send(string s, Args...)(ref DispatchData!N data, 
									 Args args)
	{
		enum idx = methodIndex!s;
		static assert(idx != -1, "Failed to find method " ~ s);

		import std.traits;
		alias R = ReturnType!((Methods!Interface)[idx]);
		return dispatch!(R, Args)(data, idx, args);
	}
}

struct ClassN(Interface, size_t N)
{
	__gshared static ClassHelper!(Interface, N) helper;

	void[N - 1] data;
	ubyte		type;

	this(T, Args...)(Args a) if(implementsI!T)
	{
		emplace!(T)(cast(T*)(v.data.ptr), a);
		type = helper.typeID!T;

	}

	this(T)(ref T t) if(implementsI!T)
	{
		import std.c.string;
		*cast(T*)(data.ptr) = t;
		type = helper.typeID!T;
	}

	auto ref opDispatch(string s, Args...)(Args args)
	{
		return call!(s, Args)(args);
	}	

	auto ref call(string s, Args...)(Args args)
	{
		return helper.call!(s, Args)(this, args);
	}

	T* opCast(T)() if(implementsI!(T))
	{
		assert(helper.typeID!T == type);
		return cast(T*)data.ptr;
	}
	
	template implementsI(T)
	{
		enum implementsI = T.sizeof <= N - 1;
	}

}

struct ClassHelper(Interface, size_t N)
{
	alias Class = ClassN!(Interface, N);
	enum maxFunctions = Methods!(Interface).length;
	
	private void*[ubyte.max * maxFunctions]    vtable;
	private TypeHash[ubyte.max] types;
	private ubyte typeCount;

	ubyte typeID(T)() if(T.sizeof <= N - 1)
	{
		enum thash = cHash!T;
		import std.algorithm;
		auto index = types[0 .. typeCount].countUntil!(x => x == thash);
		if(index == -1)
		{
			assert(typeCount < ubyte.max, "Failed to crete new type!");
			index = setupType!T();
		}


		return cast(ubyte)index;
	}

	template isOptional(alias method)
	{
		enum isOptional = exists!(Optional, __traits(getAttributes, method));
	}

	ubyte setupType(T)()
	{
		T t = T.init;
		
		types[typeCount] = cHash!T;
		alias methods = Methods!(Interface);
		auto index = typeCount * maxFunctions;
		foreach(i, method; methods)
		{

			enum id = Identifier!method;
			static if(isOptional!method)
			{
				static if(hasMember!(T, id))
					mixin("vtable[index + i] = cast(void*)(&t." ~ id ~ ").funcptr;");
				else 
					vtable[index + i] = cast(void*)null;
			}
			else 
			{
				mixin("vtable[index + i] = cast(void*)(&t." ~ id ~ ").funcptr;");
			}
		}

		return typeCount++;
	}

	template methodIndex(string name)
	{
		template isName(T...)
		{
			enum id = Identifier!T;
			enum isName = id == name;
		}

		enum methodIndex = staticIndexOf!(true, staticMap!(isName, Methods!Interface));
	}

	auto ref opDispatch(string s, Args...)(ref Virtual v, Args args)
	{
		call!(s, Args)(v, args);
	}

	auto ref call(string s, Args...)(ref Class data, Args args)
	{
		enum idx = methodIndex!s;
		static assert(idx != -1, "Failed to find method " ~ s);

		import std.traits;
		alias R = ReturnType!((Methods!Interface)[idx]);
		return dispatch!(R, Args)(data, idx, args);
	}

	auto ref dispatch(R, Args...)(ref Class data, int functionIndex, Args args)
	{
		auto ptr = vtable[data.type  * maxFunctions  + functionIndex];	
		if(ptr !is null)
		{
			alias del = R delegate(Args);

			del d;
			d.ptr	  = data.data.ptr;
			d.funcptr = cast(R function(Args))(ptr);
			return d(args);
		}
		else 
		{
			//Was an optional method do nothing!
		}
	}
}