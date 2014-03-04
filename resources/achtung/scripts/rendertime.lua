
function renderTime(fps)
	local pos  = vec2(0,0);
	local text = string.format("FPS: %d Total %.2f \nElapsed %.3f" , fps, Time.total, Time.elapsed)
	Renderer.addText(font, text, pos, 0xFF03cc42);	
end