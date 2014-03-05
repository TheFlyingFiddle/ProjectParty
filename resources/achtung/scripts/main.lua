local transitionID = 6

function init()
    fsm = FSM()
    log(tostring(fsm))
    cfuns.C.networkSend(Network)
    fsm:addState(Lobby(), "MainMenu")
    log(tostring(fsm))
    cfuns.C.networkSend(Network)
    fsm:addState(GamePlay(), "Achtung")
    log(tostring(fsm))
    cfuns.C.networkSend(Network)
    fsm:enterState("MainMenu")

    log(cfuns.string(cfuns.C.testStr()))
    cfuns.C.networkSend(Network)
end

function term()
end

function handleMessage(id, length)
	if id == transitionID then
        log("Transitioning")
        cfuns.C.networkSend(Network)
		s = "Achtung"--In.readUTF8()
        log("Transitioning to "..s)
        cfuns.C.networkSend(Network)

		fsm:enterState(s)
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
	if fsm.active.onTap then 
    	fsm.active.onTap(x, y)
    end
end