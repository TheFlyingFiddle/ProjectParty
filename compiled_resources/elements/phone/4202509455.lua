function Gatling()
	local t = PressureTowerScreen()

	local function sendAmount(amount)
		sendGatlingValue(t.cell, amount)
	end

	local crank = 
		  Crank(Rect2(400,120, 300, 300),
		  				    sendAmount,
							0xFF00FF00,
							0xFF00FFFF)
	
	local function handleGatlingInfo(gInfo)
		t.pressureDisplay.maxAmount = gInfo.maxPressure
		t.pressureDisplay.amount = gInfo.pressure
	end

	Network.setMessageHandler(Network.incoming.gatlingInfo, handleGatlingInfo)

	local baseEnter = t.enter

	function t.enter(cell) 
		baseEnter(cell)
		gui:add(crank)
	end

	return t
end
