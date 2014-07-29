local Screen = { }
local SAVE_STATE_NAME = "save_state_screen.luac"

function Screen:init()
	self.screens = { }
end

function Screen:restart()
	self:init()
	--Load the saved state
	local state = File.loadTable(SAVE_STATE_NAME)
	for i, v in ipairs(state) do 
		local screen = Type.restart(v.type, v.save)
		table.insert(self.screens, screen)
	end
end

function Screen:stop()
	--Basically we need to save all the screens. 
	--Save the current state.
	--clear the state.
	local toSave = { }
	for i=#self.screens, 1,-1 do
		local screen = self.screens[i]
		local saveName = screen:stop()
		local name = Type.typeName(screen)
		table.insert(toSave, { type = name, save = saveName })
		table.remove(self.screens)
	end

	File.saveTable(toSave, SAVE_STATE_NAME)
end

function Screen:push(screen)
	table.insert(self.screens, screen)	
end

function Screen:pop()
	table.remove(self.screens)
end

function Screen:update(...)
	for _, v in ipairs(self.screens) do
		if v.update then
			v:update(...)
		end
	end
end

function Screen:render(...)
	for _, v in ipairs(self.screens) do 
		if v.render then 
			v:render(...)
		end
	end
end

--Basically screens need access to all input event 
--To block them etc
function Screen:onDown( ... )
	for i=#self.screens,1,-1 do
		local screen = self.screens[i]
		if screen.onDown then 
			local res = screen:onDown(...)
			if res then return end
		end
	end
end

function Screen:onMove( ... )
	for i=#self.screens,1,-1 do
		local screen = self.screens[i]
		if screen.onMove then 
			local res = screen:onMove(...)
			if res then return end
		end
	end
end

function Screen:onUp( ... )
	for i=#self.screens,1,-1 do
		local screen = self.screens[i]
		if screen.onUp then 
			local res = screen:onUp(...)
			if res then return end
		end
	end
end

function Screen:onCancel( ... )
	for i=#self.screens,1,-1 do
		local screen = self.screens[i]
		if screen.onCancel then 
			local res = screen:onCancel(...)
			if res then return end
		end
	end
end

function Screen:onBackButton( ... )
	for i=#self.screens,1,-1 do
		local screen = self.screens[i]
		if screen.onBackButton then 
			local res = screen:onBackButton(...)
			if res then return end
		end
	end
end

function Screen:onMenuButton( ... )
	for i=#self.screens,1,-1 do
		local screen = self.screens[i]
		if screen.onMenuButton then 
			local res = screen:onMenuButton(...)
			if res then return end
		end
	end
end

Type.define(Screen, "ScreenStack");