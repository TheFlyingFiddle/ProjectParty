local GridMT =
{
	__index =
	{
		at =
			function(self,x,y)
				local xpos = math.floor(x)
				local ypos = math.floor(y)
				return self[xpos + ypos * self.width]
			end,
		set = 
			function(self,x,y,value)
				local xpos = math.floor(x)
				local ypos = math.floor(y)
				self[xpos + ypos * self.width] = value
				local success = self:at(x,y)
			end,
		clear =
			function(self)
				for i=1, self.width*self.height, 1 do
					self[i] = 0
				end
			end
	}
}

function Grid(width, height)
	t = {}
	t.width = width
	t.height = height

	for i=1, width*height, 1 do
		t[i] = 0
	end

	setmetatable(t, GridMT)
	return t
end