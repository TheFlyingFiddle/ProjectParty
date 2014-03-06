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
			Out.writeShort(25)
			Out.writeByte(sensorNetworkID)
			Out.writeVec3(Sensors.acceleration)
			Out.writeVec3(Sensors.gyroscope)
		end

		Network.send()
	end
	function gamePlay.handleMessage(id, length)
		if id == Network.messages.death then
			log(string.format("color: %d", playerColor))
			Network.send()
			score = In.readShort()
		end
	end
	return gamePlay
end