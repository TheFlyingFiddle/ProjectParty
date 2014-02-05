module network.server;

import std.socket, allocation, logging, collections;

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

	Socket connector;
	TcpSocket listener;

	InternetAddress localAddress;
	InternetAddress listenAddress;
	InternetAddress broadcastAddress;

	float broadcastInterval = 1.0f;
	float timeSinceLastBroadcast = 0;
	float timeout = 5f;

	void delegate(ulong) onConnect;
	void delegate(ulong) onReconnect;
	void delegate(ulong) onDisconnect;
	void delegate(ulong, ubyte[]) onMessage;

	this(A)(ref A allocator, size_t maxConnections, ushort port, ushort broadcastPort)
	{
		activeConnections = Table!(ulong, Connection)(allocator, maxConnections);
		lostConnections	= List!ulong(allocator, maxConnections);

		connector = allocator.allocate!(UdpSocket)();
		connector.blocking = false;
		
		listener = allocator.allocate!(TcpSocket)();

		import std.stdio;
		auto result = getAddress(Socket.hostName, port);
		foreach(r; result)
		{
			writeln(r);
			if(r.addressFamily == AddressFamily.INET) {
				string stringAddr = r.toAddrString();


				localAddress     = allocator.allocate!InternetAddress(stringAddr, port);
				listenAddress    = allocator.allocate!InternetAddress(stringAddr, cast(ushort)(port + 1));

				//This only works on simple networks. 
				broadcastAddress = allocator.allocate!InternetAddress(localAddress.addr | 0xFF, broadcastPort);
			}
		}

		connector.bind(localAddress);

		listener.bind(listenAddress);
		listener.blocking = false;
		listener.listen(1);	
	}

	void update(float elapsed)
	{
		broadcastInterval -= elapsed;
		if(broadcastInterval < 0) {
			broadcastInterval = 1.0f;
			broadcastServer();
		}

		acceptIncoming();
		processMessages(elapsed);
	}

	void processMessages(float elapsed)
	{
		ubyte[8192] buffer;

		for(int i = activeConnections.length - 1; i >= 0; i--)
		{
			auto socket = activeConnections.at(i).socket;
			if(!socket.isAlive()) 
			{
				closeConnection(i);
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
					closeConnection(i);
					continue;
				}

				if(wouldHaveBlocked()) {
					continue;
				}

				logChnl.warn("Socket With ID : ", activeConnections.keyAt(i), " closed for unknown reasons!");
				closeConnection(i);
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

				closeConnection(i);
			}
			else 
			{			
				activeConnections.at(i).timeSinceLastMessage = 0.0f;

				if(buffer[0] == 0)
				{
					import std.bitmanip;
					ubyte[] bbb = buffer[1 .. $];
					ulong id = read!ulong(bbb);

					logChnl.info("Id received :  ", id);

					if(id == activeConnections.keyAt(i))
					{

						logChnl.info("onConnect :  ", id);
						if(onConnect) onConnect(id);
					}
					else 
					{
						auto index = lostConnections.countUntil!(x => x == id);
						if(index != -1)
						{
							lostConnections.removeAt(index);
							activeConnections.remove(activeConnections.keyAt(i));
							activeConnections[id] = Connection(socket, 0.0f);

							logChnl.info("IMA reconnect! :  ", id);
							if(onReconnect)  
								onReconnect(id);
						} 
						else 
						{
							auto index2 = activeConnections.indexOf(id);
							if(index2 != -1)
							{
								closeConnection(index2);
								activeConnections.removeAt(i);
								activeConnections[id] = Connection(socket, 0.0f);
							}
							//If we got here an unkown assailant is trying to recconect.
							else 
							{
								auto key = activeConnections.keyAt(i);
								ubyte[ulong.sizeof] nB; ubyte[] bB = nB;
								bB.write!ulong(key, 0);
								socket.send(bB);


								logChnl.info("onInvalidConnect :  ", id);
								if(onConnect) onConnect(key);
							}
						}
					}
				} else if(onMessage)
					onMessage(activeConnections.keyAt(i), buffer[0 .. read]);
			}
		}
	}

	void broadcastServer()
	{
		ubyte[3 + uint.sizeof + ushort.sizeof] msgB;
		ubyte[] msg = msgB[0 .. $];
		msg[0] = 'P'; msg[1] = 'P'; msg[2] = 'S';
		
		import std.bitmanip;
		size_t index = 3;
		msg.write!uint(localAddress.addr, &index);
		msg.write!ushort(cast(ushort)(localAddress.port + 1), &index);

		connector.sendTo(msg, broadcastAddress);
	}

	void acceptIncoming()
	{		
		while(true)
		{
			 Socket s = listener.accept();
			 if(!s.isAlive()) return;
			 logChnl.info("Connection was received");
			 s.blocking = false;

			 import std.bitmanip;
			 auto number = uniqueNumber();
			 ubyte[ulong.sizeof] nBuff; ubyte[] bBuff = nBuff;
			 bBuff.write!ulong(number, 0);
			 s.send(bBuff);

			 auto addr = s.remoteAddress();
			 logChnl.info("UUID sent: ", number, "to endpoint ", addr);
			 activeConnections[number] = Connection(s);
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
				 !lostConnections.canFind!(x => x == num);
	}

	void closeConnection(size_t i)
	{
		ulong key     = activeConnections.keyAt(i);
		Socket socket = activeConnections.at(i).socket;
		socket.close();

		activeConnections.removeAt(i);

		if(lostConnections.length == lostConnections.capacity)
			lostConnections.removeAt(0);
		
		lostConnections ~= key;

		if(onDisconnect)
			onDisconnect(key);
	}

	@disable this(this);
}