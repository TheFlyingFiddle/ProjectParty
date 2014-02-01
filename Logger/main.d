import std.stdio;


import content.sdl;
import std.socket;
import logging;
import allocation;

struct LogConfig
{
	ushort port;
}


void main()
{
	tcpLogging();
}

void tcpLogging()
{
	auto config = fromSDLFile!LogConfig(GCAllocator.it, "config.sdl");

	Socket listener = new TcpSocket();
	listener.bind(new InternetAddress(InternetAddress.ADDR_ANY, config.port));
	listener.listen(1);


	import std.concurrency;
	Tid tid = spawn(&handleFiles, 2000);

	try 
	{
		while(true)
		{
			auto socket = listener.accept();

			ubyte[] buffer = new ubyte[1024 * 1024 * 10];
			ubyte[] tmp = new ubyte[1024];

			while(true)
			{
				auto r = socket.receive(buffer);
				if(r == 0 || r == Socket.ERROR) break;
				while(r)
				{
					auto len = buffer.read!uint();
					if(len > buffer.length)
					{
						tmp[0 .. buffer.length] = buffer;
						uint tmpLen = buffer.length;
						buffer = new ubyte[1024 * 1024 * 10];

						r += socket.receive(buffer);

						tmp[tmpLen .. len] = buffer[0 .. len - tmpLen];
						immutable(ubyte)[] buff = cast(immutable(ubyte)[])tmp[0 .. len];
						send(tid, buff);
						buffer = buffer[len - tmpLen .. $];
					}

					immutable(ubyte)[] buff = cast(immutable(ubyte)[])buffer[0 .. len];
					send(tid, buff);
					buffer = buffer[len .. $];

					r -= len + uint.sizeof;

					if(r < 0)
						writeln("nooo!!!");
				}

			}
		}
	}
	catch(Throwable t)
	{
		import std.stdio;
		writeln(t);
	}
}

void handleFiles(size_t bufferSize)
{
	import std.concurrency;

	struct LogMsg
	{
		string c;
		uint v;
		string m;
		string f;
		uint l;
	}

	LogMsg[] toLog = new LogMsg[bufferSize];
	uint count;
	
	while(true) {
		receive(
		(immutable(ubyte)[] buffer)
		{
			ubyte[] buff = cast(ubyte[])buffer;

			toLog[count].c   = read!string(buff);
			toLog[count].v	 = read!uint(buff);
			toLog[count].m   = read!string(buff);
			toLog[count].f   = read!string(buff);
			toLog[count].l   = read!uint(buff);

			count++;
			if(count == toLog.length)
			{
				count = 0;
				foreach(msg; toLog)
					logMsg(msg.c, cast(Verbosity)msg.v, 
						   msg.m, msg.f, msg.l);
			}

		});
	}
}



import std.traits;
T read(T)(ref ubyte[] buffer) if(!isArray!T)
{
	T t = *cast(T*)&buffer[0];
	buffer = buffer[T.sizeof .. $];
	return t;
}

T read(T)(ref ubyte[] buffer) if(isArray!T)
{
	uint len = read!uint(buffer);
	T t;
	t = cast(T)(buffer[0 .. len * typeof(t[0]).sizeof]);
	buffer = buffer[len * typeof(t[0]).sizeof .. $];
	return t;
}


private void logMsg(string channel, 
					Verbosity verbosity, 
					string msg, 
					string file, 
					size_t line) 
{
	import std.format, std.array, std.file;

	char[128] pathBuffer;
	auto pathSink = Appender!(char[])(pathBuffer);
	pathSink.clear();

	char[1024] buffer;
	auto sink = Appender!(char[])(buffer);
	sink.clear();

	pathSink.put("..\\logging\\");
	pathSink.put(channel);
	pathSink.put(".txt");

	auto filePath = pathSink.data;
	formattedWrite(sink, "%s %s (%s)\n\n",
					msg, file, line);

	if(!exists(filePath) || getSize(filePath) > 1024 * 10)
		write(filePath, sink.data);
	else 
		append(filePath, sink.data);
}