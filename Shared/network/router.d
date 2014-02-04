module network.router;

import collections.list;
import network.server;
import std.uuid;
import logging;

alias ConnectionHandler   = void delegate(ulong);
alias DisconnectonHandler = void delegate(ulong);
alias MessageHandler      = void delegate(ulong, ubyte[]);

auto l = LogChannel("ROUTER");

struct Router
{
	List!ConnectionHandler connectionHandlers;
	List!DisconnectonHandler disconnectionHandlers;
	List!MessageHandler messageHandlers;

	this(A)(ref A allocator, size_t capacity, ref Server server)
	{
		server.onConnect    = &connected;
		server.onDisconnect = &disconected;
		server.onMessage    = &message;

		connectionHandlers    = List!ConnectionHandler(allocator, capacity);
		disconnectionHandlers = List!DisconnectonHandler(allocator, capacity);
		messageHandlers       = List!MessageHandler(allocator, capacity);

		l.info("Router Created", this);
	}

	void connected(ulong id)
	{
		l.info("Connected called!", id);
		foreach(handler; connectionHandlers)
			handler(id);
	}

	void disconected(ulong id)
	{
		foreach(handler; disconnectionHandlers)
			handler(id);
	}
	
	void message(ulong id, ubyte[] mess)
	{
		//Decode message but not right now. 
		foreach(handler; messageHandlers)
			handler(id, mess);
	}
}