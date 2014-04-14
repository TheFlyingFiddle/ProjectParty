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

auto Convert(alias F)()
{
	return ConvertStruct!(ReturnType!F, ParameterTypeTuple!F)(&F);
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


    enum curObjObjRange =	"ForwardRange(over.root[currentIndex].objectIndex,"
		~	"over.source)";
	enum curObjNameRange =	"ForwardRange(over.root[currentIndex].objectIndex,"
		~	"over.source)";
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

    void goToNext()
	{
        SDLObject obj = over.root[currentIndex];
        auto next = cast(ushort)obj.nextIndex;
        if(!next)
            enforce(0, getSDLIterError() ~ "\n" ~ "Object had no next! Index out of bounds.");
        currentIndex = next;
	}


	T as(T)() if(isNumeric!T && !is(T==enum))
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

	T as(T)() if(is(T==bool))
	{
		assertEquals(over.root[currentIndex].type, TypeID._string,
				getSDLIterError() ~ "\n" ~
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

				static if(NeedsAllocator!A) 
					elem = as!A(allocator);
                else 
					elem = as!A;

				currentIndex = next;
			}
            return arr;
		} else {
            static assert(0, T.stringof ~ " is not an array type!");
		}
	}


	//TODO: Code duplication (see above) iteration might be refactored into an opApply?
	T as(T, A)(ref A allocator) if(is(T t == List!U, U))
	{
        static if(is(T t == List!U, U)) {
			auto listLength = walkLength;
			auto list = T(allocator, listLength);
			goToChild();

			foreach(i; 0 .. listLength) {
				auto obj = over.root[currentIndex];
				auto next = obj.nextIndex;
				static if(NeedsAllocator!U) 
					list.put = as!U(allocator);
				else 
					list.put = as!U;
				currentIndex = next;
			}
			return list;
		} else {
			static assert(0, T.stringof ~ " is not a List type!");
		}
	}

	T as(T)() if (is(T == enum))
	{
		assertEquals(over.root[currentIndex].type, TypeID._string,
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
		} else static assert(0, Vec.stringof ~ " is not a vector type.");
	}


	private template NeedsAllocator(T)
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
							isVector!T		||
							is(T == bool)	||
							isList!T);
	}

	private template isList(T)
	{
		static if (is(T t == List!U, U)) {
			enum isList = true;
		} else {
			enum isList = false;
		}
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

    T as(T, Allocator)(ref Allocator a) if (UnknownType!T)
	{        
		goToChild();
        T toReturn;

        foreach(i, dummy; toReturn.tupleof) {
			enum member = memberName!(toReturn.tupleof[i].stringof);

			alias fieldType = typeof(toReturn.tupleof[i]);
			alias attributeTypes = typeof(__traits(getAttributes, toReturn.tupleof[i]));
			static if (attributeTypes.length >= 1) 
				alias attributeType = attributeTypes[0];
			else
				alias attributeType = void;
			//  Can only traverse the tree downwards
			//  So we need to save this index to not
			//  get lost.
			auto firstIndex = currentIndex;
			//Did the field have an attribute?
			static if(__traits(getAttributes, toReturn.tupleof[i]).length >= 1) {
				static if(is(attributeType == OptionalStruct!fieldType)) {
					static if(is(attributeType == OptionalStruct!fieldType)) {
						bool thrown = false;
						try {
							goToNext!member; //Changes the index to point to the member we want.
						} catch (ObjectNotFoundException a) {
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
							static if (NeedsAllocator!fieldType)
								toReturn.tupleof[i] = as!fieldType(a);
							else
								toReturn.tupleof[i] = as!fieldType;
						}
					}
				} else static if(is(attributeType at == ConvertStruct!(R, A), R, A)) {
					goToNext!member;
					static assert(is(at.returnType : fieldType), 
								  "Incorrect returntype for convert function." ~
						" Should be "~at.returnType.stringof~" was "~fieldType.stringof);
					static if (NeedsAllocator!(at.argType))
						at.argType item = as!(at.argType)(a);
					else
						at.argType item = as!(at.argType);
					toReturn.tupleof[i] = 
						__traits(getAttributes, toReturn.tupleof[i])[0].convert(item);
				} else {
					static assert(0, "Field type mismatch: \n Field "
						   ~member~" was of type "~fieldType.stringof~
						   ", attribute was of type "~attributeType.stringof);
				}
			} else {
				goToNext!member; //Changes the index to point to the member we want.
				static if(NeedsAllocator!fieldType) {
					toReturn.tupleof[i] = as!(fieldType, Allocator)(a);
				} else {
					toReturn.tupleof[i] = as!fieldType;
				}
			}
			// We want to search the whole object for every name.
			currentIndex = firstIndex;
		}
        return toReturn;
	}

	T as(T)() if (UnknownType!T)
	{
        goToChild();
        T toReturn;

        foreach(i, dummy; toReturn.tupleof) 
		{
			enum member = memberName!(toReturn.tupleof[i].stringof);
			alias fieldType = typeof(toReturn.tupleof[i]);
			//We need to be able to assign to it.
			alias attributeTypes = typeof(__traits(getAttributes, toReturn.tupleof[i]));
			static if (attributeTypes.length >= 1) 
				alias attributeType = attributeTypes[0];
			else
				alias attributeType = void;
			static if(isArray!fieldType) 
				static assert(0, "Structs cotaining arrays need an allocator to be parsed.\n"~
						"Field "~member~" was an array, and prevented parsing.");
			else static if(is(fieldType f == List!E, E))
				static assert(0, "Structs cotaining lists need an allocator to be parsed.\n"~
						"Field "~member~" was a list, and prevented parsing.");
			else 
			{
				//  Can only traverse the tree downwards
				//  So we need to save this index to not
				//  get lost.
				auto firstIndex = currentIndex;
				//Did the field have an attribute?
				static if(__traits(getAttributes, toReturn.tupleof[i]).length >= 1) 
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
							toReturn.tupleof[i] = 
								__traits(getAttributes, toReturn.tupleof[i])[0].defaultValue;
						else
							toReturn.tupleof[i] = as!fieldType;						
	  				} 
					else static if(is(attributeType at == ConvertStruct!(R, A), R, A)) 
					{
						goToNext!member;
						static assert(is(at.returnType : fieldType), 
									  "Incorrect returntype for convert function." ~
									  " Should be "~at.returnType.stringof~" was "~fieldType.stringof);
						static if (NeedsAllocator!(at.argType))
							static assert(0, "Convertible field of type "~at.argType.stringof~
										  " needs an allocator to be parsed.");
						else
							at.argType item = as!(at.argType);
					
						toReturn.tupleof[i] = __traits(getAttributes, toReturn.tupleof[i])[0].convert(item);
					} 
					else 
					{
						static assert(0, "Field type mismatch: \n Field "
							   ~member~" was of type "~fieldType.stringof~
							   ", attribute was of type "~attributeType.stringof);
					}
				} 
				else 
				{
						goToNext!member;
						import std.conv;
						toReturn.tupleof[i] = as!fieldType;
				}
				// We want to search the whole object for every name.
				currentIndex = firstIndex;
			}
        }
        return toReturn;
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
            enforce(0, "Empty slot in array (arraycloser following arrayseparator)."
					~ getSDLError(range));
		}	
	} else if(range.front == arrayCloser) {
		range.popFront();
		return;
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
						   numberseven 	    = 0x1_0000"
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
						   freeColor = 0
						   title = |i am string|");

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

		auto stringBuf = new void[1024];
		auto allocString = RegionAllocator(stringBuf);
		assertEquals(obj.title.as!string(allocString), "i am string");
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
		assertEquals(check, source);
	}

	@Test public void testArrayAsList()
	{
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "arr = [1,2,4]");

		auto buf2 = new void[1024];
		auto alloc2 = RegionAllocator(buf2);
		auto list = List!long(alloc2, 3);
		list.put(1);
		list.put(2);
		list.put(4);

		auto sList = obj.arr.as!(List!long)(alloc2);

		assertEquals(sList, list);
	}

	@Test public void testOnlyArrayStruct()
	{

		struct ListStruct {
			List!long longList;
		}

		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "lstruct = { longList = [1,2,5] }");
	}

	@Test public void testStructWithLists()
	{
		struct ListStruct {
			List!long longList;
			int integer;
		}
		
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "lstruct = { 
						   longList=[1,2,5] 
						   integer=5
						   }");

		auto buf2 = new void[1024];
		auto alloc2 = RegionAllocator(buf2);
		auto list = List!long(alloc2, 3);
		list.put(1);
		list.put(2);
		list.put(5);
		auto ls = ListStruct(list, 5);

		auto sourceLs = obj.lstruct.as!(ListStruct)(alloc2);
		assertEquals(ls, sourceLs);
	}

	@Test public void testEnum()
	{

		enum Q {a,b,c}
		struct EnumStruct {
			Q enumField;
		}

		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "estruct = { enumField = a }");

		assertEquals(obj.estruct.enumField.as!Q, Q.a);
	}

	@Test public void testNoStringSeparators()
	{

		enum Q {a,b,c}

		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "teststring = { s = nowhitespace }");

		auto buf2 = new void[1024];
		auto alloc2 = RegionAllocator(buf2);

		assertEquals(obj.teststring.s.as!string(alloc2), "nowhitespace");
	}

	@Test public void testRecursiveStruct()
	{

		struct StructB
		{
			int i;
			int j;
		}

		struct StructC
		{
			string asdf;
		}

		struct StructA
		{
			StructB b;
			StructC c;
		}


		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		import collections.list;
		auto source = 
					"structa = {"
					~"	b = { i = 5 j = 3 }"
					~"	c = { asdf = asdf }"
					~"}";
		auto obj = fromSDL(app, source);

		auto a = StructA(StructB(5,3), StructC("asdf"));
		
		auto buf2 = new void[1024];
		auto alloc2 = RegionAllocator(buf2);
		
		assertEquals(a, obj.structa.as!StructA(alloc2));
	}

	@Test public void testStringArray()
	{
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		import collections.list;

		struct StructA  { string[] phoneResources; }
		auto source = 
			"phoneResources = [
			|achtung/scripts/main.lua|,
			|achtung/scripts/rendertime.lua|,
			|achtung/scripts/button.lua|,
			|achtung/scripts/rect.lua|,
			|achtung/fonts/Segoe54.fnt|,
			|achtung/fonts/Segoe54_0.png|,
			|achtung/textures/wallpaper.png|
			]";
		auto obj = fromSDL(app, source);

		auto a = StructA();
		a.phoneResources = [
			"achtung/scripts/main.lua",
			"achtung/scripts/rendertime.lua",
			"achtung/scripts/button.lua",
			"achtung/scripts/rect.lua",
			"achtung/fonts/Segoe54.fnt",
			"achtung/fonts/Segoe54_0.png",
			"achtung/textures/wallpaper.png"
			];

		auto buf2 = new void[1024];
		auto alloc2 = RegionAllocator(buf2);

		assertEquals(a, obj.as!StructA(alloc2));
	}

	@Test public void testColor()
	{
		import graphics.color;
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		import collections.list;

		struct StructA  { string[] phoneResources; }
		auto source = "packedValue = 0xFFFFFFFF";
		auto obj = fromSDL(app, source);

		assertEquals(Color(0xFFFFFFFF), obj.as!Color);
	}

	@Test public void testRecursiveList()
	{
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "arr = [[1,2,3],[4],[5]]");

		auto buf2 = new void[1024];
		auto alloc2 = RegionAllocator(buf2);
		auto list1 = List!long(alloc2, 3);
		list1.put(1);
		list1.put(2);
		list1.put(3);
		auto list2 = List!long(alloc2, 1);
		list2.put(4);
		auto list3 = List!long(alloc2, 1);
		list3.put(5);
		auto listOfLists = List!(List!long)(alloc2, 3);
		listOfLists.put(list1);
		listOfLists.put(list2);
		listOfLists.put(list3);

		auto sList = obj.arr.as!(List!(List!long))(alloc2);

		assertEquals(sList, listOfLists);
	}


	@Test public void testRecursiveArray()
	{
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		auto obj = fromSDL(app, "arr = [[1,2,3],[4],[5]]");

		long[][] arrOfArrs = [[1,2,3],[4],[5]];

		auto buf2 = new void[1024];
		auto alloc2 = RegionAllocator(buf2);

		auto sList = obj.arr.as!(long[][])(alloc2);

		assertEquals(sList, arrOfArrs);
	}

	@Test public void testNoWhiteSpaceDontEndWithSpace()
	{
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "teststring = { s = nowhitespace}"); // No space before } curly brace

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);

			assertEquals(obj.teststring.s.as!string(alloc2), "nowhitespace");
		}

		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "teststring = nowhitespace"); // sudden EOF while parsing identifier

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);

			assertEquals(obj.teststring.as!string(alloc2), "nowhitespace");
		}
	}

	@Test void testConversion()
	{
		import graphics;
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		struct TestStruct
		{
			@Convert!cFun() Color color;
		}
		auto obj = fromSDL(app, "color = 0xFF0000FF");
		assertEquals(obj.as!TestStruct, TestStruct(Color.red));
	}

	@Test void testConversionString()
	{
		import graphics;
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);
		struct TestStruct
		{
			@Convert!cFun2() int str;
		}
		auto obj = fromSDL(app, "str = |asdf4|");
		assertEquals(obj.as!TestStruct(GC.it), TestStruct(5));
	}

	@Test void testConversionStruct()
	{
		import graphics;
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);

		struct TestStruct
		{
			@Convert!cFun3() TestStruct2 str;
			@Convert!cFun3() TestStruct2 str2;
		}
		auto obj = fromSDL(app, "str = |asdf4| str2 = |asdf6|");
		assertEquals(obj.as!TestStruct(GC.it), TestStruct(TestStruct2(1,2), TestStruct2(1,2)));
	}

	@Test void testEmptyList()
	{
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);

		struct TestStruct
		{
			List!int ints;
			List!string strings;
		}
		auto obj = fromSDL(app, "ints = [] strings = []");
		assertEquals(TestStruct(), obj.as!TestStruct(GC.it));
	}

	@Test void testEmptyString()
	{
		auto buf = new void[1024];
		auto alloc = RegionAllocator(buf);
		auto app = RegionAppender!SDLObject(alloc);

		struct TestStruct
		{
			string str;
			string str2;
		}
		auto obj = fromSDL(app, "str = || str2 = ||");
		assertEquals(obj.as!TestStruct(GC.it), TestStruct());
	}
}

version(unittest) {		
	struct TestStruct2
	{
		int x, y;
	}
	//Global testing functions
	import graphics.color;
	Color cFun(uint c) { return Color(c); }
	int cFun2(string s) { return s.length; }
	TestStruct2 cFun3(string s) { return TestStruct2(1,2); }
}