Network.incoming = {}

Network.sendRate = 0.1
Network.sendElapsed = 0

Network.incoming.transition		= Network.messages.transition

Network.incoming.map 			= 50
Network.incoming.towerBuilt 	= 51
Network.incoming.selected 		= 52
Network.incoming.deselected 	= 53
Network.incoming.towerEntered 	= 54
Network.incoming.towerExited 	= 55
Network.incoming.towerInfo 		= 56
Network.incoming.transaction 	= 57
Network.incoming.towerSold   	= 58
Network.incoming.towerBroken	= 59
Network.incoming.towerRepaired  = 60
Network.incoming.ventInfo 		= 61
Network.incoming.ballisticInfo 	= 62
Network.incoming.gatlingInfo 	= 63
Network.incoming.pressureInfo 	= 64
	
Network.outgoing = {}

Network.outgoing.sensor 			= 1
Network.outgoing.toggleReady		= 49
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
Network.outgoing.repaired 			= 63
Network.outgoing.gatlingValue		= 64


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

local function readTransition()
	return In.readUTF8()
end

local function readCell()
	local cell = {}
	cell.x = In.readInt()
	cell.y = In.readInt()
	return cell
end

local function readMap()
	local map  = {}
	map.width  = In.readInt()
	map.height = In.readInt()
	map.tiles  = In.readByteArray() 
	return map
end

local function readTowerBuilt()
	local tower 		= { }
	tower.x 			= In.readInt()
	tower.y 			= In.readInt()
	tower.type 			= In.readByte()
	tower.typeIndex 	= In.readByte()
	tower.isOwned   	= In.readByte()
	tower.playerColor 	= In.readInt()
	tower.broken 		= In.readByte() == 1
	return tower
end

local function readSelected()
	local cell = readCell()
	cell.color = In.readInt()
	return cell
end

local function readDeselected()
	return readCell()
end

local function readTowerEntered() 
	return readCell()
end

local function readTowerExited() 
	return readCell()
end

local function readTowerInfo()
	local tower = {}

	tower.cost 			= In.readInt()
	tower.range 		= In.readFloat()
	tower.frame 		= Loader.loadFrame(In.readUTF8())
	tower.name 	        = In.readUTF8()
	tower.info 	        = In.readUTF8()
	tower.type 			= In.readByte()
	tower.typeIndex 	= In.readByte()
	tower.basic 		= In.readByte() == 1
	tower.upgradeIndex0 = In.readByte()
	tower.upgradeIndex1 = In.readByte()
	tower.upgradeIndex2 = In.readByte()
	tower.color         = 0xFFFFFFFF

	return tower
end

local function readTransaction()
	return In.readInt()
end

local function readTowerSold()
	return readCell()
end

local function readTowerBroken()
	return readCell()
end

local function readTowerRepaired()
	return readCell()
end

local function readVentInfo()
	local ventInfo = {}
	ventInfo.pressure 		= In.readFloat()
	ventInfo.maxPressure 	= In.readFloat()
	ventInfo.direction     = In.readFloat()
	ventInfo.open          = In.readFloat()
	return ventInfo
end

local function readBallisticInfo()
	 bInfo = {}
	 bInfo.pressure = In.readFloat()
	 bInfo.maxPressure = In.readFloat()
	 bInfo.direction = In.readFloat()
	 bInfo.distance = In.readFloat()
	 bInfo.maxDistance = In.readFloat()
	 bInfo.pressureCost = In.readFloat()
	return bInfo
end

local function readGatlingInfo()
	local gInfo = {}
	gInfo.pressure = In.readFloat()
	gInfo.maxPressure = In.readFloat()
	return gInfo
end

local function readPressureInfo()
	return In.readFloat()
end

Network.decoders[Network.incoming.transition] = readTransition

Network.decoders[Network.incoming.map] = readMap
Network.decoders[Network.incoming.towerBuilt] = readTowerBuilt
Network.decoders[Network.incoming.selected] = readSelected
Network.decoders[Network.incoming.deselected] = readDeselected
Network.decoders[Network.incoming.towerEntered] = readTowerEntered
Network.decoders[Network.incoming.towerExited] = readTowerExited
Network.decoders[Network.incoming.towerInfo] = readTowerInfo
Network.decoders[Network.incoming.transaction] = readTransaction
Network.decoders[Network.incoming.towerSold] = readTowerSold
Network.decoders[Network.incoming.towerBroken] = readTowerBroken
Network.decoders[Network.incoming.towerRepaired] = readTowerRepaired
Network.decoders[Network.incoming.selected] = readSelected
Network.decoders[Network.incoming.ventInfo] = readVentInfo
Network.decoders[Network.incoming.ballisticInfo] = readBallisticInfo
Network.decoders[Network.incoming.gatlingInfo] = readGatlingInfo
Network.decoders[Network.incoming.pressureInfo] = readPressureInfo

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

function sendUpgradeTower(cell, index)
	log("Sending upgrade message!")
	Out.writeShort(10)
	Out.writeByte(Network.outgoing.upgradeTower)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
	Out.writeByte(index)
end

function sendRepaired(cell)
	Out.writeShort(9)
	Out.writeByte(Network.outgoing.repaired)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
end

function sendGatlingValue(cell, gatlingValue)
	Out.writeShort(13)
	Out.writeByte(Network.outgoing.gatlingValue)
	Out.writeInt(cell.x)
	Out.writeInt(cell.y)
	Out.writeFloat(gatlingValue)
end

function sendToggleReady()
	Out.writeShort(1)
	Out.writeByte(Network.outgoing.toggleReady)
end
