module event.traits;


public import std.traits;
public import std.typetuple;

template isEvent(T)
{
	static assert(T.stringof[$ - "Event".length .. $] == "Event",
				  "Events must end with the string Event.");
	static assert(is(T == struct), "Events must be structs!");
	static assert(!hasIndirections!T, "Events must be plain old data types!");

	enum isEvent = true;
}

template mapper(alias Lambda) 
{	
	alias mapper = ParameterTypeTuple!Lambda[0];
}

template isEventHandler(alias Lambda)
{
	alias params = ParameterTypeTuple!Lambda;
	static assert(params.length == 1, "Event handles must only take 1 parameter!");
	alias EventType = params[0];
	enum isEventHandler = isEvent!(EventType); 
}

template areEventHandlers(T...)
{
	alias eventTypes = staticMap!(mapper, T);
	static assert(is(eventTypes == NoDuplicates!(eventTypes)),
				  "You can only have one event handler per eventtype");

	static assert(allSatisfy!(isEventHandler, T), 
				  "All event handlers must handle a proper eventtype");

	enum areEventHandlers = true;
}


bool hashCollision(U, T...)() if(isIntegral!U)
{
	import std.algorithm, util.hash;
	U[] hashes = new U[T.length];
	foreach(i,t;T)
	{
		enum thash = typeHash!t;
		if(hashes.find!("a == b")(thash).length != 0) 
			return true;
	}

	return false;
}

template Events(string moduleName)
{
	template filter(string member)
	{
		mixin("alias A = " ~ moduleName ~ "." ~ member ~ ";");
		static if(__traits(compiles, __traits(isPOD, A)) &&
				  __traits(compiles, member[$ - "Event".length  .. $]))
			enum filter = __traits(isPOD, A) && 
				is(A == struct)    &&  
					member[$ - "Event".length  .. $] == "Event"; 
		else 
			enum filter = false;
	}

	template mapper(string item)
	{
		mixin("alias mapper = " ~ moduleName ~ "." ~ item ~ ";");
	}

	alias Events = staticMap!(mapper, 
							  Filter!(filter, 
									  __traits(allMembers, mixin(moduleName))));
}

unittest
{
	static assert(is(Events!("event.traits") == TypeTuple!(AEvent, BEvent, CEvent)));
	static assert(!hashCollision!(short, Events!("event.traits")));
}

version(unittest) {
	struct AEvent { }
	struct BEvent { }
	struct CEvent { }
	struct Bla { }
}