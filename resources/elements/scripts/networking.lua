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
Network.outgoing.upgradeTower		= 62

Network.handlers = {}

function Network.setMessageHandler(id, callback)
	Network.handlers[id] = callback
end

function handleMessage(id, length)
	if Network.handlers[id] then
		Network.handlers[id]()
	end
end

function sendAddTower(cell, type, index)
	Out.writeShort(11)
	Out.writeByte(Network.outgoing.towerRequest)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
	Out.writeByte(type)
	Out.writeByte(index)
end

function sendSelectionMessage(cell)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.selectRequest)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
end
		
function sendDeselectionMessage(cell)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.deselect)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
end

function sendMapRequestMessage()
	Out.writeShort(1)
	Out.writeByte(Network.outgoing.mapRequest)
end

function sendTowerEntered(cell)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.towerEntered)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
end

function sendTowerExited(cell)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.towerExited)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
end

function sendVentValue(cell, ventValue)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.ventValue)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
	Out.writeFloat(ventValue)
end

function sendVentDirection(cell, ventDir)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.ventDirection)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
	Out.writeFloat(ventDir)
end

function sendSellTowerRequest(cell)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.sellTower)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
end

function sendBallisticValue(cell, ballisticValue)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.ballisticValue)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
	Out.writeFloat(ballisticValue)
end

function sendBallisticDirection(cell, ballisticDir)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.ballisticDirection)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
	Out.writeFloat(ballisticDir)
end

function sendBallisticLaunch(cell)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.ballisticLaunch)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
end

function sendUpgradeTower(cell)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.upgradeTower)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
end