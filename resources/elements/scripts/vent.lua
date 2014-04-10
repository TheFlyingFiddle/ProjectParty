function Vent()
	local t = {}

	local function sendDirection(dir)
		sendVentDirection(t.cell, dir)
	end

	local selector = 
		  DirectionSelector(Rect2(200,200,200,200),
		  				    sendDirection,
							0xFF00FF00,
							0xFF00FFFF)
	
	local pressureDisplay = 
		PressureDisplay(Rect2(100, 130,100, 250), 
					0xFFFF8800,
					0xFF770000,
					1)

	local function exit()
		sendTowerExited(t.cell)
		fsm:enterState("Elements")
	end

	local function south()
		selector.dir = math.pi * 3 / 2
		sendVentDirection(t.cell, math.pi * 3 / 2)
	end

	local function west()
		selector.dir = math.pi
		sendVentDirection(t.cell, math.pi)
	end

	local function east()
		selector.dir = 0
		sendVentDirection(t.cell, 0)
	end

	local function north()
		selector.dir = math.pi / 2
		sendVentDirection(t.cell, math.pi / 2)
	end

	local function toggle()
		if t.ventValue == 1 then t.ventValue = 0 else t.ventValue = 1 end
		sendVentValue(t.cell, t.ventValue)
	end


	local function handleVentInfo(ventInfo)
		pressureDisplay.amount = ventInfo.pressure
		pressureDisplay.maxAmount  = ventInfo.maxPressure
		selector.dir = ventInfo.direction
	end

	
	local function handlePressureInfo(pressure)
		pressureDisplay.amount = pressure	
	end

	Network.setMessageHandler(Network.incoming.ventInfo, handleVentInfo)

	function t.enter(cell) 
	
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit",0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(Screen.width - 410, 10, 400, 100), 
				   toggle, font,"On/Off", 0xFF000000))
		gui:add(pressureDisplay)
		gui:add(selector)


		Network.setMessageHandler(Network.incoming.pressureInfo, handlePressureInfo)

		sendTowerEntered(cell)
		t.cell = cell
		t.ventValue = 1
	end


	function t.exit()
		gui:clear()
	end
	
	return t
end
