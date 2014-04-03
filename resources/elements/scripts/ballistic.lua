local function exit()
	fsm:enterState("Elements")
end


function Ballistic()
	local t = {}

	local function sendDirection(dir)
		sendBallisticDirection(t.x, t.y, dir)
	end

	local selector = 
		  DirectionSelector(Rect2(200,200,200,200),
		  				    sendDirection,
							0xFF00FF00,
							0xFF00FFFF)

	local function south()
		selector.dir = math.pi * 3 / 2
		sendBallisticDirection(t.x, t.y, math.pi * 3 / 2)
	end

	local function west()
		selector.dir = math.pi
		sendBallisticDirection(t.x, t.y, math.pi)
	end

	local function east()
		selector.dir = 0
		(t.x, t.y, 0)
	end

	local function north()
		selector.dir = math.pi / 2
		sendBallisticDirection(t.x, t.y, math.pi / 2)
	end

	local function launch()

		log("Going to launch rocket!")
		sendBallisticDirection(t.x, t.y,)
	end

	function t.enter(x, y) 
	
		gui:add(Button(0xFF0000FF, pixel, 
				   Rect2(10,10, 400, 100), 
				   exit,   font, "Exit",0xFF000000))
		gui:add(Button(0xFF00FF00, pixel, 
				   Rect2(Screen.width - 410, 10, 400, 100), 
				   launch, font,"BOOM!", 0xFF000000))
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


		sendTowerEntered(x, y)
		t.x = x
		t.y = y
		t.ventValue = 1
	end

	function t.exit()
		gui:clear()
	end
	
	return t
end
