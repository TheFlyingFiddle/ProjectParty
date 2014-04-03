Network.incoming = {}

Network.sendRate = 0.1
Network.sendElapsed = 0

Network.incoming.map 			= 50
Network.incoming.towerBuilt 	= 51
Network.incoming.selected 		= 52
Network.incoming.deselected 	= 53
Network.incoming.towerEntered 	= 54
Network.incoming.towerExited 	= 55
Network.incoming.towerInfo 		= 56
Network.incoming.transaction 	= 57
Network.incoming.towerSold   	= 58

Network.outgoing = {}

Network.outgoing.sensor 			= 1
Network.outgoing.towerRequest 		= 50
Network.outgoing.selectRequest 		= 51
Network.outgoing.deselect 			= 52
Network.outgoing.mapRequest 		= 53
Network.outgoing.towerEntered 		= 54
Network.outgoing.towerExited 		= 55
Network.outgoing.ventValue 			= 56
Network.outgoing.ventDirection 		= 57
Network.outgoing.sellTower	    	= 58
Network.outgoing.ballisticValue		= 59
Network.outgoing.ballisticDirection	= 60
Network.outgoing.ballisticLaunch	= 61

Network.handlers = {}

function Network.setMessageHandler(id, callback)
	Network.handlers[id] = callback
end

function handleMessage(id, length)
	if Network.handlers[id] then
		Network.handlers[id]()
	end
end

function sendAddTower(x, y, type, index)
	Out.writeShort(11)
	Out.writeByte(Network.outgoing.towerRequest)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeByte(type)
	Out.writeByte(index)
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

function sendVentValue(x, y, ventValue)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.ventValue)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeFloat(ventValue)
end

function sendVentDirection(x,y, ventDir)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.ventDirection)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeFloat(ventDir)
end

function sendSellTowerRequest(x,y)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.sellTower)
	Out.writeInt(x)
	Out.writeInt(y)
end

function sendBallisticValue(x, y, ballisticValue)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.ballisticValue)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeFloat(ballisticValue)
end

function sendBallisticDirection(x,y, ballisticDir)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.ballisticDirection)
	Out.writeInt(x)
	Out.writeInt(y)
	Out.writeFloat(ballisticDir)
end

function sendBallisticLaunch(x,y)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.ballisticLaunch)
	Out.writeInt(x)
	Out.writeInt(y)
end

