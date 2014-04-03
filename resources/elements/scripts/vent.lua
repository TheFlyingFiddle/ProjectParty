local function exit()
	fsm:enterState("Elements")
end


function Vent()
	local t = {}

	local function sendDirection(dir)
		sendVentDirection(t.cell, dir)
	end

	local selector = 
		  DirectionSelector(Rect2(200,200,200,200),
		  				    sendDirection,
							0xFF00FF00,
							0xFF00FFFF)

	local function south()
		selector.dir = math.pi * 3 / 2
		sendVentDirection(t.cell, math.pi * 3 / 2)
	end

	local function west()
		selector.dir = math.pi
		sendVentDirection(t.cell, math.pi)
	end

	local function east()
		selector.dir = 0
		sendVentDirection(t.cell, 0)
	end

	local function north()
		selector.dir = math.pi / 2
		sendVentDirection(t.cell, math.pi / 2)
	end

	local function toggle()
		if t.ventValue == 1 then t.ventValue = 0 else t.ventValue = 1 end

		log("Going to send vent value!")
		sendVentValue(t.cell, t.ventValue)
	end

	function t.enter(cell) 
	
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit",0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(Screen.width - 410, 10, 400, 100), 
				   toggle, font,"On/Off", 0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(0, 150, 120, 60), south,
				   font, "South", 0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(0, 220, 120, 60), west,
				   font, "West", 0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(0, 290, 120, 60), east,
				   font, "East", 0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(0, 360, 120, 60), north,
				   font, "North", 0xFF000000))
		gui:add(selector)


		sendTowerEntered(cell)
		t.cell = cell
		t.ventValue = 1
	end

	function t.exit()
		gui:clear()
	end
	
	return t
end
