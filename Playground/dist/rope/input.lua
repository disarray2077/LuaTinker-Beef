local function assert_sdl(value)
    if not value then error(string.from_cstr(SDL.GetError()), 2) end
    return value
end

local Game = require('game')
local levels = require('levels')
local W, H = Game.WIDTH, Game.HEIGHT
local min, max, floor = math.min, math.max, math.floor
local input = {}

local function mapMouse(x, y, width, height)
    local scale = min(width / W, height / H)
    local vw, vh = floor(W * scale), floor(H * scale)
    local left, top = floor((width - vw) / 2), height - floor((height - vh) / 2) - vh
    return (x - left) * W / max(vw, 1), (y - top) * H / max(vh, 1)
end

local function pushSyntheticMouse(kind, x, y)
    local event = SDL.Event()
    if kind == SDL.EventType.MouseMotion then
        event.motion.type = kind
        event.motion.x = x
        event.motion.y = y
    else
        event.button.type = kind
        event.button.button = 1
        event.button.x = x
        event.button.y = y
    end
    assert_sdl(SDL.PushEvent(event) == 1)
end

local function pushSyntheticKey(key)
    local event = SDL.Event()
    event.key.type = SDL.EventType.KeyDown
    event.key.keysym.sym = key
    assert_sdl(SDL.PushEvent(event) == 1)
end

function input.poll(app, game, event)
    while SDL.PollEvent(event) ~= 0 do
        local type = event.type
        if type == SDL.EventType.Quit then
            app.running = false
        elseif type == SDL.EventType.WindowEvent then
            local kind = event.window.windowEvent
            if kind == SDL.WindowEventID.Resized or kind == SDL.WindowEventID.SizeChanged then
                app.width = event.window.data1
                app.height = event.window.data2
                app.minimized = app.width <= 0 or app.height <= 0
                app.dragging = false
                app.resetClock = true
            elseif kind == SDL.WindowEventID.Minimized or kind == SDL.WindowEventID.Focus_lost then
                app.active = false
                app.dragging = false
                app.resetClock = true
            elseif kind == SDL.WindowEventID.Restored or kind == SDL.WindowEventID.FocusGained then
                app.active = true
                app.minimized = false
                app.resetClock = true
            end
        elseif type == SDL.EventType.AppDidEnterBackground then
            app.active = false
            app.dragging = false
            app.resetClock = true
        elseif type == SDL.EventType.AppDidEnterForeground then
            app.active = true
            app.resetClock = true
        elseif type == SDL.EventType.MouseButtonDown and event.button.button == 1 then
            if app.active and not app.minimized then
                local x, y = mapMouse(event.button.x, event.button.y, app.width, app.height)
                if x >= 0 and y >= 0 and x < W and y < H then
                    app.dragging = true
                    app.lastX = x
                    app.lastY = y
                    game:click(x, y)
                end
            end
        elseif type == SDL.EventType.MouseMotion and app.dragging then
            local x, y = mapMouse(event.motion.x, event.motion.y, app.width, app.height)
            game:cut(app.lastX, app.lastY, x, y)
            app.lastX = x
            app.lastY = y
        elseif type == SDL.EventType.MouseButtonUp and event.button.button == 1 then
            if app.dragging then
                local x, y = mapMouse(event.button.x, event.button.y, app.width, app.height)
                game:cut(app.lastX, app.lastY, x, y)
            end
            app.dragging = false
        elseif type == SDL.EventType.KeyDown and event.key.isRepeat == 0 then
            local key = event.key.keysym.sym
            if key == SDL.Keycode.ESCAPE then
                app.running = false
            elseif key == SDL.Keycode.R then
                game:loadLevel(game.level)
                app.dragging = false
            elseif (key == SDL.Keycode.N or key == SDL.Keycode.SPACE) and
                game.state == "won" and game.level < #levels then
                game:loadLevel(game.level + 1)
                app.dragging = false
            elseif key >= SDL.Keycode.Num1 and key <= SDL.Keycode.Num5 then
                game:loadLevel(key - SDL.Keycode.Num1 + 1)
                app.dragging = false
            end
        end
    end
end

input.pushMouse = pushSyntheticMouse
input.pushKey = pushSyntheticKey
return input
