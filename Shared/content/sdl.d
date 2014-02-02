module content.sdl;

import std.exception;
import std.conv : to;
import std.traits;
import std.bitmanip;
import std.file;
import std.c.string :memcpy;
import std.string;
import std.range : repeat;
import allocation;
import dunit;


alias TypeID = SDLObject.Type;

enum stringSeperator = '|';
enum arrayOpener = '[';
enum arrayCloser = ']';
enum arraySeparator = ',';
enum objectOpener = '{';
enum objectCloser = '}';


struct SDLObject
{
    enum Type { _float, _string, _int, _parent}
    mixin(bitfields!(
                     uint,  "nameIndex",    23,
                     uint,  "objectIndex",  23,
                     Type,  "type",         2,
                     ushort, "nextIndex",   16
                         ));

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
	T defaultValue;
	this(T)(T t) { defaultValue = t; }
}

struct SDLIterator
{
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
		bool empty() {
			return !over.root[currentIndex].nextIndex;
		}

    @property
		size_t walkLength() {
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

    void goToChild(string name = "")()
	{
        auto range = mixin(curObjObjRange);
        auto obj = over.root[currentIndex];//Get current object, if it doesn't exist, tough luck.
        enforce(obj.type == TypeID._parent, "Foolishly tried to get children of "
				~range.readIdentifier~ 
				" of typeID "~std.conv.to!string(obj.type)~".");
        currentIndex = cast(ushort)obj.objectIndex;
        static if (name != "")
            goToNext!name;
	}

    void goToNext(string name)()
	{
        auto range = mixin(curObjObjRange);
        while(currentIndex)//An index of zero is analogous to null.
		{ 
            SDLObject obj = over.root[currentIndex];
            range.position = cast(size_t)obj.nameIndex;

            if(range.readIdentifier == name) {
                return;
			}
			currentIndex = cast(ushort)obj.nextIndex;
		} 
        throw new ObjectNotFoundException("Couldn't find object " ~ name);
	}

	class ObjectNotFoundException : Exception
	{
		this(string msg) { super(msg); }
	}

    void goToNext()
	{
        SDLObject obj = over.root[currentIndex];
        auto next = cast(ushort)obj.nextIndex;
        if(!next)
            enforce(0, "Index out of bounds.");
        currentIndex = next;
	}

    enum curObjObjRange = "ForwardRange(over.root[currentIndex].objectIndex,
		over.source)";

	T as(T)() if(isNumeric!T)
	{
        static if(isIntegral!T)
			enforce(over.root[currentIndex].type == TypeID._int,
					"SDLObject wasn't an integer, which was requested.");
        else static if(isFloatingPoint!T)
			enforce(over.root[currentIndex].type == TypeID._float ||
					over.root[currentIndex].type == TypeID._int,
					"SDLObject wasn't a floating point value, "~
					"which was requested.");
        auto range = mixin(curObjObjRange);
        if(over.root[currentIndex].type == TypeID._int)
            return cast(T)readNumber!long(range);
        else
            return cast(T)readNumber!double(range);
	}

	T as(T)() if(is(T==bool))
	{
		assertEquals(over.root[currentIndex].type, TypeID._int,
			   "SDLObject wasn't a boolean, which was requested");
		auto range = mixin(curObjObjRange);
		return readBool(range);
	}

    T as(T, A)(ref A allocator) if(isSomeString!T)
	{
        assertEquals(over.root[currentIndex].type, TypeID._string);

        auto range = mixin(curObjObjRange);
        string str = readString!T(range);
        char[] s = allocator.allocate!(char[])(str.length);
        s[] = str;
        return cast(T)s;
	}

    T as(T, A)(ref A allocator) if(isArray!T && !isSomeString!T)
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

    import math.vector, math.traits;
    Vec as(Vec)() if(isVector!Vec)
	{
		static if (is(Vec v == Vector!(len, U), int len, U)) {
			enum dimensions = ["x","y","z","w"]; // This is at the same time the vector rep and the file rep. Change.
			auto toReturn = Vec();
            goToChild();
			foreach(i;math.vector.staticIota!(0, len)) {  
				//  Can only traverse the tree downwards
				//  So we need to save this index to not
				//  get lost.
				auto firstIndex = currentIndex;
                goToNext!(dimensions[i]);
                auto range = mixin(curObjObjRange);
                mixin("toReturn." ~ dimensions[i]) = readNumber!U(range);

				// We want to search the whole object for every name.
				currentIndex = firstIndex;
			}
			return toReturn;
		} else assert(0, Vec.stringof ~ " is not a vector type.");
	}

    T as(T, Allocator)(ref Allocator a) if (!(isNumeric!T ||
					isSomeString!T ||
					isArray!T ||
					isVector!T))
	{        goToChild();
        T toReturn;

        foreach(member; __traits(allMembers, T)) {
			
            alias fieldType = typeof(__traits(getMember, toReturn, member));
			alias attributeType = typeof(__traits(getAttributes, __traits(getMember, toReturn, member)));
            //  Can only traverse the tree downwards
            //  So we need to save this index to not
            //  get lost.
            auto firstIndex = currentIndex;
			//Did the field have an attribute?
			static if(__traits(getAttributes, __traits(getMember, toReturn, member)).length >= 1) {
				static if(is(attributeType == Unpack!(OptionalStruct!fieldType))) {
					try {
						goToNext!member; //Changes the index to point to the member we want.
						static if(isArray!fieldType) {
							__traits(getMember, toReturn, member) = 
								as!fieldType(a);
						} else {
							__traits(getMember, toReturn, member) = 
								as!fieldType;
						}
					} catch (ObjectNotFoundException e) {
						//Set the field to the default value contained in the attribute.
						__traits(getMember, toReturn, member) = 
							__traits(getAttributes, __traits(getMember, toReturn, member))[0].defaultValue;
					}
				} else {
					assert(0, "Field type mismatch: \n Field "
						   ~member~" was of type "~fieldType.stringof~
						   ", attribute was of type "~attributeType.stringof);
				}
			} else {
				goToNext!member; //Changes the index to point to the member we want.
				static if(isArray!fieldType) {
					__traits(getMember, toReturn, member) = 
						as!(fieldType, Allocator)(a);
				} else {
					__traits(getMember, toReturn, member) = 
						as!fieldType;
				}
			}
            // We want to search the whole object for every name.
            currentIndex = firstIndex;
        }
        return toReturn;
	}

	T as(T)() if (!(isNumeric!T ||
                  isSomeString!T ||
                  isArray!T ||
                  isVector!T ||
					is(T==bool)))
	{
        goToChild();
        T toReturn;

        foreach(member; __traits(allMembers, T)) {
			
            alias fieldType = typeof(__traits(getMember, toReturn, member));
			alias attributeType = typeof(__traits(getAttributes, __traits(getMember, toReturn, member)));
			static if(isArray!fieldType) {
				assert(0, "Structs with arrays inside need an allocator to be parsed.\n"~
						"Field "~member~" was an array, and provented parsing.");
			} else {
				//  Can only traverse the tree downwards
				//  So we need to save this index to not
				//  get lost.
				auto firstIndex = currentIndex;
				//Did the field have an attribute?
				static if(__traits(getAttributes, __traits(getMember, toReturn, member)).length >= 1) {
					static if(is(attributeType == Unpack!(OptionalStruct!fieldType))) {
						try {
							goToNext!member; //Changes the index to point to the member we want.
							__traits(getMember, toReturn, member) = 
								as!fieldType;
						} catch (ObjectNotFoundException a) {
							//Set the field to the default value contained in the attribute.
							__traits(getMember, toReturn, member) = 
								__traits(getAttributes, __traits(getMember, toReturn, member))[0].defaultValue;
						}
					} else {
						assert(0, "Field type mismatch: \n Field "
							   ~member~" was of type "~fieldType.stringof~
							   ", attribute was of type "~attributeType.stringof);
					}
				} else {
						goToNext!member;
						__traits(getMember, toReturn, member) = 
							as!fieldType;
				}
				// We want to search the whole object for every name.
				currentIndex = firstIndex;
			}
        }
        return toReturn;
	}

	private template Unpack(T...)
	{
		alias Unpack = T;
	}



    ref SDLIterator opIndex(size_t index)
    {
        goToChild();
        foreach(i; 0..index) {
            goToNext();
		}
        return this;
	}
}

struct SDLContainer
{
    private SDLObject* root;
    private string source;

    @disable this(this);

    @property
		SDLIterator opDispatch(string s)()
	{
        auto it = SDLIterator();
        it.over = &this;
		it.goToChild!s;
        return it;
	}

    @property
		T as(T, A)(ref A allocator)
	{
        return SDLIterator(&this, 0).as!T(allocator);
	}

	@property
		T as(T)()
	{
        return SDLIterator(&this, 0).as!T;
	}

}


void toSDL(T, Sink)(T value, ref Sink sink, int level = 0) if(is(T == struct))
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
			toSDL(field, sink, level + 1);
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

void toSDL(T, Sink)(T value, ref Sink sink, int level = 0) if(is(T == string))
{
	sink.put(stringSeperator);
	sink.put(cast(char[])value);
	sink.put(stringSeperator);
}

void toSDL(T, Sink)(T value, ref Sink sink, int level = 0) if(isNumeric!T)
{
	sink.put(cast(char[])value.to!string);
	static if(isFloatingPoint!T) {
		if(std.math.floor(value) == value)	// Is integer
			sink.put('.');
	}
}

void toSDL(T, Sink)(T value, ref Sink sink, int level = 0) if(isArray!T && !is(T == string))
{
	sink.put(arrayOpener);
	foreach(i; 0 .. value.length) {
		toSDL(value[i], sink, level);
		if(i != value.length - 1)
			sink.put(',');
	}
	sink.put(arrayCloser);
}


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
	enforce(range.front == stringSeperator);
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
		   c == '/') {
			   static if(isSomeString!StringOrVoid)
				   return str(saved, range);
			   else
				   return;
		   }

		range.popFront();
	}

	enforce(0, "EOF while reading identifier");
	assert(0);
}

template isBoolOrVoid(T) {
    enum isBoolOrVoid = is(T==void) || is(T==bool);
}

BoolOrVoid readBool(BoolOrVoid = bool, Range)(ref Range range)
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
NumericVoidOrType readNumber(NumericVoidOrType, Range)(ref Range range)
if (isNumericVoidOrType!NumericVoidOrType)
{
	size_t state;
	switch(range.front)
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
						enforce(0, "error reading number");
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
						enforce(0, "error reading number");
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
						enforce(0, "error reading number!");
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
						enforce(0, "error reading number!");
				}
				break;
			case 5:	
				switch(c)
				{
					case '0': .. case '9':
						state = 6;
						break;
					default:
						enforce(0, "error reading number!");
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
						enforce(0, "error reading number!");
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
				enforce(0, "WTF");
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

T number(T)(ForwardRange a, ForwardRange b)
if(isNumeric!T)
{//BY THE GODS THIS SUCKS
//TODO: No string allocs.
//Only alternatives I see right now is to either pass appenders/allocators
//Or write your own parsers of integers and floats (very hard!)
	auto numSlice = a.over[a.position .. b.position];
	size_t properLength = b.position - a.position;
	string no_ = "";
	while(a.position != b.position) {
		if(a.front != '_') {
			no_ ~= a.front;
		}
		a.popFront();
	}
	return no_.to!T;
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

T fromSDLFile(T, A)(ref A allocator, string filePath)
{
    import allocation.native;
    auto app = MallocAppender!SDLObject(1024);
    string source = readText(filePath);
    auto cont = fromSDL(app, source);
    return cont.as!T(allocator);
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
    enforce(range.front == '=');
    range.popFront();

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
		case 't':
		case 'T':
		case 'f':
		case 'F':
			sink[objIndex].objectIndex = cast(uint)range.position;
			sink[objIndex].type = TypeID._int;
			range.readBool!void;
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
    if (range.front == arraySeparator) {
        range.popFront();
        sink[objIndex].nextIndex = nextVacantIndex;
        readArray(sink, range, nextVacantIndex);
		if (sink[objIndex].nextIndex == nextVacantIndex) {
			// Nothing was allocated, arraycloser found when expecting object
            enforce(0, "Empty slot in array (arraycloser following arrayseparator).");
		}	
	} else if(range.front == arrayCloser) {
		range.popFront();
		return;
	}

} 

class TestSDL {


	mixin UnitTest;


	@Test public void testNumbers() {
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, 
						   "numberone 	    = 123456
						   numbertwo 	    = 1234.234
						   numberthree      = 1234.34e234
						   numberfour 	    = 1234.34E-234
						   numberfive 	    = -1234
						   numbersix 	    = 0xfF
						   numberseven 	    = 0x10000"
						   );

		assertEquals(obj.numberone 	 .as!int, 123456);

		import std.math : approxEqual;
		assertFun!(approxEqual)(obj.numbertwo.as!double, 1234.234);
		assertFun!(approxEqual)(obj.numberthree.as!double, 1234.34e234);
		assertFun!(approxEqual)(obj.numberfour.as!double, 1234.34E-234);
		assertEquals(obj.numberfive	.as!int, -1234);
		assertEquals(obj.numbersix	.as!int, 0xfF);
		assertEquals(obj.numberseven.as!int, 0x10000);
	}


	@Test public void testSample() {

		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, 
						   "
						   map = 
						   {
						   width  = 800
						   height = 600
						   }

						   snakes =
						   [
						   {	
						   posx = 400
						   posy = 10
						   dirx = 1
						   diry = 0.
						   color = 42131241
						   leftKey = 65
						   rightKey = 68
						   },
						   {
						   posx = 100
						   posy = 50
						   dirx = 1.
						   diry = 0
						   color = 51231241
						   leftKey = 263
						   rightKey = 262
						   }
						   ]
						   turnSpeed = 0.02
						   freeColor = 0"
						   );

		assertEquals(obj.map.width        .as!int, 800);
		assertEquals(obj.map.height       .as!int, 600);

		assertEquals(obj.snakes[0].posx 	.as!int, 400);
		assertEquals(obj.snakes[0].posy     .as!int, 10);

		import std.math : approxEqual;
		assertFun!(approxEqual)(obj.snakes[0].dirx       .as!double, 1.);
		assertFun!(approxEqual)(obj.snakes[0].diry       .as!double, 0);
		assertEquals(obj.snakes[0].color 	.as!int, 42131241);
		assertEquals(obj.snakes[0].leftKey 	.as!int, 65);
		assertEquals(obj.snakes[0].rightKey .as!int, 68);

		assertEquals(obj.snakes[1].posx.as!int, 100);
		assertEquals(obj.snakes[1].posy.as!int, 50);
		assertFun!(approxEqual)(obj.snakes[1].dirx.as!double, 1.);
		assertFun!(approxEqual)(obj.snakes[1].diry.as!double, 0);
		assertEquals(obj.snakes[1].color    .as!int, 51231241);
		assertEquals(obj.snakes[1].leftKey 	.as!int, 263);
		assertEquals(obj.snakes[1].rightKey .as!int, 262);

		assertTrue(approxEqual(obj.turnSpeed.as!double, 0.02));
		assertEquals(obj.freeColor.as!int, 0);
	}

	@Test public void testBooleans() {

		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, 
						   "
						   booleans =
						   [
						   {	
						   testfalse = false
						   testFalse = False
						   },
						   {
						   testtrue = true
						   testTrue = True
						   }
						   ]"
						   );

		assertFalse(obj.booleans[0].testfalse.as!bool);
		assertFalse(obj.booleans[0].testFalse.as!bool);
		assertTrue(obj.booleans[1].testtrue.as!bool);
		assertTrue(obj.booleans[1].testTrue.as!bool);
	}

	@Test public void testUnderscores() {
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, 
						   "numberone 	    = 123_456
						   numbertwo 	    = 1_234.234
						   numberthree      = 1_234._3_4e2_34
						   numberfour 	    = 123_4.3_4E-23_4
						   numberfive 	    = -1_234
						   numbersix 	    = 0xf_F
						   numberseven 	    = 0x10_000"
						   );

		assertEquals(obj.numberone.as!int, 123456);

		import std.math : approxEqual;
		assertFun!(approxEqual)(obj.numbertwo 	 .as!double, 1234.234);
		assertFun!(approxEqual)(obj.numberthree   .as!double, 1234.34e234);
		assertFun!(approxEqual)(obj.numberfour 	 .as!double, 1234.34E-234);
		assertEquals(obj.numberfive 	.as!int, -1234);
		assertEquals(obj.numbersix 		.as!int, 0xfF);
		assertEquals(obj.numberseven 	.as!int, 0x10000);
	}

	@Test public void testVectors() {
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app,
						   "pos = "
						   ~"{"
						   ~"x = 4 "
						   ~"y = 5"
						   ~"}"
						   ~"floats ="
						   ~"{"
						   ~"x = 234.2 "
						   ~"y = 123.4"
						   ~"}"
						   );
		import math.vector;
		auto vec = obj.pos.as!int2;
		auto vecFloat = obj.floats.as!float2;
		assertEquals(vec, int2(4,5));
		assertEquals(vecFloat, float2(234.2f,123.4f));
	}

	@Test public void testOptional() {
		struct OptionalFields {
			@Optional(7) int totallyOptional;
			int notOptional;
		}

		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "notOptional = 4");
		auto test = obj.as!OptionalFields;
		assertEquals(test.totallyOptional, 7);
		assertEquals(test.notOptional, 4);
	}

	@Test public void testOptionalArray() {
		struct OptionalArrs {
			@Optional([1,2,3]) int[] opt;
			int[] notOpt;
		}
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "notOpt = [1,2,4]");
		auto buf2 = new void[1024];
		auto alloc2 = RegionAllocator(buf2);
		auto test = obj.as!OptionalArrs(alloc2);
		assertArrayEquals(test.opt, [1,2,3]);
		assertArrayEquals(test.notOpt, [1,2,4]);
	}

	@Test public void testToSdlSample() {
		struct Snake
		{
			long posx;
			long posy;
			double dirx;
			double diry;
			long color;
			long leftKey;
			long rightKey;

		}
		import math.vector;
		struct AchtungConfig
		{
			int2 map;
			Snake[] snakes;
			double turnSpeed;
			long freeColor;
		}

		Snake s1 = Snake(400, 10, 1, 0., 42131241, 65, 68);
		Snake s2 = Snake(100, 50, 1., 0., 51231241, 263, 262);

		auto config = AchtungConfig(int2(800,600), [s1,s2], 0.02, 0);

		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!char(alloc);
		toSDL(config, app);
		auto source = app.data;
		import collections.list;
		auto checkSource = "
map=
{
	x=800
	y=600
}
snakes=[
{
	posx=400
	posy=10
	dirx=1.
	diry=0.
	color=42131241
	leftKey=65
	rightKey=68
},
{
	posx=100
	posy=50
	dirx=1.
	diry=0.
	color=51231241
	leftKey=263
	rightKey=262
}]
turnSpeed=0.02
freeColor=0";
		List!(T) from(T)(T[] content) {
			return List!T(content.ptr, cast(uint)content.length, cast(uint)content.length);
		}

		auto check = from(cast(char[])checkSource);
		assertFun!(listEquals)(check, source);
	}

}		
bool listEquals(List)(List a, List b) {
	foreach(i, elem; a) {
		if (elem != b[i]) {
			return false;
		}
	}
	return true;
}
