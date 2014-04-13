local DragAndDroppableMT = 
{
	__index = 
	{
		onDragBegin = function(self, pos)
			self.beingDragged = true
			self.rect.pos = pos - self.rect.dim/2
			if self.onDragBeginCB then
				self.onDragBeginCB()
			end		
			self.timeSinceDrag = 0
		end,

		onDrag = function(self, pos)
			if self.beingDragged then
				self.rect.pos = pos - self.rect.dim/2
				if self.onDragCB then
					self.onDragCB()
				end
				self.timeSinceDrag = 0
			end
		end,

--		Cannot be implemented since onDragEnd isn't called by framework
--		onDragEnd = function(self, pos)
--			log("End")
--			if self.beingDragged then
--				log("IF")
--				self.rect.pos = pos - self.rect.dim/2
--				self.beingDragged = false
--				if self.onDragEndCB then
--					self.onDragEndCB()
--				end
--			end
--		end,

		update = function(self)
			if self.beingDragged then
				self.timeSinceDrag = self.timeSinceDrag + Time.elapsed
				if self.timeSinceDrag >= self.maxNoDrag then
					self.timeSinceDrag = 0
					self.beingDragged = false
					if self.onDragEndCB then
						self.onDragEndCB()
					end
				end
			end
		end,

		draw = function(self)
			Renderer.addFrame(self.frame, self.rect.pos, 
							 self.rect.dim, 0xFFFFFFFF)
		end
	}
}


function DragAndDroppable(area, frame, onDragBeginCB, onDragCB, onDragEndCB)
	local t 		= {}
	t.frame 		= frame
	t.rect			= area
	t.onDragBeginCB = onDragBeginCB
	t.onDragCB 		= onDragCB
	t.onDragEndCB 	= onDragEndCB
	t.beingDragged	= false
	t.timeSinceDrag = 0
	t.maxNoDrag		= 0.5


	setmetatable(t, DragAndDroppableMT)
	return t
end