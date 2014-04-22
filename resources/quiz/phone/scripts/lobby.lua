local readyColor      = 0xFF00cc00
local notReadyColor   = 0xFF0000cc

local textColor       = 0xFF000000

function Lobby()
	local lobby = {}
	function lobby.enter()
	    rotation = 0
	    playerColor = 0xFFFFFFFF
	    local button = Button(notReadyColor, pixel, 
	    	Rect2(Screen.width / 2 - 380 / 2, Screen.height / 2 - 70,
	    			    380, 140), toggleButton, font, "Press to be ready", textColor)
	    gui:add(button)
	end
	function lobby.exit()
		gui:clear()
	end
	return lobby
end

function toggleButton(button)
  if button.tint == notReadyColor then
    button.tint = readyColor
    button.text = "Press to be not ready"
  else
    button.tint = notReadyColor
    button.text = "Press to be ready"
  end

  sendToggleReady()
end
