module network.luagen;

import network.message;
import math;
import util.hash;
import std.conv;
import std.conv, std.string;

string generateLuaCode(alias module_)()
{
	string readers   = "local in_ = networkReaders\n";
	string writers   = "local out = networkWriters\n";
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
		writers; 
}

string luaInMessage(T)()
{
	enum id = shortHash!T;
	enum name = T.stringof[0 .. 1].toLower() ~ T.stringof[1 .. $];
	return "NetIn." ~ name ~  " = " ~ id.value.to!string ~ "\n";
}

string luaOutMessage(T)()
{
	import std.conv, std.string;
	enum id = shortHash!T;
	enum name = T.stringof[0 .. 1].toLower() ~ T.stringof[1 .. $];
	return "NetOut." ~ name ~ " = " ~ id.value.to!string ~ "\n";
}

string luaReadMessage(T)()
{
	enum tName = T.stringof[0 .. 1].toLower() ~ T.stringof[1 .. $];
	string code = "in_[NetIn." ~ tName ~ "] = function (buf)\n\t";
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

string luaWriteDebug(T)(string name, string table, string msgName) if(isBaseType!T)
{
	return text("if not ", table, "." , name, " then\n\t\t",
				"error(\"Bad message for network message ", msgName,
				" : ", table, ".", name, " of type ", T.stringof,
				" should be present\")\n\tend\n\n\t");
}

string luaWriteDebug(T)(string name, string table, string msgName) if(!isBaseType!T)
{
	string code = text("if not ", table, "." , name, " then\n\t\t",
				       "error(\"Bad message for network message ", msgName,
				        " : ", table, ".", name, " of type ", T.stringof,
				        " should be present\")\n\tend\n\n\t");

	foreach(i, field; T.init.tupleof)
	{
		alias type  = typeof(field);
		enum  fName  = T.tupleof[i].stringof;
		code ~= luaWriteDebug!type(fName, table ~ "." ~ name, msgName);
	}

	return code;
}

string luaWriteMessage(T)()
{
	import std.conv, network.message;

	enum tName = T.stringof[0 .. 1].toLower() ~ T.stringof[1 .. $];
	string code = "out[NetOut." ~ tName  ~ "] = function(buf, t)\n\t";
	

	debug
	{
		foreach(i, field; T.init.tupleof)
		{
			alias type  = typeof(field);
			enum  name  = T.tupleof[i].stringof;
			code ~= luaWriteDebug!type(name, "t", T.stringof);
		}
	}


	static if(isIndirectMessage!T)
		code ~= luaIndirectCalculateLength!T;
	else 
	{
		debug
		{
			code ~= 
				"if " ~ messageLength!T.to!string ~ " > C.bufferBytesRemaining(buf) then 
				error(\"To little buffer space left!\")
				end\n\t";
		}
		code ~= "C.bufferWriteShort(buf," ~ messageLength!T.to!string ~ ")\n\t";
	}

	code ~= "C.bufferWriteShort(buf," ~ shortHash!T.value.to!string ~ ")\n\t";
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
							   ubyte[], string, float2, float3, float4,
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


string luaReadType(T)(string name, string table) if(is(T == string))
{
	return text(table, ".", name, " = ffi.string(C.bufferReadTempUTF8(buf))\n\t");
}

string luaReadType(T)(string name, string table) if (isBaseType!T && !is(T == string))
{
	enum index = staticIndexOf!(T, basic_types);
	static assert(index != -1);
	return text(table,".",name," = C.bufferRead", names[index], "(buf)\n\t");
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
	return "C.bufferWrite" ~ names[index] ~ "(buf, " ~ table ~ "." ~ variable ~ ")\n\t"; 
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
		static if(isSomeString!type || is(type == ubyte[]))
		{
			size += 2;
			code ~= text("size = size + #t.",name,"\n\t");
		} else static if(isIndirectMessage!type) {
			code ~= luaIndirectCalculateLength!type(size, "t."~name);
		} else {
			size += type.sizeof;
		}
	}

	debug
	{
		code ~= 
		"if size > C.bufferBytesRemaining(buf) then 
		    error(\"To little buffer space left!\")
		end\n\t";
	}

	code ~= "C.bufferWriteShort(buf, size)\n\t";
	return text("local size = ", size,"\n\t",code);
}

string luaIndirectCalculateLength(T)(ref size_t size, string table)
{
	string code = "";
	foreach(i, field; T.init.tupleof)
	{
		alias type = typeof(field);
		enum  name = T.tupleof[i].stringof;
		static if(isSomeString!type || is(type == ubyte[]))
		{
			size += 2;
			code ~= "size = size + #" ~ table ~ "." ~ name ~ "\n\t";
		} else static if(isIndirectMessage!type) {
			code ~= luaIndirectCalculateLength!type(size, table~"."~name);
		} else {
			size += type.sizeof;
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