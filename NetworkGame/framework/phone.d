module framework.phone;

import collections.table;
import math;
import network.router;
import framework.messages;

struct Sensor
{
	float3 accelerometer;
}	

struct SensorService
{
	Table!(ulong, Sensor) phones;
	this(A)(ref A al, size_t capacity, Router* router)
	{
		phones = Table!(ulong, Sensor)(al, capacity);

		router.connectionHandlers    ~= (id) { onConnection(id); };
		router.reconnectionHandlers  ~= (id) { onConnection(id); };
		router.disconnectionHandlers ~= (id) { onDisconnect(id); };
		router.setMessageHandler(&onSensorMessage);
	}
	
	bool exists(ulong id)
	{
		return phones.indexOf(id) != -1;
	}

	Sensor state(ulong id)
	{
		return phones[id];
	}

	void onConnection(ulong id)
	{
		phones[id] = Sensor(float3.zero);
	}

	void onDisconnect(ulong id)
	{
		phones.remove(id);
	}

	void onSensorMessage(ulong id, SensorMessage msg)
	{
		phones[id].accelerometer = msg.accelerometer;
	}

	@disable this(this);
}