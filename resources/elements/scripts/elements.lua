local sensorNetworkID = 1

local map
local tilesize = 40
local cameraPos = vec2(0,0)
local selections = {}

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

local function distance(pos1, pos2)
	return math.sqrt((pos1.x - pos2.x)*(pos1.x - pos2.x) + (pos1.y - pos2.y)*(pos1.y - pos2.y))
end



local function confirmSelect(localPos, cell, radius)
	local pos = vec2(cell.x * tilesize + tilesize / 2 + cameraPos.x - radius,
					 cell.y * tilesize + tilesize / 2 + cameraPos.y - radius)
	log(string.format("wp: %d,%d, pos:%d,%d", localPos.x, localPos.y, pos.x, pos.y))

	local dim = vec2(radius * 2, radius * 2)
	local smallRadius = radius / 4
	local smallDim = vec2(smallRadius * 2, smallRadius * 2);


	local smallPos2 = vec2(pos.x + radius, pos.y + radius + radius * 0.66)
	local smallPos4 = vec2(pos.x + radius, pos.y + radius / 3)

	if distance(localPos, smallPos2)<= smallRadius then
		return true
	elseif distance(localPos, smallPos4)<= smallRadius then
		return false 
	elseif distance(localPos, vec2(pos.x + radius, pos.y + radius)) <= radius then
		return 0
	end
	return nil

end



local function drawConfirmationItems(cell, radius)
	local pos = vec2(cell.x * tilesize + tilesize / 2 + cameraPos.x - radius,
					 cell.y * tilesize + tilesize / 2 + cameraPos.y - radius)

	local dim = vec2(radius * 2, radius * 2)
	local smallRadius = radius / 4;
	local smallDim = vec2(smallRadius * 2, smallRadius * 2);

	local smallPos1 = vec2(pos.x + radius - smallRadius, pos.y + radius + radius * 0.66 - smallRadius)
	local smallPos2 = vec2(pos.x + radius - smallRadius, pos.y + radius / 3 - smallRadius)

	Renderer.addFrame(buyIcon, smallPos1, smallDim, 0xFF00FFFF)
	Renderer.addFrame(cancelIcon, smallPos2, smallDim, 0xFF0000FF)
end

local function drawTowerRadius(cell, towerRadius)
	local pos = vec2(cell.x * tilesize + tilesize / 2 + cameraPos.x - towerRadius,
					 cell.y * tilesize + tilesize / 2 + cameraPos.y - towerRadius)

	local dim = vec2(towerRadius * 2, towerRadius * 2)

	Renderer.addFrame(ring, pos, dim, 0x88FF00FF)
end



local function Idle()
	local t = { draw = function() end}
	function t.onTap(pos)
		local gridPos = toGridPos(pos)
		if map.tiles[gridPos.y * map.width + gridPos.x] == 0 then
			for i = 1, #selections, 1 do
				if gridPos.x == selections[i].x and gridPos.y == selections[i].y then
					return
				end
			end

			sendSelectionMessage(gridPos)
			state:enterState("Selected", gridPos)
		end
	end

	function t.enter(x, y) 
		if x and y then sendDeselectionMessage(x, y) end
	end
	return t
end

local function Selected(item1, item2, item3)
	local t = { }
	function drawSelectionCircle(cell, radius) 
		local pos = vec2(cell.x * tilesize + tilesize / 2 + cameraPos.x - radius,
						 cell.y * tilesize + tilesize / 2 + cameraPos.y - radius)

		local dim = vec2(radius * 2, radius * 2)
		local smallRadius = radius / 4;
		local smallDim = vec2(smallRadius * 2, smallRadius * 2);

		local smallPos1 = vec2(pos.x + radius/3 - smallRadius, pos.y + radius - smallRadius)
		local smallPos2 = vec2(pos.x + radius - smallRadius, pos.y + radius + radius * 0.66 - smallRadius)
		local smallPos3 = vec2(pos.x + radius + radius * 0.66 - smallRadius, pos.y + radius - smallRadius)
		local smallPos4 = vec2(pos.x + radius - smallRadius, pos.y + radius / 3 - smallRadius)

		Renderer.addFrame(circle, pos, dim, 0x88FFFFFF)
		Renderer.addFrame(item1.frame, smallPos1, smallDim, item1.color)
		Renderer.addFrame(item2.frame, smallPos2, smallDim, item2.color)
		Renderer.addFrame(item3.frame, smallPos3, smallDim, item3.color)
		Renderer.addFrame(cancelIcon, smallPos4, smallDim, 0xFF0000AA)
	end
	function selectType(localPos, cell, radius)
		local worldPos = vec2(localPos.x, localPos.y)
		local pos = vec2(cell.x * tilesize + tilesize / 2 + cameraPos.x - radius,
						 cell.y * tilesize + tilesize / 2 + cameraPos.y - radius)
		log(string.format("wp: %d,%d, pos:%d,%d", worldPos.x, worldPos.y, pos.x, pos.y))

		local dim = vec2(radius * 2, radius * 2)
		local smallRadius = radius / 4
		local smallDim = vec2(smallRadius * 2, smallRadius * 2)

		local smallPos1 = vec2(pos.x + radius/3, pos.y + radius)
		local smallPos2 = vec2(pos.x + radius, pos.y + radius + radius * 0.66)
		local smallPos3 = vec2(pos.x + radius + radius * 0.66, pos.y + radius)
		local smallPos4 = vec2(pos.x + radius, pos.y + radius / 3)

		if distance(worldPos, smallPos1)<= smallRadius then
			return item1.id
		elseif distance(worldPos, smallPos2)<= smallRadius then
			return item2.id
		elseif distance(worldPos, smallPos3)<= smallRadius then
			return item3.id
		elseif distance(worldPos, smallPos4)<= smallRadius then
			return nil
		elseif distance(worldPos, vec2(pos.x + radius, pos.y + radius)) <= radius then
			return 0
		end
		return nil
	end
	function t.draw()
		Renderer.addText(font, "In selected state", vec2(0,100), 0xFFFF0000)
		Renderer.addFrame(pixel, vec2(t.x*tilesize + cameraPos.x, 
									  t.y*tilesize + cameraPos.y), 
										vec2(tilesize,tilesize), 0xFF0000FF)

		drawSelectionCircle(t, Screen.height / 4)
	end
	function t.onTap(pos)
		local type = selectType(pos, vec2(t.x,t.y), Screen.height/4)
		if type == 0 then
			return
		elseif type then
			state:enterState("Confirm", vec2(t.x,t.y) , type)
		else
			state:enterState("Idle", t.x, t.y)
		end
	end
	function t.enter(cell)
		t.x = cell.x
		t.y = cell.y
	end
	return t
end

local function Confirm()
	local t = { }
	function t.draw()
		local towerRadius = 3 * tilesize

		Renderer.addText(font, "In Confirm state", vec2(0,100), 0xFFFF00FF)
		Renderer.addFrame(pixel, vec2(t.x*tilesize + cameraPos.x, 
									  t.y*tilesize + cameraPos.y), 
										vec2(tilesize,tilesize), 0xFFFF0000)
		
		drawTowerRadius(t, towerRadius)
		drawConfirmationItems(t, towerRadius)
	end
	function t.onTap(pos)
		local towerRadius = 3 * tilesize
		local type = confirmSelect(pos, vec2(t.x,t.y), towerRadius)
		if type == 0 then
			return
		elseif type then
			sendAddTower(t.x, t.y, t.type)
			state:enterState("Idle", t.x, t.y)
		else
			state:enterState("Idle", t.x, t.y)
		end
	end
	function t.enter(cell, type)
		t.x = cell.x
		t.y = cell.y
		t.type = type
	end
	return t	
end

function Elements()
	local elements = {}
	function elements.enter(item1, item2, item3)
		sendMapRequestMessage()
		state = FSM()
		state:addState(Idle(), "Idle")
		state:addState(Selected(item1, item2, item3), "Selected")
		state:addState(Confirm(), "Confirm")
		state:enterState("Idle")
		--score = 0
	end
	function elements.exit()
		Loader.unloadFont(font)
	end
	function elements.render()
		--local scoreStr = string.format("Score: %d", score)
		--local size = Font.measure(font, scoreStr)
		--local pos = vec2(Screen.width / 2 - size.x / 2,
			--Screen.height / 2 - size.y / 2)

		Renderer.addText(font, string.format("CameraPos:%d,%d",
			cameraPos.x, cameraPos.y), vec2(0,100), 0xFFFFFF00)
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

		renderTime(font)
		state.active.draw()
	end
	function elements.update()
		updateTime()

		if useButtons then
			--Send le buttons
		else
			Out.writeShort(25)
			Out.writeByte(sensorNetworkID)
			Out.writeVec3(Sensors.acceleration)
			Out.writeVec3(Sensors.gyroscope)
		end

		Network.send()
	end
	function elements.handleMessage(id, length)
		if id == Network.messages.map then
			map = {}
			map.width = In.readInt()
			map.height = In.readInt()
			map.tiles = In.readByteArray() 
		elseif id == Network.messages.towerBuilt then
			local x = In.readInt()
			local y = In.readInt()
			local type = In.readByte()
			map.tiles[y*map.width + x] = type
		elseif id == Network.messages.selectRequest then
			local rx = In.readInt()
			local ry = In.readInt()
			local rcolor = In.readInt()

			selections[#selections + 1] = {x = rx, y = ry, color = rcolor} 
		elseif id == Network.messages.deselect then
			local rx = In.readInt()
			local ry = In.readInt()

			for i = 1, #selections, 1 do
				if selections[i].x == rx and selections[i].y == ry then
					table.remove(selections, i)
					return
				end
			end 
		end
	end
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

