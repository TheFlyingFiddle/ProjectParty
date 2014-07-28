module broadcaster;
import std.socket;
import std.concurrency;
import compilers;
import util.hash;
import log;
import network.service;
import network.util;
import core.atomic;
import std.conv;
import std.datetime;
import allocation;

shared int reloaderCount = 0;

enum fileService = "FILE_RELOADING_SERVICE";



struct ReloadItem
{
	string name;
	void[] data;
}

struct ReloadingInfo
{
	ReloadItem[] items;
}

Tid reloadServiceTid;
void reloadChanged(CompiledItem[] items, HashID hash)
{
	if(reloaderCount > 0)
	{
		ReloadItem[] copy = new ReloadItem[items.length];
		foreach(i, ref item; copy) {
			item.data	   = items[i].data.dup;
			item.name = to!string(hash.value) ~ items[i].extension; 
		}

		ReloadingInfo info;
		info.items = copy;
		send(reloadServiceTid, cast(immutable ReloadingInfo)info);
	}
}


void spawnReloadingService()
{
	reloadServiceTid = spawn(&reloadingService);
}

private void reloadingService()
{
	NetworkServices services = NetworkServices(Mallocator.it, 22222, 1);

	Socket broadcast = new UdpSocket();
	broadcast.bind(new InternetAddress(InternetAddress.ADDR_ANY, 0));
	auto broadcastAddr = lanBroadcastAddress(Mallocator.it, 21345);

	Socket listener = new TcpSocket();
	listener.bind(new InternetAddress(localIPString, 0));
	listener.listen(1);
	listener.blocking = false;

	struct ReloadingData
	{
		uint ip;
		ushort port;
	}
	auto addr = cast(InternetAddress)listener.localAddress;
	ReloadingData data = ReloadingData(addr.addr, addr.port);
	services.add(fileService, data);


	Tid[] reloaders;
	bool done = false;
	while(!done)
	{
		services.poll();
		
		while(true)
		{
			auto socket = listener.accept();
			if(!socket.isAlive())
			{
				break;
			}
			
			socket.blocking = true;
			reloaders ~= spawn(&reloader, cast(immutable Socket)socket);
		}

		auto received = receiveTimeout(100.msecs, (immutable ReloadingInfo info) 
		{
			//Depricated (?)
			foreach(item; info.items)
			{
				broadcast.sendTo(item.name, broadcastAddr);	
			}

			foreach(tid; reloaders)
			{
				send(tid, info);
			}
		},
		(bool shutdown)
		{
			done = true;
			foreach(tid; reloaders)
			{
				send(tid, true);
			}
		});
	}
}

bool sendItems(immutable ReloadingInfo info, Socket socket)
{
	import util.bitmanip;
	ubyte[128] buffer;

	buffer[].write!ushort(cast(ushort)info.items.length, 0);
	int err = socket.send(buffer[0 .. 2]);
	if(err == Socket.ERROR) return false; 


	logInfo("Sending files: ", info.items.length);
	foreach(item; info.items)
	{	
		size_t offset = 0;
		buffer[].write!string(item.name, &offset);
		buffer[].write!uint(item.data.length, &offset);
		
		err = socket.send(buffer[0 .. offset]);	
		if(err == Socket.ERROR) return false; 
		err = socket.send(item.data);	
		if(err == Socket.ERROR) return false; 
	}

	return true;
}

void reloader(immutable Socket im_socket)
{
	auto socket = cast(Socket)im_socket; //GAY

	atomicOp!"+="(reloaderCount, 1);
	logInfo("Started reloading for connection: ", socket.remoteAddress);

	try
	{
		bool done = false;
		while(!done)
		{
			receive((immutable ReloadingInfo info) 
			{
				done = !sendItems(info, socket);
				if(done) 
					logErr("Failed to send item to connection: ", socket.remoteAddress);
				else 
					logInfo("Sen files to connection: ", socket.remoteAddress);
			},
			(bool shutdown)
			{
				done = true;
			});
		}
	} 
	catch(Throwable t)
	{
		logErr("Reloading thread failed! ", t);
	}
	finally
	{
		atomicOp!"-="(reloaderCount, 1);
	}

	logInfo("Stoped reloading for connection: ", socket.remoteAddress);
}