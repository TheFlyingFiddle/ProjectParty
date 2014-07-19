local renderer
local atlas
local position
local rotation
local network

local bolder;

function Game.start()
	Log.info("Starting!")

	renderer  = CRenderer(128)
	atlas     = resources:load(R.Atlas)
	bolder    = atlas.boulder;
	position  = { x= 100, y= 100 }
	rotation  = 0
	Screen.setOrientation(Orientation.landscape)

	--network   = Network(0xFFFF, 0xFFFF)
	--network:connect(Game.server.ip, Game.server.tcpPort, Game.server.udpPort, 1000)	
end

function Game.restart()
	Game.start()
	Log.info("Restarting!")
	position = File.loadTable("savestate.luac")
	Screen.setOrientation(Orientation.landscape)
end

function Game.stop()
	File.saveTable( { x =position.x, y =position.y }, "savestate.luac")
	resources:unloadAll()
	--network:disconnect()
end

function Game.step()
	updateReloading()

    gl.glClearColor(1,0.5,0.5,1)
    gl.glClear(gl.GL_COLOR_BUFFER_BIT)
    gl.glViewport(0,0,C.gGame.screen.width,C.gGame.screen.height)
    gl.glEnable(gl.GL_BLEND)
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)

   	renderer:addFrame(atlas.pixel,   vec2(100, 100), vec2(256,256) , 0xaaFFFF00)
	renderer:addFrame(atlas.orange,  vec2(100, 100), vec2(128,128) , 0xFF000000)
   	renderer:addFrame(atlas.banana2, vec2(228, 100), vec2(128,128) , 0xFFFFFFFF)

   	rotation = rotation - 0.1

    renderer:addFrameTransform(atlas.banana2, 
    						   vec2(position.x, position.y), 
    						   vec2(256, 256), 
    						   0xFFFFFFFF,
    					       vec2(128, 128), 
    					       rotation, 
    					       true)
    renderer:draw()
end

function Input.onDown(id, x, y)
	position = vec2(x, y)
end