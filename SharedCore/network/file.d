module network.file;

import allocation, util.bitmanip, content.sdl;
import content.file, util.strings;
import std.stdio, std.algorithm, std.file, std.path, std.socket; 
import log;
import collections;

enum FileMessages
{
	sentFile = 0,
	removeFiles = 1,
	allFilesSent = 2
}


private struct GeneratedFile
{
	//Includes extension
	string name; 
	void[] data;
}

//Need something here that will make generated stuff send
__gshared List!GeneratedFile generatedFiles;
void addGeneratedFile(string name, void[] data)
{
	if(generatedFiles.capacity == 0)
		generatedFiles = List!GeneratedFile(GlobalAllocator, 10);

	generatedFiles ~= GeneratedFile(name, data);
}

private void throwingSend(Socket socket, void[] buffer)
{
	int sent = socket.send(buffer);
	if(sent == Socket.ERROR)
		throw new Exception("Failed to send data!");
}


size_t writeFileMetadata(ubyte[] buffer, const(char)[] fileName, size_t fileSize)
{
	size_t offset = 0;

	buffer.write!ubyte(FileMessages.sentFile, &offset);
	buffer.write!(char[])(cast(char[])fileName, &offset);
	buffer.write!uint(fileSize, &offset);

	return offset;
}

void sendGeneratedFiles(Socket socket, ubyte[] buffer)
{
	foreach(file; generatedFiles)
	{
		size_t offset = writeFileMetadata(buffer, file.name, file.data.length);
		socket.throwingSend(buffer[0 .. offset]);
		socket.throwingSend(file.data);
	}
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

	sendGeneratedFiles(socket, buffer);
	sendAllFilesSent(socket);
}

void sendFile(Socket socket, const(char)[] entry, const(char)[] folder, ubyte[] buffer)
{
	//Hack...
	if(entry.baseName == "Thumbs.db") return;

	logInfo("Sending file ", entry);

	auto file = File(cast(string)entry, "rb");	
	auto fileName = entry[folder.length + 1 .. $];

	size_t offset = writeFileMetadata(buffer, fileName, cast(uint)file.size);
	socket.throwingSend(buffer[0 .. offset]);

	uint sent = 0;
	while(sent != file.size())
	{
		auto data = file.rawRead(buffer);
		socket.throwingSend(data);
		sent += data.length;
	}

	logInfo("File sent ", entry);
}

void listenForFileRequests(uint ip, ushort port, string resourceFolder)
{
	import network.message, content.content, network.file;
	import concurency.task, util.bitmanip;

	TcpSocket listener  = GlobalAllocator.allocate!(TcpSocket)();
	auto address		= GlobalAllocator.allocate!(InternetAddress)(ip, port);

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
	
	try
	{
		auto size = socket.receive(slice);
		assert(size >= 1);
		if(slice.read!ubyte == 1)
		{
			logInfo("Receiving map file!");
			//Read map
			slice = rec[];
			size = socket.receive(slice);
			logInfo("Received map file!");

			FileMap map = fromSDLSource!FileMap(Mallocator.it, cast(string)slice[0 .. size], default_context);
			sendDiffFiles(socket, resourceFolder, map);
		}
		else 
		{
			sendAllFiles(socket, resourceFolder);
		}
	}
	catch(Exception e)
	{
		logErr("Failed to send all files!: ", e);
	}

	socket.shutdown(SocketShutdown.SEND);
	socket.close();
}

void sendAllFilesSent(Socket socket)
{
	logInfo("All files sent");

	ubyte id = FileMessages.allFilesSent;
	socket.throwingSend((&id)[0 .. 1]);
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

	socket.throwingSend(buffer[0 .. offset]);

	
	sendGeneratedFiles(socket, buffer);
	sendAllFilesSent(socket);
}