local function handleTransition(state)
	fsm:enterState(state, true)
end

function init()
	font  	= Loader.loadFont("fonts/SegoeUILight72.fnt")
	
	pixel 	= Loader.loadFrame("textures/pixel.png")
	circle 	= Loader.loadFrame("textures/circle.png")
	plus 	= Loader.loadFrame("textures/plus.png")

	gui = Gui()

	Screen.setOrientation(Orientation.portrait)

	Network.setMessageHandler(Network.incoming.transition, handleTransition)

    fsm = FSM()
    fsm:addState(Guessing(), "GamePlay")
    fsm:addState(Lobby(), "Lobby")
    fsm:enterState("Lobby")
end

function term()
end

function update()
	if fsm.active.update then fsm.active.update() end
	gui:update()

	Network.update()
	Network.send()
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

function logf(fmt, ...)
	log(string.format(fmt, ...))
end