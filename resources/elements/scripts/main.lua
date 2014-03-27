Network.messages.map= 50
Network.messages.towerRequest = 51

function init()
    fsm = FSM()
    fsm:addState(Elements(), "Elements")
    fsm:enterState("Elements")
end

function term()
end

function handleMessage(id, length)
		log(string.format("Got a netowrk message id=%d len=%d", id, length))
		Network.send()
	if id == Network.messages.transition then
		s = In.readUTF8()
		fsm:enterState(s)
	end
	if fsm.active.handleMessage then 
		log("Sending message to active state")
		Network.send()
		fsm.active.handleMessage(id, length) 
	end
end

function update()
	if fsm.active.update then fsm.active.update() end
end

function render()
	if fsm.active.render then fsm.active.render() end
end

function onTap(x, y)
	if fsm.active.onTap then
    	fsm.active.onTap(x, y)
    end
end

function onTouch(x, y, pointerIndex)
	if fsm.active.onTouch then
		fsm.active.onTouch(x, y, pointerIndex)
	end
end

function onDrag(x, y)
	if fsm.active.onDrag then
		fsm.active.onDrag(x,y)
	end
end

function onDragBegin(x, y)
	if fsm.active.onDragBegin then
		fsm.active.onDragBegin(x,y)
	end
end

function onDragEnd(x, y)
	if fsm.active.onDragEnd then
		fsm.active.onDragEnd(x,y)
	end
end

function onPinchBegin(x0, y0, x1, y1)
	log("Pinch begin")
	Network.send()
	if fsm.active.onPinchBegin then
		fsm.active.onPinchBegin(x0,y0, x1, x1)
	end
end

function onPinch(x0, y0, x1, y1)
	log("Pinch punch")
	Network.send()
	if fsm.active.onPinch then
		fsm.active.onPinch(x0, y0, x1, y1)
	end
end