local transitionID = 52

function init()
    fsm = FSM()
    fsm:addState(Lobby(), "lobby")
    fsm:addState(GamePlay(), "gamePlay")
    fsm:enterState("lobby")
end

function term()
end

function handleMessage(id, length)
	if id == transitionID then
		string = In.readUTF8()
		fsm:enterState(string)
	end
	if fsm.active.handleMessage then fsm.active.handleMessage() end
end

function update()
	if fsm.active.update then fsm.active.update() end
end

function render()
	if fsm.active.render then fsm.active.render() end
end

function onTap(x, y)
	if fsm.active.onTap then fsm.active.onTap(x, y) end
end