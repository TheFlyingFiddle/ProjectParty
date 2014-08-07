local GUI = { }

local function inRect(pos, dim, point)
	return pos.x < point.x and
	   	   pos.x + dim.x > point.x and
	  	   pos.y < point.y and 
	   	   pos.y + dim.y > point.y
end

local function pressed(pos, dim)
	for k,v in pairs(Input.released) do 
 		if inRect(pos, dim, v.down) and 
 		   inRect(pos, dim, v.pos) then 
 		   return true
 		end
 	end
 	return false
end

local function renderButton(item, renderer, pos, dim, content)

	local cond = false
	for _, v in pairs(Input.pointers) do 
		if inRect(pos, dim, v.down) and 
		   inRect(pos, dim, v.pos) then 
		   cond = true 
		   break
		end
	end

	local color
	if cond then 
		color = item.highlight
	else
		color = item.color
	end


	renderer:addFrame(item.bgFrame, pos, dim, color)

	if type(content) == "string" then 
    	local size = vec2(item.size, item.size) * item.font:measure(content);
    	local fpos = pos + ((dim - size) / 2)
    	renderer:addText(item.font, content, fpos, 
    				     item.textColor, 
    				     vec2(item.size, item.size),
    				     vec2(0.2, 0.6))
	else 
		--Frames used are actually Frame[1] normally...
		local frame = content[0]
		local size = vec2(frame.width * frame.texture.width,
						  frame.height * frame.texture.height)

		local fpos = pos + ((dim - size) / 2);
		renderer:addFrame(frame, fpos, size, 0xFFFFFFFF)
	end
end

local function renderTextBox(item, renderer, pos, dim, text, hint)
	local color
	local tex
	if text then 
		color = item.fgColor
		tex   = text 
	else 
		color = item.htColor
		tex   = hint
	end

	renderer:addFrame(item.bgFrame, pos, dim, item.bgColor)

	local size = item.size * item.font:measure(tex);
	local fpos = pos + vec2(0, (dim.y - size.y) / 2)
	renderer:addText(item.font, 
					 tex, 
					 fpos, 
				     color, 
				     item.size,
				     vec2(0.2, 0.6))
end

local function renderToggle(item, renderer, pos, dim, value)
	local color
	local img
	if value then 
		color = item.toggleColor
		img   = item.toggleFrame
	else
		color = item.untoggleColor
		img   = item.untoggleFrame
	end

	renderer:addFrame(img, pos, dim, color)
end

local function renderSlider(item, renderer, pos, dim, value)
	local long  = math.max(dim.x, dim.y)
	local short = math.min(dim.x, dim.y) 
	local off   = long * 0.01 * value - short / 2
	off = math.min(math.max(off, 0), long - short)

	renderer:addFrame(item.bgFrame, pos, dim, item.bgColor)

	local sPos 
	if dim.y < dim.x then 
		sPos = pos + vec2(off, 0)
	else
		sPos = pos + vec2(0, off)
	end

	renderer:addFrame(item.fgFrame, sPos, vec2(short, short), item.fgColor)
end

function GUI:button(pos, dim, text)
	self.buttonRenderer:render(self.renderer, pos, dim, text)
	return pressed(pos, dim)
end

function GUI:textBox(pos, dim, text, hint)
	--Do text input logic
	self.textBoxRenderer:render(self.renderer, pos, dim, text, hint)
end

function GUI:toggle(pos, dim, value)
	self.toggleRenderer:render(self.renderer, pos, dim, value)
	local res = pressed(pos, dim)
	if res then 
		return not value
	else
		return value
	end
end

function GUI:slider(pos, dim, value)
	for _, v in pairs(Input.pointers) do 
		if inRect(pos, dim, v.down) then 
			if dim.y < dim.x then 
				local calc = ((v.pos - pos).x / dim.x) * 100
				value = math.max(0, math.min(100, calc))
			else
				local calc = ((v.pos - pos).y / dim.y) * 100
				value = math.max(0, math.min(100, calc))
			end
		end		
	end	

	--Calculate Value based on stuff
	self.sliderRenderer:render(self.renderer, pos, dim, value, min, max)
	return value
end

function GUI:init(renderer, fonts, frame)
	self.buttonRenderer = 
	{ 
		font = fonts:find("consola"), 
		size = 20, 
		bgFrame = frame, 
		color = 0xFFFFFFFF,
		highlight = 0xFF00FFFF,
		textColor = 0xFF00FF00,
		render = renderButton
	}

	self.textBoxRenderer = 
	{
		font    = fonts:find("consola"),
		size    = vec2(20,20),
		bgFrame = frame,
		bgColor = 0xFFFFFFFF,
		htColor = 0xFFaaaaaa,
		fgColor = 0xFFaa3300,
		render  = renderTextBox
	}

	self.toggleRenderer = 
	{
		toggleFrame = frame,
		untoggleFrame = frame,
		toggleColor = 0xFFFFFFFF,
		untoggleColor = 0xFF000000,
		render = renderToggle
	}

	self.sliderRenderer = 
	{
		bgFrame = frame,
		fgFrame = frame,
		bgColor = 0xFF00FFFF,
		fgColor = 0xFFFF0000,
		render  = renderSlider
	}

	self.renderer = renderer
end

Type.define(GUI, "GUI")