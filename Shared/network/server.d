module network.server;

import std.socket, std.uuid, 
	allocation, logging, collections;

auto logChnl = LogChannel("LOBBY");

struct PhoneConnection
{
	Socket socket;
	UUID   id;
}

struct Server
{
	List!PhoneConnection activeConnections;
	List!UUID			   lostConnections;

	Socket listener;
	InternetAddress addr;

	void delegate(UUID) onConnect;
	void delegate(UUID) onDisconnect;
	void delegate(UUID, ubyte[]) onMessage;

	this(A)(ref A allocator, size_t maxConnections, ushort port)
	{
		activeConnections = List!PhoneConnection(allocator, maxConnections);
		lostConnections	= List!UUID(allocator, maxConnections);

		listener  = allocator.allocate!(TcpSocket)();
		addr      = allocator.allocate!(InternetAddress)(InternetAddress.ADDR_ANY, port);

		listener.blocking = false;
		listener.bind(addr);
		listener.listen(10);
	}

	void update()
	{
		acceptIncoming();
		processMessages();
	}

	void processMessages()
	{
		ubyte[8192] buffer;

		for(int i = activeConnections.length - 1; i >= 0; i--)
		{
			auto con = activeConnections[i];
			if(!con.socket.isAlive()) 
			{
				closeConnection(i);
				continue;
			}

			auto read = con.socket.receive(buffer);

			if(Socket.ERROR == read)
			{	
				//Reading will fail if we are in non-blocking mode and no
				//message was received.
				if(wouldHaveBlocked())
					continue;

				logChnl.warn("Socket With UUID : ", con.id, " closed for unknown reasons!");
				closeConnection(i);
			} 
			else if(0 == read)
			{
				try
				{
					//Can fail due to remoteAddress. 
					logChnl.info("Connection from ", con.socket.remoteAddress().toString(),
									 "with id ", con.id, " was closed. ");
				} 
				catch(SocketException)
				{
					logChnl.info("Connection closed!");
				}

				closeConnection(i);
			}
			else 
			{			
				if(onMessage)
					onMessage(con.id, buffer[0 .. read]);
			}
		}
	}

	void acceptIncoming()
	{		
		while(true)
		{
			Socket s = listener.accept();
			if(!s.isAlive()) return;

			logChnl.info("Connection was received");

			//A new connection has been asstablished. (It might be a recconect but at this point we don't care)
			//We send the uuid as a string connection. As UTF-8 ofc.
			UUID uuid = randomUUID();
			char[36] parsed;
			uuid.toString((x) { parsed[] = x; });
			s.send(parsed);

			logChnl.info("UUID sent: ", parsed);
			activeConnections ~= PhoneConnection(s, uuid);

			if(onConnect)
				onConnect(uuid);
		}	
	}

	void closeConnection(size_t i)
	{
		UUID uuid = activeConnections[i].id;
		activeConnections[i].socket.close();
		if(lostConnections.length == lostConnections.capacity)
		{
			lostConnections.remove!(x => true);
		}

		lostConnections ~= activeConnections[i].id;
		activeConnections.remove(activeConnections[i]);

		if(onDisconnect)
			onDisconnect(uuid);
	}
}