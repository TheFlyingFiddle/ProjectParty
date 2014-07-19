local netMT = { }
netMT.__index = netMT

local msgMT = {}
msgMT.__newindex = function (t, key, value)
	if t[key] then 
		error(string.format("Already defined! %s ", key))
	end

	if type(value) ~= "function" then
		error("Can only instert function into network io tables")
	end

	rawset(t, key, value)
end

global.networkReaders = { }
global.networkWriters = { }
global.NetIn  = { }
global.NetOut = { }

setmetatable(networkReaders, msgMT)
setmetatable(networkWriters, msgMT)


function global.Network(bufSize, messageHandler, sessionID)
	local t = { }
	t.tcp = TcpSocket(bufSize, bufSize)

	t.udp = UdpSocket(bufSize, bufSize)
	if sessionID then 
		t.sessionID = sessionID
	end

	t.messageHandler = messageHandler

	setmetatable(t, netMT)
	return t;
end

function netMT:connect(ip, tcpPort, udpPort, timeout)
	local tcp = self.tcp

	tcp:blocking(true)
	tcp:connect(ip, tcpPort, timeout)
	tcp:receiveTimeout(timeout)

	local sessionID = tcp.inStream:readLong()
	tcp.outStream:writeLong(sessionID)
	tcp.outStream:flush()

	--We have already connected once so we perform a reconnect!
	if self.sessionID then 
		local ok = tcp.inStream:readByte() == 1
		tcp:blocking(false)

		if not ok then 
			error("Failed to reconnect")
		end 
	else 
		self.sessionID = sessionID
	end

	tcp:blocking(false)

	self.upd.bind(0,0)
	self.udp:blocking(false)

	--More complex then this!
end

function netMT:disconnect()
	self.tcp:close()
	self.udp:close()
end

local function readTcpMessages(stream, handler)
	while stream:dataLength() > 2 do 
		local length = stream:readShort()
		if stream:dataLength() >= length then 
			local id 	 = stream:readByte()
			local buffer = stream:buffer()
			handler(id, buffer)
		else
			stream:setPosition(stream:getPosition() - 2)
		end 
	end
end

local function readUdpMessages(buffer, handler)
	local rem = C.bufferBytesRemaining(buffer)
	while rem > 2 do
		local length = C.bufferReadShort(buffer)
		if rem - 2 >= length then 
			local id = C.bufferReadByte(buffer)
			handler(id, buffer)
		else 
			buffer[0].ptr = buffer[0].ptr - 2
		end
	end
end

function netMT:receive()
	self.tcp:receive()
	self.udp:receive()

	readTcpMessages(self.tcp.inStream, self.messageHandler)
	readUdpMessages(self.udp.inBuffer, self.messageHandler)
end

function netMT:send()
	self.tcp.outStream:flush()
	self.udp:send()
end