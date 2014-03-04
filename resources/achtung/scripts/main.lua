local sensorNetworkID = 1
local deathNetworkID  = 50
local score = 0

--Timing related stuff below
local fpsCounter = 0
local fps = 0
local lastSecond = 0

local function updateTime()
	if Time.total - lastSecond > 1 then
		fps = fpsCounter
		fpsCounter = 0
		lastSecond = Time.total
	end
	fpsCounter = fpsCounter + 1
end


function init()
	frame = Loader.loadFrame("textures/wallpaper.png")
	font  = Loader.loadFont("fonts/Blocked72.fnt")
    rotation = 0

    --log(string.format("Loaded %d, %d", frame, font));
end

function term()
end

function handleMessage(id, length)
	if id == deathNetworkID then
		score = In.readShort()
	end
end

function update()
	updateTime();

	if not cfuns.C.networkIsAlive(Network) then
		log("We are not connected :(")
		return;
	end

	if useButtons then
		--Send le buttons
	else 
		Out.writeShort(25)
		Out.writeByte(sensorNetworkID)
		Out.writeVec3(Sensors.acceleration)
		Out.writeVec3(Sensors.gyroscope)
	end

	cfuns.C.networkSend(Network)
end

function render()
	local pos = vec2(0, 0);
	local text = string.format("Score: %d", score)

	local dim = vec2(Screen.width, Screen.height)
	Renderer.addFrame(frame, pos, dim, 0xFF0000FF)

	pos.y = Screen.height - 50;
	--Renderer.addText(font, text, pos, 0xFF00cccc)

	renderTime(fps)
end