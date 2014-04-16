function Drawing()
	local t = {}

	t.toDraw = "ERROR"
	t.pixels = Grid(Screen.width, Screen.height) 

	local function addPixel(x,y)
		t.pixels:set(x,y,1)
	end

	function t.render()
		local size = Font.measure(font, t.toDraw)
		Renderer.addText(font, t.toDraw, 
						 vec2(Screen.width/2 - size.x/2, 
							  Screen.height  - size.y), 
						 0xFF000000)
		for y=1, t.pixels.height, 1 do
			for x=1, t.pixels.width, 1 do
				if t.pixels:at(x,y) == 1 then
					Renderer.addFrame(pixel, vec2(x,y), vec2(4,4), 0xFF000000)
				end
			end
		end
	end

	function t.onDragBegin(x,y)
		local pos = vec2(x/Screen.width, y/Screen.height)
		sendPixel(1, pos)
		addPixel(x,y)
		logf("BEGI: [x: %d, y: %d]", x, y)
	end

	function t.onDrag(x,y)
		local pos = vec2(x/Screen.width, y/Screen.height)
		sendPixel(0, pos)
		addPixel(x,y)
		logf("DRAG: [x: %d, y: %d]", x, y)
	end

	local function onBetweenRounds()
		fsm:enterState("Between")
	end

	function t.enter(toDraw)
		t.toDraw = toDraw

		Network.setMessageHandler(Network.incoming.betweenRounds, onBetweenRounds)
	end	

	function t.exit()
		Network.removeMessageHandler(Network.incoming.betweenRounds, onBetweenRounds)
		t.pixels:clear()
	end

	return t
end

