module util.strings;

import util.hash;
import std.conv;
import std.exception;


static char[1024] c_buffer;
char* toCString(const char[] str, char[] output = c_buffer) 
{
	output[0 .. str.length] = str[];
	output[str.length] = '\0';
	return output.ptr;
}

//Should not be gc collected? Or maby it should.
//Should this be __gshared?
__gshared string[uint] strings;

struct StringID
{
	uint hash;
	alias toString this;

	this(const(char[]) str)
	{
		this.hash = id(str);
	}

	this(const(char[]) str)()
	{
		this.hash = id!(str);
	}

	string toString()
	{
		return strings[hash];
	}

	bool opEquals(StringID other)
	{
		return hash == other.hash;
	}
}

private uint id(const(char[]) s)()
{
	enum hash = bytesHash(cast(const(void*))s.ptr, s.length, 0);
	return id(s, hash);	
}

private uint id(const(char[]) s)
{
	auto hash = bytesHash(cast(const(void*))s.ptr, s.length, 0);
	return id(s, hash);
}

private uint id(const(char[]) s,  uint hash)
{
	auto str = strings.get(hash, null);
	if(str is null)
		strings[hash] = s.idup;
	else enforce(str == s, "Hash collision detected! between " ~ s ~ " and " ~ str ~ " with hash " ~ hash.to!string);
	return hash;
}