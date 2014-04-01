local function exit()
	fsm:enterState("Elements")
end

function Vent()
	local t = {}

	local function toggle()
		if t.ventValue == 1 then t.ventValue = 0 else t.ventValue = 1 end
		sendVentValue(t.x, t.y, t.ventValue)
	end

	function t.enter(x, y) 
		sendTowerEntered(x, y)
		t.x = x
		t.y = y
		t.exitButton = Button(0xFF0000FF, pixel, "Exit", Rect(vec2(10,10), 
						vec2(400, 100)), exit, 0xFF000000)
		t.toggleButton = Button(0xFF00FF00, pixel, "On/Off", Rect(vec2(Screen.width - 410, 10), 
						vec2(400, 100)), toggle, 0xFF000000)
		t.ventValue = 1
	end

	function t.exit()

	end

	function t.update()
		Network.send()
	end

	function t.render()
		t.exitButton:draw(font)
		t.toggleButton:draw(font)

	end

	function t.onTap(x, y)
		t.exitButton:onTap(x, y)
		t.toggleButton:onTap(x, y)
	end

	return t
end
