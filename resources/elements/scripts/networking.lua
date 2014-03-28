
function sendAddTower(x, y, type)
	Out.writeShort(10)
	Out.writeByte(Network.messages.towerRequest)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeByte(type)
end

function sendSelectionMessage(pos)
	Out.writeShort(9)
	Out.writeByte(Network.messages.selectRequest)
	Out.writeInt(pos.x)
	Out.writeInt(pos.y)
end
		
function sendDeselectionMessage(x, y)
	Out.writeShort(9)
	Out.writeByte(Network.messages.deselect)
	Out.writeInt(x)
	Out.writeInt(y)
end

function sendMapRequestMessage()
	Out.writeShort(1)
	Out.writeByte(Network.messages.mapRequest)
end
