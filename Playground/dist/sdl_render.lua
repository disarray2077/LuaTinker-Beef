local function assert_sdl(value)
    if not value then
        error(string.from_cstr(SDL.GetError()), 2)
    end
    return value
end

assert_sdl(SDL.Init(SDL.InitFlag.Video) == 0)

local window
local renderer
local frames = 0

local function run()
    window = assert_sdl(SDL.CreateWindow("LuaTinker Playground", SDL.WindowPos.Centered, SDL.WindowPos.Centered,
        640, 480, SDL.WindowFlags.Shown))
    renderer = assert_sdl(SDL.CreateRenderer(window, -1, SDL.RendererFlags.Software))

    local event = SDL.Event()
    local rect = SDL.Rect(296, 216, 48, 48)
    local border = SDL.Rect(40, 40, 560, 400)

    local left, right = false, false
    local running = true

    local previous = SDL.GetTicks()

    -- Useful for running the same program with SDL_VIDEODRIVER=dummy.
    local max_frames = tonumber(os.getenv("PLAYGROUND_MAX_FRAMES"))

    while running and (not max_frames or frames < max_frames) do
        while SDL.PollEvent(event) ~= 0 do
            if event.type == SDL.EventType.Quit then
                running = false
            elseif event.type == SDL.EventType.KeyDown or event.type == SDL.EventType.KeyUp then
                local key = event.key.keysym.sym
                local down = event.type == SDL.EventType.KeyDown
                if key == SDL.Keycode.ESCAPE and down then running = false end
                if key == SDL.Keycode.LEFT then left = down end
                if key == SDL.Keycode.RIGHT then right = down end
            end
        end

        local now = SDL.GetTicks()
        local dt = (now - previous) / 1000
        previous = now
        if left then rect.x = rect.x - math.floor(280 * dt + 0.5) end
        if right then rect.x = rect.x + math.floor(280 * dt + 0.5) end
        rect.x = math.max(0, math.min(640 - rect.w, rect.x))

        assert_sdl(SDL.SetRenderDrawColor(renderer, 18, 22, 33, 255) == 0)
        assert_sdl(SDL.RenderClear(renderer) == 0)
        assert_sdl(SDL.SetRenderDrawColor(renderer, 62, 83, 109, 255) == 0)
        assert_sdl(SDL.RenderDrawRect(renderer, border) == 0)
        assert_sdl(SDL.RenderDrawLine(renderer, 40, 400, 600, 400) == 0)
        assert_sdl(SDL.SetRenderDrawColor(renderer, 245, 180, 70, 255) == 0)
        assert_sdl(SDL.RenderFillRect(renderer, rect) == 0)

        SDL.RenderPresent(renderer)
        SDL.Delay(16)

        frames = frames + 1
    end
end

local ok, err = xpcall(run, debug.traceback)
if renderer then SDL.DestroyRenderer(renderer) end
if window then SDL.DestroyWindow(window) end

SDL.Quit()

if not ok then error(err) end
print("Playground exited after " .. frames .. " frames")
