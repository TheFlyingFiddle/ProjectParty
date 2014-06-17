module broadcaster;
import std.socket;
import std.concurrency;

Tid broadcastTid;

void setupbroadcast(ushort port)
{
	broadcastTid = spawn(&broadcast, port);
}

void broadcastChange(string name)
{
	send(broadcastTid, name);
}

void broadcast(ushort port)
{
	Socket socket = new UdpSocket();
	socket.bind(new InternetAddress(InternetAddress.ADDR_ANY, port));
	

	bool done = false;
	while(!done)
	{
		receive(
			(string name) 
			{
				auto s = socket.sendTo(name, new InternetAddress("192.168.1.255", 21345));			
				import std.stdio;
				writeln(s == Socket.ERROR);
				writeln(s);
			},
			(bool shutdown)
			{
				done = true;
			});
	}
}