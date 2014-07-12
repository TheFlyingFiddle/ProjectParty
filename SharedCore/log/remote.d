module log.remote;

import log;
import std.socket;
import util.bitmanip;
import allocation;
import network.util;
import network.service;
import core.sync.mutex;


__gshared private NetworkServiceFinder finder;

__gshared private TcpSocket socket;
__gshared private InternetAddress remote;
__gshared private Mutex lock;
__gshared private string loggingID;

static this()
{
	finder = NetworkServiceFinder(GlobalAllocator, servicePort, "LOGGING_SERVICE", &onServiceFound);
}

void initializeRemoteLogging(string loggingID)
{
	socket = GlobalAllocator.allocate!TcpSocket;
	lock	= GlobalAllocator.allocate!Mutex();

	.loggingID	 = loggingID;
	logger = &beforeConnectLogger;
}

void termRemoteLogging()
{
	socket.close();
	GlobalAllocator.deallocate(socket);
	GlobalAllocator.deallocate(lock);

	if(remote)
		GlobalAllocator.deallocate(remote);
}

private bool connect(uint ip, ushort port)
{
	import std.stdio;
	remote = GlobalAllocator.allocate!InternetAddress(ip, port);
	scope(failure) 
	{
		GlobalAllocator.deallocate(remote);
		remote = null;
		writeln("Failed to connect to logging application!");
		return false;
	}
	
	socket.connect(GlobalAllocator.allocate!InternetAddress(ip, port));

	import util.bitmanip;
	size_t offset = 0;
	ubyte[64] buffer;
	buffer[].write!(string)(loggingID, &offset);
	socket.send(buffer[0 .. offset]);
	return true;
}

private void onServiceFound(const(char)[] service, ubyte[] serviceInfo)
{
	auto ip		= serviceInfo.read!uint;
	auto port	= serviceInfo.read!ushort;
	if(connect(ip, port))
	{
		logger = &remoteLogger;
	}
}

private void beforeConnectLogger(string channel, Verbosity verbosity,
						 const(char)[] msg, string file, 
						 size_t line) nothrow 
{
	scope(failure) return;

	synchronized(lock)
	{
		if(!finder.pollServiceFound())
			finder.sendServiceQuery();
	}

	writelnLogger(channel, verbosity, msg, file, line);
}

private void remoteLogger(string channel, Verbosity verbosity,
				  const(char)[] msg, string file, 
				  size_t line) nothrow 
{
	try
	{
		
		ubyte[256] buffer;
		size_t offset = 0;
		buffer[].write!(ubyte)(cast(ubyte)verbosity, &offset);
		buffer[].write!string(file, &offset);
		buffer[].write!uint(cast(uint)line, &offset);
		buffer[].write!(ushort)(cast(ushort)msg.length, &offset);
		
		synchronized(lock)
		{
			socket.send(buffer[0 .. offset]);
			auto r = socket.send(msg);
		
			if(r == Socket.ERROR) {
				termRemoteLogging();
				initializeRemoteLogging(loggingID);
			}
		}
	}
	catch(Error e)
	{
		throw e;
	}
	catch 
	{
		writelnLogger(channel, verbosity, msg, file, line);
	}
}