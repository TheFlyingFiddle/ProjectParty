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
			sendTowerExited(t.cell)
			fsm:enterState("Elements")
		end
	end

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
		sendTowerEntered(t.cell)
	end

	function t.exit()
		gui:clear()
	end

	local function handleBallisticInfo()
		local pressure = In.readFloat()
		local maxPressure = In.readFloat()
		local direction = In.readFloat()
		local distance = In.readFloat()
		local maxDistance = In.readFloat()
		local pressureCost = In.readFloat() 

		dirSelector.dir = direction
		pressureDisplay.maxAmount = maxPressure
		pressureDisplay.amount = pressure
		amountSelector.amount = distance / maxDistance
		t.pressureCost = pressureCost
	end

	local function handlePressureInfo()
		local pressure = In.readFloat()
		pressureDisplay.amount = pressure
	end

	Network.setMessageHandler(Network.incoming.ballisticInfo, handleBallisticInfo)
	Network.setMessageHandler(Network.incoming.pressureInfo, handlePressureInfo)
	
	return t
end
