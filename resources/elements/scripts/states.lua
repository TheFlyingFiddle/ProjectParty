
local fsmMetaTable = {
	__index = {
		addState = function(fsm, state, name)
			fsm[name] = state
		end,
		removeState = function(fsm, name)
			fsm[name] = nil
		end,
		enterState = function(fsm, name)
			if fsm.active then fsm.active.exit() end
			fsm.active = fsm[name]
			fsm.active.enter()
		end
}
}


function FSM()
	local fsm = {}
	setmetatable(fsm, fsmMetaTable)
	return fsm
end