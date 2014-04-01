Network.incoming = {}

Network.incoming.map = 50
Network.incoming.towerBuilt = 51
Network.incoming.selected = 52
Network.incoming.deselected = 53
Network.incoming.towerEntered = 54
Network.incoming.towerExited = 55

Network.outgoing = {}

Network.outgoing.towerRequest = 50
Network.outgoing.selectRequest = 51
Network.outgoing.deselect = 52
Network.outgoing.mapRequest = 53
Network.outgoing.slingshotStart = 54
Network.outgoing.slingshotUpdate = 55
Network.outgoing.slingshotEnd = 56
Network.outgoing.towerEntered = 57
Network.outgoing.towerExited = 58

function sendAddTower(x, y, type)
	Out.writeShort(10)
	Out.writeByte(Network.outgoing.towerRequest)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeByte(type)
end

function sendSelectionMessage(pos)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.selectRequest)
	Out.writeInt(pos.x)
	Out.writeInt(pos.y)
end
		
function sendDeselectionMessage(x, y)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.deselect)
	Out.writeInt(x)
	Out.writeInt(y)
end

function sendMapRequestMessage()
	Out.writeShort(1)
	Out.writeByte(Network.outgoing.mapRequest)
end

function sendSlingshotBegin(x, y, pos) 
	Out.writeShort(17)
	Out.writeByte(Network.outgoing.slingshotStart)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeVec2(pos)
end

function sendSlingshotUpdate(x, y, pos) 
	Out.writeShort(17)
	Out.writeByte(Network.outgoing.slingshotUpdate)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeVec2(pos)
end

function sendSlingshotEnd(x, y) 
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.slingshotEnd)
	Out.writeInt(x)
	Out.writeInt(y)
end

function sendTowerEntered(x, y)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.towerEntered)
	Out.writeInt(x)
	Out.writeInt(y)
end

function sendTowerExited(x, y)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.towerExited)
	Out.writeInt(x)
	Out.writeInt(y)
end