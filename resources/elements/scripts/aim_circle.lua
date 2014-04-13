local AimCircleMT = 
{
	__index = 
	{
		onDrag = function(self, pos)
			if pointInRect(self.rect, pos) then 
				self.direction = Vector2.angleBetween(
					self.rect:center(), pos)
				self.magnitude = Vector2.distance(
					self.rect:center(), pos)
				if self.callback then
					self.callback(self.direction, self.magnitude / (self.rect.dim.x / 2))
				end
			end
		end,
		draw = function (self)
			Renderer.addFrame(ring, self.rect.pos,
							  self.rect.dim, 0xFF00FF00)
			if(self.magnitude > self.rect.dim.x / 2) then
				self.magnitude = self.rect.dim.x / 2
			end

			local pos = Vector2.fromPolar(self.magnitude, self.direction) + self.rect:center() - vec2(20, 20)
			local dim = vec2(40, 40)
			Renderer.addFrame(circle, pos, dim, 0xFFFFAA66)
		end
	}
}

function AimCircle(area, callback)
	local t     = {}
	t.rect      = area
	t.direction = 0
	t.magnitude = 0
	t.callback 	= callback
	setmetatable(t, AimCircleMT)
	return t
end