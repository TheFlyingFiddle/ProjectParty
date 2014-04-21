local resolution = 2
function Drawing()
	local t = {}

	t.toDraw = "ERROR"
	t.pixels = Grid(Screen.width, Screen.height) 

	--Previous position
	t.prevPos = vec2(0,0)

	local function addBetween(prevPos, newPos)
		local dist = Vector2.distance(prevPos, newPos)/resolution
		if dist == 0 then 
			t.pixels:set(newPos.x,newPos.y,1)
		else

			local between = prevPos
			local diff = newPos-prevPos
			for i=0, math.ceil(dist), resolution do
				between = prevPos + diff*i/dist
				t.pixels:set(between.x,between.y,1)
			end
		end
		t.prevPos = newPos
	end

	function t.render()
		--White background
		Renderer.addFrame(pixel, vec2(0,0), vec2(Screen.width, Screen.height), 0xFFFFFFFF)
		--Render drawing
		for y=1, t.pixels.height do
			for x=1, t.pixels.width do
				if t.pixels:at(x,y) == 1 then
					Renderer.addFrame(smooth, vec2(x,y), vec2(8,8), 0xFF000000)
				end
			end
		end

		local text = "Draw: "..t.toDraw
		local size = Font.measure(font, text)
		local pos = vec2(Screen.width/2 - size.x/2, 
						 Screen.height  - size.y*2)
		--render backdrop to make text pop against drawing
		Renderer.addFrame(smooth, pos, size, 0xAAFFFFFF)
		Renderer.addText(font, text, pos, 0xFF000000)
	end

	function t.onDragBegin(x,y)
		local pos = vec2(x/Screen.width, y/Screen.height)
		sendPixel(1, pos)
		pos = vec2(x,y)
		addBetween(pos, pos)
	end

	function t.onDrag(x,y)
		local pos = vec2(x/Screen.width, y/Screen.height)
		sendPixel(0, pos)
		pos = vec2(x,y)
		addBetween(t.prevPos, pos)
	end

	local function onBetweenRounds()
		fsm:enterState("Between")
	end

	local function clearCanvas()
		t.pixels:clear()
		sendClear()
	end

	function t.enter(toDraw)
		t.toDraw = toDraw
		gui:add(Button(0x883333AA, pixel, Rect2(
											Screen.width/12,
											Screen.height/12,
											Screen.width/6,
											Screen.height/6),
						clearCanvas, font, "Clear", 0xFFFFFFFF))

		Network.setMessageHandler(Network.incoming.betweenRounds, onBetweenRounds)
	end	

	function t.exit()
		Network.removeMessageHandler(Network.incoming.betweenRounds, onBetweenRounds)
		t.pixels:clear()
		gui:clear()
	end

	return t
end

