local gui_mt = 
{
	__index = 
	{
		onTap = function(self, position)
			log("Tapping")

			for k, v in pairs(self.items) do
				local mt = getmetatable(v)
				if pointInRect(v.rect, position) and mt.__index.onTap then

					v:onTap(position)
					return true
				end
			end
		end,
		onDrag = function(self, position)
			for k, v in pairs(self.items) do
				local mt = getmetatable(v)
				if pointInRect(v.rect, position) and mt.__index.onDrag then
					v:onDrag(position)
					return true
				end
			end
		end,
		onDragBegin = function(self, position)
			for k, v in pairs(self.items) do
				local mt = getmetatable(v)
				if pointInRect(v.rect, position) and mt.__index.onDragBegin then
					v:onDragBegin(position)
					return true
				end
			end
		end,
		onDragEnd = function(self, position)
			for k, v in pairs(self.items) do
				local mt = getmetatable(v)
				if pointInRect(v.rect, position) and mt.__index.onDragEnd then
					v:onDragEnd(position)
					return true
				end
			end
		end,
		onPinchBegin = function(self, position0, position1)
			for k, v in pairs(self.items) do
				local mt = getmetatable(v)
				if mt.__index.onPinchBegin then
					v:onPinchBegin(position0, position1)
				end
			end
		end,
		onPinch = function(self, position0, position1)
			for k, v in pairs(self.items) do
				local mt = getmetatable(v)
				if mt.__index.onPinch then
					v:onPinch(position0, position1)
				end
			end
		end,
		draw = function(self) 
			for k, v in pairs(self.items) do
				v:draw()
			end
		end,
		update = function(self) 
			for k, v in pairs(self.items) do
				local mt = getmetatable(v)
				if mt.__index.update then
					v:update()
				end
			end
		end,
		clear = function(self)
			self.items = {}
		end,
		add = function(self, element)
			table.insert(self.items, element)
		end
	}	
}

function Gui()
	local gui = {}
	gui.items = {}

	setmetatable(gui, gui_mt)

	return gui
end