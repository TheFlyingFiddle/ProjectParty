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

	spawn(&connectNormal, iaddr);
	spawn(&connectNormal, iaddr);
	spawn(&connectReconnector, iaddr);
}

void connectReconnector(immutable InternetAddress iaddr)
{
	auto addr = cast(InternetAddress)iaddr;
	ubyte[1024] buffer;

	auto connection = connect(addr, buffer);

	while(true)
	{
		sendAccelerometerData(connection, buffer);

		//if(dice(0.005, 0.995) == 0) {
			connection.socket.shutdown(SocketShutdown.BOTH);
			connection.socket.close();
			//Thread.sleep(5.seconds);
			connection = connect(addr, buffer, connection.id);
		//}
		Thread.sleep(16.msecs);
	}
}

void sendAccelerometerData(Connection connection, ubyte[] buffer)
{
	//Send fake accelerometer data or something here.
	ubyte[] buff = buffer;

	size_t offset = 0;
	//1 == ACCELEROMETER_DATA
	buff.write!ubyte(1, &offset);
	buff.write!float(0, &offset);
	buff.write!float(2, &offset);
	buff.write!float(0, &offset);

	connection.socket.send(buffer[0 .. offset]);
}

void connectNormal(immutable InternetAddress iaddr)
{
	auto addr = cast(InternetAddress)iaddr;
	ubyte[1024] buffer;

	auto connection = connect(addr, buffer);
	while(true)
	{
		while(true)
		{
			sendAccelerometerData(connection, buffer);
			import core.thread;
			Thread.sleep(16.msecs);
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
	buff.write!ubyte(0, &offset);
	buff.write!ulong(id, &offset);

	tcp.send(buff[0 .. offset]);
	
	return Connection(tcp, id);
}

struct Connection
{
	Socket socket;
	ulong id;
}