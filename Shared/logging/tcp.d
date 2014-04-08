module logging.tcp;

import logging;
import std.socket;
import std.array;
import content.sdl;
import std.concurrency;
import allocation;

Socket socket;
Address address;

ubyte[] buffer;
uint taken;

struct NetConfig
{
	string ip;
	ushort port;
	uint bufferSize;
}

void initializeTcpLogger(string configFile)
{
	scope(failure) 
	{
		logger = &fallbackLogger;
		return;
	}

	auto config = fromSDLFile!NetConfig(GC.it, configFile);    

	logger = &tcpLogger;
    buffer = GC.it.allocate!(ubyte[])(config.bufferSize, 8);

	socket  =  GC.it.allocate!TcpSocket;
	address =  getAddress(config.ip, config.port)[0];

	socket.connect(address);
}

void fallbackLogger(string channel, Verbosity verbosity, const(char)[] msg, string file, size_t line) nothrow
{
	import std.stdio;
	scope(failure) return;

//	if(channel == "PROFILE") return;

//	writeln(channel, "   ", msg, "    ", file, "(", line, ")");
}


void tcpLogger(string channel, Verbosity verbosity, const(char)[] msg, string file, size_t line) nothrow
{
	scope(failure) return;

	if(!socket.isAlive())
	{
		socket.close();
		socket = GC.it.allocate!TcpSocket(address);
	}

	try 
	{
		ubyte[] buff = buffer[taken .. $];
		uint offset;
		offset = buff.write(offset, 0);
		offset = buff.write(offset, channel);
		offset = buff.write(offset, cast(uint)verbosity);
		offset = buff.write(offset, msg);
		offset = buff.write(offset, file);
		offset = buff.write(offset, line);
		buff.write(0, offset - uint.sizeof);
		
		taken += offset;

		if(taken > 8192 - 1024) 
		{
			socket.send(buffer[0 .. taken]);
			taken = 0;
		}
	}
	catch(Exception e)
	{
		import std.c.stdio;
		printf("An exception was thrown while sending
			   a message to the logging application!\n %s", e.msg.ptr);
	}
}

import std.traits;

uint write(T)(ref ubyte[] buffer, uint offset, T value) if(!isArray!T)
{
	*(cast(uint*)&buffer[offset]) = cast(uint)value;
	offset += T.sizeof;
	return offset;
}

uint write(T)(ref ubyte[] buffer, uint offset, T value) if(isArray!T)
{
	offset = buffer.write!uint(offset, cast(uint) value.length);
	(buffer[offset .. offset + typeof(value[0]).sizeof * value.length])[] 
		= cast(ubyte[])value;

	offset += typeof(value[0]).sizeof * value.length;
	return offset;
}
