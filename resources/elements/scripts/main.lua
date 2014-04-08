assets = {}

function init()
	font  			= Loader.loadFont("fonts/Segoe54.fnt")
	pixel 			= Loader.loadFrame("textures/pixel.png")
	circle 			= Loader.loadFrame("textures/circle.png")
	ring 			= Loader.loadFrame("textures/ring.png")
	fireIcon 		= Loader.loadFrame("textures/fire_icon.png")
	waterIcon 		= Loader.loadFrame("textures/water_icon.png")
	iceIcon 		= Loader.loadFrame("textures/ice_icon.png")
	lightningIcon 	= Loader.loadFrame("textures/lightning_icon.png")
	windIcon 		= Loader.loadFrame("textures/wind_icon.png")
	natureIcon 		= Loader.loadFrame("textures/nature_icon.png")
	cancelIcon 		= Loader.loadFrame("textures/cancel_icon.png")
	buyIcon 		= Loader.loadFrame("textures/buy_icon.png")
	infoIcon        = Loader.loadFrame("textures/ice_icon.png")

	assets.fire  		= { id = 2, frame = fireIcon, 		color = 0xFF0066FF }
	assets.water 		= { id = 3, frame = waterIcon, 		color = 0xFFFFaa22 }
	assets.ice   		= { id = 4, frame = iceIcon,		color = 0xFFFFFFCC }
	assets.lightning 	= { id = 5, frame = lightningIcon, 	color = 0xFF00FFFF }
	assets.wind 		= { id = 6, frame = windIcon, 		color = 0xFFaaFFaa }
	assets.nature 		= { id = 7, frame = natureIcon,		color = 0xFF00FF00 }

	gui = Gui()

    fsm = FSM()
    fsm:addState(Elements(), "Elements")
    fsm.Elements.init()
    fsm:addState(Vent(), "Vent")
    fsm:addState(Ballistic(), "Ballistic")
    fsm:addState(Repair(), "Repair")
	fsm:addState(Gatling(), "Gatling")
	fsm:addState(Info(), "Info")
    fsm:enterState("Elements")
end

function term()
end

function update()
	if fsm.active.update then fsm.active.update() end

	Network.sendElapsed = Network.sendElapsed + Time.elapsed
	if true then
		Out.writeShort(25)
		Out.writeByte(Network.outgoing.sensor)
		Out.writeVec3(Sensors.acceleration)
		Out.writeVec3(Sensors.gyroscope)

		Network.send()

		Network.sendElapsed = 0
	end

end

function render()
	if fsm.active.render then fsm.active.render() end
	gui:draw()
end

function onTap(x, y)
	if not gui:onTap(vec2(x, y)) and fsm.active.onTap then
    	fsm.active.onTap(x, y)
    end
end

function onTouch(x, y, pointerIndex)
	if fsm.active.onTouch then
		fsm.active.onTouch(x, y, pointerIndex)
	end
end

function onDrag(x, y)
	if not gui:onDrag(vec2(x, y)) and fsm.active.onDrag then
		fsm.active.onDrag(x,y)
	end
end

function onDragBegin(x, y)
	if not gui:onDragBegin(vec2(x, y)) and fsm.active.onDragBegin then
		fsm.active.onDragBegin(x,y)
	end
end

function onDragEnd(x, y)
	if not gui:onDragEnd(vec2(x, y)) and fsm.active.onDragEnd then
		fsm.active.onDragEnd(x,y)
	end
end

function onPinchBegin(x0, y0, x1, y1)
	gui:onPinchBegin(vec2(x0, y0), vec2(x1, y1))
	if fsm.active.onPinchBegin then
		fsm.active.onPinchBegin(x0,y0, x1, x1)
	end
end

function onPinch(x0, y0, x1, y1)
	gui:onPinch(vec2(x0, y0), vec2(x1, y1))
	if fsm.active.onPinch then
		fsm.active.onPinch(x0, y0, x1, y1)
	end
end