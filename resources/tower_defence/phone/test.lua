local Test = { }

function Test:init(pos, text)
	self.font = resources:load(R.Fonts);
	self.pos  = pos
	self.text = text
	self.fps     = 0
	self.count   = 0
	self.elapsed = 0
end

function Test:restart(fileName)
	local loaded = File.loadTable(fileName)
	self:init(unpack(loaded))	
end

function Test:stop()
	return File.saveRandomTable({ self.pos, self.text })
end

function Test:update( ... )
	self.count = self.count + 1
	self.elapsed = self.elapsed + Time.delta
	if self.elapsed > 1.0 then 
		self.elapsed = self.elapsed - 1.0
		self.fps   = self.count
		self.count = 0
	end
end

function Test:render()
	local consola = self.font:find("consola")
	local frame	  = resources:load(R.Atlas).pixel;
	renderer:addFrame(frame, vec2(-100, -100), vec2(Screen.width + 200,Screen.height + 200) , 0x44000000)

	renderer:addText(consola, 
    				 self.text .. string.format("FPS %d", self.fps),
                     self.pos,
    				 0xFFFFFF00, 
    				 vec2(80,40), 
    				 vec2(0.4, 0.6))


end

function Test:onDown(id, x, y)
	self.pos = vec2(x, y)
end

Type.define(Test, "Test")