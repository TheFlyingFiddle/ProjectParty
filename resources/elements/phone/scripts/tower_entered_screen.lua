local function exit(tower)
	sendTowerExited(tower.cell)
	fsm:enterState("GamePlay")
end

function TowerEnteredScreen()
	local t = {}

	function t.onBackButton()
		exit(t)
		return true
	end
	return t
end

function PressureTowerScreen()
	local t = TowerEnteredScreen()

	t.pressureDisplay = 
		PressureDisplay(Rect2(	Screen.width/24, Screen.height/12, 
								Screen.width/12, Screen.height*3/5), 
					0xFFFF8800,
					0xFF770000,
					1)

	local function handlePressureInfo(pressure)
		t.pressureDisplay.amount = pressure	
	end

	local function handleTowerBroken(cell)
		log("towerBroken")
		if cell.x == t.cell.x and cell.y == t.cell.y then
			exit(t)			
		end
	end

	function t.enter(cell)
		gui:add(t.pressureDisplay)
		Network.setMessageHandler(Network.incoming.towerBroken, handleTowerBroken)
		Network.setMessageHandler(Network.incoming.pressureInfo, handlePressureInfo)

		sendTowerEntered(cell)
		t.cell = cell
	end

	function t.exit()
		Network.removeMessageHandler(Network.incoming.towerBroken, handleTowerBroken)
		Network.removeMessageHandler(Network.incoming.pressureInfo, handlePressureInfo)

		gui:clear()
	end

	return t
end