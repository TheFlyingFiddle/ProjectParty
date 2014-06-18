module network.luagen;

import network.message;
import math;
import util.hash;
string generateLuaCode(alias module_)()
{
	string readers   = "";
	string writers   = "";
	string decoders  = "";
	string incomming = "";
	string outgoing  = "";

	foreach(member; __traits(allMembers, module_))
	{
		static if(__traits(compiles, __traits(getMember, module_, member)))
		{
			alias type = TypeTuple!(__traits(getMember, module_, member))[0];
			static if(is(type == struct) && isOutMessage!type) 
			{
				readers ~= luaReadMessage!type;
				incomming ~= luaInMessage!type;
				decoders ~= luaDecoder!type;
			} 
			static if(is(type == struct) && isInMessage!type)
			{
				writers ~= luaWriteMessage!type;
				outgoing ~= luaOutMessage!type;
			}
		}
	}

	return incomming ~ 
		outgoing  ~ 
		readers   ~ 
		writers   ~
		decoders; 
}

string luaInMessage(T)()
{
	import std.conv, std.string;
	enum id = shortHash!T;
	enum name = T.stringof[0 .. 1].toLower() ~ T.stringof[1 .. $];
	return "Network.incomming." ~ name ~  " = " ~ id.to!string ~ "\n";
}

string luaOutMessage(T)()
{
	import std.conv, std.string;
	enum id = shortHash!T;
	enum name = T.stringof[0 .. 1].toLower() ~ T.stringof[1 .. $];
	return "Network.outgoing." ~ name ~ " = " ~ id.to!string ~ "\n";
}

string luaDecoder(T)()
{
	return "Network.decoders[Network.incoming." ~ T.stringof ~ "] = read" ~ T.stringof ~ "\n";
}

string luaReadMessage(T)()
{
	string code = "function read" ~ T.stringof ~ "()\n\t";
	code ~= "local t = { }\n\t";
	foreach(i, field; T.init.tupleof)
	{
		alias type = typeof(field);
		enum  name = T.tupleof[i].stringof;
		code ~= luaReadType!type(name, "t");
	}

	code ~= "return t\nend\n\n";
	return code;
}

string luaWriteMessage(T)()
{
	import std.conv, network.message;

	string code = "function send" ~ T.stringof ~ "(t)\n\t";

	static if(isIndirectMessage!T)
		code ~= luaIndirectCalculateLength!T;
	else 
		code ~= "Out.writeShort(" ~ messageLength!T.to!string ~ ")\n\t";

	code ~= "Out.writeShort(" ~ shortHash!T.to!string ~ ")\n\t";
	foreach(i, field; T.init.tupleof)
	{
		alias type  = typeof(field);
		enum  name  = T.tupleof[i].stringof;
		code ~= luaWriteType!type(name, "t");
	}
	code ~= "end\n\n";
	return code;
}

import math;
alias basic_types = TypeTuple!(byte, ubyte, short, ushort,
							   int, uint, long, ulong, 
							   float, double,
							   string, ubyte[],
							   float2, float3, float4,
							   uint2, uint3, uint4,
							   ushort2, ushort3, ushort4);

enum names  = 
["Byte", "Byte",  "Short", "Short",
"Int",  "Int",   "Long",  "Long",
"Float","Double","UTF8","ByteArray",
"Float2", "Float3", "Float4",
"Int2", "Int3", "Int4",
"Short2", "Short3", "Short4"];

import std.traits, std.typetuple;

enum isBaseType(T) = staticIndexOf!(T, basic_types) != -1;

string luaReadType(T)(string name, string table) if (isBaseType!T)
{
	enum index = staticIndexOf!(T, basic_types);
	static assert(index != -1);
	return table~"."~name~" = In.read" ~ names[index] ~ "()\n\t";
}

string luaReadType(T)(string name, string table) if (!isBaseType!T && is(T == struct))
{
	string s = table~"."~name~" = { }\n\t";

	foreach(i, field; T.init.tupleof)
	{
		alias Type = typeof(field);
		enum varName = T.tupleof[i].stringof;
		s ~= luaReadType!Type(varName, table~"."~name);
	}
	return s;
}

string luaWriteType(T)(string variable, string table) if (isBaseType!T)
{
	enum index = staticIndexOf!(T, basic_types);
	static assert(index != -1);
	return "Out.write" ~ names[index] ~ "(" ~ table ~ "." ~ variable ~ ")\n\t"; 
}

string luaWriteType(T)(string name, string table) if (!isBaseType!T && is(T == struct))
{
	string s = "";

	foreach(i, field; T.init.tupleof)
	{
		alias Type = typeof(field);
		enum varName = T.tupleof[i].stringof;
		s ~= luaWriteType!Type(varName, table~"."~name);
	}
	return s;
}

string luaIndirectCalculateLength(T)()
{
	import std.conv;
	size_t size = 2;
	string code = "";
	foreach(i, field; T.init.tupleof)
	{
		alias type = typeof(field);
		enum  name = T.tupleof[i].stringof;
		static if(is(type == string) || is(type == ubyte[]))
		{
			size += 2;
			code ~= "size = size + #t." ~ name ~ "\n\t";
		} else static if(isIndirectMessage!type) {
			code ~= luaIndirectCalculateLength!type(size, "t."~name);
		} else {
			code ~= type.sizeof;
		}
	}

	code ~= "Out.writeShort(size)\n\t";
	return "local size = " ~ size.to!string ~ "\n\t" ~ code;
}

string luaIndirectCalculateLength(T)(ref size_t size, string table)
{
	string code = "";
	foreach(i, field; T.init.tupleof)
	{
		alias type = typeof(field);
		enum  name = T.tupleof[i].stringof;
		static if(is(type == string) || is(type == ubyte[]))
		{
			size += 2;
			code ~= "size = size + #" ~ table ~ "." ~ name ~ "\n\t";
		} else static if(isIndirectMessage!type) {
			code ~= luaIndirectCalculateLength!type(size, table~"."~name);
		} else {
			code ~= type.sizeof;
		}
	}
	return code;
}

size_t messageLength(T)()
{
	size_t length = 0;
	foreach(i, field; T.init.tupleof)
	{
		alias type = typeof(field);
		length += type.sizeof;
	}
	return length + 2;
}