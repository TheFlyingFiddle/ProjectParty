local GridMT =
{
	__index =
	{
		at =
			function(self,x,y)
				return self[x + y * self.width]
			end,
		set = 
			function(self,x,y,value)
				logf("SETP: [x: %d, y: %d]", x, y)
				self[x + y * self.width] = value
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