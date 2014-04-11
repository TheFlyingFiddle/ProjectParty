local DragAndDroppableMT = 
{
	__index = 
	{

		onDragBegin = function(self, pos)
				self.rect.pos = pos
				if self.onDragBeginCB then
					onDragBeginCB()
				end		
		end,

		onDrag = function(self, pos)
				self.rect.pos = pos
				if self.onDragCB then
					onDragCB()
				end
		end,

		onDragEnd = function(self, pos)
				self.rect.pos = pos
				if self.onDragEndCB then
					onDragEndCB()
				end
		end,

		draw = function(self)
			Renderer.addFrame(self.frame, self.rect.pos, 
							 self.rect.dim, 0xFFFFFFFF)
		end
	}
}


function DragAndDroppable(area, frame, onDragBeginCB, onDragCB, onDragEndCB)
	local t  	= {}
	t.rect 	    = area
	t.onDragBeginCB = onDragBeginCB
	t.onDragCB = onDragCB
	t.onDragEndCB = onDragEndCB


	setmetatable(t, DragAndDroppableMT)
	return t
end