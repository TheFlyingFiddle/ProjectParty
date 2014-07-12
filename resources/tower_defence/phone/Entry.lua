local renderer
local atlas
local position

function Game.start()
	renderer = CRenderer(128)
	atlas    = Resources.loadFile("Atlas.luac")
	position = { x= 100, y= 100 }
	Screen.setOrientation(Orientation.landscape)
	Log.info("Start is done!")
end

function Game.restart()
	Game.start()
	Log.info("Restarting!")
	position = Resources.loadTable("savestate.luac")
	Screen.setOrientation(Orientation.landscape)
end

function Game.stop()
	Resources.saveTable( { x =position.x, y =position.y }, "savestate.luac")
end

function Game.step()
	Log.info("Dance Man 243|")
    gl.glClearColor(0,0.3,0.4,1)
    gl.glClear(gl.GL_COLOR_BUFFER_BIT)
    gl.glViewport(0,0,C.gGame.screen.width,C.gGame.screen.height)
    gl.glEnable(gl.GL_BLEND)
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)

    renderer:addFrame(atlas.pixel, vec2(100, 100), vec2(240, 235), 0xaaFFFFFF)
    renderer:addFrame(atlas.orange, vec2(position.x, position.y), vec2(atlas.width, atlas.height), 0xFFFFFFFF)
    renderer:draw()
end


function Input.onDown(id, x, y)
	position = vec2(x, y)
end