function Ballistic()
	local t = {}

	local function sendDirection(dir)
		sendBallisticDirection(t.cell, dir)
	end

	local function sendAmount(amount)
		sendBallisticValue(t.cell, amount)
	end

	local function exit()
		sendTowerExited(t.cell)
		fsm:enterState("Elements")
	end


	local dirSelector = 
		  DirectionSelector(Rect2(400,200,400,400),
		  				    sendDirection,
							0xFF00FF00,
							0xFF00FFFF)

	local amountSelector =
			AmountSelector(	Rect2(100,200,100,400),
							sendAmount,
							0xFF00FF00,
							0xFF0000FF)

	local pressureDisplay = 
				PressureDisplay(Rect2(200,200,100,400), 
							0xFFFF8800,
							0xFF770000,
							1)

	local function launch()
		if pressureDisplay.amount >= t.pressureCost then
			sendBallisticLaunch(t.cell)
		end
	end

	local function handleBallisticInfo(bInfo)
		dirSelector.dir = bInfo.direction
		pressureDisplay.maxAmount = bInfo.maxPressure
		pressureDisplay.amount = bInfo.pressure
		amountSelector.amount = bInfo.distance / bInfo.maxDistance
		t.pressureCost = bInfo.pressureCost
	end

	local function handlePressureInfo(pressure)
		pressureDisplay.amount = pressure
	end

	Network.setMessageHandler(Network.incoming.ballisticInfo, handleBallisticInfo)

	function t.enter(cell) 
	
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit", 0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(Screen.width - 410, 10, 400, 100), 
				   launch, font,"BOOM!", 0xFF000000))
		gui:add(dirSelector)
		gui:add(amountSelector)
		gui:add(pressureDisplay)


		t.cell = cell
		t.amount = 0
		dirSelector.dir = 0
		t.pressureCost = 10000
		pressureDisplay.amount = 1

		Network.setMessageHandler(Network.incoming.pressureInfo, handlePressureInfo)

		sendTowerEntered(t.cell)
	end

	function t.exit()
		gui:clear()
	end


	return t
end
