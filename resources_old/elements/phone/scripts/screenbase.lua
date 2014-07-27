function ScreenBase()
	local t = {}

	local function exit()
		sendTowerExited(t.cell)
		fsm:enterState("GamePlay")
	end

	function t.onBackButton()
		exit()
		return true
	end
	return t
end