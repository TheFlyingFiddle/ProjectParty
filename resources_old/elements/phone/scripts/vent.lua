function Vent()
	local t = PressureTowerScreen()

	local function sendDirection(dir)
		sendVentDirection(t.cell, dir)
	end

	local selector = 
		  DirectionSelector(Rect2(200,200,200,200),
		  				    sendDirection,
							0xFF00FF00,
							0xFF00FFFF)
	
	local function toggle()
		if t.ventValue == 1 then t.ventValue = 0 else t.ventValue = 1 end
		sendVentValue(t.cell, t.ventValue)
	end

	local function handleVentInfo(ventInfo)
		t.pressureDisplay.amount = ventInfo.pressure
		t.pressureDisplay.maxAmount  = ventInfo.maxPressure
		selector.dir = ventInfo.direction
	end
	
	Network.setMessageHandler(Network.incoming.ventInfo, handleVentInfo)

	local baseEnter = t.enter

	function t.enter(cell) 
		baseEnter(cell)
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(Screen.width - 410, 10, 400, 100), 
				   toggle, font,"On/Off", 0xFF000000))
		gui:add(selector)
		t.ventValue = 1
	end

	return t
end
