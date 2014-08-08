--Game.renderer

local atlas
local position
local rotation
local network
local font
local bolder
local gui

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
    end

    Log.info("Got here")


	global.renderer = CRenderer(1024)
	atlas     = resources:load(R.Atlas)
	font	  = resources:load(R.Fonts)

    gui = GUI(renderer, font, atlas.pixel)


	bolder    = atlas.boulder;
	position  = { x= 100, y= 100 }
	rotation  = 0
	Screen.setOrientation(ORIENTATION_LANDSCAPE)

	network   = Network(0xFFFF, Game.server, onConnect, onDisconnect)
    network:asyncConnect(onConnect)
end

function Entry:restart()
	Game:start(true)
	position = File.loadTable("savestate.luac")
end

function Entry:stop()
	File.saveTable( { x =position.x, y =position.y }, "savestate.luac")
	resources:unloadAll()
	network:disconnect()
    stack:stop()
    Log.info("Stopped!")
end

local toggled = false
local vslideval = 50


function Entry:step()
    updateTime()
    if updateReloading() then 
        return
    end

    gl.glClearColor(1,0.7,1,0)
    gl.glClear(gl.GL_COLOR_BUFFER_BIT)
    gl.glViewport(0,0,Screen.width,Screen.height)
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

    renderer:addFrame(atlas.banana, vec2(0,0),vec2(100,100), 0xFFFFFFFF)
    renderer:addFrame(atlas.banana2, vec2(100,0),vec2(100,100), 0xFFFFFFFF)
    renderer:addFrame(atlas.base_tower, vec2(200,0),vec2(100,100), 0xFFFFFFFF)
    renderer:addFrame(atlas.orange, vec2(300,0),vec2(100,100), 0xFFFFFFFF)
    renderer:addFrame(atlas.teddy, vec2(400,0),vec2(100,100), 0xFFFFFFFF)
    renderer:addFrame(atlas.baws, vec2(500,0),vec2(100,100), 0xFFFFFFFF)
    renderer:addFrame(atlas.clock_base, vec2(600,0),vec2(100,100), 0xFFFFFFFF)
    renderer:addFrame(atlas.pixel, vec2(700,0),vec2(100,100), 0xFFFFFFFF)
    renderer:addFrame(atlas.boulder, vec2(0,100),vec2(100,100), 0xFFFFFFFF)

    gui:button(vec2(200, 300), vec2(120, 64), "Hello\nthar")
    gui:textBox(vec2(400, 300), vec2(120, 30), nil, "Name here")
    gui:textBox(vec2(400, 250), vec2(120, 30), "text here", "Name here")

    local vval = gui:slider(vec2(200, 400), vec2(300,32), vslideval)
    if vval ~= vslideval then 
        vslideval = vval
        Log.infof("Slider value changed! %f", vval)
    end

    gui:slider(vec2(720, 200), vec2(35, 300), vslideval)

    local res = gui:toggle(vec2(0,250), vec2(64,64), toggled)
    if res ~= toggled then 
        toggled = res
        Log.info("Toggle state changed!")
        Input.showKeyboard()
    end

    stack:update()
    stack:render()



    renderer:draw()
 
    network:sendMessage(NetOut.testMessageA, { a = 5, b = 103, d = 4})


	network:send()

    if #callbacks > 0 then 
        for i, v in ipairs(callbacks) do
            v()
        end
        callbacks = { }
    end

    Input.clear()
end

global.callbacks = { }

Type.define(Entry, "Entry")
Log.infof("Type = %s", Type.Entry)
setmetatable(Game, Type.Entry) -- Simple isntit?

global.config = 
{ 
    name = "impact", 
    color = 0xFF000000, 
    size = 50, 
    tresh = vec2(0.35, 0.65), 
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

function Input.onBackButton( ... )
    if Input.keyboardVisible then 
        Log.info("Hiding keyboard!")
        Input.hideKeyboard()
    end

    return true
end