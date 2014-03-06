module network.message;
import std.traits;
import util.bitmanip;
import network.server;

template isMessage(T)
{
	enum isMessageTrue = __traits(compiles, T.id)		&&
							is(typeof(T.id) == ubyte);

	static if (!__traits(compiles, T.id))
		static assert(0, "Messages has to have a enum named id."
					  ~"Type: "~ T.stringof);
	static if (!is(typeof(T.id) == ubyte))
		static assert(0, "Message id has to be of type ubyte. "
					  ~"Type: "~ T.stringof);

	enum isMessage = isMessageTrue;
}

template isIndirectMessage(T)
{
	enum isMessageTrue =	
					__traits(compiles, T.maxSize);

	static if (!__traits(compiles, T.maxSize))
		static assert(0, "Indirect messages need to have a maximal size. "~
						"Type: "~T.stringof);

	enum isIndirectMessage = isMessageTrue;
}

size_t writeMessage(T)(ubyte[] buf, T message)
if (isMessage!T)
{
	size_t offset = 2;
	buf.write!ubyte(T.id, &offset);
	foreach(i, field; message.tupleof)
	{
		alias type = typeof(field);
		buf.write!type(field, &offset);
	}
	buf.write!ushort(cast(ushort)(offset -2), 0);
	return offset;
}

void sendMessage(T)(Server* server, ulong id, T message)
if (isMessage!T && hasIndirections!T && isIndirectMessage!T)
{
	ubyte[T.maxSize + ubyte.sizeof + ushort.sizeof] buf = void;
	auto length = buf.writeMessage(message);
	
	server.send(id, buf[0..length]);
}

void sendMessage(T)(Server* server, ulong id, T message)
if (isMessage!T && !hasIndirections!T)
{
	ubyte[T.sizeof + ubyte.sizeof + ushort.sizeof] buf = void;
	auto length = buf.writeMessage(message);
	
	server.send(id, buf[0..length]);
}

unittest {
	struct Message {
		enum ubyte id = 5;
		uint content = 298;
	}

	struct IndirectMessage {
		enum ubyte id = 234;
		enum maxSize = 7;
		string content = "saldf";
	}

	ubyte[7] buf = void;
	buf.writeMessage(Message());
	sendMessage(null, 234, Message());
	sendMessage(null, 23, IndirectMessage());
}