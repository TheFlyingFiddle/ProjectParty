function Repair()
	local rep = { }
	rep.speed = 0

	local gravity = 2 


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
		log("Checking")
		if pointInRect(	rep.bolt.rect,
						rep.cog.rect.pos +
						rep.cog.rect.dim/2) then
			log("YAY")
			repair()
		end
	end

	local function onDragBeginCB()
	end

	local function onDragCB() 
	end

	local function onDragEndCB()
		log("deCB")
		checkIfCorrectPosition()
	end

	rep.bolt = ImageBox(0xFFFFFFFF, corrodedBolt,
			Rect2(	Screen.width * 0.62, 
					Screen.height * 0.64,
					Screen.height * 0.05,
					Screen.height * 0.05))

	rep.cog = DragAndDroppable(Rect2(Screen.width*0.67, 0,
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
		if not rep.cog.beingDragged then
			rep.cog.rect.pos.y = math.max(0, rep.cog.rect.pos.y - rep.speed)
			rep.speed = rep.speed + gravity
			if rep.cog.rect.pos.y < 0 then
				rep.cog.rect.pos.y = 0
			end
		else 
			rep.speed = 0
		end
	end

	function rep.enter(cell) 
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit" ,0xFF000000))		
		gui:add(rep.bolt)
		gui:add(rep.cog)
		sendTowerEntered(cell)
		rep.cell = cell
	end

	return rep
end