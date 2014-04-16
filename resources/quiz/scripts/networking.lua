Network.incoming = {}

Network.sendRate = 0.1
Network.sendElapsed = 0

Network.incoming.choices	 	= 50
Network.incoming.correctAnswer 	= 51
Network.incoming.showAnswer		= 52
	
Network.outgoing = {}

Network.outgoing.choice 		= 50
Network.outgoing.buyScore 		= 51

Network.handlers = {}
Network.decoders = {}

function Network.setMessageHandler(id, callback)	
	if Network.handlers[id] then
		table.insert(Network.handlers[id], callback)
	else 
		Network.handlers[id] = { callback }
	end
end

function Network.removeMessageHandler(id, callback)
	if Network.handlers[id] then
		for i=1, #Network.handlers[id], 1 do
			local t = Network.handlers[id]
			if t[i] == callback then
				table.remove(t, i)
				return
			end
		end
	end
end

function Network.setMessageDecoder(id, callback)
	Network.decoders[id] = callback
end

function handleMessage(id, length)
	if Network.decoders[id] then
		local message = Network.decoders[id]()
		if Network.handlers[id] then
			for k, v in pairs(Network.handlers[id]) do
				v(message)
			end
		end
	end
end

local function readChoices()
	local len = In.readShort()
	local choices = {}
	for i=1, len, 1 do
		choices[i] = In.readUTF8()
	end
	choices.category = In.readByte()
	return choices
end

local function readVoid()
end

local function readShowAnswer()
	return In.readByte()
end

Network.decoders[Network.incoming.choices]			= readChoices
Network.decoders[Network.incoming.correctAnswer] 	= readVoid
Network.decoders[Network.incoming.showAnswer] 		= readShowAnswer

function sendChoice(choice)
	Out.writeShort(2)
	Out.writeByte(Network.outgoing.choice)
	Out.writeByte(choice)
end

function sendBuyScore(category)
	Out.writeShort(2)
	Out.writeByte(Network.outgoing.buyScore)
	Out.writeByte(category)
end
