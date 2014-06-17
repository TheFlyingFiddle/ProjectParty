module network.router;

import collections.list;
import network.server;
import network.message;

alias ConnectionHandler   = void delegate(ulong);
alias ReconnectionHandler = void delegate(ulong);
alias DisconnectonHandler = void delegate(ulong);
alias RawMessageHandler   = void delegate(ulong, ubyte[]);

struct MessageHandler
{
	void delegate() del;
	void function(void delegate(), ulong, ubyte[]) func;
	this(void delegate() del,
		 void function(void delegate(), ulong, ubyte[]) func)
	{
		this.del  = del;
		this.func = func;
	}

	void opCall(ulong id, ubyte[] data)
	{
		func(del, id, data);
	}
}

struct Router
{
	List!ConnectionHandler connectionHandlers;
	List!ReconnectionHandler reconnectionHandlers;
	List!DisconnectonHandler disconnectionHandlers;
	List!RawMessageHandler messageHandlers;

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
		messageHandlers       = List!RawMessageHandler(allocator, maxHandlers);
	}

	ref List!ConnectionHandler connections() 
	{
		return connectionHandlers;
	}

	ref List!ReconnectionHandler reconnections()
	{
		return reconnectionHandlers;
	}

	ref List!DisconnectonHandler disconnections()
	{
		return disconnectionHandlers;
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
		if(specificMessageHandlers[msgid] != MessageHandler.init) {
			specificMessageHandlers[msgid](id, mess);
		}
	}

	void setMessageHandler(T)(void delegate(ulong, T) fun) if(isIncommingMessage!T) 
	{
		import std.traits;
		static void func(void delegate() d, ulong id, ubyte[] data)
		{
			alias del_t = void delegate(ulong, T);
			del_t del = cast(del_t)d;
			
			T t = data.readMessageContent!T;
			del(id, t);
		}
		
		auto messageID = messageID!T;
		specificMessageHandlers[messageID] = MessageHandler(cast(void delegate())fun, &func);
	}

	void removeMessageHandler(T)() if(isIncommingMessage!T)
	{
		specifcMessageHandler[messageID!T] = MessageHandler.init;
	}
}