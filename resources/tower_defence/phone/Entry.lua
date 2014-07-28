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
	font	  = resources:load(R.Fonts)
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
	position = File.loadTable("savestate.luac")
	Screen.setOrientation(Orientation.landscape)

	Log.info("restarted!")
end

function Game.stop()
	File.saveTable( { x =position.x, y =position.y }, "savestate.luac")
	resources:unloadAll()
    Log.info("Disconnecting network")
	network:disconnect()
    Log.info("Disconnected network")
end

function Game.step()
    if updateReloading() then 
        return
    end

    gl.glClearColor(1,0.7,1,0)
    gl.glClear(gl.GL_COLOR_BUFFER_BIT)
    gl.glViewport(0,0,C.gGame.screen.width,C.gGame.screen.height)
    gl.glEnable(gl.GL_BLEND)
    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)

    if Game.paused then 
        return;
    end

	network:receive()

   	renderer:addFrame(atlas.pixel,   vec2(100, 100), vec2(256,256) , 0xaaFFFF00)
	renderer:addFrame(atlas.orange,  vec2(100, 100), vec2(128,128) , 0xFF000000)
   	renderer:addFrame(atlas.banana2, vec2(200, 100), vec2(128,128) , 0xFFFFFFFF)
   	rotation = rotation - 0.1

    renderer:addFrameTransform(atlas.banana2, 
    						   vec2(position.x, position.y), 
    						   vec2(256, 256), 
    						   0xFFFFFFFF,
    					       vec2(128, 128), 
    					       rotation, 
    					       true)

    local msg = "Hello there young padowan!\n  --Dance\n\t  --Dance"

    local consola = font:find("consola")
    local size    = vec2(50,50) * consola:measure(msg);
    local pos     = vec2( (Screen.width - size.x) / 2, Screen.height - size.y)


    renderer:addText(consola, 
    				 msg,
                     pos,
    				 0xFFAA2266, 
    				 vec2(50, 50), 
    				 vec2(0.25, 0.6))

    renderer:draw()
 

    network:sendMessage(NetOut.testMessageA, { a = 5, b = 103})
	network:send()
end

function Input.onDown(id, x, y)
	position = vec2(x, y)
end