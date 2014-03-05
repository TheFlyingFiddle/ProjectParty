
local fsmMetaTable = {
	__index = {
		addState = function(fsm, state, name)
			fsm[name] = state
		end,
		removeState = function(fsm, name)
			fsm[name] = nil
		end,
		enterState = function(fsm, name)
			if fsm.active then fun.active.exit() end
			fsm.active = fun[name]
			fsm.active.enter()
		end
}
}


function FSM()
	local fsm = {}
	setmetatable(fsm, fsmMetaTable)
	return fsm
ends