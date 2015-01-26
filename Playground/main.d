import std.stdio;

int main(string[] argv)
{
    writeln("Hello D-World!");
    return 0;
}

import std.typetuple;
import util.trats;

alias Tup = TypeTuple;

//Returns true if T implements I
template implements(T, I)
{
}

struct RTTI
{
	string name;
	ubyte  size; 
	ubyte  alignment; //ETC;
}

struct Optional
{
	//Optional
}

//Include Equals amd ToString
//Class implementation with virtual dispatch etc.
struct DynType(I) 
{
	enum maxTypes = ubyte.max; //Default to 256 diffrent implementations.

	alias M = Methods!I; 
	enum numMethod = M.length + 4;
	static void*[maxTypes * M.length] functions;
	
	//Hash of fully qualified name
	static uint[maxTypes] typeHash;
	static uint typeCount;
	
	//Would like to do this statically but don't think that it's
	//Possible.

	static ubyte registerTypes(T...)
	{
		foreach(t; T) registerType!t;
	}

	static ubyte registerType(T)() if(implements!(T, I))
	{
		auto idx = typeCount * numMethod;
		functions[idx++] = cast(void*)&eq0!T;
		functions[idx++] = cast(void*)&eq1!T;
		functions[idx++] = cast(void*)&toStr!T;
		functions[idx++] = cast(void*)&genRTTI!T;

		T dummy;
		foreach(m; M)
		{
			functions[idx++] = cast(void*)(&dummy).funcptr;
		}

		typeHash[typeCount++] = cHash!T.value;
	}

	static bool eq0(T)(ref DynType!(I) first, ref DynType!(I) second)
	{
		if(first.typeIndex == second.typeIndex)
		{
			auto f = cast(T*)first;
			auto s = cast(T*)second;
			return *f == *s;
		}

		return false;
	}
    
	static bool eq1(T)(ref DynType!(I) self, ref T t)
	{
		return (cast(T)self) == t;
	}

	static void toStr(T)(ref DynType!(I) self,  scope void delegate(const(char)[]) sink) const {
		auto t = cast(T*)self;

		import util.strings;
		static if(__traits(compiles, () => t.toString(sink)))
			t.toString(sink);
		else
			sink(text1024(t));
	}

	static RTTI genRTTI(T)()
	{
		enum data = RTTI(T.stringof, T.sizeof, T.alignof);
		return data;
	}

	void[N - 1] data;
	ubyte typeIndex;

	//We should create a casting operator.
	//Or rather two casting operators.
	T* opCast(T:T*)() if(implements!(T, I))
	{
		ubyte typeIndex = getTypeIndex!T;
		assert(typeIndex == this.typeIndex); //Safe cast.

		return cast(T*)data.ptr;
	}

	ref T opCast(T)()     if(implements!(T,I))
	{
		return *opCast!(T*);
	}

	bool opEquals(ref DynType!(I) other)
	{
		alias fun = bool function(ref DynType!(I,N), ref DynType!(I,N));
		auto f = cast(fun)functions[self.typeIndex * numMethods + 0];
		return f(this, other);
	}

	bool opEquals(T)(ref T other)
	{
		auto tIndex = getTypeIndex!T;
		if(tIndex != this.typeIndex) return false;

		alias fun = bool function(ref DynType!(I,N), ref T);
		auto f = cast(fun)functions[self.typeIndex * numMethods + 0];
		return f(this, other);
	}

	void toString(scope void delegate(const(char)[]) sink) const
	{
		alias fun = bool function(ref DynType!(I,N), scope void delegate(const(char)[]));
		auto f = cast(fun)functions[self.typeIndex * numMethods + 2];
		return f(this, other);
	}

	auto ref opDispatch(string s, Args...)(Args ...)
	{
		static assert(validMethod!(s, Args), "Not a method of Interface " ~ I.stringof);
		
		

	}

	//Case 0 implement using opDispatch.
	//Case 1 implement using string mixin.
}

mixin template RegisterDynTypes(I)
{
	private alias C = DynType!(I);
	private alias types = Structs!(__MODULE__); //Filter on implementing.
	shared static this()
	{
		C.registerTypes!(types);
	}
}