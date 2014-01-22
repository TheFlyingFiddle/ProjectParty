module logging.tcp;

import logging;
import std.socket;
import std.array;
import content.sdl;
import std.concurrency;
import allocation.gc;

__gshared Tid loggerTid;

void initialize(string configFile)
{
    struct NetConfig
	{
        ushort port;
        string ip;
	}
	import std.file;
    {
    	auto obj = fromSDLFile!NetConfig(GCAllocator.it, configFile);
    	loggerTid = spawn(&loggingSender, obj.ip, obj.port);
    }
}


void loggingSender(string ip, ushort port)
{
	struct Msg
	{
		string channel, msg, file;
		size_t line, verbosity;
	}




	Appender!(char[]) sink;
	Socket socket = new Socket(AddressFamily.INET,
							   SocketType.STREAM,
							   ProtocolType.TCP);

	try {
		socket.connect(getAddress(ip, port)[0]);
		sink = appender!(char[]);

		while(true)
		{
			receive(
					(string channel, Verbosity verbosity, string msg, string file, size_t line) {
						try 
						{
        //TODO: fix
							//toSDL(Msg(channel, msg, file, line, verbosity), sink);
							socket.send(sink.data);
							sink.clear();
						}
						catch(Exception e) 
						{
							import std.c.stdio;
							printf("An exception was thrown while sending
								   a message in the TCP logger!\n %s", e.msg);
						}
					});
		}

	} 
	catch(Exception e)
	{
		import std.stdio;
		writeln(e);
	}
}

void tcpLogger(string channel, Verbosity verbosity, string msg, string file, size_t line) nothrow
{
	try 
	{
		send(loggerTid, channel, verbosity, msg, file, line);
	}
	catch(Exception e)
	{
		import std.c.stdio;
		printf("An exception was thrown while sending
			   a message to the logging thread!\n %s", e.msg);
	}
}