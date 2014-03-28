
function ElementSelection()
	local t = {}
	local selected1
	local selected2
	local selected3
	local elements = { { item = assets.fire }, { item = assets.water }, { item = assets.ice },
					   { item = assets.lightning }, { item = assets.wind }, { item = assets.nature }}
	local spacing = 10
	local size = (Screen.width - (spacing*6 + 40)) / 6
	local x = 20
	local y = 10
	for i=1, #elements, 1 do
		elements[i].area = Rect(vec2(x,y), vec2(size, size))
		x = x + size + spacing
	end
	function t.update()
	end
	function t.render()
		local dim = vec2(size,size)
		local size = size + 20
		local ringDim = vec2(size, size)
		local spacing = 40
		local position = vec2(Screen.width/2 - size - spacing - size/2, Screen.height/2 - 10)

		Renderer.addFrame(ring, position, ringDim, 0xFFFFFFFF)
		position.x = position.x + spacing + size
		Renderer.addFrame(ring, position, ringDim, 0xFFFFFFFF)
		position.x = position.x + spacing + size
		Renderer.addFrame(ring, position, ringDim, 0xFFFFFFFF)

		for i=1, #elements, 1 do
			Renderer.addFrame(elements[i].item.frame, elements[i].area.pos, dim, elements[i].item.color)
		end


		local str = "Select your elements!"
		local size = Font.measure(font, str)
		Renderer.addText(font, str, vec2(Screen.width/2 - size.x/2, Screen.height - size.y - spacing), 0xFFFFFFFF)

		if selected1 and selected2 and selected3 then
			local pos = vec2(Screen.width/2 - 100, Screen.height/2 - ringDim.y/2 - 40)
			Renderer.addFrame(pixel, pos, vec2(200, 72), 0xFF00AA00)

			local str = "Play!"
			local size = Font.measure(font, str)
			pos.y = pos.y + 15
			pos.x = pos.x + 100 - size.x/2
			Renderer.addText(font, str, pos, 0xFFFFFFFF)
		end
	end
	function t.onTap(x, y)
		log("ONTAP")
		Network.send()
		local position = vec2(x,y)
		for i=1, #elements, 1 do
			if pointInRect(elements[i].area, position) then
			Network.send()
				if not selected1 then
					selected1 = elements[i].item
					elements[i].area.pos = vec2(Screen.width/2 - size - 60 - size/2, Screen.height/2)
				elseif not selected2 then
					selected2 = elements[i].item
					elements[i].area.pos = vec2(Screen.width/2 - size/2, Screen.height/2)
				elseif not selected3 then
					selected3 = elements[i].item
					elements[i].area.pos = vec2(Screen.width/2 + size/2 + 60, Screen.height/2)
				end
			end
		end
		if selected1 and selected2 and selected3 then
			local pos = vec2(Screen.width/2 - 100, Screen.height/2 - (size+20)/2 - 40)
			if pointInRect(Rect(pos, vec2(200, 100)), position) then
				fsm:enterState("Elements", selected1, selected2, selected3)
			end
		end

	end
	return t
end