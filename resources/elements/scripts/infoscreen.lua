local function exit()
	fsm:enterState("Elements")
end


function Info()
	local t = {}

	function t.enter(tower) 
		t.tower = tower

		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit",0xFF000000))
	end

	function t.exit()
		gui:clear()
	end

	function t.render()
		local headingSize = Font.measure(font, t.tower.name)
		Renderer.addText(font, t.tower.name, vec2(Screen.width / 2 - headingSize.x / 2, 
			                                      Screen.height - headingSize.y), 0xFFFFFFFF)

		local textSize = Font.measure(font, t.tower.info)
		Renderer.addText(font, t.tower.info, vec2(10, 
			                                      Screen.height - headingSize.y - textSize.y - 20), 0xFFFFFFFF)
	end
	
	return t
end
