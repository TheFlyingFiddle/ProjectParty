module network.file;

import allocation, util.bitmanip, content.sdl;
import content.file, util.strings;
import std.stdio, std.algorithm, std.file, std.path, std.socket; 

enum FileMessages
{
	sentFile = 0,
	removeFiles = 1,
	allFilesSent = 2
}

void sendAllFiles(Socket socket, string folder)
{
	ubyte[] buffer = GlobalAllocator.allocate!(ubyte[])(0xFFFF);
	scope(exit) GlobalAllocator.deallocate(buffer);

	size_t offset = 0;
	foreach(entry; dirEntries(folder, SpanMode.shallow)) 
		if(baseName(entry.name) != fileCacheName)
	{
		sendFile(socket, entry.name, folder, buffer);
	}
}

void sendFile(Socket socket, const(char)[] entry, const(char)[] folder, ubyte[] buffer)
{
	auto file = File(cast(string)entry, "rb");	
	auto fileName = entry[folder.length + 1 .. $];

	size_t offset = 0;
	buffer.write!(ubyte)(FileMessages.sentFile, &offset); 
	buffer.write!(char[])(cast(char[])fileName, &offset);
	buffer.write!(uint)(cast(uint)file.size, &offset);
	socket.send(buffer[0 .. offset]);

	uint sent = 0;
	while(sent != file.size())
	{
		auto data = file.rawRead(buffer);
		socket.send(data);
		sent += data.length;
	}
}

void listenForFileRequests(uint ip, ushort port, string resourceFolder)
{
	import network.message, content.content, network.file;
	import concurency.task, util.bitmanip;

	TcpSocket listener = GlobalAllocator.allocate!(TcpSocket)();
	auto address  = GlobalAllocator.allocate!(InternetAddress)(ip, port);
	import std.stdio;
	writeln(cast(void*)ip, " ", port);
	writeln(address);

	listener.bind(address);
	listener.blocking = true;
	listener.listen(1);

	while(true)
	{
		Socket socket = listener.accept();
		taskpool.doTask!(sendFiles)(socket, resourceFolder);
	}
}


void sendFiles(Socket socket, string resourceFolder)
{
	ubyte[0xffff] rec; ubyte[] slice = rec[];

	auto size = socket.receive(slice);
	assert(size >= 1);
	if(slice.read!ubyte == 1)
	{
		//Read map
		slice = rec[];
		size = socket.receive(slice);

		writeln(size);
		writeln(cast(char[])slice[0 .. size]);
		FileMap map = fromSDLSource!FileMap(Mallocator.it, cast(string)slice[0 .. size]);
		sendDiffFiles(socket, resourceFolder, map);
	}
	else 
	{
		sendAllFiles(socket, resourceFolder);
	}

	socket.shutdown(SocketShutdown.SEND);
	socket.close();
}


void sendAllFilesSent(Socket socket)
{
	ubyte id = FileMessages.allFilesSent;
	socket.send((&id)[0 .. 1]);
}

void sendDiffFiles(Socket socket, string folder, FileMap map)
{
	auto path = text1024(folder, dirSeparator, fileMapName);
	auto fileMap = fromSDLFile!FileMap(Mallocator.it, cast(string)path);

	ubyte[] buffer = GlobalAllocator.allocate!(ubyte[])(0xFFFF);
	scope(exit) GlobalAllocator.deallocate(buffer);

	foreach(item; fileMap.items)
	{
		if(!map.items.canFind(item))
		{
			sendFile(socket, text1024(folder, dirSeparator, item.name), folder, buffer);
		}

		auto index = map.items.countUntil!(x => x.name == item.name);
		if(index != -1)
			map.items = map.items.remove(index);
	}

	sendFile(socket, text1024(folder, dirSeparator, fileMapName), folder, buffer);

	size_t offset = 0;
	buffer.write!(ubyte)(FileMessages.removeFiles, &offset);
	buffer.write!(ushort)(cast(ushort)map.items.length, &offset);
	foreach(item; map.items)
	{
		buffer.write!(char[])(cast(char[])item.name, &offset);
	}
	socket.send(buffer[0 .. offset]);


	sendAllFilesSent(socket);
}