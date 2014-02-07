module network.server;

import std.socket, allocation, logging, collections, std.conv;

auto logChnl = LogChannel("LOBBY");

struct Connection
{
	Socket socket;
	float timeSinceLastMessage;
}

struct Server
{
	List!ulong lostConnections;
	Table!(ulong, Connection) activeConnections;
	Table!(ulong, Connection) pendingConnections;

	Socket connector;
	TcpSocket listener;

	InternetAddress listenerAddress;
	InternetAddress broadcastAddress;

	float broadcastInterval = 1f;
	float timeSinceLastBroadcast = 0;
	float timeout = 5f;

	void delegate(ulong) onConnect;
	void delegate(ulong) onReconnect;
	void delegate(ulong) onDisconnect;
	void delegate(ulong, ubyte[]) onMessage;

	this(A)(ref A allocator, size_t maxConnections, ushort broadcastPort)
	{
		activeConnections  = Table!(ulong, Connection)(allocator, maxConnections);
		pendingConnections = Table!(ulong, Connection)(allocator, maxConnections);
		lostConnections	 = List!ulong(allocator, maxConnections);

		connector = allocator.allocate!(UdpSocket)();
		connector.blocking = false;
		
		listener = allocator.allocate!(TcpSocket)();

		auto result = getAddress(Socket.hostName);
		foreach(r; result)
		{
			if(r.addressFamily == AddressFamily.INET) {
				string stringAddr = r.toAddrString();
				connector.bind(r);
				listener.bind(r);

				listenerAddress = allocator.allocate!InternetAddress(stringAddr, 
													  listener.localAddress.toPortString.to!ushort);

				//This only works on simple networks. 
				broadcastAddress = allocator.allocate!InternetAddress(listenerAddress.addr | 0xFF, broadcastPort);
			}
		}
	
		listener.blocking = false;
		listener.listen(200);	
	}

	void update(float elapsed)
	{
		broadcastInterval -= elapsed;
		if(broadcastInterval < 0) {
			broadcastInterval = 1.0f;
			broadcastServer();
		}

		acceptIncoming();
		processPendingConnections(elapsed);
		processMessages(elapsed);
	}

	void processPendingConnections(float elapsed)
	{
		ubyte[ulong.sizeof + 1] buffer;
		
		for(int i = pendingConnections.length - 1; 
			 i >= 0; i--)
		{
			auto socket = pendingConnections.at(i).socket;
			auto r = socket.receive(buffer);
			if(r == Socket.ERROR)
			{
				if(wouldHaveBlocked())
					continue;
				
				logChnl.warn("Pending socket closed for unkown reasons! ID :", pendingConnections.keyAt(i));
				closeConnection(pendingConnections, i, false, false);
			}
			else if(r == 0)
			{
				logChnl.warn("Pending socket closed! ID : ", pendingConnections.keyAt(i));
				closeConnection(pendingConnections, i, false, false);
			} 
			
			if(buffer[0] == 0)
			{
				import std.bitmanip;
				ubyte[] bbb = buffer[1 .. $];
				ulong id = read!ulong(bbb);

				logChnl.info("Id received :  ", id);

				if(id == pendingConnections.keyAt(i))
				{
					logChnl.info("onConnect :  ", id);
					activeConnections[id] = Connection(socket, 0.0f);
					pendingConnections.removeAt(i);

					if(onConnect) 
						onConnect(id);
				}
				else 
				{
					auto index = lostConnections.countUntil!(x => x == id);
					if(index != -1)
					{
						lostConnections.removeAt(index);
						activeConnections[id] = Connection(socket, 0.0f);
						pendingConnections.removeAt(i);						

						logChnl.info("IMA reconnect! :  ", id);
						if(onReconnect)  
							onReconnect(id);
					} 
					else 
					{
						auto index2 = activeConnections.indexOf(id);
						if(index2 != -1)
						{
							closeConnection(activeConnections, index2, true, false);
							pendingConnections.removeAt(i);
							activeConnections[id] = Connection(socket, 0.0f);
						}
						//If we got here an unkown assailant is trying to recconect.
						else 
						{
							logChnl.info("An invalid reconnection request was found! :  ", id);
							closeConnection(pendingConnections, i, false, false);
						}
					}
				}
			} 
			else 
			{
				logChnl.error("Trying to send a message that is not a 
								  connection message while connecting!!!!");
				closeConnection(pendingConnections, i, false, false);

			}
		}
	}

	void processMessages(float elapsed)
	{
		ubyte[8192] buffer;

		for(int i = activeConnections.length - 1; i >= 0; i--)
		{
			auto socket = activeConnections.at(i).socket;
			if(!socket.isAlive()) 
			{
				closeConnection(activeConnections, i, true, true);
				continue;
			}

			auto read = socket.receive(buffer);

			if(Socket.ERROR == read)
			{	
				//Reading will fail if we are in non-blocking mode and no
				//message was received. Since timeout is wierd in non-blocking mode
				//we do it manually.
				activeConnections.at(i).timeSinceLastMessage += elapsed;
				if(activeConnections.at(i).timeSinceLastMessage > timeout)
				{
					logChnl.warn("Socket with ID : ", activeConnections.keyAt(i), " closed since it timed out!");
					closeConnection(activeConnections, i, true, true);
					continue;
				}

				if(wouldHaveBlocked()) {
					continue;
				}

				logChnl.warn("Socket With ID : ", activeConnections.keyAt(i), " closed for unknown reasons!");
				closeConnection(activeConnections, i, true, true);	
			} 
			else if(0 == read)
			{
				try
				{
					//Can fail due to remoteAddress. 
					logChnl.info("Connection from ", socket.remoteAddress().toString(),
									 "with id ", activeConnections.keyAt(i), " was closed. ");
				} 
				catch(SocketException)
				{
					logChnl.info("Connection closed!");
				}

				closeConnection(activeConnections, i, true, true);
			}
			else 
			{			
				activeConnections.at(i).timeSinceLastMessage = 0.0f;
				if(onMessage)
					onMessage(activeConnections.keyAt(i), buffer[0 .. read]);
			}
		}
	}

	void broadcastServer()
	{
		ubyte[1024] msgB = void;
		ubyte[] msg = msgB[0 .. $];
		msg[0] = 'P'; msg[1] = 'P'; msg[2] = 'S';


		import std.bitmanip;
		size_t index = 3;
		msg.write!uint(listenerAddress.addr, &index);
		msg.write!ushort(listenerAddress.port, &index);
		
		msg.write!uint(Socket.hostName.length, &index);
		foreach(char c; Socket.hostName)
			msg.write!(char)(c, &index);

		connector.sendTo(msg, broadcastAddress);
	}

	void acceptIncoming()
	{		
		while(true)
		{
			 Socket s = listener.accept();
			 if(!s.isAlive()) return;
			 logChnl.info("Connection was received: ", activeConnections.length + pendingConnections.length);
			 s.blocking = false;

			 import std.bitmanip;
			 auto number = uniqueNumber();
			 ubyte[ulong.sizeof] nBuff; ubyte[] bBuff = nBuff;
			 bBuff.write!ulong(number, 0);
			 s.send(bBuff);

			 auto addr = s.remoteAddress();
			 logChnl.info("UUID sent: ", number, "to endpoint ", addr);
			 pendingConnections[number] = Connection(s, 0.0f);
		}	
	}

	ulong uniqueNumber()
	{
		import std.random;

		ulong num = uniform(1, ulong.max);
		while(!unique(num)) num = uniform(1, ulong.max);
		return num;
	}

	 bool unique(ulong num)
	{
		import std.algorithm;
		return !activeConnections.keys.canFind!(x => x == num) &&
				 !lostConnections.canFind!(x => x == num) &&
				 !pendingConnections.keys.canFind!(x => x == num);
	}

	void closeConnection(ref Table!(ulong, Connection) table, int i,
								bool wasConnected, bool addToLost)
	{
		ulong key     = table.keyAt(i);
		Socket socket = table.at(i).socket;
		socket.close();

		table.removeAt(i);

		if(addToLost)
		{
			if(lostConnections.length == lostConnections.capacity)
				lostConnections.removeAt(0);
		
			lostConnections ~= key;
		}

		if(wasConnected && onDisconnect)
			onDisconnect(key);
	}

	@disable this(this);
}