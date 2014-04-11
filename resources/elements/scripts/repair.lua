function Repair()
	local rep = { }
	rep.lifted = false

	local function repair()
		sendRepaired(rep.cell)
		sendTowerExited(rep.cell)
		fsm:enterState("Elements")
	end	

	local function exit()
		sendTowerExited(rep.cell)
		fsm:enterState("Elements")
	end

	local function onDragBeginCB
		rep.lifted = true
	end

	local function onDragEndCB

	end


	local cog = DragAndDroppable(Rect2(Screen.width*0.67, 0,
								Screen.height * 0.2, 
								Screen.height * 0.2 ), 
								cog1,)

	function rep.exit()
		gui:clear()
	end

	function rep.enter(cell) 
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit" ,0xFF000000))		
		sendTowerEntered(cell)
		rep.cell = cell
	end

	return rep
end