local function assert_sdl(value)
    if not value then error(string.from_cstr(SDL.GetError()), 2) end
    return value
end

local baseDir = PlaygroundScript:gsub('\\', '/'):match('^(.*)/[^/]+$') or '.'
package.path = baseDir .. '/?.lua;' .. baseDir .. '/../?.lua;' .. package.path

local Game = require('game')
local graphics = require('graphics')
local input = require('input')

local W, H, DT = Game.WIDTH, Game.HEIGHT, Game.STEP
local min = math.min
local game = Game.new()
local frames = 0

local function run()
    assert_sdl(SDL.Init(SDL.InitFlag.Video) == 0)
    graphics.open()

    game:loadLevel(1)

    local app = {
        width=W,
        height=H,
        active=true,
        minimized=false,
        dragging=false,
        running=true,
        resetClock=false,
        previous=SDL.GetTicks(),
        accumulator=0
    }

    local synthetic = os.getenv("PLAYGROUND_SYNTHETIC_INPUT") == "1"
    if synthetic then
        input.pushMouse(SDL.EventType.MouseButtonDown, 460, 125)
        input.pushMouse(SDL.EventType.MouseMotion, 500, 125)
        input.pushMouse(SDL.EventType.MouseButtonUp, 500, 125)
    end

    local maxFrames = tonumber(os.getenv("PLAYGROUND_MAX_FRAMES"))
    local event = SDL.Event()
    while app.running and (not maxFrames or frames < maxFrames) do
        input.poll(app, game, event)
        if not app.running then
            break
        end
        if not app.active or app.minimized then
            app.accumulator = 0
            app.resetClock = true
            SDL.Delay(16)
        else
            local now = SDL.GetTicks()
            local elapsed = (now - app.previous) / 1000
            app.previous = now
            if app.resetClock then
                elapsed, app.accumulator, app.resetClock = 0, 0, false
            end
            app.accumulator = app.accumulator + min(elapsed, 0.1)
            while app.accumulator >= DT do
                game:step(DT)
                app.accumulator = app.accumulator - DT
            end

            graphics.draw(game)
            graphics.present(app.width, app.height)

            SDL.Delay(1)
            frames = frames + 1

            if synthetic and game.level == 1 and game.state == "won" then
                input.pushKey(SDL.Keycode.N)
            end
        end
    end
end

local ok, err = xpcall(run, debug.traceback)
graphics.close()
SDL.Quit()

if not ok then error(err, 0) end
print('Rope playground exited after ' .. frames .. ' frames on level ' .. game.level)
