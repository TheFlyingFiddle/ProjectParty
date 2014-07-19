module network.message;
import std.traits;
import util.bitmanip;
import network.server;
import util.hash;
import log;

struct InMessage { }
struct OutMessage { }
struct InoutMessage { }

alias Alias(T) = T;
template isOutMessage(T)
{
	static if(__traits(getAttributes,T).length > 0)
		alias type = Alias!(__traits(getAttributes, T)[0]);
	else 
		alias type = void;
	enum isOutMessage = is(type == OutMessage) || is(type == InoutMessage);
}

template isInMessage(T)
{
	static if(__traits(getAttributes,T).length > 0)
		alias type = Alias!(__traits(getAttributes, T)[0]);
	else 
		alias type = void;
	enum isInMessage = is(type == InMessage) || is(type == InoutMessage);
}

template isIndirectMessage(T)
{
	enum isIndirectMessage = hasIndirections!T;
}

//I am not sure this should be here. And i am sure that it should not be in this form. 

size_t writeMessage(T)(ubyte[] buf, T message)
{
	size_t offset = 2;
	buf.write!ushort(shortHash!(T).value, &offset);
	foreach(i, field; message.tupleof)
	{
		alias type = typeof(field);
		buf.write!type(field, &offset);
	}
	buf.write!ushort(cast(ushort)(offset -2), 0);
	return offset;
}

T readMessageContent(T)(ref ubyte[] buf) if(isInMessage!T)
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
	if (isOutMessage!T && hasIndirections!T)
{
	ubyte[0xFFFF] buf = void;
	
	auto length = buf.writeMessage(message);
	server.send(id, buf[0..length]);
}

void sendMessage(T)(Server* server, ulong id, T message) 
	if (isOutMessage!T && !hasIndirections!T)
{
	ubyte[T.sizeof + ushort.sizeof + ushort.sizeof] buf = void;
	auto length = buf[].writeMessage(message);
	
	server.send(id, buf[0..length]);
}

unittest {
	//struct Message {
	//    enum meta = Message(5, Outgoing);
	//    uint content = 298;
	//}
	//
	//struct InMessage {
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
	//auto readMsg = buf[3 .. $].readMessageContent!InMessage;
	//assert(msg.content == readMsg.content);
	//assert(__traits(compiles, sendMessage(null, 234, Message())));
	//assert(__traits(compiles, sendMessage(null, 23, IndirectMessage())));
}