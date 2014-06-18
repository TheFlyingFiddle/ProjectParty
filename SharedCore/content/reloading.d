module content.reloading;
import concurency.task;
import content.content;
import std.socket;
import allocation;

version(RELOADING)
{
	void setupReloader(ushort port, AsyncContentLoader* loader)
	{
		doPoolTask!reloading(port, loader);
	}

	void reloading(ushort port, AsyncContentLoader* loader)
	{
		registerThread("reloader");
		auto socket  = Mallocator.it.allocate!(UdpSocket)();
		auto address = Mallocator.it.allocate!(InternetAddress)(InternetAddress.ADDR_ANY, cast(ushort)21345);
		socket.bind(address);
		socket.blocking = true;
		ubyte[256] buffer;
		while(true)
		{
			uint i = socket.receive(buffer);
			if(i == Socket.ERROR)
			{
				if(wouldHaveBlocked())
					continue;
			}


			auto array = Mallocator.it.allocate!(char[])(i);
			array[0 .. i] = cast(char[])buffer[0 .. i];
			doTaskOnMain!performReload(cast(string)array, loader);
		}
	}

	void performReload(string id, AsyncContentLoader* loader)
	{
		import std.path, std.conv, util.hash;
		auto path = id[0 .. $ - id.extension.length];
		loader.reload(HashID(path.to!uint));
		Mallocator.it.deallocate(cast(void[])id);
	}
}