local DirectionSelectorMT = 
{
	__index = 
	{
		onDrag = function(self, x,y)
			local pos = vec2(x,y)
			if pointInRect(self.rect, pos) then
				local angle = Vector2.angleBetween(self.rect:center(), pos)
				self.dir = angle
				if self.callback then 
					self.callback(angle)
				end 			
			end
		end,
		draw = function(self)
			Renderer.addFrame(ring, self.rect.pos, 
							  self.rect.dim, self.ringColor)
			local pos = Vector2.fromPolar(self.rect.dim.x / 2, self.dir) 
							+ self.rect:center() - vec2(20, 20)
			local dim = vec2(40,40)
			Renderer.addFrame(circle, pos, dim, self.ballColor)		
		end 
	}
}


function DirectionSelector(area, callback, ringColor, ballColor)
	local t  	= {} 
	t.rect 	    = area
	t.dir  		= 0
	t.callback  = callback
	t.ringColor = ringColor
	t.ballColor = ballColor
	setmetatable(t, DirectionSelectorMT)
	return t
end