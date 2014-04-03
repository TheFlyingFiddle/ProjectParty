local AmountSelectorMT = 
{
	__index = 
	{
		onDrag = function(self, pos)
			if pointInRect(self.rect, pos) then
				local localPos = pos - self.rect.pos
				local amount = localPos.y / self.rect.dim.y
				self.amount = amount 
				if self.callback then 
					self.callback(amount)
				end 			
			end
		end,
		draw = function(self)
			Renderer.addFrame(pixel, self.rect.pos, 
							  self.rect.dim, self.offColor)
			local height = self.amount*self.rect.dim.y
			Renderer.addFrame(pixel, self.rect.pos, 
							  vec2(self.rect.dim.x, height),
							  self.onColor)
		end 
	}
}


function AmountSelector(area, callback, onColor, offColor)
	local t  	= {} 
	t.rect 	    = area
	t.amount 	= 0
	t.callback  = callback
	t.onColor 	= onColor
	t.offColor 	= offColor
	setmetatable(t, AmountSelectorMT)
	return t
end