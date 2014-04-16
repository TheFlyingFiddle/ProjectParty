local function setChoices(choices)
	gui:clear()
	for i=1, #choices, 1 do
		local function choose()
			sendChoice(i - 1)
		end
		gui:add(Button(0xFF0000FF, pixel,
			Rect2(Screen.width/2 - Screen.width/4,
				  (i - 1) * Screen.height/4,
				  Screen.width/2,
				  Screen.height/4),
			choose,
			font,
			choices[i],
			0xFFFFFFFF))
	end
end

function Guessing()
	local t = {}

	local function onYouGuess(choices)
		setChoices(choices)
	end

	local function onCorrectAnswer()
		score = score + 1

	end

	local function onIncorrectAnswer()
		score = math.max(0, score - 1)
	end

	local function onBetweenRounds()
		fsm:enterState("Between")
	end

	function t.enter(choices)
		setChoices(choices)
		Network.setMessageHandler(Network.incoming.youGuess, onYouGuess)
		Network.setMessageHandler(Network.incoming.correctAnswer, onCorrectAnswer)
		Network.setMessageHandler(Network.incoming.incorrectAnswer, onIncorrectAnswer)
		Network.setMessageHandler(Network.incoming.betweenRounds, onBetweenRounds)
	end	

	function t.exit()
		gui:clear()
		Network.removeMessageHandler(Network.incoming.youGuess, onYouGuess)
		Network.removeMessageHandler(Network.incoming.correctAnswer, onCorrectAnswer)
		Network.removeMessageHandler(Network.incoming.incorrectAnswer, onIncorrectAnswer)
		Network.removeMessageHandler(Network.incoming.betweenRounds, onBetweenRounds)
	end

	return t
end