local selector_mt = 
{
	__index = 
	{
		draw = function(self) 

		local pos = self.rect.pos
		local radius = self.rect.dim.x / 2
		local dim = vec2(radius * 2, radius * 2)
		local smallRadius = radius / 4
		local smallDim = vec2(smallRadius * 2, smallRadius * 2)
		local angle = math.pi / 2

		Renderer.addFrame(circle, pos, dim, 0x88FFFFFF)

		for i = 1, #self.items, 1 do
			local smallPos = Vector2.fromPolar(radius - smallRadius, angle) + self.rect:center() - smallDim / 2
			angle = angle + (math.pi * 2 / #self.items)
			Renderer.addFrame(self.items[i].frame, smallPos, smallDim, self.items[i].color)
		end
		
		end,
		onTap = function(self, pos)
			local radius = self.rect.dim.x / 2
			local smallRadius = radius / 2.7
			local angle = math.pi / 2

			for i = 1, #self.items, 1 do
				local smallPos = Vector2.fromPolar(radius - smallRadius, angle) + self.rect:center()
				angle = angle + (math.pi * 2 / #self.items)
				if Vector2.distance(pos, smallPos) < smallRadius and self.callback then
					self.callback(self.items[i])
				end
			end
		end
	}
}

function Selector(rect, callback, items) 
	local selector = {}
	selector.rect = rect
	selector.callback = callback
	selector.items = items

	setmetatable(selector, selector_mt)

	return selector
end