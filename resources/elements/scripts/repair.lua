function Repair()
	local rep = { }

	local function repair()
		sendRepaired(rep.cell)
		sendTowerExited(rep.cell)
		fsm:enterState("Elements")
	end	

	local function exit()
		sendTowerExited(rep.cell)
		fsm:enterState("Elements")
	end

	function rep.exit()
		gui:clear()
	end

	function rep.enter(cell) 
	
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit" ,0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(Screen.width - 410, 10, 400, 100), 
				   repair, font,"Do repair", 0xFF000000))
		
		sendTowerEntered(cell)
		rep.cell = cell
	end

	return rep
end