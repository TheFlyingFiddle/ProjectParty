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
		  Crank(Rect2(400,200,400,400),
		  				    sendAmount,
							0xFF00FF00,
							0xFF00FFFF)

	function t.enter(cell) 
	
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit", 0xFF000000))
		gui:add(crank)

		t.cell = cell
		sendTowerEntered(t.cell)
	end

	function t.exit()
		gui:clear()
	end
	
	return t
end
