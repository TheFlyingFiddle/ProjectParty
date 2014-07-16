module network.service;

import network.util;
import std.socket;
import collections;
import allocation;

enum anyService = "ANY_NETWORK_SERVICE";
enum size_t serviceMessageMax	= 256;
enum ushort servicePort			= 34299; //A random port used by all services! 

struct NetworkServiceProvider
{
	string id;
	ubyte[] data;
}

struct NetworkServices 
{
	List!NetworkServiceProvider services; 
	UdpSocket socket;

	this(A)(ref A allocator, ushort port, uint maxServices)
	{
		services = List!NetworkServiceProvider(allocator, maxServices);
		socket = allocator.allocate!UdpSocket;
		socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
		socket.blocking = false;
		socket.bind(allocator.allocate!InternetAddress(localIPString, port));
	}

	void add(T)(string serviceID, auto ref T t)
	{
		auto index = services.countUntil!(x => x.id == serviceID);
		assert(index == -1, "Cannot add two services with the service ID!");

		import serialization.base;
		NetworkServiceProvider data;
		data.id = serviceID;
		data.data = serializeAllocate(Mallocator.it, t);
		services ~= data;
	}

	void poll()
	{
		ubyte[serviceMessageMax] buffer = void; ubyte[] buf = buffer;

		Address addr; 
		auto r = socket.receiveFrom(buffer, addr);
		if(r > 0) //We received a message.
		{
			//Parse the message.
			import util.bitmanip;
			auto s = buf.read!(char[]);
			if(s == anyService)
			{
				foreach(i; 0 .. services.length)
				{
					sendService(i, addr);
				}
			}
			else
			{
				auto index = services.countUntil!(x => x.id == s);
				if(index != -1)
				{
					sendService(index, addr);
				}
			}
		} else {
			assert(wouldHaveBlocked(), "Network Service Socket Failed!");
		}
	}

	private void sendService(uint index, Address to)
	{
		import util.bitmanip;
		ubyte[serviceMessageMax] buffer = void; ubyte[] buf = buffer[];
		auto service = services[index];

		size_t offset = 0;
		buffer[].write(service.id, &offset);
		buffer[offset .. offset + service.data.length] = service.data[];
		offset += service.data.length;
		socket.sendTo(buffer[0 .. offset], to);
	}
}

struct NetworkServiceFinder
{
	string toFind;
	UdpSocket socket;
	InternetAddress broadcastAddress;

	void function(const(char)[], ubyte[]) foundFunc;
	void delegate(const(char)[], ubyte[]) foundDel;

	this(A)(ref A allocator, ushort port, string toFind)
	{
		this.toFind = toFind;
		broadcastAddress = lanBroadcastAddress(allocator, port);

		socket = allocator.allocate!UdpSocket;
		socket.bind(allocator.allocate!InternetAddress(InternetAddress.ADDR_ANY, cast(ushort)0));
		socket.blocking = false;
	}

	this(A)(ref A allocator, ushort port, string toFind, void function(const(char)[], ubyte[]) func)
	{
		this(allocator, port, toFind);
		foundFunc = func;
	}

	this(A)(ref A allocator, ushort port, string toFind, void delegate(const(char)[], ubyte[]) del)
	{
		this(allocator, port, toFind);
		foundDel = del;
	}

	~this()
	{
		socket.close();
	}

	void sendServiceQuery()
	{
		ubyte[serviceMessageMax] buffer = void;

		import util.bitmanip;
		size_t offset = 0;
		buffer[].write(toFind, &offset);
		socket.sendTo(buffer[0 .. offset], broadcastAddress);
	}
	
	bool pollServiceFound()
	{
		import util.bitmanip;
		ubyte[serviceMessageMax] buffer = void;

		auto r = socket.receive(buffer[]);
		if(r > 0)
		{
			auto buff = buffer[0 .. r];
			auto serviceID = buff.read!(char[]);

			if(toFind != anyService && serviceID != toFind) 
				return false; 

			if(foundFunc) foundFunc(serviceID, buff);
			else foundDel(serviceID, buff);

			return true;
		}
		else
		{
			assert(wouldHaveBlocked, "Socket failed!");
		}

		return false;
	}
}