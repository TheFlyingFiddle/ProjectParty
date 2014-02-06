module game.input.phone;

import collections.list;
import math;
import logging;
import std.algorithm;
import network.router;

auto logChnl = LogChannel("PHONE");
private static List!Phone phones;

struct Phone
{
	ulong id;
	PhoneState phoneState;

	static bool exists(ulong id)
	{
		return phones.canFind!(x => x.id == id);
	}

	static PhoneState state(ulong id)
	{
		auto p = phones;
		auto index = phones.countUntil!(x => x.id == id);
		assert(index != -1);
		return phones[index].phoneState;
	}

	static init(A)(ref A allocator, size_t capacity, ref Router router)
	{
		phones = List!Phone(allocator, capacity);
		
		router.connectionHandlers    ~= (id) { onConnection(id); };
		router.reconnectionHandlers  ~= (id) { onConnection(id); };
		router.disconnectionHandlers ~= (id) { onDisconnect(id); };
		router.messageHandlers       ~= (id, msg) { onMessage(id, msg); }; 
	}
}

struct PhoneState
{
	float3 accelerometer = float3.zero;
	float3 gyroscope = float3.zero;
}

void onConnection(ulong id)
{
	Phone p;
	p.id = id;
	
	phones ~= p;
}

void onDisconnect(ulong id)
{
	phones.remove!(x => x.id == id);
}

void onMessage(ulong id, ubyte[] message)
{
	import std.bitmanip;

	auto index = phones.countUntil!(x => x.id == id);
	if(index == -1) return;

	//Accelereometer data.
	if(message[0] == 1) //Need to make this more formal!
	{
		message = message[1 .. $];
		auto f = float3(message.read!float, message.read!float, message.read!float);
		phones[index].phoneState.accelerometer = f;
		logChnl.info("Accelerometer data changed for ", phones[index].id, " to", f);
	}
}