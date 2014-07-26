local netMT = { }
netMT.__index = netMT

global.networkReaders = global.networkReaders or { }
global.networkWriters = global.networkWriters or { }
global.NetIn  		  = global.NetIn  or { }
global.NetOut 		  = global.NetOut or { }

function global.Network(bufSize, messageHandler, sessionID)
	local t = { }
	t.tcp = TcpSocket(bufSize, bufSize)
	t.udp = UdpSocket(bufSize, bufSize)
	if sessionID then 
		t.sessionID = sessionID
	end

	t.messageHandler = messageHandler
	t.router		 = { }
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

	self.udp:bind(0,0)
	self.udp:blocking(false)
	self.udp:connect(ip, udpPort)

	--More complex then this!
end

function netMT:disconnect()
	self.tcp:close()
	self.udp:close()
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

	Log.infof("Key: ", key)

	if key then 
		Log.warnf("No reader for message! %s", key)
	else 
		Log.warnf("There is no message reader for id %d", id)
	end
end

local function readTcpMessages(self, stream, handler)
	while stream:dataLength() > 2 do 
		local length = stream:readShort()
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
				end
			end
		else
			stream:setPosition(stream:getPosition() - 2)
		end 
	end
end

local function readUdpMessages(self, buffer)
	local rem = C.bufferBytesRemaining(buffer)
	while rem > 2 do
		local length = C.bufferReadShort(buffer)
		if rem - 2 >= length then 
			local id = C.bufferReadShort(buffer)
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

function netMT:receive()
	self.tcp:receive()
	self.udp:receive()

	--readTcpMessages(self, self.tcp.inStream, self.messageHandler)
	--readUdpMessages(self, self.udp.inBuffer, self.messageHandler)
end

function netMT:send()
	--self.tcp.outStream:flush()
	--self.udp:send(self.udp.ip, self.udp.port)
end

function netMT:addListener(id, listener)
	if not self.router[id] then 
		self.router[id] = { }
	end

	table.insert(self.router[id], listener)
end

function netMT:sendMessage(id, msg)
	local func = networkWriters[id]
	if func then 
		local buf = self.tcp.outStream:buffer();
		func(buf, msg)
	end				
end

function netMT:removeListener(id, listener)
	for i ,v in ipairs(self.router[id]) do
		if v == listener then
			table.remove(i)
			return
		end
	end
end
