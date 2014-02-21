module game.input.phone;

import collections.table;
import math;
import logging;
import std.algorithm;
import network.router;

auto logChnl = LogChannel("PHONE");
private static Table!(ulong, Phone) phones;

struct Phone
{
	PhoneState phoneState;

	static bool exists(ulong id)
	{
		return phones.indexOf(id) != -1;
	}

	static PhoneState state(ulong id)
	{
		return phones[id].phoneState;
	}

	static init(A)(ref A allocator, size_t capacity, ref Router router)
	{
		phones = Table!(ulong, Phone)(allocator, capacity);
		
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
	phones[id] = Phone();
}

void onDisconnect(ulong id)
{
	phones.remove(id);
}

void onMessage(ulong id, ubyte[] message)
{
	import std.bitmanip;

	auto p = phones;
	//Accelereometer data.
	if(message[0] == 1) //Need to make this more formal!
	{


		message = message[1 .. $];
		//We got a partial message and we do not care
		auto f = float3(message.read!float, message.read!float, message.read!float);
		phones[id].phoneState.accelerometer = f;

		logChnl.info("Got accelerometer data!  ", f);
		//logChnl.info("Accelerometer data changed for ", phones[index].id, " to", f);
	}
}