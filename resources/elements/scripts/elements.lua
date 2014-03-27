local sensorNetworkID = 1

local font
local map
local pixel
local tilesize = 40
local cameraPos = vec2(0,0)

function Elements()
	local elements = {}
	function elements.enter()
		font  = Loader.loadFont("fonts/Segoe54.fnt")
		pixel = Loader.loadFrame("textures/pixel.png")
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
				if map.tiles[row*map.width + col] == 0 then
					color = 0xFF00FF00
				else
					color = 0xFFFFFFFF
				end

				Renderer.addFrame(pixel, pos, dim, color)
				pos.x = pos.x + dim.x
			end
			pos.x = cameraPos.x
			pos.y = pos.y + dim.y
		end
		renderTime(font)
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
		end
	end
	function elements.onTap(x,y)
		local cellx = x / tilesize
		local celly = y / tilesize

		Out.writeShort(10)
		Out.writeByte(Network.messages.towerRequest)
		Out.writeInt(cellx)
		Out.writeInt(celly)
		Out.writeByte(0)
	end

	local oldDrag
	function elements.onDrag(x, y)
		local deltaX = x - oldDrag.x
		local deltaY = y - oldDrag.y
		cameraPos.x = cameraPos.x + deltaX
		cameraPos.y = cameraPos.y + deltaY
		oldDrag = vec2(x,y)

	end

	function elements.onDragBegin(x, y)
		oldDrag = vec2(x,y)
	end

	return elements
end
