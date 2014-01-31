module game.input.phone;

import collections.list;
import math;
import logging;
import std.algorithm;
import std.uuid;
import network.router;

auto logChnl = LogChannel("PHONE");
private static List!Phone phones;

struct Phone
{
	UUID id;
	PhoneState phoneState;

	static bool exists(UUID id)
	{
		return phones.canFind!(x => x.id == id);
	}

	static PhoneState state(UUID id)
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
		router.disconnectionHandlers ~= (id) { onDisconnect(id); };
		router.messageHandlers       ~= (id, msg) { onMessage(id, msg); }; 
	}
}

struct PhoneState
{
	float3 accelerometer = float3.zero;
	float3 gyroscope = float3.zero;
}

void onConnection(UUID id)
{
	Phone p;
	p.id = id;
	
	phones ~= p;
}

void onDisconnect(UUID id)
{
	phones.remove!(x => x.id == id);
}

void onMessage(UUID id, ubyte[] message)
{
	import std.bitmanip;

	auto index = phones.countUntil!(x => x.id == id);
	if(index == -1) return;

	//Accelereometer data.
	if(message[0] == 0)
	{
		message = message[1 .. $];
		auto f = float3(message.read!float, message.read!float, message.read!float);
		phones[index].phoneState.accelerometer = f;
		logChnl.info("Accelerometer data changed for ", phones[index].id, " to", f);
	}
}