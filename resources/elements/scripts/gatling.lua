function Gatling()
	local t = {}

	local function sendAmount(amount)
		sendGatlingValue(t.cell, amount)
	end

	local function exit()
		sendTowerExited(t.cell)
		fsm:enterState("Elements")
	end

	local crank = 
		  Crank(Rect2(400,120, 300, 300),
		  				    sendAmount,
							0xFF00FF00,
							0xFF00FFFF)

  	local pressureDisplay = 
		PressureDisplay(Rect2(100, 130,100, 250), 
					0xFFFF8800,
					0xFF770000,
					1)
	
	local function handleGatlingInfo(gInfo)
		pressureDisplay.maxAmount = gInfo.maxPressure
		pressureDisplay.amount = gInfo.pressure
	end

	local function handlePressureInfo(pressure)
		pressureDisplay.amount = pressure
	end

	Network.setMessageHandler(Network.incoming.gatlingInfo, handleGatlingInfo)

	function t.enter(cell) 
	
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit", 0xFF000000))
		gui:add(crank)
		gui:add(pressureDisplay)

		Network.setMessageHandler(Network.incoming.pressureInfo, handlePressureInfo)

		t.cell = cell
		sendTowerEntered(t.cell)
	end

	function t.exit()
		gui:clear()
	end
	
	return t
end
