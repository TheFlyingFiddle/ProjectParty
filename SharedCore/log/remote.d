module log.remote;

import log;
import std.socket;
import util.bitmanip;
import allocation;
import network.util;
import core.sync.mutex;

__gshared TcpSocket socket;
__gshared UdpSocket waiter;
__gshared InternetAddress broadcast, remote;
__gshared Mutex lock;

__gshared ushort loggingPort;
__gshared string loggingID;

void initializeRemoteLogging(string loggingID, ushort loggingPort)
{
	socket = GlobalAllocator.allocate!TcpSocket;
	waiter = GlobalAllocator.allocate!UdpSocket;
	broadcast = GlobalAllocator.allocate!InternetAddress(localIPString(), loggingPort);
	lock	= GlobalAllocator.allocate!Mutex();
	
	waiter.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
	waiter.blocking = false;
	waiter.bind(broadcast);

	.loggingID	 = loggingID;
	.loggingPort = loggingPort;

	logger = &beforeConnectLogger;
}

void termRemoteLogging()
{
	socket.close();
	waiter.close();

	GlobalAllocator.deallocate(socket);
	GlobalAllocator.deallocate(broadcast);
	GlobalAllocator.deallocate(waiter);
	GlobalAllocator.deallocate(lock);

	if(remote)
		GlobalAllocator.deallocate(remote);
}

private void connect(uint ip, ushort port)
{
	import std.stdio;
	remote = GlobalAllocator.allocate!InternetAddress(ip, port);
	scope(failure) 
	{
		GlobalAllocator.deallocate(remote);
		remote = null;
		writeln("Failed to connect to logging application!");
	}
	
	socket.connect(GlobalAllocator.allocate!InternetAddress(ip, port));

	import util.bitmanip;
	size_t offset = 0;
	ubyte[64] buffer;
	buffer[].write!(string)(loggingID, &offset);
	socket.send(buffer[0 .. offset]);
}

private void beforeConnectLogger(string channel, Verbosity verbosity,
						 const(char)[] msg, string file, 
						 size_t line) nothrow 
{
	scope(failure) return;

	synchronized(lock)
	{
		ubyte[6] buffer;
		auto r = waiter.receive(buffer);

		if(r != Socket.ERROR && r != 0)
		{
			ubyte[] buf; buf = buffer[];
			auto ip = buf.read!uint;
			auto port = buf.read!ushort;
			connect(ip, port);
			logger = &remoteLogger;
		}
		else 
		{
			writelnLogger(channel, verbosity, msg, file, line);
		}
	}
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
				initializeRemoteLogging(loggingID, loggingPort);
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