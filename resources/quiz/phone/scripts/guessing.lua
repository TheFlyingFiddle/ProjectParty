local activeColor = 0xFF00FF00
local inactiveColor = 0xFF005500

local categoryColors = 
{
	0xFF0088FF,
	0xFF009900,
	0xFF4422FF,
	0xFFFF0000,
	0xFF00FFFF,
	0xFF002288
}

local categoryScores = { 0, 0, 0, 0, 0, 0 }

local extraScore = 0
local extraScoreColor = 0xFFFFFFFF
local scoreCost = 3

function Guessing()
	local t = {}

	local function setChoices(choices)
			logf("Width: %d, Height: %d", Screen.width, Screen.height)

		gui:clear()
		for i=1, #choices, 1 do
			local function choose(button)
				for k, v in pairs(gui.items) do
					if v == button then
						v.tint = activeColor 
					else
						v.tint = inactiveColor
					end
				end
				sendChoice(i-1)
			end
			gui:add(Button(inactiveColor, pixel,
				Rect2(0,
					  (i - 1) * Screen.height/8,
					  Screen.width,
					  Screen.height/8),
				choose,
				font,
				choices[i],
				0xFFFFFFFF))
		end
	end

	local function onChoices(choices)
		setChoices(choices)
		t.category = choices.category+1
	end

	local function onCorrectAnswer()
		if categoryScores[t.category] == 3 then
			extraScore = extraScore + 1
		else
			categoryScores[t.category] = categoryScores[t.category] + 1
		end
	end

	local function onShowAnswer(answer)
		for i, v in ipairs(gui.items) do
			v.callback = nil
			if i == answer + 1 then
				v.tint = 0xFFFF0000
			end
		end
	end

	function t.render()
		local dim = vec2(Screen.width/6,Screen.width/6)
		for i, value in ipairs(categoryColors) do
			local position = vec2((i%2)*(Screen.width/2), 
				Screen.height - (i%3+1)*(Screen.width/6))
			for j=1, categoryScores[i] do
				Renderer.addFrame(circle, position + vec2(dim.x * (j-1),0), dim, categoryColors[i])
			end
		end

		for i=1, extraScore do
			local position = vec2(dim.x * (i-1), Screen.height/2)
			Renderer.addFrame(circle, position, dim, extraScoreColor)
		end
		if extraScore >= scoreCost then
			for i, value in ipairs(categoryColors) do
				local position = vec2((i%2)*(Screen.width/2), 
					Screen.height - (i%3+1)*(Screen.width/6))
				if categoryScores[i] < 3 then
					Renderer.addFrame(plus, position + vec2(dim.x * categoryScores[i],0), 
							dim, categoryColors[i])
				end
			end
		end
	end

	function t.onTap(x,y)
		local dim = vec2(Screen.width/6,Screen.width/6)
		if extraScore >= scoreCost then
			for i, value in ipairs(categoryColors) do
				local position = vec2((i%2)*(Screen.width/2), 
					Screen.height - (i%3+1)*(Screen.width/6))
				if categoryScores[i] < 3 then
					if pointInRect(Rect(position + vec2(dim.x * categoryScores[i],0), 
							dim), vec2(x,y)) then
						categoryScores[i] = categoryScores[i] + 1
						sendBuyScore(i-1)
						extraScore = extraScore - scoreCost
					end
				end
			end
		end
	end

	function t.enter()
		Network.setMessageHandler(Network.incoming.choices, onChoices)
		Network.setMessageHandler(Network.incoming.correctAnswer, onCorrectAnswer)
		Network.setMessageHandler(Network.incoming.showAnswer, onShowAnswer)
	end	

	function t.exit()
		gui:clear()
		Network.removeMessageHandler(Network.incoming.choices, onChoices)
		Network.removeMessageHandler(Network.incoming.correctAnswer, onCorrectAnswer)
		Network.removeMessageHandler(Network.incoming.showAnswer, onShowAnswer)
	end

	return t
end