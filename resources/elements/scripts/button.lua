local function checkTapped(item, pos)
    if item.callback and pointInRect(item.rect, pos) then
        item.callback()
    end
end

local ButtonMT = { 
  __index = { 
    onTap = checkTapped,
    draw =  function(self)
                Renderer.addFrame(self.frame, self.rect.pos, 
                                  self.rect.dim, self.tint)
                local size = Font.measure(self.font, self.text)
                local pos  = vec2(self.rect.pos.x + self.rect.dim.x / 2 - size.x / 2,
                                  self.rect.pos.y + self.rect.dim.y / 2 - size.y / 2)
                Renderer.addText(self.font, self.text, pos, self.textTint)
            end
          }
 }

local SimpleButtonMT = 
{
  __index = 
  {
    onTap = checkTapped,
    draw  = function(self)
        Renderer.addFrame(self.frame, self.rect.pos, 
                          self.rect.dim, self.tint)
    end
  } 
}

function Button (tint, frame, rect, callback, font, text, textTint)
  local button = {}
  button.tint = tint
  button.frame = frame
  button.rect = rect
  button.callback = callback

  button.font = font
  button.text = text
  button.textTint = textTint
  setmetatable(button, ButtonMT)
  return button
end

function SimpleButton(tint, frame, rect, callback)
  local t = { }
  t.frame = frame
  t.tint  = tint
  t.rect  = rect
  t.callback = callback

  setmetatable(t, SimpleButtonMT)
  return t
end