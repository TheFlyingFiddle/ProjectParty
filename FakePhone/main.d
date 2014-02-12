module main;

import std.stdio;
import std.socket;
import std.bitmanip;
import std.random;
import core.thread;

void main()
{

	Socket udp = new UdpSocket;
	udp.bind(new InternetAddress(InternetAddress.ADDR_ANY, 7331));
	
	ubyte[1024] buffer;
	auto bytesRead = udp.receive(buffer);
	
	ubyte[] readBuffer = buffer[0 .. bytesRead];

	assert(readBuffer.read!ubyte == 'P');
	assert(readBuffer.read!ubyte == 'P');
	assert(readBuffer.read!ubyte == 'S');

	uint ip     = readBuffer.read!uint;
	ushort port = readBuffer.read!ushort; 

	auto addr  = new InternetAddress(ip, port);
	auto iaddr = cast(immutable InternetAddress)addr;
	import std.concurrency;

	size_t numConnections = 10;

	foreach(i ; 0 .. numConnections)
		spawn(&connectNormal, iaddr);
}

void connectReconnector(immutable InternetAddress iaddr)
{
	auto addr = cast(InternetAddress)iaddr;
	ubyte[1024] buffer;

	auto connection = connect(addr, buffer);
	Thread.sleep(2.seconds);
	while(true)
	{
		foreach(i; 0 .. 2) 
		{
			sendAccelerometerData(connection, buffer);
			Thread.sleep(33.msecs);
		}

		Thread.sleep(uniform(0, 4).seconds);
		connection.socket.shutdown(SocketShutdown.BOTH);
		connection.socket.close();

		Thread.sleep(16.msecs);
		connection = connect(addr, buffer, connection.id);
	}
}

uint sendAccelerometerData(Connection connection, ubyte[] buffer)
{
	//Send fake accelerometer data or something here.
	ubyte[] buff = buffer;

	import std.random;
	size_t offset = 0;
	//1 == ACCELEROMETER_DATA
	buff.write!ushort(13, &offset);
	buff.write!ubyte(1, &offset);
	buff.write!float(0, &offset);
	buff.write!float(uniform(-10, 10), &offset);
	buff.write!float(0, &offset);

	return connection.socket.send(buffer[0 .. offset]);
}

void connectNormal(immutable InternetAddress iaddr)
{
	auto addr = cast(InternetAddress)iaddr;
	ubyte[1024] buffer;

	auto connection = connect(addr, buffer);
	while(true)
	{
		try 
		{
			while(true)
			{
				enforce(sendAccelerometerData(connection, buffer) == 15);
				import core.thread;
				Thread.sleep(33.msecs);
			}
		} 
		catch(Exception e) 
		{
			scope(failure) writeln("Failed to reconnect!");

			writeln("Lost connection!");
			connection.socket.shutdown(SocketShutdown.SEND);
			connection.socket.close();
			connection = connect(addr, buffer, connection.id);
		}
		import core.thread;
		Thread.sleep(16.msecs);
	}
}

auto connect(InternetAddress addr, ubyte[] buffer, ulong prevId = 0)
{
	Socket tcp = new TcpSocket;
	tcp.connect(addr);	
	writeln("Connected!");

	auto bytesRead = tcp.receive(buffer);
	ubyte[] buff = buffer;
	auto id = buff.read!ulong;
	buff = buffer;

	if(prevId != 0)
		id = prevId;

	size_t offset = 0;
	buff.write!ulong(id, &offset);
	tcp.send(buff[0 .. offset]);

	buff = buffer;

	auto name = "Stupid AI 5000";
	offset = 0;
	buff.write!ushort(cast(ushort)(name.length + 1), &offset);
	buff.write!ubyte(0, &offset);
	buff[offset .. offset + name.length] = cast(ubyte[])name;
	tcp.send(buff[0 .. offset + name.length]);

	return Connection(tcp, id);
}

struct Connection
{
	Socket socket;
	ulong id;
}