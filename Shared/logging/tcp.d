module logging.tcp;

import logging;
import std.socket;
import std.array;
import content.sdl;
import std.concurrency;
import allocation.gc;

Socket socket;
NetConfig config;

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
	import allocation;

	//logger = &tcpLogger;
    config = fromSDLFile!NetConfig(GCAllocator.it, configFile);    
	buffer = cast(ubyte[])Mallocator.it.allocate(config.bufferSize, 8);

	import std.stdio;
	writeln("Trying to connect to the logger!");
	writeln(config);
	socket = new TcpSocket();
	//socket.connect(getAddress(config.ip, config.port)[0]);
}

void tcpLogger(string channel, Verbosity verbosity, const(char)[] msg, string file, size_t line) nothrow
{
	scope(failure) return;

	if(!socket.isAlive())
	{
		socket.close();
		socket = new TcpSocket(new InternetAddress(config.ip, config.port));
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
			   a message to the logging application!\n %s", e.msg);
	}
}

import std.traits;

uint write(T)(ref ubyte[] buffer, uint offset, T value) if(!isArray!T)
{
	*(cast(uint*)&buffer[offset]) = value;
	offset += T.sizeof;
	return offset;
}

uint write(T)(ref ubyte[] buffer, uint offset, T value) if(isArray!T)
{
	offset = buffer.write!uint(offset, value.length);
	(buffer[offset .. offset + typeof(value[0]).sizeof * value.length])[] 
		= cast(ubyte[])value;

	offset += typeof(value[0]).sizeof * value.length;
	return offset;
}
