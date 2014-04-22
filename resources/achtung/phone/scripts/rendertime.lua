--Timing related stuff below
local fpsCounter = 0
local fps = 0
local lastSecond = 0

function updateTime()
	if Time.total - lastSecond > 1 then
		fps = fpsCounter
		fpsCounter = 0
		lastSecond = Time.total
	end
	fpsCounter = fpsCounter + 1
end

function renderTime(font)
	local pos  = vec2(0, Screen.height - 100);

	local text = string.format("FPS: %d Total %.2f \nElapsed %.3f" , fps, Time.total, Time.elapsed)
	Renderer.addText(font, text, pos, 0xFF03cc42);
end
