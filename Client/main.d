import std.stdio;



import std.concurrency, core.thread;
import std.conv, std.socket, std.stdio;

void main()
{
	while(true) { 
		Thread.sleep(1.seconds);
		spawn(&client);
	}
}

void client()
{
	Socket socket = new TcpSocket();
	socket.connect(new InternetAddress("127.0.0.1", 1337));
	socket.send("Hello there sir");

	import std.random, std.datetime;
	Thread.sleep(uniform(1, 10).seconds);
	socket.shutdown(SocketShutdown.SEND);
	socket.close();
}