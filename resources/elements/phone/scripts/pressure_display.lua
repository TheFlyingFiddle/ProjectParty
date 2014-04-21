--This class will be extended with COOL STUFF later
local PressureDisplayMT = 
{
	__index = 
	{
		draw = function(self)
			Renderer.addFrame(pixel, self.rect.pos, 
							  self.rect.dim, self.offColor)
			local height = (self.amount / self.maxAmount) 
							* self.rect.dim.y
			Renderer.addFrame(pixel, self.rect.pos, 
							  vec2(self.rect.dim.x, height),
							  self.onColor)
		end 
	}
}


function PressureDisplay(area, onColor, offColor, maxAmount)
	local t  	= {} 
	t.rect 	    = area
	t.amount 	= 0
	t.maxAmount = maxAmount
	t.onColor 	= onColor
	t.offColor 	= offColor
	setmetatable(t, PressureDisplayMT)
	return t
end