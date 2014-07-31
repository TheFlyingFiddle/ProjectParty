--Game.renderer

local atlas
local position
local rotation
local network
local font
local bolder;

local function onMsg(msg)
end

local function onConnect()
    config.msg = "Connected!"
end

local function onDisconnect()
    config.msg = "Disconnected!"
end

local Entry = { }

function Entry:start(restart)
	Log.info("Starting!")

    if restart then 
        global.stack   = Type.restart("ScreenStack")
    else
        global.stack    = ScreenStack()
        stack:push(Test({x = 100, y = 100}, "This is \nsome text!"))
        stack:push(Test({x = 100, y = 100}, "This is \nother text!"))
    end

    Log.info("Got here")

	global.renderer = CRenderer(128)
	atlas     = resources:load(R.Atlas)
	font	  = resources:load(R.Fonts)
	bolder    = atlas.boulder;
	position  = { x= 100, y= 100 }
	rotation  = 0
	Screen.setOrientation(Orientation.landscape)

	network   = Network(0xFFFF, Game.server, onConnect, onDisconnect)
    network:asyncConnect(onConnect)
end

function Entry:restart()
	Game:start(true)
	position = File.loadTable("savestate.luac")
	Screen.setOrientation(Orientation.landscape)
end

function Entry:stop()
	File.saveTable( { x =position.x, y =position.y }, "savestate.luac")
	resources:unloadAll()
	network:disconnect()
    stack:stop()
    Log.info("Stopped!")
end

function Entry:step()
    updateTime()
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

    local consola = font:find(config.name)
    local size    = vec2(config.size, config.size) * consola:measure(config.msg);
    local pos     = vec2( (Screen.width - size.x) / 2, Screen.height - size.y)


    renderer:addText(consola, 
    				 config.msg,
                     pos,
    				 config.color, 
    				 vec2(config.size, config.size), 
    				 config.tresh)

    stack:update()
    stack:render()


    renderer:draw()
 
    network:sendMessage(NetOut.testMessageA, { a = 5, b = 103})


	network:send()

    if #callbacks > 0 then 
        for i, v in ipairs(callbacks) do
            v()
        end
        callbacks = { }
    end
end

global.callbacks = { }

Type.define(Entry, "Entry")
Log.infof("Type = %s", Type.Entry)
setmetatable(Game, Type.Entry) -- Simple isntit?

global.config = 
{ 
    name = "consola", 
    color = 0xFF000000, 
    size = 50, 
    tresh = vec2(0.2, 0.65), 
    msg = "Hello there young padowan!\n  --Dance\n\t  --Dance" 
}

function Input.onMenuButton()
    stack:onMenuButton()
end

function Input.onUp( ... )
    stack:onUp(...)
end

function Input.onDown( ... )
    stack:onDown(...)
end

function Input.onCancel( ... )
    stack:onCancel(...)
end

function Input.onMove( ... )
    stack:onMove(...)
end