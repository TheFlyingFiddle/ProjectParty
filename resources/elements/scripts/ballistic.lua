function Ballistic()
	local t = {}

	local function sendDirection(dir)
		sendBallisticDirection(t.x, t.y, dir)
	end

	local function sendAmount(amount)
		sendBallisticValue(t.x, t.y, amount)
	end

	local function exit()
		sendTowerExited(t.x, t.y)
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

	local function launch()
		sendBallisticLaunch(t.x, t.y)
		sendTowerExited(t.x, t.y)
		fsm:enterState("Elements")
	end

	function t.enter(x, y) 
	
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit", 0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(Screen.width - 410, 10, 400, 100), 
				   launch, font,"BOOM!", 0xFF000000))
		gui:add(dirSelector)
		gui:add(amountSelector)

		sendTowerEntered(x, y)
		t.x = x
		t.y = y
		t.amount = 1
	end

	function t.exit()
		gui:clear()
	end
	
	return t
end
