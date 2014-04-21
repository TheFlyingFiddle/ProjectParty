function Between()
	local t = {}

	local function onReady()
		sendReady()
	end

	local function onYouGuess(choices)
		fsm:enterState("Guessing", choices)
	end

	local function onYouDraw(toDraw)
		fsm:enterState("Drawing", toDraw)
	end

	function t.enter()
		gui:add(Button(0xFF00AA00, pixel, Rect2(
											Screen.width/3,
											Screen.height/3,
											Screen.width/3,
											Screen.height/3),
						onReady, font, "I'm ready!", 0xFFFFFFFF))
		Network.setMessageHandler(Network.incoming.youDraw, onYouDraw)
		Network.setMessageHandler(Network.incoming.youGuess, onYouGuess)
	end

	function t.exit()
		Network.removeMessageHandler(Network.incoming.youGuess, onYouGuess)
		Network.removeMessageHandler(Network.incoming.youDraw, onYouDraw)
		gui:clear()
	end

	return t
end