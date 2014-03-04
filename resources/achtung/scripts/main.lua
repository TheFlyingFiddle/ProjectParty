local sensorNetworkID = 1
local deathNetworkID  = 50
local score = 0
local font

local button

function init()
	local frame = Loader.loadFrame("textures/wallpaper.png")
	font  = Loader.loadFont("fonts/Segoe54.fnt")
    rotation = 0

    log(string.format("Loaded %d, %d", frame, font));
    log("Hello tihs is helloman");

    button = Button(0xFF0000FF, frame, "helloman", Rect(vec2(50, 50), vec2(140, 140)), toggleButton, 0xFFFFFFFF)
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
  drawButton(button, font)

	renderTime(fps)
end

function onTap(x, y)
    if pointInRect(button.rect, vec2(x,y)) then
      button.callback()
    end
end

function toggleButton()
  if button.tint == 0xFF0000FF then
    button.tint = 0xFFFF00FF
    button.text = "READYMAN!!"
    else
    button.tint = 0xFF0000FF
    button.text = "Not so ready man..."
    end
end
