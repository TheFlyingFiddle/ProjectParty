import std.stdio;


import content.sdl;
import std.socket;
import logging;
import allocation;

struct LogConfig
{
	ushort port;
	string loggerDir;
}


void main()
{
	tcpLogging();
}

void tcpLogging()
{
	auto config = fromSDLFile!LogConfig(GC.it, "config.sdl");

	Socket listener = new TcpSocket();
	listener.bind(new InternetAddress(InternetAddress.ADDR_ANY, config.port));
	listener.listen(1);


	import std.concurrency;
	Tid tid = spawn(&handleFiles, 2000, config.loggerDir);

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

void handleFiles(size_t bufferSize, string loggerDir)
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
	uint c;
	
	while(true) {
		receive(
		(immutable(ubyte)[] buffer)
		{
			ubyte[] buff = cast(ubyte[])buffer;

			toLog[c].c   = read!string(buff);
			toLog[c].v	 = read!uint(buff);
			toLog[c].m   = read!string(buff);
			toLog[c].f   = read!string(buff);
			toLog[c].l   = read!uint(buff);

			import std.stdio;
			writeln(toLog[c].m);

			c++;
			if(c == toLog.length)
			{
				import std.algorithm;

				sort!("a.c > b.c", SwapStrategy.unstable)(toLog);
				c = 0;

				string s;
				File f = openFile(loggerDir, toLog[0].c);
				foreach(msg; toLog)
				{
					if(msg.c != s)
					{
						f.close();
						f = openFile(loggerDir, msg.c);
						s = msg.c;
					}

					logMsg(f, cast(Verbosity)msg.v, msg.m, msg.f, msg.l);
				}
			}
		});
	}
}

File openFile(string path, string channel)
{
	import std.file;
	
	string p = path ~ channel ~ ".txt";
	if(!exists(p) || getSize(p) > 1024 * 10)
		return File(p, "w");
	else 
		return File(p, "a");
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

private void logMsg(File f, 
					Verbosity verbosity, 
					string msg, 
					string file, 
					size_t line) 
{
	import std.format, std.array;
	char[1024] buffer = void;
	auto sink = Appender!(char[])(buffer);
	sink.clear();

	formattedWrite(sink, "%s %s (%s)\n\n",
					msg, file, line);
	f.rawWrite(sink.data);
}