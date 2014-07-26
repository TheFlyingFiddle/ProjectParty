local renderer
local atlas
local position
local rotation
local network
local font
local bolder;

local function onMsg(msg)
end

function Game.start()
	Log.info("Starting!")

	renderer  = CRenderer(128)
	atlas     = resources:load(R.Atlas)
	font	  = resources:load(R.consola)
	bolder    = atlas.boulder;
	position  = { x= 100, y= 100 }
	rotation  = 0
	Screen.setOrientation(Orientation.landscape)


	network   = Network(0xFFFF, 0xFFFF)
	network:connect(Game.server.ip, Game.server.tcpPort, Game.server.udpPort, 1000)	
	network:addListener(NetIn.testMessageB, onMsg)
end

function Game.restart()
	Game.start()
	Log.info("Restarting!")
	position = File.loadTable("savestate.luac")
	Screen.setOrientation(Orientation.landscape)

	Log.info("restarted!")
end

function Game.stop()
	File.saveTable( { x =position.x, y =position.y }, "savestate.luac")
	resources:unloadAll()
	network:disconnect()
end

function Game.step()
	if C.remoteDebugUpdate() then 
        return
    end

	network:receive()
	updateReloading()

    gl.glClearColor(0,0,0,0)
    gl.glClear(gl.GL_COLOR_BUFFER_BIT)
    gl.glViewport(0,0,C.gGame.screen.width,C.gGame.screen.height)
    gl.glEnable(gl.GL_BLEND)
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)

   	renderer:addFrame(atlas.pixel,   vec2(100, 100), vec2(256,256) , 0xaaFFFF00)
	renderer:addFrame(atlas.orange,  vec2(100, 100), vec2(128,128) , 0xFF000000)
   	renderer:addFrame(atlas.banana2, vec2(200, 100), vec2(128,128) , 0xFFFFFFFF)
   	rotation = rotation - 0.1

    renderer:addFrameTransform(atlas.orange, 
    						   vec2(position.x, position.y), 
    						   vec2(256, 256), 
    						   0xFFFFFFFF,
    					       vec2(128, 128), 
    					       rotation, 
    					       true)

    renderer:addText(font.font, 
    				 "Hello there young padowan!",
    				 vec2(0,-100),
    				 0xFFAAFFAA, 
    				 100, 
    				 vec2(0.2,0.45))

     renderer:addText(font.font, 
    				 "Hello there young padowan!",
    				 vec2(0,0),
    				 0xFFAAFFAA, 
    				 200, 
    				 vec2(0,0.5))

    renderer:draw()
 
 

    network:sendMessage(NetOut.testMessageA, { a = 5, b = 103})
	network:send()
end

function Input.onDown(id, x, y)
	position = vec2(x, y)
end