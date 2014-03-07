local sensorNetworkID = 1
local deathNetworkID  = 50
local toggleReadyID   = 51

local readyColor      = 0xFFcc0000
local notReadyColor   = 0xFF00cc00
local textColor       = 0xFF000000

local score = 0
local font
local button

function Lobby()
	local lobby = {}
	function lobby.enter()
		local frame = Loader.loadFrame("textures/pixel.png")
		font  = Loader.loadFont("fonts/Segoe54.fnt")
	    rotation = 0
	    playerColor = 0xFFFFFFFF

	    log(string.format("Loaded %d, %d", frame, font));

	    button = Button(notReadyColor, frame, "Press to be ready",
	    	Rect(vec2(Screen.width / 2 - 380 / 2, Screen.height / 2 - 70),
	    			    vec2(380, 140)), toggleButton, textColor)
	end
	function lobby.exit()
		Loader.unloadFrame(button.frame)
		Loader.unloadFont(font)
	end
	function lobby.render()
		drawButton(button, font)
		renderTime(font)
	end
	function lobby.update()
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
	function lobby.onTap(x, y)
	    if pointInRect(button.rect, vec2(x,y)) then
	      button.callback(button)
	    end
	end
	function lobby.handleMessage(id, length)
    log(string.format("Handle message called %d", id))
		if id == Network.messages.color then
			playerColor = In.readInt()
		end
	end
	return lobby
end

function toggleButton(button)
  if button.tint == notReadyColor then
    button.tint = readyColor
    button.text = "Press to be ready"
  else
    button.tint = notReadyColor
    button.text = "Press to be not ready"
  end

  Out.writeShort(1)
  Out.writeByte(toggleReadyID)
end
