module network.message;
import std.traits;
import util.bitmanip;
import network.server;

struct IncommingNetworkMessage
{
	ubyte id;
	alias id this;
}

struct OutgoingNetworkMessage
{
	ubyte id;
	ushort size = 0;

	alias id this;
}

template isOutgoingMessage(T)
{
	static if(__traits(getAttributes,T).length > 0)
		enum attribute = __traits(getAttributes, T)[0];
	else 
		enum attribute = null;
	alias type = OriginalType!(typeof(attribute));
	enum isOutgoingMessage = is(type == OutgoingNetworkMessage);
}

template isIncommingMessage(T)
{
	static if(__traits(getAttributes,T).length > 0)
		enum attribute = __traits(getAttributes, T)[0];
	else 
		enum attribute = null;
	alias type = OriginalType!(typeof(attribute));
	enum isIncommingMessage = is(type == IncommingNetworkMessage);
}

template messageID(T)
{
	enum messageID = __traits(getAttributes, T)[0].id;
}

//I am not sure this should be here. And i am sure that it should not be in this form. 

size_t writeMessage(T)(ubyte[] buf, T message)
{
	enum meta = __traits(getAttributes, T)[0];

	size_t offset = 2;
	buf.write!ubyte(meta.id, &offset);
	foreach(i, field; message.tupleof)
	{
		alias type = typeof(field);
		buf.write!type(field, &offset);
	}
	buf.write!ushort(cast(ushort)(offset -2), 0);
	return offset;
}

T readMessageContent(T)(ref ubyte[] buf) if(isIncommingMessage!T)
{
	T t;
	foreach(i, field; t.tupleof)
	{
		alias type = typeof(field);
		t.tupleof[i] =  buf.read!type;
	}

	return t;
}

void sendMessage(T)(Server* server, ulong id, T message) 
	if (isOutgoingMessage!T && hasIndirections!T)
{
	enum meta = __traits(getAttributes, T)[0];
	static if(meta.size == 0)
		ubyte[0xFFFF] buf = void;
	else
		ubyte[meta.size + ubyte.sizeof + ushort.sizeof] buf = void;
	
	auto length = buf.writeMessage(message);
	server.send(id, buf[0..length]);
}

void sendMessage(T)(Server* server, ulong id, T message) 
	if (isOutgoingMessage!T && !hasIndirections!T)
{
	ubyte[T.sizeof + ubyte.sizeof + ushort.sizeof] buf = void;
	auto length = buf.writeMessage(message);
	
	server.send(id, buf[0..length]);
}

unittest {
	//struct Message {
	//    enum meta = Message(5, Outgoing);
	//    uint content = 298;
	//}
	//
	//struct IncommingMessage {
	//    enum meta = Message(5, Incomming);
	//    uint content;
	//}
	//
	//struct IndirectMessage {
	//    enum meta = Message(234, Outgoing);
	//    enum maxSize = 7;
	//    string content = "saldf";
	//}
	//
	//ubyte[7] buf = void;
	//
	//Message msg;
	//buf.writeMessage(msg);
	//
	//auto readMsg = buf[3 .. $].readMessageContent!IncommingMessage;
	//assert(msg.content == readMsg.content);
	//assert(__traits(compiles, sendMessage(null, 234, Message())));
	//assert(__traits(compiles, sendMessage(null, 23, IndirectMessage())));
}

import network.message;
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
			static if(is(type == struct) && isOutgoingMessage!type) 
			{
				readers ~= luaReadMessage!type;
				incomming ~= luaIncommingMessage!type;
				decoders ~= luaDecoder!type;
			} 
			else static if(is(type == struct) && isIncommingMessage!type)
			{
				writers ~= luaWriteMessage!type;
				outgoing ~= luaOutgoingMessage!type;
			}
		}
	}

	return incomming ~ 
			 outgoing  ~ 
		    readers   ~ 
		    writers   ~
		    decoders; 
}

private string luaIncommingMessage(T)()
{
	import std.conv, std.string;
	enum id = __traits(getAttributes, T)[0].id;
	enum name = T.stringof[0 .. 1].toLower() ~ T.stringof[1 .. $];
	return "Network.incomming." ~ name ~  " = " ~ id.to!string ~ "\n";
}

private string luaOutgoingMessage(T)()
{
	import std.conv, std.string;
	enum id = __traits(getAttributes, T)[0].id;
	enum name = T.stringof[0 .. 1].toLower() ~ T.stringof[1 .. $];
	return "Network.outgoing." ~ name ~ " = " ~ id.to!string ~ "\n";
}

private string luaDecoder(T)()
{
	return "Network.decoders[Network.incoming." ~ T.stringof ~ "] = read" ~ T.stringof ~ "\n";
}

private string luaReadMessage(T)()
{
	string code = "function read" ~ T.stringof ~ "()\n\t";
	code ~= "local t = { }\n\t";
	foreach(i, field; T.init.tupleof)
	{
		alias type = typeof(field);
		enum  name = T.tupleof[i].stringof;
		code ~= "t." ~ name ~ " = " ~ luaReadType!type ~ "\n\t";
	}

	code ~= "return t\nend\n\n";
	return code;
}

private string luaWriteMessage(T)()
{
	import std.conv, network.message;

	string code = "function send" ~ T.stringof ~ "(";
	foreach(i, field; T.init.tupleof)
		code ~= T.tupleof[i].stringof ~ ",";
	code ~= ")\n";

	static if(__traits(compiles, isIndirectMessage!T))
		code ~= luaIndirectCalculateLength!T;
	else 
		code ~= "\tOut.writeShort(" ~ messageLength!T.to!string ~ ")\n";

	code ~= "\tOut.writeByte(" ~ T.id.to!string ~ ")\n";
	foreach(i, field; T.init.tupleof)
	{
		alias type  = typeof(field);
		enum  name  = T.tupleof[i].stringof;
		code ~= "\t" ~ luaWriteType!type(name) ~ "\n";
	}
	code ~= "end\n\n";
	return code;
}

private alias basic_types = TypeTuple!(byte, ubyte, short, ushort,
						 int, uint, long, ulong, 
						 float, double,
						 string, ubyte[]);

private enum names  = 
["Byte", "Byte",  "Short", "Short",
"Int",  "Int",   "Long",  "Long",
"Float","Double","UTF8","ByteArray"];

enum sizes = [ 1, 1, 2, 2, 4, 4, 8, 8, 4, 8 ];

import std.traits, std.typetuple;
private string luaReadType(T)()
{
	enum index = staticIndexOf!(T, basic_types);
	static assert(index != -1);

	return "In.read" ~ names[index] ~ "()";
}

private string luaWriteType(T)(string variable)
{
	enum index = staticIndexOf!(T, basic_types);
	static assert(index != -1);
	return "Out.write" ~ names[index] ~ "(" ~ variable ~ ")"; 
}

private string luaIndirectCalculateLength(T)()
{
	import std.conv;
	size_t size = 0;
	string code = "";
	foreach(i, field; T.init.tupleof)
	{
		alias type = typeof(field);
		enum  name = T.tupleof[i].stringof;
		static if(is(type == string) || is(type == ubyte[]))
		{
			size += 2;
			code ~= "\tsize = size + #" ~ name ~ "\n";
		} else 
			size += luaTypeSize!type;
	}

	code ~= "\tOut.writeShort(size)\n";
	return "\tlocal size = " ~ size.to!string ~ "\n" ~ code;
}

private size_t messageLength(T)()
{
	size_t length = 0;
	foreach(i, field; T.init.tupleof)
	{
		alias type = typeof(field);
		length += luaTypeSize!type;
	}
	return length + 1;
}

private size_t luaTypeSize(T)()
{

	enum index = staticIndexOf!(T, types);
	static assert(index != -1);
	return sizes[index];
}