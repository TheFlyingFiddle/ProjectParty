
local fsmMetaTable = {
	__index = {
		addState = function(fsm, state, name)
			fsm[name] = state
		end,
		removeState = function(fsm, name)
			fsm[name] = nil
		end,
		enterState = function(fsm, name)
			if fsm.active and fsm.active.exit then fsm.active.exit() end
			fsm.active = fsm[name]
			if fsm.active.enter then
				fsm.active.enter()
			end
		end
}
}


function FSM()
	local fsm = {}
	setmetatable(fsm, fsmMetaTable)
	return fsm
end