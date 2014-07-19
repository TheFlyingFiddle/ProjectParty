module network.router;

import collections.table;
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

alias HandlerTable = Table!(ushort, MessageHandler, SortStrategy.sorted);

struct Router
{
	List!ConnectionHandler connectionHandlers;
	List!ReconnectionHandler reconnectionHandlers;
	List!DisconnectonHandler disconnectionHandlers;
	List!RawMessageHandler messageHandlers;

	HandlerTable specificHandlers;

	this(A)(ref A allocator, Server* server)
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

		specificHandlers = HandlerTable(allocator, maxHandlers);
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
		foreach(handler; messageHandlers)
			handler(id, mess);

		import util.bitmanip;
		auto msgid = mess.read!ushort;
		auto sHandler = msgid in specificHandlers;
		if(sHandler)
		{
			(*sHandler)(id, mess);
		}
	}

	void setMessageHandler(T)(void delegate(ulong, T) fun) if(isInMessage!T) 
	{
		import std.traits;
		static void func(void delegate() d, ulong id, ubyte[] data)
		{
			alias del_t = void delegate(ulong, T);
			del_t del = cast(del_t)d;
			
			T t = data.readMessageContent!T;
			del(id, t);
		}
		
		import util.hash;
		auto mesID = shortHash!(T).value;
		specificHandlers[mesID] = MessageHandler(cast(void delegate())fun, &func);
	}

	void removeMessageHandler(T)() if(isIncommingMessage!T)
	{
		specificHandlers.remove(shortHash!(T).value);
	}
}