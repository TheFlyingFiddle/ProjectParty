import std.stdio;
import std.socket;

import math;
import std.conv, std.socket, std.stdio;
import std.datetime;
import lobby;
import core.thread;
import allocation;
import logging;
import util.profile;
import network.router;
import network.server;
import std.uuid;
import game.input.phone;

void writeLogger(string chan, Verbosity v, string msg, string file, size_t line) nothrow
{
	import std.stdio;
	scope(failure) return; //Needed since writeln can potentially throw.
	writeln(chan, "   ", msg, "       ", file, "(", line, ")");
}

int main()
{
	logger = &writeLogger;

	RegionAllocator base = RegionAllocator(Mallocator.it, 1024 * 1024);
	auto allocator = ScopeStack(base);

	Server server  = Server(allocator, 100, 1337);
	Router router  = Router(allocator, 100, server);
	Phone.init(allocator, 100, router);


	UUID uuid;
	router.connectionHandlers ~= (x) { uuid = x; };

	while(true)
	{
		//auto p = StackProfile("Lobby");
		Thread.sleep(16.msecs);
		server.update();
		
		auto logger = LogChannel("Test");

		if(!Phone.exists(uuid)) 
			continue;

		PhoneState state = Phone.state(uuid);
		logger.info(state.accelerometer);
	}

	return 0;
}




