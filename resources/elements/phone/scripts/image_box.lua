local ImageBoxMT = 
{
  __index = 
  {
    draw  = function(self)
    	Renderer.addFrame(self.frame, self.rect.pos, 
                          self.rect.dim, self.tint)
    end
  } 
}

function ImageBox(tint, frame, rect)
  local t = { }
  t.frame = frame
  t.tint  = tint
  t.rect  = rect

  setmetatable(t, ImageBoxMT)
  return t
end