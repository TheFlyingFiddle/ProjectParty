function init()
	Game.setFps(60)
end

function term()
end

function handleMessage(id, length)
	if id == 50 then 
		local sequence  = In.readShort()
		local bytes     = In.readByteArray()
		Out.writeShort(3)
		Out.writeByte(50)
		Out.writeShort(sequence)
		Network.send()
	end
end

function update()
	--Sending sensordata on every update.
	Out.writeShort(25)
	Out.writeByte(1)
	Out.writeVec3(Sensors.acceleration)
	Out.writeVec3(Sensors.gyroscope)
	Network.send()
end

function render()
end