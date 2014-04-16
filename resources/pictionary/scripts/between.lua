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
		gui:add(SimpleButton(0xFF00FF00, pixel, Rect2(100,100,200,100), onReady))
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