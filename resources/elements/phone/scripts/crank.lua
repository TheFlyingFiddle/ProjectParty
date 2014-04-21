local function crankPos(crank)
	return crank.rect:center() + vec2(
				(crank.rect.dim.x/2) * math.cos(crank.dir), 
				(crank.rect.dim.y/2) * math.sin(crank.dir))
end

local CrankMT = 
{
	__index = 
	{
		onDrag = function(self, pos)
			if Vector2.distance(crankPos(self), pos) < 200 then -- Arbitrary magic magnet
				local angle = Vector2.angleBetween(self.rect:center(), pos)
				local diff = angle - self.dir
				self.dir = angle
				if self.callback and diff > 0 and diff < math.pi then 
					self.callback(diff)
				end 			
			end
		end,
		draw = function(self)
			Renderer.addFrame(ring, self.rect.pos, 
							  self.rect.dim, self.ringColor)
			local pos = Vector2.fromPolar(self.rect.dim.x / 2, self.dir) 
							+ self.rect:center() - vec2(20, 20)
			local dim = vec2(80,80)
			Renderer.addFrame(circle, pos, dim, self.ballColor)		
		end 
	}
}

function Crank(area, callback, ringColor, ballColor)
	local t  	= {} 
	t.rect 	    = area
	t.dir  		= 0
	t.callback  = callback
	t.ringColor = ringColor
	t.ballColor = ballColor

	setmetatable(t, CrankMT)
	return t
end