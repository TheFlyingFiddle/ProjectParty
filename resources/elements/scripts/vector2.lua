Vector2 = { } 

function Vector2.fromPolar(magnitude, angle)
	local x = math.cos(angle) * magnitude
	local y = math.sin(angle) * magnitude

	return vec2(x, y)
end

function Vector2.angleBetween(v0, v1)
	return math.atan2(v1.y - v0.y, v1.x - v0.x)
end
