function Repair()
	local rep = { }
	rep.lifted = false
	rep.speed = 0

	local gravity = 0.1


	local function repair()
		sendRepaired(rep.cell)
		sendTowerExited(rep.cell)
		fsm:enterState("Elements")
	end	

	local function exit()
		sendTowerExited(rep.cell)
		fsm:enterState("Elements")
	end

	local function checkIfCorrectPosition()
	end

	local function onDragBeginCB()
		rep.lifted = true
	end

	local function onDragCB() 
	end

	local function onDragEndCB()
		rep.lifted = false
		checkIfCorrectPosition()
	end

	local bolt = ImageBox(0xFFFFFFFF, corrodedBolt,
			Rect2(	Screen.width * 0.62, 
					Screen.height * 0.64,
					Screen.height * 0.05,
					Screen.height * 0.05))

	local cog = DragAndDroppable(Rect2(Screen.width*0.67, 0,
								Screen.height * 0.2, 
								Screen.height * 0.2 ),
								corrodedCog,
								onDragBeginCB,
								onDragCB,
								onDragEndCB)

	function rep.exit()
		gui:clear()
	end

	function rep.update()
		if not rep.lifted then
			cog.rect.pos.y = math.min(0, cog.rect.pos.y - rep.speed * gravity)
			speed = speed + gravity
			if cog.rect.pos.y < 0 then
				cog.rect.pos.y = 0
			end
		else 
			rep.speed = 0
		end
	end

	function rep.enter(cell) 
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit" ,0xFF000000))		
		gui:add(bolt)
		gui:add(cog)
		sendTowerEntered(cell)
		rep.cell = cell
	end

	return rep
end