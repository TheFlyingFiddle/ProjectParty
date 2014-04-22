function table.copy(param)
	local t = { }
	for k, v in pairs(param) do
		t[k] = v
	end

	return t
end