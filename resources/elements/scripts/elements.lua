local map
local tilesize = 40
local cameraPos = vec2(0,0)
local selections = {}
local towers = {}
local towerImages = {}
local money = 0

local tileColors = 
	{
		0xFF559567,
		0xFF456a90,
		0xFF0000FF,
		0xFFFF0000,
		0xFFFFFF00,
		0xFF00FFFF,
		0xFF88FF88,
		0xFF00FF00
}

local state

local function toGridPos(pos)
	local cellx = math.floor((pos.x - cameraPos.x) / tilesize)
	local celly = math.floor((pos.y - cameraPos.y) / tilesize)
	return vec2(cellx,celly)
end

local function Idle()
	local t = { draw = function() end}
	function t.onTap(pos)
		local gridPos = toGridPos(pos)
		local tileType = map.tiles[gridPos.y * map.width + gridPos.x]
		if tileType == 0 then
			for i = 1, #selections, 1 do
				if gridPos.x == selections[i].x and gridPos.y == selections[i].y then
					return
				end
			end
			sendSelectionMessage(gridPos)
			state:enterState("BuildableSelected", gridPos)
		elseif tileType > 1 then
			state:enterState("TowerSelected", gridPos)
		end
	end

	function t.enter(x, y) 
		if x and y then sendDeselectionMessage(x, y) end
	end
	return t
end

local function TowerSelected()
	local t = { }

	local function callback(item)
		if item.id == 0 then
			local type = map.tiles[t.y*map.width + t.x]
			if type == 3 then
				fsm:enterState("Ballistic", t.x, t.y)
			elseif type == 2 then
				fsm:enterState("Vent", t.x, t.y)
			end
		elseif item.id == 1 then
			--Do upgrade if possible
		elseif item.id == 3 then
			sendSellTowerRequest(t.x, t.y)
			state:enterState("Idle", t.x, ty)
		else
			state:enterState("Idle", t.x, ty)
		end
	end

	local enter    = { id = 0, frame = fireIcon,	color = 0xFFFFFFFF }
	local upgrade  = { id = 1, frame = buyIcon,		color = 0xFF00FF00 }
	local cancel   = { id = 2, frame = cancelIcon,  color = 0xFF0000FF }
	local sell     = { id = 3, frame = buyIcon,     color = 0xFF0000FF }
	local selector = Selector(Rect(0,0,0,0), callback, {enter, upgrade, cancel, sell})
	
	function t.draw()
		local radius = Screen.height / 4
		selector.rect.pos = vec2(t.x * tilesize + tilesize / 2 + cameraPos.x - radius,
					 			 t.y * tilesize + tilesize / 2 + cameraPos.y - radius)
		selector.rect.dim = vec2(radius * 2, radius * 2)

		selector:draw()
	end

	function t.onTap(pos)
		selector:onTap(pos)
	end

	function t.enter(cell)
		t.x = cell.x
		t.y = cell.y
	end

	return t
end

local function BuildableSelected()
	local t = { }
	
	local function callback(item)
		state:enterState("Confirm", vec2(t.x, t.y), item)
	end	

	local selector

	function t.onTap(pos)
		selector:onTap(pos)
	end

	function t.draw()
		Renderer.addText(font, "In selected state", vec2(0,100), 0xFFFF0000)
		Renderer.addFrame(pixel, vec2(t.x*tilesize + cameraPos.x, 
									  t.y*tilesize + cameraPos.y), 
										vec2(tilesize,tilesize), 0xFF0000FF)
		local radius = Screen.height / 4
		selector.rect.pos = vec2(t.x * tilesize + tilesize / 2 + cameraPos.x - radius,
					 			 t.y * tilesize + tilesize / 2 + cameraPos.y - radius)
		selector.rect.dim = vec2(radius * 2, radius * 2)

		selector:draw()
	end

	function t.enter(cell)
		t.x = cell.x
		t.y = cell.y

		selector = Selector(Rect(0,0,0,0), callback, towers)
	end

	return t
end

local function Confirm()
	local t = { }

	local function callback(item) 
		if item.id == 0 then
			sendAddTower(t.x, t.y, t.tower.type, t.tower.typeIndex)
			state:enterState("Idle", t.x, t.y)
		else 
			state:enterState("Idle", t.x, t.y)
		end
	end

	local buy = {id = 0, frame = buyIcon, color = 0xFFFFFFFF}
	local cancel = {id = 1, frame = cancelIcon, color = 0xFF000000}
	local selector = Selector(Rect(0,0,0,0), callback, {buy, cancel})

	function t.draw()
		local towerRadius = 3 * tilesize

		Renderer.addText(font, "In Confirm state", vec2(0,100), 0xFFFF00FF)
		Renderer.addFrame(pixel, vec2(t.x*tilesize + cameraPos.x, 
									  t.y*tilesize + cameraPos.y), 
										vec2(tilesize,tilesize), 0xFFFF0000)

		local radius = Screen.height / 4
		selector.rect.pos = vec2(t.x * tilesize + tilesize / 2 + cameraPos.x - radius,
					 			 t.y * tilesize + tilesize / 2 + cameraPos.y - radius)
		selector.rect.dim = vec2(radius * 2, radius * 2)

		selector:draw()
	end
	function t.onTap(pos)
		selector:onTap(pos)
	end
	function t.enter(cell, tower)
		t.x = cell.x
		t.y = cell.y
		t.tower = tower
	end
	return t	
end

function Elements()
	local elements = {}
	function elements.enter()
		state:enterState("Idle")
	end
	function elements.init()
		sendMapRequestMessage()
		state = FSM()
		state:addState(Idle(), "Idle")
		state:addState(BuildableSelected(), "BuildableSelected")
		state:addState(TowerSelected(), "TowerSelected")
		state:addState(Confirm(), "Confirm")
	end

	function elements.exit()
	end
	function elements.render()
		local pos = vec2(cameraPos)
		local dim = vec2(tilesize,tilesize)
		for row=0, map.height-1, 1 do
			for col=0, map.width-1, 1 do
				local color
				local type = map.tiles[row*map.width + col]
				color = tileColors[type+1]
				Renderer.addFrame(pixel, pos, dim, color)
				pos.x = pos.x + dim.x
			end
			pos.x = cameraPos.x
			pos.y = pos.y + dim.y
		end
		for i = 1, #selections, 1 do 
			Renderer.addFrame(pixel, vec2(selections[i].x * tilesize + cameraPos.x,
										  selections[i].y * tilesize + cameraPos.y), dim, 
				selections[i].color)
		end
		for k,v in pairs(towerImages) do
			pos = cameraPos + v.pos * tilesize
			Renderer.addFrame(v.frame, pos, dim, v.color)
		end

		renderTime(font)
		Renderer.addText(font, string.format("Gold: %d", money), vec2(0, 300), 0xFFFFFFFF)
		state.active.draw()
	end
	function elements.update()

	end

	local function handleMap()
		map = {}
		map.width = In.readInt()
		map.height = In.readInt()
		map.tiles = In.readByteArray() 
	end

	local function handleTowerBuilt() 
		local x = In.readInt()
		local y = In.readInt()
		local type = In.readByte()
		local typeIndex = In.readByte()
		map.tiles[y*map.width + x] = type

		for k,v in pairs(towers) do
			if v.type == type and v.typeIndex == typeIndex then
				log("I'm in the if statement!")
				table.insert(towerImages, {frame = v.frame, color = v.color, pos = vec2(x, y)})
			end
		end
	end

	local function handleSelectRequest()
		local rx = In.readInt()
		local ry = In.readInt()
		local rcolor = In.readInt()
		selections[#selections + 1] = {x = rx, y = ry, color = rcolor} 
	end

	local function handleDeselectRequest()
		local rx = In.readInt()
		local ry = In.readInt()

		for i = 1, #selections, 1 do
			if selections[i].x == rx and selections[i].y == ry then
				table.remove(selections, i)
				return
			end
		end 
	end	

	local function handleTowerInfo() 
		local tower = {}

		tower.cost = In.readInt()
		tower.range = In.readFloat()
		tower.frame = Loader.loadFrame(In.readUTF8())
		tower.color = In.readInt()
		tower.type = In.readByte()
		tower.typeIndex = In.readByte()
		tower.upgradeIndex = In.readByte()

		table.insert(towers, tower)
	end

	local function handleTransaction()
		local amount = In.readInt()
		money = money + amount
	end

	local function handleTowerSold()
		local x = In.readInt()
		local y = In.readInt()

		map.tiles[y*map.width + x] = 0

		for k, v in pairs(towerImages) do
			if v.pos.x == x and v.pos.y == y then
				table.remove(towerImages, k)
				return
			end
		end

	end

	Network.setMessageHandler(Network.incoming.map, handleMap)
	Network.setMessageHandler(Network.incoming.towerBuilt, handleTowerBuilt)
	Network.setMessageHandler(Network.incoming.selected, handleSelectRequest)
	Network.setMessageHandler(Network.incoming.deselected, handleDeselectRequest)
	Network.setMessageHandler(Network.incoming.towerInfo, handleTowerInfo)
	Network.setMessageHandler(Network.incoming.transaction, handleTransaction)
	Network.setMessageHandler(Network.incoming.towerSold, handleTowerSold)

	function elements.onTap(x,y)
		state.active.onTap(vec2(x,y))
	end

	local oldDrag
	function elements.onDrag(x, y)
		local deltaX = x - oldDrag.x
		local deltaY = y - oldDrag.y
		oldDrag = vec2(x,y)
		moveCamera(deltaX, deltaY)
	end

	function elements.onDragBegin(x, y)
		oldDrag = vec2(x,y)
	end

	local oldDist, centerP
	function elements.onPinchBegin(x0, y0, x1, y1)
		centerP = vec2((x0 + x1) / 2, (y0 + y1) / 2)
		oldDist    = math.sqrt((x0 - x1) * (x0 - x1) + (y0 - y1) * (y0 - y1))
	end

	function elements.onPinch(x0, y0, x1, y1)
		log("pinch")
		local dist    = math.sqrt((x0 - x1) * (x0 - x1) + (y0 - y1) * (y0 - y1))
		local delta   = dist - oldDist
		oldDist = dist
		if math.abs(delta) < 2 then
			return
		end
		local oldTileSize = tilesize
		tilesize = tilesize + delta * 0.06

		log(tostring(tilesize))

		local minTileX = Screen.width / map.width
		local minTileY = Screen.height / map.height
		local minTile = math.min(minTileX, minTileY)

		local maxTile = Screen.height / 5

		if tilesize < minTile then
			tilesize = minTile
		elseif tilesize > maxTile then
			tilesize = maxTile
		end

		local x = (cameraPos.x / oldTileSize) * (tilesize - oldTileSize)
		local y = (cameraPos.y / oldTileSize) * (tilesize - oldTileSize)
		moveCamera(x,y)
	end

	function moveCamera(x, y)
		cameraPos.x = cameraPos.x + x
		cameraPos.y = cameraPos.y + y
		if cameraPos.x > 0 then
			cameraPos.x = 0
		elseif cameraPos.x < -map.width * tilesize + Screen.width then
			cameraPos.x = -map.width * tilesize + Screen.width
		end

		if cameraPos.y > 0 then
			cameraPos.y = 0
		elseif cameraPos.y < -map.height * tilesize + Screen.height then
			cameraPos.y = -map.height * tilesize + Screen.height
		end
	end

	return elements
end

