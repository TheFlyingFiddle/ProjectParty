
local fsmMetaTable = {
	__index = {
		addState = function(fsm, state, name)
			fsm[name] = state
		end,
		removeState = function(fsm, name)
			fsm[name] = nil
		end,
		enterState = function(fsm, name, ...)

		log("2")
			if fsm.active and fsm.active.exit then fsm.active.exit() end
		log("3")
			fsm.active = fsm[name]
		log("4")
		if fsm.active then log("active") end
			if fsm.active.enter then
				fsm.active.enter(...)
			end
		log("5")
		end
	}
}


function FSM()
	local fsm = {}
	setmetatable(fsm, fsmMetaTable)
	return fsm
end