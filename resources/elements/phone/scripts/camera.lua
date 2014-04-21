local CameraMT = 
{
	__index =
	{
		onDragBegin = function (self, pos)
			self.dragPos = pos
		end,
		onDrag = function (self, pos)
			local delta = self.dragPos - pos
			self.dragPos = pos
			self:move(delta)
		end,
		onPinchBegin = function(self, pos0, pos1)
			self.pinchDist = Vector2.distance(pos0, pos1)
			log(string.format("Pinch begin! %f", self.pinchDist))
		end,
		onPinch = function(self, pos0, pos1)
			log("Pinching")
			local dist     = Vector2.distance(pos0, pos1)
			local delta    = dist - self.pinchDist

			log(string.format("Pos %f,%f Pos %f,%f", pos0.x, pos0.y, pos1.x, pos1.y))
			log(string.format("Pinch %f, %f, %f", self.pinchDist, dist, delta))
			self.pinchDist = dist


			if math.abs(delta) < 2 then
				return
			end

			self:zoomDelta(delta)
		end,
		transform = function(self, pos)
			return pos - self.pos * self.zoom 
		end,
		worldPos = function(self, screenPos)
			return screenPos / self.zoom + self.pos
		end,
		scale = function(self, pos)
			return pos * self.zoom
		end,
		move = function(self, delta)
			self.pos = self.pos + delta

			local width = self.viewport.dim.x / self.zoom
			local worldWidth = self.worldDim.x
			if self.pos.x < 0 then
				self.pos.x = 0
			elseif self.pos.x + width > worldWidth then
				self.pos.x = math.max(0, worldWidth - width)
			end

			local height = self.viewport.dim.y / self.zoom
			local worldHeight = self.worldDim.y

			if self.pos.y < 0 then
				self.pos.y = 0
			elseif self.pos.y + height > worldHeight then
				self.pos.y =  math.max(0, worldHeight - height)
			end
		end,
		zoomDelta = function(self, delta)
			self.zoom = self.zoom + delta * 0.01
			self.zoom = math.min(self.maxZoom, self.zoom)
			self.zoom = math.max(self.minZoom, self.zoom)
		end
	}
}

function Camera(viewport, worldDim, minZoom, maxZoom)
	local camera = { }
	camera.viewport  = viewport
	camera.worldDim  = worldDim

	camera.minZoom   = minZoom
	camera.maxZoom   = maxZoom
	camera.zoom      = 1.0
	
	camera.dragPos   = vec2(0,0)
	camera.pinchDist = 0

	camera.pos 		 = vec2(0,0)

	setmetatable(camera, CameraMT)
	return camera
end