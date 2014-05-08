Network.messages.death = 50
Network.messages.toggleReady = 51
Network.messages.color = 52
Network.messages.position = 53
Network.messages.win = 54

function init()
    fsm = FSM()
	Game.setFps(120)
    Screen.setOrientation(Orientation.landscape)
    fsm:addState(Lobby(), "MainMenu")
    fsm:addState(GamePlay(), "Achtung")
    fsm:addState(GameOver(), "GameOver")
    fsm:enterState("MainMenu")
end

function term()
end

function handleMessage(id, length)
	if id == Network.messages.transition then
		s = In.readUTF8()
		fsm:enterState(s)
	end
	if fsm.active.handleMessage then fsm.active.handleMessage(id, length) end
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
