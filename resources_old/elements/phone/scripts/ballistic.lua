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

	local function launch(button)
		if t.pressureDisplay.amount >= button.cost then
			sendBallisticLaunch(t.cell, button.id)
		end
	end

	local function handleBallisticInfo(bInfo)
		t.pressureDisplay.maxAmount = bInfo.maxPressure
		t.pressureDisplay.amount = bInfo.pressure
		t.smallBoomButton.cost = bInfo.smallBoomCost
		t.bigBoomButton.cost = bInfo.bigBoomCost
	end

	Network.setMessageHandler(Network.incoming.ballisticInfo, handleBallisticInfo)

	local baseEnter = t.enter

	function t.enter(cell)
		baseEnter(cell)
		t.smallBoomButton = Button(0xFF00FF00, pixel, 
				   Rect2(t.pressureDisplay.rect:right() + margin,
				   	     t.pressureDisplay.rect:bottom(), 
				   	     buttonWidth,
				   	     buttonHeight), 
				   launch, font,"boom", 0xFF000000)
		t.smallBoomButton.id = 0
		t.smallBoomButton.cost = 1000

		t.bigBoomButton = Button(0xFF00FF00, pixel, 
				   Rect2(t.pressureDisplay.rect:right() + margin,
				   	     t.pressureDisplay.rect:bottom() + buttonHeight + margin, 
				   	     buttonWidth,
				   	     buttonHeight), 
				   launch, font,"BOOM!", 0xFF000000)
		t.bigBoomButton.id = 1
		t.bigBoomButton.cost = 1000

		gui:add(t.smallBoomButton)
		gui:add(t.bigBoomButton)
		
		gui:add(aimCircle)
	end

	function t.update()
		if t.pressureDisplay.amount >= t.smallBoomButton.cost then
			t.smallBoomButton.tint = 0xFF00FF00
		else
			t.smallBoomButton.tint = 0xFF888888
		end
		if t.pressureDisplay.amount >= t.bigBoomButton.cost then
			t.bigBoomButton.tint = 0xFF00FF00
		else
			t.bigBoomButton.tint = 0xFF888888
		end

	end

	return t
end
