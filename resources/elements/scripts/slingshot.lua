function Slingshot()
	local t = {}

	function t.enter(x, y) 
		sendTowerEntered(x, y)
		t.x = x
		t.y = y
	end

	function t.exit()

	end

	function t.update()

	end

	function t.render()

	end

	function t.onDrag(x, y)
		sendSlingshotUpdate(t.x, t.y, vec2(x, y))
	end

	function t.onDragBegin(x, y)
		t.startPos = vec2(x, y)

		sendSlingshotBegin(t.x, t.y, t.startPos)
	end

	function t.onDragEnd(x, y)
		sendSlingshotEnd(t.x, t.y)
	end

	return t
end
