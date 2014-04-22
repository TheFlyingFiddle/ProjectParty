local font
local position = 0

function GameOver()
	local gameOver = {}

function gameOver.enter()
		font  = Loader.loadFont("fonts/Segoe54.fnt")
	end

function gameOver.exit()
		Loader.unloadFont(font)
	end

function gameOver.render()
		local posStr = string.format("You finished in %d place", position)
		local size = Font.measure(font, posStr)
		local pos = vec2(Screen.width / 2 - size.x / 2,
			Screen.height / 2 - size.y / 2)

		Renderer.addText(font, posStr, pos, playerColor)
	end

function gameOver.update()
		updateTime()
	end

function gameOver.handleMessage(id, length)
    log("Got message")
    Network.send();
		if id == Network.messages.position then
			position = In.readShort()
		end
	end
	return gameOver
end