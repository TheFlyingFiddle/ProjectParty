module network.router;

import collections.list;
import network.server;
import std.uuid;
import logging;

alias ConnectionHandler   = void delegate(UUID);
alias DisconnectonHandler = void delegate(UUID);
alias MessageHandler      = void delegate(UUID, ubyte[]);

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

	void connected(UUID id)
	{
		l.info("Connected called!", id);
		foreach(handler; connectionHandlers)
			handler(id);
	}

	void disconected(UUID id)
	{
		foreach(handler; disconnectionHandlers)
			handler(id);
	}
	
	void message(UUID id, ubyte[] mess)
	{
		//Decode message but not right now. 
		foreach(handler; messageHandlers)
			handler(id, mess);
	}
}