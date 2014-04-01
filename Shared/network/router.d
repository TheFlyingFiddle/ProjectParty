module network.router;

import collections.list;
import network.server;
import std.uuid;
import logging;

alias ConnectionHandler   = void delegate(ulong);
alias ReconnectionHandler = void delegate(ulong);
alias DisconnectonHandler = void delegate(ulong);
alias MessageHandler      = void delegate(ulong, ubyte[]);

auto l = LogChannel("ROUTER");

struct Router
{
	List!ConnectionHandler connectionHandlers;
	List!ReconnectionHandler reconnectionHandlers;
	List!DisconnectonHandler disconnectionHandlers;
	List!MessageHandler messageHandlers;

	MessageHandler[ubyte.max] specificMessageHandlers;

	this(A)(ref A allocator, ref Server server)
	{
		enum maxHandlers = 255;

		server.onConnect    = &connected;
		server.onReconnect  = &reconnect;
		server.onDisconnect = &disconected;
		server.onMessage    = &message;

		connectionHandlers    = List!ConnectionHandler(allocator, maxHandlers);
		reconnectionHandlers  = List!ReconnectionHandler(allocator, maxHandlers);
		disconnectionHandlers = List!DisconnectonHandler(allocator, maxHandlers);
		messageHandlers       = List!MessageHandler(allocator, maxHandlers);
	}

	void connected(ulong id)
	{
		foreach(handler; connectionHandlers)
			handler(id);
	}

	void disconected(ulong id)
	{
		foreach(handler; disconnectionHandlers)
			handler(id);
	}

	void reconnect(ulong id)
	{
		foreach(handler; reconnectionHandlers)
			handler(id);
	}
	
	void message(ulong id, ubyte[] mess)
	{
		//Decode message but not right now. 
		foreach(handler; messageHandlers)
			handler(id, mess);

		import util.bitmanip;
		auto msgid = mess.read!ubyte;
		if(specificMessageHandlers[msgid] != null)
			specificMessageHandlers[msgid](id, mess);
	}

	void setMessageHandler(ubyte messageId, MessageHandler messageHandler)
	{
		specificMessageHandlers[messageId] = messageHandler;
	}
}