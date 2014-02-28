module network.server;

import std.socket, allocation, logging, collections, std.conv;

auto logChnl = LogChannel("LOBBY");

struct Connection
{
	Socket socket;
	float timeSinceLastMessage;
	ulong id;
}

//This is not how i want to do things but i am forced by phobos.
class Listener : TcpSocket
{
	FreeList!(Socket) freeList;

	this(A)(ref A allocator, size_t maxConnections)
	{
		super();
		freeList = FreeList!(Socket)(allocator, maxConnections);
	}

	override Socket accepting()
	{
	  return freeList.allocate();
	}

	void deallocate(Socket toFree)
	{
		freeList.deallocate(toFree);
	}
}

struct PartialMessage
{
	ubyte[] data;
	uint length;
	ulong id;
}

struct ServerConfig
{
	float broadcastInterval;
	float connectionTimeout;
	uint maxConnections;
	uint maxMessageSize;
	ushort broadcastPort;
}

enum NetworkMessage
{
	alias_   = 0,
	sensor   = 1,
	file     = 2,
	allFilesSent = 3,
	fileReload = 4
}

struct Server
{
	ServerConfig config;
	ulong bytesProcessed;

	List!ulong lostConnections;
	List!PartialMessage partialMessages;
	List!Connection activeConnections;
	List!Connection pendingConnections;
	
	Socket connector;
	Listener listener;

	InternetAddress listenerAddress;
	InternetAddress broadcastAddress;

	string hostName;
	string listenerString;
	float timeSinceLastBroadcast = 0;

	void delegate(ulong) onConnect;
	void delegate(ulong) onReconnect;
	void delegate(ulong) onDisconnect;
	void delegate(ulong, ubyte[]) onMessage;

	this(A)(ref A allocator, ServerConfig config)
	{
		this.config = config;

		activeConnections  = List!Connection(allocator, config.maxConnections);
		pendingConnections = List!Connection(allocator, config.maxConnections);
		lostConnections	   = List!ulong(allocator,      config.maxConnections);

		listener = allocator.allocate!(Listener)(allocator, config.maxConnections);
		listener.blocking = false;

		connector = allocator.allocate!(UdpSocket)();
		connector.blocking = false;


		partialMessages	   = List!PartialMessage(allocator, config.maxConnections);
		foreach(i; 0 .. config.maxConnections)
			partialMessages ~= PartialMessage(allocator.allocate!(ubyte[])(config.maxMessageSize), 0, 0);
	
		this.hostName = Socket.hostName;
		auto result = getAddress(hostName);
		foreach(r; result)
		{
			if(r.addressFamily == AddressFamily.INET) {
				string stringAddr = r.toAddrString();
				connector.bind(r);
				listener.bind(r);

				listenerAddress = allocator.allocate!InternetAddress(stringAddr, listener.localAddress.toPortString.to!ushort);
				
				//This only works on simple networks. 
				broadcastAddress = allocator.allocate!InternetAddress(listenerAddress.addr | 0xFF, config.broadcastPort);
			}
		}

		listener.listen(200);	
		listenerString = listenerAddress.toString();
	}

	~this()
	{
		listener.shutdown(SocketShutdown.SEND);
		listener.close();
		connector.close();

		foreach(ref con; activeConnections) { 
			con.socket.shutdown(SocketShutdown.SEND);
			con.socket.close();

			listener.deallocate(con.socket);
		}

		foreach(ref con; pendingConnections) {
			con.socket.shutdown(SocketShutdown.SEND);
			con.socket.close();

			listener.deallocate(con.socket);
		}
	}

	void update(float elapsed)
	{
		timeSinceLastBroadcast += elapsed;
		if(timeSinceLastBroadcast >= config.broadcastInterval) {
			timeSinceLastBroadcast -= config.broadcastInterval;
			broadcastServer();
		}

		acceptIncoming();
		processPendingConnections(elapsed);
		processMessages(elapsed);
	}

	void processPendingConnections(float elapsed)
	{
		ubyte[ulong.sizeof] buffer;
		
		for(int i = pendingConnections.length - 1; i >= 0; i--)
		{
			auto con = pendingConnections[i];
			auto r   = con.socket.receive(buffer);
			if(r == Socket.ERROR)
			{
				if(wouldHaveBlocked())
					continue;
				
				logChnl.warn("Pending socket closed for unkown reasons! ID :", con.id);
				closeConnection(pendingConnections, i, false, false);
			}
			else if(r == 0)
			{
				logChnl.warn("Pending socket closed! ID : ", con.id);
				closeConnection(pendingConnections, i, false, false);
			} else {	
				import util.bitmanip;
				ubyte[] bbb = buffer;
				ulong id = read!ulong(bbb);

				logChnl.info("Id received :  ", id);
				if(id == con.id)
				{
					logChnl.info("onConnect :  ", id);
					pendingConnections.removeAt(i);
					activateConnection(con.socket, id, false);
				}
				else 
				{
					auto index = lostConnections.countUntil!(x => x == id);
					if(index != -1)
					{
						logChnl.info("Reconnected :  ", id);

						lostConnections.removeAt(index);
						pendingConnections.removeAt(i);			

						ubyte ok = 1;
						con.socket.send((&ok)[0 .. 1]);
						
						activateConnection(con.socket, id,  true);		
					} 
					else 
					{
						auto index2 = activeConnections.countUntil!(x => x.id == id);
						if(index2 != -1)
						{
							logChnl.warn("Reconnected but connection was stil active!:  ", id);
							closeConnection(activeConnections, index2, true, false);

							ubyte ok = 1;
							con.socket.send((&ok)[0 .. 1]);

							pendingConnections.removeAt(i);
							activateConnection(con.socket, id,  true);		
						}
						//If we got here an unkown assailant is trying to recconect.
						else 
						{
							ubyte not_ok = 0;
							con.socket.send((&not_ok)[0 .. 1]);

							logChnl.info("An invalid reconnection request was found! :  ", id, " on connection ", con);
							closeConnection(pendingConnections, i, false, false);
						}
					}
				}
			}
		} 
	}

	void processMessages(float elapsed)
	{
		ubyte[8192] buffer = void;

		for(int i = activeConnections.length - 1; i >= 0; i--)
		{
			auto con = &activeConnections[i];
			if(!con.socket.isAlive()) 
			{
				closeConnection(activeConnections, i, true, true);
				continue;
			}


			//Partial messages must be checked since the last frame.
			const pIndex = partialMessages.countUntil!(x => x.id == con.id);
			const len    = partialMessages[pIndex].length;

			if(len != 0) 
				buffer[0 .. len] = partialMessages[pIndex].data[0 .. len];
			
			auto read = con.socket.receive(buffer[len .. $]);
			if(Socket.ERROR == read)
			{	
				//Reading will fail if we are in non-blocking mode and no
				//message was received. Since timeout is wierd in non-blocking mode
				//we do it manually.
				con.timeSinceLastMessage += elapsed;
				if(con.timeSinceLastMessage > config.connectionTimeout)
				{
					logChnl.warn("Socket with ID : ", con.id, " closed since it timed out!");
					closeConnection(activeConnections, i, true, true);
					continue;
				}

				if(wouldHaveBlocked()) {
					continue;
				}

				logChnl.warn("Socket With ID : ", con.id, " closed for unknown reasons!");
				closeConnection(activeConnections, i, true, true);	
			} 
			else if(0 == read)
			{ 
				logChnl.info("Connection closed!");
				closeConnection(activeConnections, i, true, true);
			}
			else 
			{			
				bytesProcessed += read;
				con.timeSinceLastMessage = 0.0f;
				partialMessages[pIndex].length = 0;
				sendMessages(i, con.id, buffer[0 .. read + len]);
			}
		}
	}

	void send(ulong id, ubyte[] message)
	{
		auto index = activeConnections.countUntil!(x => x.id == id);
		if(index == -1) {
			logChnl.info("Trying to send to a connection that does not exist!");
			return;
		}


		while(true) {
			int sent = activeConnections[index].socket.send(message);
			logChnl.info("Wrote ", sent, " out of ", message.length);

			if(sent != -1)
				message = message[sent .. $];

			if(message.length == 0)
				break;
		}

	}

	void broadcast(ubyte[] message)
	{
		foreach(ref con; activeConnections)
			con.socket.send(message);
	}

	void sendMessages(uint listIndex, ulong key, ubyte[] buffer)
	{
		import util.bitmanip;
		while(buffer.length)
		{
			ubyte[] tmp = buffer;

			if(buffer.length >= 2) 
			{
				auto len = buffer.read!ushort();
				if(len > config.maxMessageSize)
				{
					logChnl.error("Recived a message who's length is greater then the maximum size of our messages!");
					closeConnection(activeConnections, listIndex, true, true);
					return;
				}

				if(len > buffer.length)
				{
					auto index = partialMessages.countUntil!(x => x.id == key);
					partialMessages[index].data[0 .. tmp.length] = tmp;
					partialMessages[index].length = tmp.length;
					break;
				}

				//Do we want to do this here? It
				//spits data oriented design in the face
				//i think? But the only other reasonable way
				//to do it would be to split it up into multiple
				//buffers 1 per message and then run those buffers
				//side by side... (That might be better)
				//This can also be done here if we do it in the router.
				//But then a all messages sent delegate is required
				//It does open up the door for some cool optimizations
				//so maby that is the best thing to do.
				ubyte[] message = buffer[0 .. len];
				buffer = buffer[len .. $];
				onMessage(key, message);
			} 
			else
			{
				auto index = partialMessages.countUntil!(x => x.id == key);
				partialMessages[index].data[0 .. tmp.length] = tmp;
				partialMessages[index].length = tmp.length;

				logChnl.info("Got a one byte partial message!");
				break;

			}
		}
	}

	void broadcastServer()
	{
		ubyte[1024] msgB = void;
		ubyte[] msg = msgB[0 .. $];
		msg[0] = 'P'; msg[1] = 'P'; msg[2] = 'S';


		import util.bitmanip;
		size_t index = 3;
		msg.write!uint(listenerAddress.addr, &index);
		msg.write!ushort(listenerAddress.port, &index);
		
		msg.write!ushort(cast(ushort)hostName.length, &index);
		foreach(char c; hostName)
			msg.write!(char)(c, &index);

		connector.sendTo(msg, broadcastAddress);
	}

	void acceptIncoming()
	{	
		while(activeConnections.length +  pendingConnections.length < activeConnections.capacity)
		{
			 Socket s = listener.accept();
			 if(!s.isAlive()) 
			 {
				listener.deallocate(s);
				return;
			 }



			 logChnl.info("Connection was received: ", activeConnections.length + pendingConnections.length);
			 s.blocking = false;

			 //Send session key.
			 import util.bitmanip;
			 auto number = uniqueNumber();
			 ubyte[ulong.sizeof] nBuff; ubyte[] bBuff = nBuff;
			 bBuff.write!ulong(number, 0);
			 s.send(bBuff);
			 pendingConnections ~= Connection(s, 0.0f, number);
		}	
	}


	void activateConnection(Socket socket, ulong id, bool isReconnect)
	{
		activeConnections ~= Connection(socket, 0.0f, id);

		auto index = partialMessages.countUntil!(x => x.id == 0);
		partialMessages[index].id = id;

		auto fun = isReconnect ? onReconnect : onConnect;
		if(fun)
			fun(id);
	}

	void closeConnection(ref List!Connection connections, 
						 int i, bool wasConnected, bool addToLost)
	{
		auto con = connections[i];
		connections.removeAt(i);

		con.socket.close();
		listener.deallocate(con.socket);

		auto index = partialMessages.countUntil!(x => x.id == con.id);
		if(index != -1) {
			partialMessages[index].id = 0;
			partialMessages[index].length = 0;
		}

		if(addToLost)
		{
			if(lostConnections.length == lostConnections.capacity)
				lostConnections.removeAt(0);

			lostConnections ~= con.id;
		}

		if(wasConnected && onDisconnect)
			onDisconnect(con.id);
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
		return !activeConnections.canFind!(x => x.id == num) &&
				 !lostConnections.canFind!(x => x == num) &&
				!pendingConnections.canFind!(x => x.id == num);
	}

	@disable this(this);
}