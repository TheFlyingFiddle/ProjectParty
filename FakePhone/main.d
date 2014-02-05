module main;

import std.stdio;
import std.socket;
import std.bitmanip;

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
	spawn(&connectNormal, iaddr);
}

void connectNormal(immutable InternetAddress iaddr)
{
	auto addr = cast(InternetAddress)iaddr;
	ubyte[1024] buffer;
	Socket tcp = new TcpSocket;

	try
	{
		tcp.connect(addr);	
		writeln("Connected!");

		auto bytesRead = tcp.receive(buffer);
		ubyte[] buff = buffer;
		auto id = buff.read!ulong;
		buff = buffer;

		size_t offset = 0;
		buff.write!ubyte(0, &offset);
		buff.write!ulong(id, &offset);

		tcp.send(buff[0 .. offset]);
	} 
	catch(Exception e)
	{
		writeln(e);
		return;
	}

	while(true)
	{
		//Send fake accelerometer data or something here.
		ubyte[] buff = buffer;

		size_t offset = 0;
		//1 == ACCELEROMETER_DATA
		buff.write!ubyte(1, &offset);
		buff.write!float(0, &offset);
		buff.write!float(2, &offset);
		buff.write!float(0, &offset);

		tcp.send(buffer[0 .. offset]);

		import core.thread;
		Thread.sleep(16.msecs);
	}
}