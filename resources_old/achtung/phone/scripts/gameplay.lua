local sensorNetworkID = 1

local font
local score

function GamePlay()
	local gamePlay = {}
	function gamePlay.enter()
		font  = Loader.loadFont("fonts/Segoe54.fnt")
		score = 0
	end
	function gamePlay.exit()
		Loader.unloadFont(font)
	end
	function gamePlay.render()
		local scoreStr = string.format("Score: %d", score)
		local size = Font.measure(font, scoreStr)
		local pos = vec2(Screen.width / 2 - size.x / 2,
			Screen.height / 2 - size.y / 2)

		Renderer.addText(font, scoreStr, pos, playerColor)
	end
	function gamePlay.update()
		updateTime()

		if useButtons then
			--Send le buttons
		else
			UOut.writeShort(25)
			UOut.writeByte(sensorNetworkID)
			UOut.writeVec3(Sensors.acceleration)
			UOut.writeVec3(Sensors.gyroscope)
		end

		Network.usend()
	end
	function gamePlay.handleMessage(id, length)
		if id == Network.messages.death then
			vibrate(100)
			score = In.readShort()
		elseif id == Network.messages.win then
			score = In.readShort()
		elseif id == Network.messages.color then
			playerColor = In.readInt()
		end
	end
	return gamePlay
end
