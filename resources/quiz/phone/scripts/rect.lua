local RectMT = 
{
  __index = 
  {
    left = function(rect)
    return rect.pos.x
  end,
  
  right = function(rect)
    return rect.pos.x + rect.dim.x
  end,

  top = function(rect)
    return rect.pos.y + rect.dim.y
  end,

  bottom = function(rect)
    return rect.pos.y
  end,
    
  center = function(rect)
    return vec2(rect.pos.x + rect.dim.x / 2, 
                rect.pos.y + rect.dim.y / 2)
  end

  }
}

function Rect(pos, dim)
  local rect = {}
  rect.pos = pos
  rect.dim = dim

  setmetatable(rect, RectMT)
  return rect
end

function Rect2(x,y,w,h)
  return Rect(vec2(x,y), vec2(w,h))
end


function pointInRect(rect, point)
  return point.x > rect:left() and
         point.x < rect:right() and
         point.y > rect:bottom() and
         point.y < rect:top()
end

