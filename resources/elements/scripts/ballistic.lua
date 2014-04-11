function Ballistic()
	local t = {}

	local margin = Screen.width / 40
	local buttonWidth = Screen.width / 6
	local buttonHeight = Screen.width / 10 

	local function sendDirection(dir)
		sendBallisticDirection(t.cell, dir)
	end

	local function sendAmount(amount)
		sendBallisticValue(t.cell, amount)
	end

	local function sendDirectionAndAmount(dir, amount)
		sendDirection(dir)
		sendAmount(amount)
	end

	local function exit()
		sendTowerExited(t.cell)
		fsm:enterState("Elements")
	end

	local circleSize = Screen.height - (2 * margin)

	local aimCircle =
		AimCircle(Rect2(Screen.width - (circleSize + margin), 
						margin, 
						circleSize, 
						circleSize),
			sendDirectionAndAmount)

	local pressureDisplay = 
				PressureDisplay(Rect2(
								buttonWidth + (2 * margin), 
								margin, 
								buttonWidth, 
								Screen.height - (2 * margin)), 
							0xFFFF8800,
							0xFF770000,
							1)

	local function launch()
		if pressureDisplay.amount >= t.pressureCost then
			sendBallisticLaunch(t.cell)
		end
	end

	local function handleBallisticInfo(bInfo)
		pressureDisplay.maxAmount = bInfo.maxPressure
		pressureDisplay.amount = bInfo.pressure
		t.pressureCost = bInfo.pressureCost
	end

	local function handlePressureInfo(pressure)
		pressureDisplay.amount = pressure
	end

	local function handleTowerBroken(cell)
		if cell.x == t.cell.x and cell.y == t.cell.y then
			exit()			
		end
	end

	Network.setMessageHandler(Network.incoming.ballisticInfo, handleBallisticInfo)

	function t.enter(cell) 
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(margin, 
				   	     Screen.height / 2 - (margin + buttonHeight), 
				   	     buttonWidth, 
				   	     buttonHeight), 
				   exit,   font, "Exit", 0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(margin,
				   	     Screen.height / 2 + margin, 
				   	     buttonWidth,
				   	     buttonHeight), 
				   launch, font,"BOOM!", 0xFF000000))
		
		gui:add(aimCircle)
		gui:add(pressureDisplay)

		t.cell = cell
		t.pressureCost = 0.1
		pressureDisplay.amount = 1
--
		Network.setMessageHandler(Network.incoming.towerBroken, handleTowerBroken)
		Network.setMessageHandler(Network.incoming.pressureInfo, handlePressureInfo)

		sendTowerEntered(t.cell)
	end

	function t.exit()
		gui:clear()

		Network.removeMessageHandler(Network.incoming.towerBroken, handleTowerBroken)
		Network.removeMessageHandler(Network.incoming.pressureInfo, handlePressureInfo)
	end


	return t
end
