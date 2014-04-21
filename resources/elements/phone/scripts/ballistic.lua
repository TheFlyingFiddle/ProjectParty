function Ballistic()
	local t = PressureTowerScreen()

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

	local circleSize = Screen.height - (2 * margin)

	local aimCircle =
		AimCircle(Rect2(Screen.width - (circleSize + margin), 
						margin, 
						circleSize, 
						circleSize),
			sendDirectionAndAmount)

	local function launch()
		if t.pressureDisplay.amount >= t.pressureCost then
			sendBallisticLaunch(t.cell)
		end
	end

	local function handleBallisticInfo(bInfo)
		t.pressureDisplay.maxAmount = bInfo.maxPressure
		t.pressureDisplay.amount = bInfo.pressure
		t.pressureCost = bInfo.pressureCost
	end

	Network.setMessageHandler(Network.incoming.ballisticInfo, handleBallisticInfo)

	local baseEnter = t.enter

	function t.enter(cell)
		baseEnter(cell)

		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(margin,
				   	     Screen.height / 2 + margin, 
				   	     buttonWidth,
				   	     buttonHeight), 
				   launch, font,"BOOM!", 0xFF000000))
		
		gui:add(aimCircle)
		t.pressureCost = 0.1
		t.pressureDisplay.amount = 1
	end

	return t
end
