local netMT = { }
netMT.__index = netMT

global.networkReaders = global.networkReaders or { }
global.networkWriters = global.networkWriters or { }
global.NetIn  		  = global.NetIn  or { }
global.NetOut 		  = global.NetOut or { }


local CONNECTION_TIMEOUT = 10000
local UDP_PORT = 11111

--Sort of a hack but can it be avoided?
local connections = { }

local function onConnect(socket, connected)
	local network = connections[socket]
	connections[socket] = nil

	local f = function()
		network:onConnect(socket, connected)
	end

	table.insert(callbacks, f)
end

local function connect(self, tcp, udp)

	tcp:blocking(true)
	tcp:sendTimeout(1000)
	tcp:receiveTimeout(1000)

	Log.info("read long a")
	local sessionID = tcp.inStream:readLong()
	Log.info("read long b")
	tcp.outStream:writeLong(sessionID)
	Log.info("write long a")
	tcp.outStream:flush()
	Log.info("write long b")

	--We have already connected once so we perform a reconnect!
	if id then 
		local ok = tcp.inStream:readByte() == 1
		tcp:blocking(false)

		if not ok then 
			error("Failed to reconnect")
		end 
	else 
		self.sessionID = sessionID
	end

	tcp:blocking(false)
	udp:bind(C.platformLanIP(), 0)
	udp:blocking(false)
	udp:connect(self.serverIP, self.udpPort)

	self.connectCb()

	self.connecting = false
	self.connected  = true
end

function netMT:onConnect(socket, connected)
	if not connected then 
		self.connecting = false
		self:asyncConnect()
		return
	end

	self.tcp = TcpFromSocket(socket, self.bufSize, self.bufSize)
	self.udp = UdpSocket(self.bufSize, self.bufSize)
	connect(self, self.tcp, self.udp)
end

function netMT:asyncConnect()
	if self.connected or self.connecting then 
		error("Already connecting!")
	end

	self.connecting = true

	local sock = C.socketCreate(C.TCP_SOCKET)
	connections[sock] = self
	C.socketAsyncConnect(sock, self.serverIP, self.tcpPort, CONNECTION_TIMEOUT, onConnect)
end

function netMT:isConnected()
	return self.connected
end

function global.Network(bufSize, server, onConnect, onDisconnect)
	local t = { }
	t.tcpPort    = server.tcpPort
	t.udpPort    = server.udpPort 
	t.serverIP   = server.ip
	t.bufSize    = bufSize
	t.connected  = false
	t.connecting = false
	t.connectCb  = onConnect
	t.disconnectCb = onDisconnect

	if server.sessionID then 
		t.sessionID = server.sessionID
	end

	t.router		 = { }
	setmetatable(t, netMT)
	return t;
end

function netMT:disconnect()
	if not self.connected then return end
	Log.info("Disconnecting")

	self.disconnectCb()

	self.tcp:close()
	self.udp:close()

	self.connected = false;
	self.tcp = nil
	self.udp = nil
end

local function readErrorReport(id)
	local key = nil
	for k,v in pairs(NetIn) do
		Log.infof("%s = %d", k, v)
		if v == id then 
			key = k
			break
		end
	end				

	if key then 
		Log.warnf("No reader for message! %s", key)
	else 
		Log.warnf("There is no message reader for id %d", id)
	end
end

local function readTcpMessages(self, stream, handler)
	while stream:dataLength() > 2 do 
		local length = stream:readShort()
		--Log.infof("Got message of length %d", length)

		if stream:dataLength() >= length then 
			local id = stream:readShort()
			local buffer = stream:buffer()
			local func = networkReaders[id]
			if not func then
				readErrorReport(id)
				buffer[0].ptr = buffer[0].ptr + length - 2
			else 
				local value = func(buffer)
				if self.router[id] then
					for i,v in ipairs(self.router[id]) do
						v(value)
					end
				else 
					--Log.warnf("Received a message that we have no handler for! %d", id)
				end
			end
		else
			stream:setPosition(stream:getPosition() - 2)
		end 
	end
end

local function readUdpMessages(self, buffer)

	local rem = buffer:remaining()
	while rem > 2 do
		Log.info("Rem is %d", rem)
		local length = buffer:readShort()
		if length == 0 then 
			error("Corrupted connection!");
		end

		if rem - 2 >= length then 
			local id = buffer:readShort()
			local func = networkReaders[id]
			if not func then
				readErrorReport(id)
				buffer[0].ptr = buffer[0].ptr + length - 2
			else 
				local value = func(buffer)
				if self.router[id] then
					for i,v in ipairs(self.router[id]) do
						v(value)
					end
				end
			end
		else 
			buffer[0].ptr = buffer[0].ptr - 2
		end
	end
end

local function recv(self)
	self.tcp:receive()
	self.udp:receive()
	readTcpMessages(self, self.tcp.inStream, self.messageHandler)
	readUdpMessages(self, self.udp.inBuffer, self.messageHandler)
end

function netMT:receive()
	if not self.connected then return end
	recv(self)
end

function netMT:send()
	if not self.connected then return end
	self.tcp.outStream:flush()
	self.udp:send(self.udp.ip, self.udp.port)
end

function netMT:addListener(id, listener)
	if not self.router[id] then 
		self.router[id] = { }
	end

	table.insert(self.router[id], listener)
end

function netMT:removeListener(id, listener)
	for i ,v in ipairs(self.router[id]) do
		if v == listener then
			table.remove(i)
			return
		end
	end
end

function netMT:sendMessage(id, msg)
	--if not self.connected then return end
--
	--local func = networkWriters[id]
	--if func then 
	--	local buf = self.tcp.outStream:buffer();
	--	func(buf, msg)
	--end				
end--