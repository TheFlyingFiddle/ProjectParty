module content.sdl;

import std.exception;
import std.conv : to;
import std.traits;
import std.bitmanip;
import std.file;
import std.c.string :memcpy;
import std.string;
import std.range : repeat;
import collections.list;
import allocation;
import math.traits, math.vector;
import graphics.color;

alias TypeID = SDLObject.Type;

enum stringSeperator	= '|';
enum arrayOpener 		= '[';
enum arrayCloser 		= ']';
enum arraySeparator 	= ',';
enum objectOpener 		= '{';
enum objectCloser 		= '}';

private enum int nameIndexNumBits	= 23;
private enum int objectIndexNumBits = 23;
private enum int typeNumBits		= 2;
private enum int nextIndexNumBits	= 16;

private enum int noNameValue = (1<<nameIndexNumBits) - 1;

struct SDLObject
{
    enum Type { _float, _string, _int, _parent}
    mixin(bitfields!(
                     uint,  "nameIndex",    nameIndexNumBits,
                     uint,  "objectIndex",  objectIndexNumBits,
                     Type,  "type",         typeNumBits,
                     ushort, "nextIndex",   nextIndexNumBits
                         ));

	bool hasName()
	{
		return this.nameIndex != noNameValue;
	}

    string toString()
	{
        import std.conv : text;
        return text("name: ", nameIndex, 
					"\tobj: ", objectIndex, 
					"\ttype: ", type, 
					"\tnext: ", nextIndex, "\n");
	}
}

// Used as an attribute in structs to specify that the attribute
// is not necessary to specify in the config file.
OptionalStruct!T Optional(T)(T val)
{
	return OptionalStruct!T(val);
}

struct OptionalStruct(T)
{
	alias T defaultType;
	T defaultValue;
	this(T)(T t) { defaultValue = t; }
}

template Convert(alias F)
{
	alias args =  ParameterTypeTuple!F;
	static if(args.length == 1)
		enum Convert = ConvertStruct!(ReturnType!F, ParameterTypeTuple!F)(&F);
	else static if(args.lenght == 2)
		enum Convert = ContextConvertStruct!(ReturnType!F, ParameterTypeTuple!F)(&F);
	else 
		static assert(0, "Invalid Convert Method!");
}

struct ContextConvertStruct(R, T, C)
{
	alias argType = T;
	alias returnType = R;
	alias context	 = C;

	R function(T, C) convert;

	this(R function(T, C) converter)
	{
		this.convert = converter;
	}
}

struct ConvertStruct(R, T)
{
	alias argType = T;
	alias returnType = R;

	R function(T) convert;

	this(R function(T) converter)
	{
		this.convert = converter;
	}
}

struct PostModify(T, A)
{
	alias argType = T;
	void function(ref A, ref T) modify;
	this(void function(ref A,ref T) modify)
	{
		this.modify = modify;
	}
}


struct SDLContext
{
	bool canRead(T)() { return false; }
	T read(T, C)(SDLIterator!(C)* iterator) 
	{
		static assert(0, "Should not be instantiated!"); 
	}

	void write(T, Sink)(ref T val, ref Sink s, int level)
	{
		static assert(0, "Should not be instantiated!");
	}

}
__gshared SDLContext default_context;


struct SDLIterator(C)
{
	C* context;
    SDLContainer* over;
    ushort currentIndex;

    ref SDLIterator opDispatch(string name)()
	{
        goToChild!name;
        return this;
	}
	/**
    //I kind of wanted to do this, but it seems to be impossible.
    T opDispatch(string name, T)()
	{
		goToChild!name;
		return over.root[currentIndex].as!T;
	}
	*/  

	@property 
		ref IAllocator allocator() { return over.allocator; }

    @property
		bool empty() {
			return !over.root[currentIndex].nextIndex;
		}

	@property
		bool hasChildren() {
			return cast(bool) over.root[currentIndex].objectIndex;
		}

    @property
		size_t walkLength() {
			if(!hasChildren)
				return 0;
			ushort savedIndex = currentIndex;
			goToChild();
			size_t size = 1;
			while(!empty) {
				size++;
				goToNext();
			}
			currentIndex = savedIndex;
			return size;
		}

    private enum curObjObjRange  =	"ForwardRange(over.root[currentIndex].objectIndex,"
		~	"over.source)";
	private enum curObjNameRange =	"ForwardRange(over.root[currentIndex].nameIndex,"
		~	"over.source)";

	string readName()
	{
		assert(current.hasName, "Attempt to read name of nameless object!\n"~getSDLIterError);
		auto range = mixin(curObjNameRange);
		return readIdentifier(range);
	}

	float readFloat()
	{
		assert(SDLObject.Type._float == current.type, getSDLIterError);
		auto range = mixin(curObjObjRange);
		return readNumber!float(range);
	}

	int readInt()
	{
		assert(SDLObject.Type._int == current.type, getSDLIterError);
		auto range = mixin(curObjObjRange);
		return readNumber!int(range);
	}

	string readString()
	{
		assert(SDLObject.Type._string == current.type, getSDLIterError);
		auto range = mixin(curObjObjRange);
		return .readString(range);
	}

	string getSDLIterError()
	{
		auto range = mixin(curObjNameRange);
		return "Error in object "~readIdentifier(range)~" at index "~to!string(currentIndex);
	}

    void goToChild(string name = "")()
	{
        auto range = mixin(curObjObjRange);
        auto obj = over.root[currentIndex];//Get current object, if it doesn't exist, tough luck.
        enforce(obj.type == TypeID._parent, "Tried to get children of non-parent object "
				~range.readIdentifier~ 
				" of typeID "~std.conv.to!string(obj.type)~".");
        currentIndex = cast(ushort)obj.objectIndex;
        static if (name != "")
            goToNext!name;
	}

    void goToNext(string name)()
	{
        auto range = mixin(curObjObjRange);
		SDLObject obj;
        while(currentIndex)//An index of zero is analogous to null.
		{ 
            obj = over.root[currentIndex];
            range.position = cast(size_t)obj.nameIndex;

            if(range.readIdentifier == name) {
                return;
			}
			currentIndex = cast(ushort)obj.nextIndex;
		} 
		auto nameRange = ForwardRange(cast(size_t)obj.nameIndex, this.over.source);
        throw new ObjectNotFoundException("Couldn't find object " ~ name ~ "\n" ~
										  "Search terminated on object " ~ 
										  readIdentifier(nameRange)
										  );
	}

	class ObjectNotFoundException : Exception
	{
		this(string msg) { super(msg); }
	}

	bool hasNext()
	{
        SDLObject obj = over.root[currentIndex];
        auto next = cast(ushort)obj.nextIndex;
		return next != 0;
	}

    void goToNext()
	{
        SDLObject obj = over.root[currentIndex];
        auto next = cast(ushort)obj.nextIndex;
        if(!next)
            enforce(0, getSDLIterError() ~ "\n" ~ "Object had no next! Index out of bounds.");
        currentIndex = next;
	}

	T as_impl(T)() if(isVector!T)
	{
		static if(is(T v == Vector!(len, U), int len, U))
		{
			goToChild();
			enum dimensions = ["x","y","z","w"]; // This is at the same time the vector rep and the file rep. Change.
			auto toReturn = T();
			foreach(i; math.vector.staticIota!(0, len)) 
			{  
				//  Can only traverse the tree downwards
				//  So we need to save this index to not
				//  get lost.
				auto firstIndex = currentIndex;
		        goToNext!(dimensions[i]);
	            auto range = ForwardRange(over.root[currentIndex].objectIndex, over.source);
	            toReturn.data[i] = readNumber!U(range);

				// We want to search the whole object for every name.
				currentIndex = firstIndex;
			}

			return toReturn;
		}
		else 
		{
			static assert("Vector sdl code is wrong!");
		}
	}

	T as_impl(T)() if(isNumeric!T && !is(T==enum))
	{
        static if(isIntegral!T)
			enforce(over.root[currentIndex].type == TypeID._int,
					getSDLIterError() ~ "\n" ~
					"SDLObject wasn't an integer, which was requested.");
        else static if(isFloatingPoint!T)
			enforce(over.root[currentIndex].type == TypeID._float ||
					over.root[currentIndex].type == TypeID._int,
					getSDLIterError() ~ "\n" ~
					"SDLObject wasn't a floating point value, " ~
					"which was requested.");
        auto range = mixin(curObjObjRange);
        if(over.root[currentIndex].type == TypeID._int)
            return cast(T)readNumber!long(range);
        else
            return cast(T)readNumber!double(range);
	}

	T as_impl(T)() if(is(T==bool))
	{
		assert(over.root[currentIndex].type == TypeID._string,
				getSDLIterError() ~ "\n" ~
	 			"SDLObject wasn't a boolean, which was requested");
		auto range = mixin(curObjObjRange);
		return readBool(range);
	}

    T as_impl(T)() if(isSomeString!T)
	{
        assert(over.root[currentIndex].type == TypeID._string);

        auto range = mixin(curObjObjRange);
        string str = .readString!T(range);
        char[] s = allocator.allocate!(char[])(str.length);
        s[] = str;
        return cast(T)s;
	}

    T as_impl(T)() if(isArray!T && !isSomeString!T)
    {
        static if(is(T t == A[], A)) {
            auto arr = allocator.allocate!T(walkLength);
            goToChild();

            foreach(ref elem; arr) {
                auto obj = over.root[currentIndex]; //  Can only traverse the tree downwards
                auto next = obj.nextIndex;          //  So we need to save this index to not
													//  get lost.
				elem = as!A;
				currentIndex = next;
			}
            return arr;
		} else {
            static assert(0, T.stringof ~ " is not an array type!");
		}
	}

	//TODO: Code duplication (see above) iteration might be refactored into an opApply?
	T as_impl(T)() if(is(T t == List!U, U))
	{
        static if(is(T t == List!U, U)) {
			auto listLength = walkLength;
			auto list = T(allocator, listLength);
			goToChild();

			foreach(i; 0 .. listLength) {
				auto obj = over.root[currentIndex];
				auto next = obj.nextIndex;
				list.put = as!U;
				currentIndex = next;
			}
			return list;
		} else {
			static assert(0, T.stringof ~ " is not a List type!");
		}
	}

	T as_impl(T)() if (is(T == enum))
	{
		assert(over.root[currentIndex].type == TypeID._string,
					 getSDLIterError() ~ "\n" ~
					 "SDLObject wasn't an enum, which was requested");
		auto range = mixin(curObjObjRange);

		string name = range.readIdentifier;
		
		foreach(member; EnumMembers!T) {
			//TODO: Allocates :(
			if(member.to!string == name)
				return member;
		}
		assert(0, getSDLIterError() ~ "\n" ~ 
			   name ~ " is not a valid value of enum type " ~ T.stringof);
	}

	T as_impl(T)() if(is(T == Color))
	{
		return Color(as_impl!(uint)());
	}

	private template memberName(string fullName)
	{
		import std.string;
		enum index = lastIndexOf(fullName, '.');
		static if (index == -1)
			enum memberName = fullName;
		else
			enum memberName = fullName[index+1..$];
	}

	T as_impl(T : void*)() { return null; }
	T as_impl(T)()
	{
		auto a = allocator;

		goToChild();
		T toReturn;
        foreach(i, dummy; toReturn.tupleof) 
		{
			enum member = memberName!(toReturn.tupleof[i].stringof);

			alias fieldType			= typeof(toReturn.tupleof[i]);
			alias attributeTypes	= typeof(__traits(getAttributes, toReturn.tupleof[i]));

			static if (attributeTypes.length >= 1) 
				alias attributeType = attributeTypes[0];
			else
				alias attributeType = void;

			//  Can only traverse the tree downwards
			//  So we need to save this index to not
			//  get lost.
			auto firstIndex = currentIndex;

			//Did the field have an attribute?
			static if(__traits(getAttributes, toReturn.tupleof[i]).length >= 1)
			{
				static if(is(attributeType == OptionalStruct!Type, Type) &&	is(attributeType.defaultType : fieldType)) 
				{
					static if(is(attributeType == OptionalStruct!fieldType)) 
					{
						bool thrown = false;

						try 
						{
							goToNext!member; //Changes the index to point to the member we want.
						}
						catch (ObjectNotFoundException a)
						{
							//Set the field to the default value contained in the attribute.
							thrown = true;
						}

						if (thrown)
						{
							toReturn.tupleof[i] = 
								__traits(getAttributes, toReturn.tupleof[i])[0].defaultValue;
						}
						else
						{
							toReturn.tupleof[i] = as!fieldType;
						}
					}
				} 
				else static if(is(attributeType at == ConvertStruct!(R, A), R, A)) 
				{
					goToNext!member;
					static assert(is(R : fieldType), "Incorrect returntype for convert function." ~ " Should be " ~ at.returnType.stringof ~" was " ~ fieldType.stringof);

					at.argType item = as!(at.argType)();
					toReturn.tupleof[i] = __traits(getAttributes, toReturn.tupleof[i])[0].convert(item);
				} 
				else static if(is(attributeType at == ContextConvertStruct!(R, A, C*), R, A)) 
				{
					goToNext!member;
					static assert(is(R : fieldType), "Incorrect returntype for convert function." ~ " Should be " ~ at.returnType.stringof ~" was " ~ fieldType.stringof);

					at.argType item = as!(at.argType)();
					toReturn.tupleof[i] = __traits(getAttributes, toReturn.tupleof[i])[0].convert(item, context);
				}
				else
				{
					goToNext!member; //Changes the index to point to the member we want.
					static if(NeedsAllocator!fieldType) 
					{
						toReturn.tupleof[i] = as!(fieldType)();
					} 
					else
					{
						auto value_ = as!fieldType;
						toReturn.tupleof[i] = value_;
					}
				}
			} 
			else 
			{
				goToNext!member; //Changes the index to point to the member we want.
				static if(NeedsAllocator!fieldType) 
				{
					toReturn.tupleof[i] = as!(fieldType)();
				} 
				else
				{
					auto value_ = as!fieldType;
					toReturn.tupleof[i] = value_;
				}
			}
			// We want to search the whole object for every name.
			currentIndex = firstIndex;
		}
        return toReturn;
	}

    T as(T)()
	{        
		enum context_compiles = __traits(compiles, () => context.read!(T, C)(&this));
		static if(context_compiles)
		{
			pragma(msg, T.stringof);
			return context.read!T(&this);
		}

		enum as_impl_compiles = __traits(compiles, as_impl!(T)());
		static if(as_impl_compiles)
		{
			return as_impl!(T)();
		}

		static if(!context_compiles && !as_impl_compiles)
		{
			as_impl!(T)();
		}

		//static assert(0, "Cannot serialize this type!");
	}

    ref SDLIterator opIndex(size_t index)
    {
        goToChild();
        foreach(i; 0..index) {
            goToNext();
		}
        return this;
	}

	private SDLObject current()
	{
		return (*over)[currentIndex];
	}
}

public template NeedsAllocator(T)
{
	enum NeedsAllocator = UnknownType!T  ||
		isSomeString!T	|| 
		isArray!T		|| 
		isList!T;
}

private template UnknownType(T)
{
	enum UnknownType = !(isNumeric!T	||
						 isSomeString!T	||
						 isArray!T 		||
						 isVector!T	    ||
						 is(T == bool)	||
							 isList!T);
}

struct SDLContainer
{
    SDLObject* root;
    private string source;
	private IAllocator allocator;

    @property
		SDLIterator opDispatch(string s)()
	{
        auto it = SDLIterator();
        it.over = &this;
		it.goToChild!s;
        return it;
	}

    @property T as(T, C)(ref C context)
	{
        return SDLIterator!(C)(&context, &this, 0).as!(T)();
	}

	private SDLObject opIndex(size_t index)
	{
		return root[index];
	}

	private int opApplyRecursion(uint index, int delegate(ref SDLObject) dg)
	{
		auto result = dg(root[index]);
		if(result)
			return result;
		if(root[index].type == SDLObject.Type._parent
		   && root[index].objectIndex)
		{
			result = opApplyRecursion(root[index].objectIndex, dg);
			if(result)
				return result;
		}
		if(root[index].nextIndex)
			result = opApplyRecursion(root[index].nextIndex, dg);
		return result;
	}

	private int opApply(int delegate(ref SDLObject) dg)
	{
		return opApplyRecursion(0,dg);
	}

	string toString()
	{
		string toReturn = "";
		foreach(sdl;this)
		{
			import std.stdio;
			toReturn ~= sdl.toString ~ "\n";
		}
		return toReturn;
	}
}

void toSDL(T, Sink)(auto ref T value, ref Sink s)
{
	toSDL(value, s, &default_context);
}

void toSDL(T, Sink, C)(auto ref T value, ref Sink sink, C* context, int level = 0)
{
	enum context_compiles = __traits(compiles, () => context.write(value, sink, level));
	static if(context_compiles)
	{
		context.write(value, sink, level);
	}	
	else 
	{
		toSDL_impl!(T, Sink, C)(value, sink, context, level);
	}
}

void toSDL_impl(T, Sink, C)(T value, ref Sink sink, C* context, int level) if(is(T == bool))
{
	if(value)
		sink.put("true");
	else
		sink.put("false");
}

void toSDL_impl(T, Sink, C)(T value, ref Sink sink, C* context, int level) if(is(T == struct) && !isList!(T) &&
																			  !is(T == Color))
{
	if(level != 0) {
		sink.put('\n');
		sink.put('\t'.repeat(level - 1));
		sink.put(objectOpener);
	}
	
	import math;
	static if (is(T vec == Vector!(len, U), int len, U)) {
		enum dimensions = ['x','y','z','w']; // This is at the same time the vector rep and the file rep. TODO: DRY.
		foreach(i;staticIota!(0, len)) {  
			sink.put('\n');
			sink.put('\t'.repeat(level));
			sink.put(dimensions[i]);
			sink.put('=');
			sink.put(cast(char[])(mixin("value." ~ dimensions[i]).to!string));
		}
	} else {
		foreach(i, field; value.tupleof) {
			sink.put('\n');
			sink.put('\t'.repeat(level));
			sink.put(cast(char[])__traits(identifier, T.tupleof[i]));
			sink.put('=');
			toSDL(field, sink, context, level + 1);
		}
	}

//Quick note about casts to char[]
//These exists since a non-trivial
//amount of the underlying implementations
//of sinks require mutability.
	if(level != 0){
		sink.put('\n');
		sink.put('\t'.repeat(level - 1));
		sink.put(objectCloser);
	}
}

void toSDL_impl(T, Sink, C)(T value, ref Sink sink, C* context, int level = 0) if(is(T == Color))
{
	import std.format;
	formattedWrite(sink, "0x%x", value.packedValue);
}

void toSDL_impl(T, Sink, C)(T value, ref Sink sink, C* context, int level = 0) if(is(T == string))
{
	sink.put(stringSeperator);
	sink.put(cast(char[])value);
	sink.put(stringSeperator);
}

void toSDL_impl(T, Sink, C)(T value, ref Sink sink, C* context, int level = 0) if(isNumeric!T)
{
	sink.put(cast(char[])value.to!string);
	static if(isFloatingPoint!T) {
		if(std.math.floor(value) == value)	// Is integer
			sink.put('.');
	}
}

void toSDL_impl(T, Sink, C)(T value, ref Sink sink, C* context, int level = 0) if((isArray!T || isList!(T)) && !is(T == string))
{
	sink.put(arrayOpener);
	foreach(i; 0 .. value.length) {
		toSDL(value[i], sink, context, level + 1);
		if(i != value.length - 1)
			sink.put(',');
	}
	sink.put(arrayCloser);
}

void toLua(Sink)(SDLIterator it, ref Sink sink, uint level = 0)
{
	import std.algorithm;
	// Always assume you have a new line to yourself (simple)
	sink.put('\t'.repeat(level));

	//Do we have a name? (Or are we an array element?)
	if(it.current.hasName)
		sink.put(cast(char[])(it.readName~" = "));

	//Check what kind of object we have
	final switch(it.current.type) with (SDLObject.Type)
	{
		case _parent:
			if(it.current.hasName)
			{
				sink.put('\n');
				sink.put('\t'.repeat(level));
			}
			sink.put('{');
			sink.put('\n');
			if(it.hasChildren)
			{
				auto save = it.currentIndex;
				it.goToChild;
				toLua(it, sink, level+1);
				it.currentIndex = save;
			}
			sink.put('\t'.repeat(level));
			sink.put('}');
			break;
		case _float:
			sink.put(it.readFloat.to!(char[]));
			break;
		case _string:
			sink.put('"');
			sink.put(cast(char[])it.readString);
			sink.put('"');
			break;
		case _int:
			sink.put(it.readInt.to!(char[]));
			break;
	}

	// Commas are always welcome in Lua! (If not at root level)
	if(level)
		sink.put(',');
	sink.put('\n');
	if(!it.empty)
	{
		it.goToNext;
		toLua(it, sink, level);
	}
}

/*
string toLuaFromSource(A)(ref A appender, string sdlSource)
	if (__traits(compiles, appender.put('\n')))
{
	ubyte[5*1024] objBuf = void;
	auto alloc = RegionAllocator(objBuf);
	auto cont = fromSDLSource(alloc, sdlSource, default_context);

	appender.put(cast(char[])("local sdlObject =\n{\n"));
	toLua(SDLIterator(&cont, 1), appender, 1);
	appender.put(cast(char[])"}\nreturn sdlObject");

	auto luaList = appender.data;
	return cast(string)luaList.buffer[0..luaList.length];
}

void toLuaFileFromFile(string sdlFile, string luaFile)
{
	import std.file;
	auto sdlSource = cast(string)read(sdlFile);

	char[5*1024] luaBuffer = void;
	auto luaAlloc = RegionAllocator(luaBuffer);
	auto luaApp = RegionAppender!char(luaAlloc);

	auto luaSource = toLuaFromSource(luaApp, sdlSource);

	//Save it to a file;
	write(luaFile, cast(void[])luaSource);
} */

struct ForwardRange
{
	size_t position;
	string over;

	@property ForwardRange save() 
	{ 
		return ForwardRange(position, over); 
	}

	@property bool empty() 
	{ 
		return over.length == position; 
	}

	void popFront() 
	{
		position++; 
	}

	@property char front() { return over[position]; }

	this(size_t position, string over)
	{
		this.position = position;
		this.over = over;
	}

	this(string over)
	{
		this.position = 0;
		this.over = over;
	}
}

bool isWhiteSpace(char c)
{
	return	c == '\n' ||
			c == '\r' ||
			c == '\t' ||
			c == ' ';
}

void skipWhitespace(ref ForwardRange range)
{
	while(!range.empty && isWhiteSpace(range.front))
	{
		range.popFront();
	}

	if (!range.empty && range.front == '/')
	{
		range.skipLine();
		range.skipWhitespace();
	}
}

void skipLine(ref ForwardRange range)
{
	while(!range.empty && 
		  range.front != '\n' &&
		  range.front != '\r')
	{
		range.popFront();
	}	
}	

template isStringOrVoid(T)
{
	enum isStringOrVoid = is(T == void) || isSomeString!T;
}
StringOrVoid readString(StringOrVoid = string)(ref ForwardRange range)
if (isStringOrVoid!StringOrVoid)
{
	if(range.front != stringSeperator)
		return readIdentifier!StringOrVoid(range);
	range.popFront();
	static if(isSomeString!StringOrVoid)
		auto saved = range.save();
	while(!range.empty) {
		if(range.front == stringSeperator)  {
			static if (isSomeString!StringOrVoid) {
				string s = str(saved, range);
				range.popFront();
				return s;
			} else {
				range.popFront();
				return;
			}
		}
		range.popFront();
	}

	enforce(0, "Eof reached while parsing string!");
	assert(0);
}

StringOrVoid readIdentifier(StringOrVoid = string)(ref ForwardRange range)
	if (isStringOrVoid!StringOrVoid)
{
	static if(isSomeString!StringOrVoid)
		auto saved = range.save();
	while(!range.empty)
	{
		char c = range.front;
		if(c == '\n' || c == '\t' 
		   || c == '\r' || c == ' ' || 
		   c == '='||
		   c == '/' ||
		   c == '}' ||
		   c == ']') {
			   static if(isSomeString!StringOrVoid)
				   return str(saved, range);
			   else
				   return;
		   }

		range.popFront();
	}

   static if(isSomeString!StringOrVoid)
	   return str(saved, range);
   else
	   return;
	// If we reach end of file, we actually just want to stop parsing.
	//enforce(0, "EOF while reading identifier");
	//assert(0);
}

template isBoolOrVoid(T) {
    enum isBoolOrVoid = is(T==void) || is(T==bool);
}

BoolOrVoid readBool(BoolOrVoid = bool)(ref ForwardRange range)
if (isBoolOrVoid!BoolOrVoid)
{
	static if (is(BoolOrVoid==bool))
		auto saved = range.save;
	while(!isWhiteSpace(range.front)) {
		range.popFront;
	}
	static if(is(BoolOrVoid==void)) 
		return;

	static if (is(BoolOrVoid==bool)) {
		import std.string : capitalize;
		string trueOrFalse = str(saved, range);
		if (trueOrFalse == "False" ||
			trueOrFalse == "false")
			return  false;
		if (trueOrFalse == "True" ||
			trueOrFalse == "true")
			return  true;
		enforce(0, "Invalid bool " ~ trueOrFalse);
	}
	assert(0, "Invalid codepath in readBool.");
}

template isNumericVoidOrType(T) {
	enum isNumericVoidOrType = is(T==void) || is(T==TypeID) || isNumeric!T;
}
NumericVoidOrType readNumber(NumericVoidOrType)(ref ForwardRange range)
if (isNumericVoidOrType!NumericVoidOrType)
{
	size_t state;
	char rc = range.front;
	switch(rc)
	{
		case '-':
			state = 0;
			break;
		case '0':
			state = 7;
			break;
		case '1': .. case '9':
			state = 1;
			break;
		case '.':
			state = 2;
			break;
		default :
			enforce(0, "Error reading number");
			break;
	}	

	bool shouldEnd = false;
	static if (isNumeric!NumericVoidOrType)
		auto saved = range;
	range.popFront();
	while(!range.empty)
	{
		char c = range.front;

		if(c == '_') { // Support for underscores in numbers.
			range.popFront(); // TODO:	A lot of numbers which might not actually be legal
			continue;			//		such as -__1234__23214_ are accepted...	
		}

		switch(state)
		{
			case 0:
				switch(c) 
				{
					case '0': .. case '9':
						state = 1;
						break;
					default:
						enforce(0, "Error reading number. "~getSDLError(range));
				}
				break;
			case 1:
				switch(c)
				{
					case '0': .. case '9':
						break;
					case 'e': 
					case 'E':
						state = 4;
						break;
					case '.':
						state = 3;
						break;
					default :
						shouldEnd = true;
				}
				break;
			case 2:
				switch(c) 
				{
					case '0': .. case '9':
						state = 3;
						break;
					default:
						enforce(0, "Error reading number. "~getSDLError(range));
				}
				break;
			case 3:
				switch(c)
				{
					case '0': .. case '9':
						break;
					case 'e': 
					case 'E':
						state = 4;
						break;
					case '.':
						enforce(0, "Error reading number. "~getSDLError(range));
                        break;
					default :
						shouldEnd = true;
				}
				break;
			case 4:
				switch(c)
				{
					case '0': .. case '9':
						state = 6;
						break;
					case '-':
					case '+':
						state = 5;
						break;
					default :
						enforce(0, "Error reading number. "~getSDLError(range));
				}
				break;
			case 5:	
				switch(c)
				{
					case '0': .. case '9':
						state = 6;
						break;
					default:
						enforce(0, "Error reading number. "~getSDLError(range));
				}
				break;
			case 6:
				switch(c)
				{
					case '0': .. case '9':
						break;
					default:
						shouldEnd = true;
						break;
				}
				break;
			case 7:
				switch(c)
				{
					case '0': .. case '9':
						state = 1;
						break;
					case '.':
						state = 3;
						break;
					case 'x':
					case 'X':
						state = 8;
						break;
					default:
						shouldEnd = true;
						break;
				}
				break;
			case 8:
				switch(c)
				{
					case '0': .. case '9':
					case 'a': .. case 'f':
					case 'A': .. case 'F':
						state = 9;
						break;
					default:
						enforce(0, "Error reading number. "~getSDLError(range));
				}
				break;
			case 9:
				switch(c)
				{
					case '0': .. case '9':
					case 'a': .. case 'f':
					case 'A': .. case 'F':
						break;
					default:
						shouldEnd = true;
						break;
				}
				break;
			default:
				enforce(0, "Error reading number. "~getSDLError(range));
		}

		if(shouldEnd)
			break;

		range.popFront();
	}

	static if(is(NumericVoidOrType==void)) {
		return;
	} else {
		import std.conv;
		switch (state) {
			case 1:
			case 7://Integer
				static if(is(NumericVoidOrType==TypeID))
					return TypeID._int;
                else static if(isIntegral!NumericVoidOrType) {
				    return number!NumericVoidOrType(saved, range);
				}
			case 9://Hexadecimal
				static if(is(NumericVoidOrType==TypeID))
					return TypeID._int;
				else static if(isIntegral!NumericVoidOrType) {
                    return cast(NumericVoidOrType)parseHex(saved, range);
				}
			case 3:
			case 6://Floating point
				static if(is(NumericVoidOrType==TypeID))
					return TypeID._float;
				else static if(isFloatingPoint!NumericVoidOrType) {
                    return number!NumericVoidOrType(saved, range);
				}
			default:
				assert(0, "Invalid number parsing state: " ~ to!string(state));
		}
	}
}

string str(ForwardRange a, ForwardRange b)
{
	return a.over[a.position .. b.position];
}

T number(T)(ForwardRange a, ForwardRange b) if(isNumeric!T)
{
	auto numSlice = a.over[a.position .. b.position];
	size_t properLength = b.position - a.position;

	//And a static array saved the day :)
	char[128] no_;
	int counter = 0;
	while(a.position != b.position) {
		if(a.front != '_') {
			no_[counter++] = a.front;
		}
		a.popFront();
	}
	return no_[0 .. counter].to!T;
}

long parseHex(ForwardRange saved, ForwardRange range)
{
	enforce(saved.front == '0', "Hexadecimal strings should start with 0");
	saved.popFront();
	enforce(saved.front == 'x' || saved.front == 'X');
    saved.popFront();
	long acc = 0;
	size_t currentPosition = 0;
	while( saved.position - 1 != range.position) {
		range.position--;
		auto c = range.front; 
		switch (c) {
			case '0': .. case '9':
				acc += to!long(c - '0') * 16^^(currentPosition);
				break;
			case 'a': .. case 'f':
				acc += to!long(c - 'a' + 10) * 16^^(currentPosition);
				break;
			case 'A': .. case 'F':
				acc += to!long(c - 'A' + 10) * 16^^(currentPosition);
				break;
			case '_':
				continue;
				break;
			default:
				return acc;
		}
		currentPosition++;
	}
	return acc;
}

T fromSDLSource(T, A)(ref A allocator, string source)
{
	return fromSDLSource!T(allocator, source, default_context);
}

T fromSDLSource(T, A, C)(ref A allocator, string source, C context) if(is(C == struct))
{
	auto iall = Mallocator.it.allocate!(CAllocator!A)(allocator);
	scope(exit) Mallocator.it.deallocate(iall);


	import allocation.native;
    auto app = MallocAppender!SDLObject(1024);

	if(source[0] == 0xEF &&
	   source[1] == 0xBB &&
	   source[2] == 0xBF)
	{
		source = source[3..$];
	}

    auto cont = fromSDL(app, source);
	static if(is(T == SDLContainer))
		return cont;

	cont.allocator = iall;

    return cont.as!T(context);
}

T fromSDLFile(T, A)(ref A al, string fp)
{
	return fromSDLFile!(T, A, SDLContext)(al, fp, default_context);
}

T fromSDLFile(T, A, C)(ref A allocator, string filePath, C context) if(is(C == struct))
{
    import allocation.native;
	auto iall = Mallocator.it.allocate!(CAllocator!A)(allocator);
	scope(exit) Mallocator.it.deallocate(iall);

    auto app = MallocAppender!SDLObject(1024);
    auto source = readText(filePath);

	// Trim BOM (byte order mark) from utf8
	// The standard library really should handle this...
	if(source[0] == 0xEF &&
	   source[1] == 0xBB &&
	   source[2] == 0xBF)
	{
		source = source[3..$];
	}
    auto cont = fromSDL(app, source);
	static if(is(T == SDLContainer))
		return cont;

		
	cont.allocator = iall;
    return cont.as!T(context);
}

T fromSDL(T, A, C)(ref A allocator, string source, C context) if(is(C == struct))
{
	return fromSDL(allocator, source).as!T(allocator, context);
}

SDLContainer fromSDL(Sink)(ref Sink sink, string source)
{
    auto container = SDLContainer();
    auto root = SDLObject();
	root.type = TypeID._parent;
    root.objectIndex = 1;
    root.nextIndex = 0;
    sink.put(root);
    container.source = source;
    ushort numObjects = 1;
    auto range = ForwardRange(source);
    readObject(sink, range, numObjects); 
    enforce(numObjects>1, "Read from empty sdl");

    auto list = sink.data();
    container.root = list.buffer;
    return container;
}

//Only used to build the tree of SDLObjects from the file.
private void readObject(Sink)(ref Sink sink, ref ForwardRange range, ref ushort nextVacantIndex)
{

    range.skipWhitespace();
    if(range.front == objectCloser) {
        range.popFront();
        return;
    }

    auto objIndex = sink.put(SDLObject());
    nextVacantIndex++;
    sink[objIndex].nameIndex = cast(uint)range.position;
    range.readIdentifier!void;//Don't care about the name, we are just building the tree
    range.skipWhitespace();
    enforce(range.front == '=', getSDLError(range));
    range.popFront();

    range.skipWhitespace();

    auto c = range.front;

    switch(c)
    {
        case objectOpener:
            range.popFront();
            sink[objIndex].type = TypeID._parent;
            sink[objIndex].objectIndex = nextVacantIndex;
            readObject(sink, range, nextVacantIndex);
            if (sink[objIndex].objectIndex == nextVacantIndex)
                sink[objIndex].objectIndex = 0; // If the child was empty, we basically emulate null
            break;
        case arrayOpener:
            range.popFront();
            sink[objIndex].type = TypeID._parent;
            sink[objIndex].objectIndex = nextVacantIndex;
            readArray(sink, range, nextVacantIndex);
            if (sink[objIndex].objectIndex == nextVacantIndex)
                sink[objIndex].objectIndex = 0; // If the array was empty, we basically emulate null
            break;
        case '0' : .. case '9':
        case '-' :
        case '.' :
            sink[objIndex].objectIndex = cast(uint)range.position;
            sink[objIndex].type = range.readNumber!TypeID;
            break;
        case stringSeperator:
            sink[objIndex].type = TypeID._string;
            sink[objIndex].objectIndex = cast(uint)range.position;
            range.readString!void;
            break;
		case 'a': .. case 'z':
		case 'A': .. case 'Z':
			sink[objIndex].type = TypeID._string;
            sink[objIndex].objectIndex = cast(uint)range.position;
            range.readString!void;
			break;
        case '/':
            skipLine(range);
            break;

        default :
            enforce(0, "Unrecognized char while parsing object.");		
    }

    range.skipWhitespace();
    if (!range.empty) {
        sink[objIndex].nextIndex = nextVacantIndex;
        readObject(sink, range, nextVacantIndex);
		if (sink[objIndex].nextIndex == nextVacantIndex)
			sink[objIndex].nextIndex = 0; // If the object was empty, we basically emulate null
	}
}

void readArray(Sink)(ref Sink sink, ref ForwardRange range, ref ushort nextVacantIndex)
{
	range.skipWhitespace();

    //Defend against empty arrays.
	if(range.front == arrayCloser) {
		range.popFront(); 
		return;
	}

    auto objIndex = sink.put(SDLObject());
    nextVacantIndex++;

	// Array elements don't have names
	sink[objIndex].nameIndex = noNameValue;

    //In readobject we would read the name here, but array elements have no names.

    skipWhitespace(range);

    auto c = range.front;

    switch(c)
    {
        case objectOpener:
            range.popFront();
            sink[objIndex].type = TypeID._parent;
            sink[objIndex].objectIndex = nextVacantIndex;
            readObject(sink, range, nextVacantIndex);
            if (sink[objIndex].objectIndex == nextVacantIndex)
                sink[objIndex].objectIndex = 0; // If the child was empty, we basically emulate null
            break;
        case arrayOpener: // This is exactly the same as the above case...
            range.popFront();
            sink[objIndex].type = TypeID._parent;
            sink[objIndex].objectIndex = nextVacantIndex;
            readArray(sink, range, nextVacantIndex);
            if (sink[objIndex].objectIndex == nextVacantIndex)
                sink[objIndex].objectIndex = 0; // If the array was empty, we basically emulate null
            break;
        case '0' : .. case '9':
        case '-' :
        case '.' :
            sink[objIndex].objectIndex = cast(uint)range.position;
            sink[objIndex].type = range.readNumber!TypeID;
            break;
        case stringSeperator:
            sink[objIndex].type = TypeID._string;
            sink[objIndex].objectIndex = cast(uint)range.position;
            range.readString!void;
            break;
        case '/':
            skipLine(range);
            break;

        default :
            enforce(0, "Unrecognized char while parsing array.");		
    }
    range.skipWhitespace();
	
	if(range.front == arrayCloser) {
		range.popFront();
		return;
	}
	if (range.front == arraySeparator) {
		range.popFront();
	}
	if(range.front == arrayCloser) {
		range.popFront();
		return;
	}
	range.skipWhitespace();
	sink[objIndex].nextIndex = nextVacantIndex;
	readArray(sink, range, nextVacantIndex);
	if (sink[objIndex].nextIndex == nextVacantIndex) {
		// Nothing was allocated, arraycloser found when expecting object
		enforce(0, "Empty slot in array (arraycloser following arrayseparator)."
				~ getSDLError(range));
	}	

}

private enum errorlength = 50;
string getSDLError(ref ForwardRange currentPos)
{
	size_t startPos = (0>currentPos.position-errorlength) ? 0 : currentPos.position-errorlength;

	size_t maxPos = currentPos.over.length;
	size_t endPos	= (maxPos < currentPos.position+errorlength) ? maxPos : currentPos.position+errorlength;
	return	"Error at line "~to!string(getLineNumber(currentPos))~" of .sdl data.\n"
				~ currentPos.over[startPos..currentPos.position]
				~ "***ERROR HERE***" 
				~ currentPos.over[currentPos.position..endPos];
}

size_t getLineNumber(ref ForwardRange currentPos)
{
	return count(currentPos.over[0..currentPos.position], "\n") + 1;
}
