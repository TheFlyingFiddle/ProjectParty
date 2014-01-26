import std.stdio;
import std.socket;


void main()
{
	auto v = new void[1024];
	//v[1] = cast(void)120;

	auto v2 = new void[1024];
	v2[] = v;

}


void mai()
{
	Socket server = new Socket(AddressFamily.INET,
										SocketType.STREAM,
										ProtocolType.TCP);
	Address address = new InternetAddress(InternetAddress.ADDR_ANY, 1337);

	server.bind(address);
	server.listen(1);
	server.blocking = true;

	while(true) {
		Socket socket = server.accept();
		writeln("Connection Accepted!");
	
		byte[1024] data;
		size_t recived = socket.receive(data);
		writeln(cast(char[])data[2 .. recived]);
		socket.close();
	}
	readln;


}