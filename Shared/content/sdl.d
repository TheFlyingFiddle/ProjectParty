module content.sdl;

import std.exception;
import std.conv : to;
import std.range;
import std.traits;

enum stringSeperator = '|';
enum arrayOpener = '[';
enum arrayCloser = ']';
enum arraySeparator = ',';
enum objectOpener = '{';
enum objectCloser = '}';

struct SDLObject
{
	//An array item is an item in an array (it has no name)
	enum Type { number, string_, array, object, integer }

	string name; //Not used by stuff in array. (Could do it some other way but meh)
	union
	{		
		double				_number = 0;
        long                _integer;
		string				string_;
		SDLObject[]			collection;
	}

	Type type;

	@property double number()
	{
		if(type == Type.integer)
			return integer;
		else if(type == Type.number) 
			return _number;

		assert(0, "The SDLObject is a " ~ type.to!string ~ " " ~ "and not a number!");
	}

	@property long integer()
	{
		assert(type == Type.integer);
		return _integer;
	}

	@property size_t length()
	{
		assert(type == SDLObject.Type.array ||
			   type == SDLObject.Type.object);
		return collection.length;
	}


	this(long value, string name) 
	{
		this.type   = Type.integer;
		this.name   = name;
		this._integer= value;
	}

	this(double value, string name)
	{
		this.type   = Type.number;
		this.name	= name;
		this._number	= value;
	}

	this(string value, string name)
	{
		this.type    = Type.string_;
		this.name    = name;
		this.string_ = value;
	}

	this(string name)
	{
		this.type = Type.object;
		this.name = name;
		this.collection.length = 0;
	}

	this(SDLObject[] array, string name)
	{
		this.type = Type.array;
		this.name = name;
		this.collection = array;
	}

	this(SDLObject obj, string name)
	{
		this.type = obj.type;
		this.name = name;
		this.collection = obj.collection;
	}

	this(T)(T val, string name)
	{
		this.type = Type.array;
		this.name = name;
		this.collection = new SDLObject[val.length];
		foreach(i, ref item; collection)
			item = SDLObject(val[i], ""); 
	}

	ref SDLObject opIndex(size_t index) 
	{
		enforce(type == Type.array);
		return collection[index];
	}

	void opDispatch(string name, T)(T value)
	{
		set(name, value);
	}

	ref SDLObject opDispatch(string name)()
	{
		enforce(type == Type.object);
		foreach(ref item; collection)
			if(item.name == name)
				return item;

		enforce(0, "Item not found");
		assert(0);
	}

	void set(T)(string name, T value)
	{
		enforce(type == Type.object);
		foreach(ref item; collection)
			if(item.name == name) {
				item = SDLObject(value, name);
				return;
			}

		this.collection ~= SDLObject(value, name);
	}

    import std.typecons;
    import math.vector;
    import math.traits;

	Vec get(Vec)() if ( isVector!Vec)
	{
        static if (is(Vec v == Vector!(len, U), int len, U)) {
            enum dimensions = ["x","y","z","w"]; // This is at the same time the vector rep and the file rep. Change.
            auto toReturn = Vec();
            foreach(i;math.vector.staticIota!(0, len)) {
                foreach(ref item; collection) {
                    if(item.name == dimensions[i]) {
                        static if (isFloatingPoint!U) 
                            mixin("toReturn." ~ dimensions[i]) =  cast(U)item.number;
                        else 
                            mixin("toReturn." ~ dimensions[i]) =  cast(U)item.integer;
                    }
                }
            }
            return toReturn;
        } else assert(0, Vec.stringof ~ " is not a vector type.");
	}

    unittest {
		import std.stdio;
        auto obj = fromSDL("
                           pos = 
                           {
						   x = 4
						   y = 5
                           }
                           floats =
                           {
						   x = 234.2
						   y = 123.4
                           }"
                           );

        auto vec = obj.pos.get!int2;
        auto vecFloat = obj.floats.get!float2;
        assert(vec == int2(4,5));
        assert(vecFloat == float2(234.2f,123.4f));
    }
}

void toSDL(T, Sink)(T value, Sink sink, int level = 0) if(is(T == struct))
{
	if(level != 0) {
		sink.put('\n');
		sink.put('\t'.repeat(level - 1));
		sink.put(objectOpener);
	}

	foreach(i, field; value.tupleof) {
		sink.put('\n');
		sink.put('\t'.repeat(level));
		sink.put(__traits(identifier, T.tupleof[i]));
		sink.put("=");
		toSDL(field, sink, level + 1);
	}

	if(level != 0){
		sink.put('\n');
		sink.put('\t'.repeat(level - 1));
		sink.put(objectCloser);
	}
}

void toSDL(T, Sink)(T value, Sink sink, int level = 0) if(is(T == string))
{
	sink.put(stringSeperator);
	sink.put(value);
	sink.put(stringSeperator);
}

void toSDL(T, Sink)(T value, Sink sink, int level = 0) if(is(T : double))
{
	sink.put(value.to!string);
}

void toSDL(T, Sink)(T value, Sink sink, int level = 0) if(isArray!T && !is(T == string))
{
	sink.put(arrayOpener);
	foreach(i; 0 .. value.length) {
		toSDL(value[i], sink, level);
		if(i != value.length - 1)
			sink.put(',');
	}
	sink.put(arrayCloser);
}

void toSDL(Sink)(SDLObject obj, Sink sink)
{
	alias T = SDLObject.Type;

	if(obj.name != "") {
		sink.put(obj.name);
		sink.put('=');
	}
	final switch(obj.type) 
	{
		case T.number:
			sink.put( obj.number.to!string );
			break;
		case T.string_:
			sink.put(stringSeperator);
			sink.put( obj.string_);
			sink.put(stringSeperator);
			break;
		case T.array  :
		case T.object :
			toSDL_inner(obj, sink);
			break;
	}
}

void toSDL_inner(Sink)(SDLObject obj, Sink sink)
{
	alias T = SDLObject.Type;
	final switch(obj.type)
	{
		case T.number:
			sink.put( obj.number.to!string); //Allocates :S
			break;
		case T.string_:
			sink.put(stringSeperator);
			sink.put( obj.string_);
			sink.put(stringSeperator);
			break;
		case T.array:
			sink.put(arrayOpener);
			scope(exit) sink.put(arrayCloser);
			foreach(i, item; obj.collection) {
				toSDL_inner(item, sink);	
				if(i != obj.collection.length - 1)
					sink.put(arraySeparator);
			}
			break;
		case T.object:
			if(obj.name != "")
				sink.put(objectOpener);
			foreach(item; obj.collection) {
				sink.put(item.name);
				sink.put('=');
				toSDL_inner(item, sink);
			}
			if(obj.name != "")
				sink.put(objectCloser);
			break;
	}

}

void skipLine(Range)(ref Range range)
{
	while(!range.empty && 
		  range.front != '\n' &&
		  range.front != '\r')
	{
		range.popFront();
	}	
}	

void skipWhitespace(Range)(ref Range range)
{
	while(!range.empty && (
						   range.front == '\n' ||
						   range.front == '\r' ||
						   range.front == '\t' ||
						   range.front == ' '))
	{
		range.popFront();
	}

	if (!range.empty && range.front == '/')
	{
		range.skipLine();
		range.skipWhitespace();
	}
}

SDLObject fromSDL(string source)
{
	return fromSDL(ForwardRange(source));
}

SDLObject fromSDL(Range)(Range range)
{
	range.skipWhitespace();
	SDLObject root = range.readObject();
	return root;
}

SDLObject readObject(Range)(ref Range range)
{
	SDLObject obj;
	obj.type = SDLObject.Type.object;

	string ident;
	while(!range.empty)
	{
		range.skipWhitespace();
		if(range.front == objectCloser) {
			range.popFront();
			return obj;
		}

		ident = range.readIdentifier();
		range.skipWhitespace();
		enforce(range.front == '=');
		range.popFront();

		skipWhitespace(range);

        auto c = range.front;

		switch(c)
		{
			case objectOpener:
				range.popFront();
				obj.set(ident, range.readObject());
				break;
			case arrayOpener:
				range.popFront();
				obj.set(ident, range.readArray());
				break;
			case '0' : .. case '9':
            case '-' :
			case '.' :
				readNumber(range, obj, ident);
				//obj.set(ident, range.readNumber());
				break;
			case stringSeperator:
				obj.set(ident, range.readString());
				break;
			case '/':
				skipLine(range);
				break;

			default :
				enforce(0, "Unrecognized char while parsing array.");		
		}

		range.skipWhitespace();
	}

	return obj;
}

SDLObject[] readArray(Range)(ref Range range)
{
	SDLObject[] arr;
	while(!range.empty)
	{
		range.skipWhitespace();		
		if(range.front == arrayCloser) {
			range.popFront();
			return arr;
		}
		char c = range.front;
		switch(range.front)
		{
			case objectOpener:
				range.popFront();
				arr ~= range.readObject();
				break;
			case arrayOpener:
				range.popFront();
				arr ~= SDLObject(range.readArray(), "");
				break;
			case '0' : .. case '9':
			case '.' :
				//arr ~= SDLObject(range.readNumber(), "");
                auto obj = SDLObject();
                readNumber(range, obj, "");
                arr ~= obj;
				break;
			case stringSeperator:
				arr ~= SDLObject(range.readString(), "");
				break;
			case arraySeparator:
				range.popFront();
				break;
			case '/':
				skipLine(range);
				break;
			default :
				enforce(0, "Unrecognized char");		
		}

        range.skipWhitespace();
	}

	enforce(0, "EOF reached while parsing array");
	assert(0);
}

string readIdentifier(Range)(ref Range range)
{
	auto saved = range.save();
	while(!range.empty)
	{
		char c = range.front;
		if(c == '\n' || c == '\t' 
		   || c == '\r' || c == ' ' || 
		   c == '='||
		   c == '/') {
			   return str(saved, range);
		   }

		range.popFront();
	}

	enforce(0, "EOF while reading identifier");
	assert(0);
}

string readString(Range)(ref Range range)
{
	enforce(range.front == stringSeperator);
	range.popFront();
	auto saved = range.save();
	while(!range.empty) {
		if(range.front == stringSeperator)  {
			string s = str(saved, range);
			range.popFront();
			return s;
		}
		range.popFront();
	}

	enforce(0, "Eof reached while parsing string!");
	assert(0);
}

void readNumber(Range)(ref Range range, ref SDLObject obj, string identifier)
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
	auto saved = range;
	range.popFront();
	while(!range.empty)
	{
		char c = range.front;
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

    import std.conv;
    switch (state) {
        case 1:
        case 7://Integer
            obj.set(identifier, number!long(saved, range));
            break;
        case 9://Hexadecimal
            string s = saved.over[saved.position .. range.position];
			obj.set(identifier, parseHex(s));
            break;
        case 3:
        case 6://Floating point
            obj.set(identifier, number!double(saved, range));
            break;
        default:
			assert(0, "Invalid number parsing state: " ~ to!string(state));
	}

} unittest {
    import std.stdio;
    auto obj = fromSDL("
					   numberone 	    = 123456
					   numbertwo 	    = 1234.234
					   numberthree      = 1234.34e234
					   numberfour 	    = 1234.34E-234
					   numberfive 	    = -1234
					   numbersix 	    = 0xfF
					   numberseven 	    = 0x10000"
                       );

	assert(obj.numberone 	 .integer    == 123456);
	assert(obj.numbertwo 	 .number     == 1234.234);
	assert(obj.numberthree   .number     == 1234.34e234);
	assert(obj.numberfour 	 .number     == 1234.34E-234);
	assert(obj.numberfive 	 .integer    == -1234);
	assert(obj.numbersix 	 .integer    == 0xfF);
	assert(obj.numberseven 	 .integer    == 0x10000);
}

string str(Range)(Range a, Range b)
{
	return a.over[a.position .. b.position];
}

T number(T, Range)(Range a, Range b)
if(isNumeric!T)
{
	return a.over[a.position .. b.position].to!T;
}

long parseHex(string a)
{
    enforce(a[0] == '0', "Hexadecimal strings should start with 0");
    enforce(a[1] == 'x' || a[1] == 'X');
    long acc = 0;
    for(int i = 2; i<a.length; i++) {
        auto c =  a[i];
        switch ( c) {
            case '0': .. case '9':
                acc += to!long(c - '0') * 16^^(a.length - 1 - i);
                break;
            case 'a': .. case 'f':
                acc += to!long(c - 'a' + 10) * 16^^(a.length - 1 - i);
                break;
            case 'A': .. case 'F':
                acc += to!long(c - 'A' + 10) * 16^^(a.length - 1 - i);
                break;
            default:
                assert(0, "Invalid hexadecimal digit: " ~ to!string(c));
		}
	}
    return acc;
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