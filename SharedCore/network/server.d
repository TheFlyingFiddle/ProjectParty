module network.server;

import std.socket, allocation, log, collections, std.conv;

auto logChnl = LogChannel("LOBBY");

struct Connection
{
	Socket socket;
	float timeSinceLastMessage;
	ulong id;
	
	ubyte[] inBuffer;
	ubyte[] outBuffer;
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
		return freeList.pureAllocate();
	}

	void deallocate(Socket toFree)
	{
		freeList.deallocate(toFree);
	}
}

struct ServerConfig
{
	float connectionTimeout;
	uint maxConnections;
	uint maxMessageSize;
}

//This is a special case message since the server send's it itself
//Should probably be 0 and not 8
enum SHUTDOWN_ID = 8;

struct Server
{
	ServerConfig config;
	ulong bytesProcessed;

	List!ulong lostConnections;
	List!Connection activeConnections;
	List!Connection pendingConnections;
	
	Socket udpSocket;
	Listener listener;

	InternetAddress listenerAddress;
	InternetAddress updAddress;

	char[] hostName;
	string listenerString;

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

		listener =  allocator.allocate!Listener(allocator, config.maxConnections);
		listener.blocking = false;
		
		udpSocket = allocator.allocate!(UdpSocket)();
		udpSocket.blocking = false;

		string s = Socket.hostName;
		this.hostName = allocator.allocate!(char[])(s.length);
		this.hostName[] = s[];
		auto result = getAddress(hostName);
		foreach(r; result)
		{
			if(r.addressFamily == AddressFamily.INET) {
				listener.bind(r);

				auto udpAddr = allocator.allocate!InternetAddress(r.toAddrString, cast(ushort)0);
				udpSocket.bind(udpAddr);

				this.updAddress = cast(InternetAddress)udpSocket.localAddress;
				this.listenerAddress = cast(InternetAddress)listener.localAddress;
			}
		}

		listener.listen(200);	
		listenerString = listenerAddress.toString();
	}

	~this()
	{
		listener.shutdown(SocketShutdown.SEND);
		listener.close();
		ubyte[3] shutdownMessage = [1, 0, SHUTDOWN_ID];
		foreach(ref con; activeConnections) { 
			
			send(con.id, shutdownMessage);

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
		sendLeftovers();
		acceptIncoming();
		processPendingConnections(elapsed);
		processUDPMessages(elapsed);
		processMessages(elapsed);
	}

	private void sendLeftovers()
	{
		for(int i = activeConnections.length - 1; i >= 0; i--)
		{
			auto con = activeConnections[i];
			if(con.outBuffer.length > 0)
			{
				auto sent = send(con, con.outBuffer);
				if(sent > 0)
				{
					con.outBuffer[0 .. con.outBuffer.length - sent] = con.outBuffer[sent .. $];
				}
			}
		}
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

	void processUDPMessages(float elapsed)
	{
		import util.bitmanip;
		ubyte[8192] buffer = void;
		while(true)
		{
			auto read = udpSocket.receiveFrom(buffer);
			if(read == 0 || read == Socket.ERROR) break;

			ubyte[] buf = buffer[0 .. read];
			read -= ulong.sizeof;
			auto sessionID = buf.read!ulong;
			auto index = activeConnections.countUntil!(x => x.id == sessionID);
			if(index != -1)
			{
				onMessage(sessionID, buf[2 .. $]);
				activeConnections[index].timeSinceLastMessage = 0;
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
			const len    = con.inBuffer.length;

			if(len != 0) 
				buffer[0 .. len] = con.inBuffer[];
			
			auto read = con.socket.receive(buffer[len .. $]);
			if(Socket.ERROR == read)
			{	
				//Reading will fail if we are in non-blocking mode and no
				//message was received.
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
				con.inBuffer.length = 0;
				forwardMessages(i, *con, buffer[0 .. read + len]);
			}
		}
	}

	int send(ref Connection con, ubyte[] data)
	{
		con.timeSinceLastMessage = 0;

		auto sent = con.socket.send(data);
		if(sent > 0) 
		{
			return sent;
		}
		else if(sent == Socket.ERROR)
		{
			if(wouldHaveBlocked()) 
			{
				return 0;
			}
			else 
			{
				logChnl.warn("Failed to send data to connection! ", con.id);
				auto index = activeConnections.countUntil!(x => x.id == con.id);
				closeConnection(activeConnections, index, true, true);
				return -1;
			}
		}

		return sent;
	}


	void send(ulong id, ubyte[] message)
	{
		auto index = activeConnections.countUntil!(x => x.id == id);
		if(index == -1) {
			logChnl.info("Trying to send to a connection that does not exist!");
			return;
		}

		send(activeConnections[index], message);
	}

	private void forwardMessages(uint listIndex, ref Connection con, ubyte[] buffer)
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
				} else if(len < 2)
				{
					logChnl.error("Received a message who's length is less then the minimum size 2!", len);
					closeConnection(activeConnections, listIndex, true, true);
					return;
				}

				if(len > buffer.length)
				{
					con.inBuffer.ptr[0 .. tmp.length] = tmp;
					break;
				}

				ubyte[] message = buffer[0 .. len];
				buffer = buffer[len .. $];
				onMessage(con.id, message);
			} 
			else
			{
				con.inBuffer.ptr[0 .. tmp.length] = tmp;
				logChnl.info("Got a one byte partial message!");
				break;
			}
		}
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

			 s.setOption(SocketOptionLevel.TCP, SocketOption.TCP_NODELAY, 1);


			 logChnl.info("Connection was received: ", activeConnections.length + pendingConnections.length);
			 s.blocking = false;

			 //Send session key.
			 import util.bitmanip;
			 auto number = uniqueNumber();

			 logChnl.info("Sending SessionID: ", number);
			 ubyte[ulong.sizeof] nBuff; ubyte[] bBuff = nBuff;

			 logChnl.info("Sending SessionID: ", (cast(ubyte*)&number)[0 .. 8]);
			 bBuff.write!ulong(number, 0);
			 s.send(bBuff);
			 pendingConnections ~= Connection(s, 0.0f, number);
		}	
	}

	void activateConnection(Socket socket, ulong id, bool isReconnect)
	{
		Connection connection = Connection(socket, 0.0f, id);
		connection.inBuffer   = GlobalAllocator.allocate!(ubyte[])(config.maxMessageSize);
		connection.outBuffer  = GlobalAllocator.allocate!(ubyte[])(config.maxMessageSize);

		connection.inBuffer.length = 0;
		connection.outBuffer.length = 0;


		activeConnections ~= connection;
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

		if(addToLost)
		{
			if(lostConnections.length == lostConnections.capacity)
				lostConnections.removeAt(0);

			lostConnections ~= con.id;
		}

		if(wasConnected && onDisconnect)
		{
			GlobalAllocator.deallocate(con.inBuffer.ptr[0 .. config.maxMessageSize]);
			GlobalAllocator.deallocate(con.outBuffer.ptr[0 .. config.maxMessageSize]);
			onDisconnect(con.id);
		}
	}

	private ulong uniqueNumber()
	{
		import std.random;

		ulong num = uniform(1, ulong.max);
		while(!unique(num)) num = uniform(1, ulong.max);
		return num;
	}

	private bool unique(ulong num)
	{
		import std.algorithm;
		return !activeConnections.canFind!(x => x.id == num) &&
				 !lostConnections.canFind!(x => x == num) &&
				!pendingConnections.canFind!(x => x.id == num);
	}

	@disable this(this);
}