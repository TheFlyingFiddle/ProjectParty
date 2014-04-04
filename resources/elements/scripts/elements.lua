local map
local tilesize = 40
local selections = {}
local towers = {}
local towerInstances = {}
local money = 0
local brokenIcon
local camera

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
local selector
local selectedCell

local function toGridPos(pos)
	local worldPos = camera:worldPos(pos)
	local cellx = math.floor( worldPos.x / tilesize)
	local celly = math.floor( worldPos.y / tilesize)
	log(string.format("gridPos %d,%d", cellx, celly))
	return vec2(cellx, celly)
end

local function findInstance(cell)
	for k, v in pairs(towerInstances) do
		if v.pos.x == cell.x and 
		   v.pos.y == cell.y then
			return v
		end
	end

	log(string.format("Did not find a tower for cell %d,%d", cell.x, cell.y))
end

local function Idle()
	local t = { }

	function t.onTap(pos)
		local gridPos = toGridPos(pos)
		local tileType = map.tiles[gridPos.y * map.width + gridPos.x]
		if tileType == 0 then
			for i = 1, #selections, 1 do
				if gridPos.x == selections[i].x and gridPos.y == selections[i].y then
					return
				end
			end
			selectedCell = gridPos
			sendSelectionMessage(gridPos)
			state:enterState("BuildableSelected")
		elseif tileType  == 1 then
			return
		else 
			selectedCell = gridPos
			state:enterState("TowerSelected", tileType)
		end
	end

	function t.enter() 
		selector = nil
		if selectedCell then
			sendDeselectionMessage(selectedCell)
			selectedCell = nil
		end
	end
	return t
end

local function TowerSelected()
	local t = { }

	local function callback(item)
		if item.id == 0 then

			local tower = findInstance(selectedCell)
			if tower.broken then
				fsm:enterState("Repair", selectedCell)
				return
			end

			if t.tileType == 2 then
				fsm:enterState("Vent", selectedCell)
			elseif t.tileType == 3 then
				fsm:enterState("Ballistic", selectedCell)
			end
		elseif item.id == 1 then			
			sendUpgradeTower(selectedCell)
			state:enterState("Idle")
		elseif item.id == 3 then
			sendSellTowerRequest(selectedCell)
			state:enterState("Idle")
		else
			state:enterState("Idle")
		end
	end

	function t.enter(type)
		local enter    = { id = 0, frame = fireIcon,	color = 0xFFFFFFFF }
		local upgrade  = { id = 1, frame = buyIcon,		color = 0xFF00FF00 }
		local cancel   = { id = 2, frame = cancelIcon,  color = 0xFF0000FF }
		local sell     = { id = 3, frame = buyIcon,     color = 0xFF0000FF }

		local items = { enter }
		local tower = findInstance(selectedCell)
	
		if tower.ownedByMe then
			table.insert(items, sell)
			table.insert(items, cancel)
			if towers[tower.type].upgradeIndex ~= 255 then
				table.insert(items, upgrade)
			end	
		else 
			table.insert(items, cancel)
		end

		selector = Selector(Rect(0,0,0,0), callback, items)
		t.tileType = type
	end

	return t
end

local function BuildableSelected()
	local t = { }
	
	local function callback(item)

		if item.id and item.id == 0 then
			state:enterState("Idle")
		else
			state:enterState("Confirm", item)
		end
	end	

	function t.enter()
		local items    = table.copy(towers)
		local cancel   = { id = 0, frame = cancelIcon,  color = 0xFF0000FF }
		table.insert(items,cancel)
		selector = Selector(Rect(0,0,0,0), callback, items)
	end

	return t
end

local function Confirm()
	local t = { }

	local function callback(item) 
		if item.id == 0 then
			sendAddTower(selectedCell, t.tower.type, t.tower.typeIndex)
			state:enterState("Idle")
		else 
			state:enterState("Idle")
		end
	end

	function t.enter(tower)
		local buy = {id = 0, frame = buyIcon, color = 0xFFFFFFFF}
		local cancel = {id = 1, frame = cancelIcon, color = 0xFF000000}
		selector = Selector(Rect(0,0,0,0), callback, {buy, cancel})
		t.tower = tower
	end
	return t	
end

function Elements()
	local elements = {}
	camera = Camera( Rect2(0, 0, Screen.width, Screen.height), vec2(1000, 1000), 0.5, 3)
	brokenIcon = windIcon

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

	function elements.render()
		local origin = camera:transform(vec2(0,0))
		local pos = vec2(origin)
		local dim = camera:scale(vec2(tilesize, tilesize))

		for row=0, map.height-1, 1 do
			for col=0, map.width-1, 1 do
				local color
				local type = map.tiles[row*map.width + col]
				color = tileColors[type+1]
				Renderer.addFrame(pixel, pos, dim, color)
				pos.x = pos.x + dim.x
			end
			pos.x = origin.x
			pos.y = pos.y + dim.y
		end

		
		pos = vec2(origin.x - 0.5, origin.y - 0.5)
		local gridLineDim = camera:scale(vec2(map.width * tilesize, 1))
		for i=0, map.height, 1 do
			Renderer.addFrame(pixel, pos, gridLineDim, 0x44FFFFFF)
			pos.y = pos.y + camera:scale(tilesize)
		end

		pos = vec2(origin.x - 0.5, origin.y - 0.5)
		local gridLineDim = camera:scale(vec2(1, map.width * tilesize))
		for i=0, map.width, 1 do
			Renderer.addFrame(pixel, pos, gridLineDim, 0x44FFFFFF)
			pos.x = pos.x + camera:scale(tilesize)
		end


		for i = 1, #selections, 1 do 
			Renderer.addFrame(pixel, 
				camera:transform(vec2(selections[i].x * dim.x,
								      selections[i].y * dim.y)), dim, 
				selections[i].color)
		end

		for k,v in pairs(towerInstances) do
			local frame
			if v.broken then frame = brokenIcon else frame = v.frame end

			pos = camera:transform(v.pos * dim.x)
			Renderer.addFrame(frame, pos, dim, v.color)
		end

		renderTime(font)
		Renderer.addText(font, string.format("Gold: %d ", money), vec2(0, 300), 0xFFFFFFFF)

		if selector then
			local radius = Screen.height / 4
			selector.rect.pos = 
			camera:transform(vec2(selectedCell.x * dim.x + dim.x / 2 - radius, 
								  selectedCell.y * dim.y + dim.y / 2 - radius))
			selector.rect.dim = vec2(radius * 2, radius * 2)
			selector:draw()
		end

	end

	local function handleMap()
		map = {}
		map.width = In.readInt()
		map.height = In.readInt()
		map.tiles = In.readByteArray() 

		camera.worldDim = vec2(map.width * tilesize, map.height * tilesize)

	end

	local function handleTowerBuilt() 
		local x = In.readInt()
		local y = In.readInt()
		local type = In.readByte()
		local typeIndex = In.readByte()
		local isOwned   = In.readByte()

		map.tiles[y*map.width + x] = type

		for k,v in pairs(towers) do
			if v.type == type and v.typeIndex == typeIndex then
				table.insert(towerInstances, 
					{ frame = v.frame, color = v.color, 
					  pos = vec2(x, y), broken = false ,
					  type = k, ownedByMe = isOwned == 1})
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

		for k, v in pairs(towerInstances) do
			if v.pos.x == x and v.pos.y == y then
				table.remove(towerInstances, k)
				return
			end
		end

	end

	local function handleTowerBroken()
		local x = In.readInt()
		local y = In.readInt()

		local tower = findInstance(vec2(x, y))
		tower.broken = true
	end

	local function handleTowerRepaired()
		local x = In.readInt()
		local y = In.readInt()

		local tower = findInstance(vec2(x, y))
		tower.broken = false
	end

	Network.setMessageHandler(Network.incoming.map, handleMap)
	Network.setMessageHandler(Network.incoming.towerBuilt, handleTowerBuilt)
	Network.setMessageHandler(Network.incoming.selected, handleSelectRequest)
	Network.setMessageHandler(Network.incoming.deselected, handleDeselectRequest)
	Network.setMessageHandler(Network.incoming.towerInfo, handleTowerInfo)
	Network.setMessageHandler(Network.incoming.transaction, handleTransaction)
	Network.setMessageHandler(Network.incoming.towerSold, handleTowerSold)
	Network.setMessageHandler(Network.incoming.towerBroken, handleTowerBroken)
	Network.setMessageHandler(Network.incoming.towerRepaired, handleTowerRepaired)

	function elements.onTap(x,y)
		if state.active.onTap then
			state.active.onTap(vec2(x,y))
		end

		if selector then
			if pointInRect(selector.rect, vec2(x,y)) then
				selector:onTap(vec2(x,y))	
			else
				state:enterState("Idle")
			end
		end
	end

	function elements.onDragBegin(x, y)
		camera:onDragBegin(vec2(x, y))
	end

	function elements.onDrag(x, y)
		camera:onDrag(vec2(x,y))
	end

	function elements.onPinchBegin(x0, y0, x1, y1)
		camera:onPinchBegin(vec2(x0,y0), vec2(x1, y1))
	end

	function elements.onPinch(x0, y0, x1, y1)
		camera:onPinch(vec2(x0,y0), vec2(x1, y1))
	end

	return elements
end

