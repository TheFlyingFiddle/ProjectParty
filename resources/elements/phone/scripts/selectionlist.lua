
local slmt = {}
slmt.__index = {
			select = function(slist, pos)

			end,
			draw = function(slist)
			end
		}
function SelectionList(rect, frames)
	local slist = {}
	setmetatable(slist, slmt)

end