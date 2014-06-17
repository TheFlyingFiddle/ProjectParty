Network.incoming = {}

Network.sendRate = 0.1
Network.sendElapsed = 0

Network.incoming.transition		= Network.messages.transition
Network.incoming.youDraw		= 50
Network.incoming.youGuess	 	= 51
Network.incoming.betweenRounds	= 52
Network.incoming.correctAnswer 	= 53
Network.incoming.incorrectAnswer= 54
	
Network.outgoing = {}

Network.outgoing.toggleReady	= 49
Network.outgoing.choice 		= 50
Network.outgoing.ready 			= 51
Network.outgoing.pixel 			= 52
Network.outgoing.clear 			= 53


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
	logf("Message ID: %d", id)
	if Network.decoders[id] then
		local message = Network.decoders[id]()
		if Network.handlers[id] then
			for k, v in pairs(Network.handlers[id]) do
				v(message)
			end
		end
	end
end

local function readTransition()
	return In.readUTF8()
end

local function readYouDraw()
	return In.readUTF8()
end

local function readYouGuess()
	local len = In.readShort()
	local choices = {}
	for i=1, len, 1 do
		choices[i] = In.readUTF8()
	end
	return choices
end

local function readBetweenRounds()
	return In.readByte() == 1
end

local function readCorrectAnswer()
end

local function readIncorrectAnswer()
end

Network.decoders[Network.incoming.transition] = readTransition

Network.decoders[Network.incoming.youDraw] 			= readYouDraw
Network.decoders[Network.incoming.youGuess] 		= readYouGuess
Network.decoders[Network.incoming.betweenRounds] 	= readBetweenRounds
Network.decoders[Network.incoming.correctAnswer] 	= readCorrectAnswer
Network.decoders[Network.incoming.incorrectAnswer] 	= readIncorrectAnswer

function sendChoice(choice)
	Out.writeShort(2)
	Out.writeByte(Network.outgoing.choice)
	Out.writeByte(choice)
end

function sendReady()
	Out.writeShort(1)
	Out.writeByte(Network.outgoing.ready)
end

function sendPixel(begin, position)
	Out.writeShort(10)
	Out.writeByte(Network.outgoing.pixel)
	Out.writeByte(begin)
	Out.writeFloat(position.x)
	Out.writeFloat(position.y)
end

function sendClear()
	Out.writeShort(1)
	Out.writeByte(Network.outgoing.clear)
end


function sendToggleReady()
	Out.writeShort(1)
	Out.writeByte(Network.outgoing.toggleReady)
end