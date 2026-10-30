local function assert_sdl(value)
    if not value then
        error(string.from_cstr(SDL.GetError()), 2)
    end
    return value
end

local baseDir = PlaygroundScript:gsub("\\", "/"):match("^(.*)/[^/]+$") or "."
package.path = baseDir .. "/?.lua;" .. baseDir .. "/../?.lua;" .. package.path

local presentation = require("presentation")
local playerAI = require("player_ai")
local levels = require("levels")
local Random = require("random")

-- Set BREAKOUT_AI=0 for manual control, or BREAKOUT_UNRESTRICTED=1 for full-speed rendering and simulation.
local aiEnabled = os.getenv("BREAKOUT_AI") ~= "0"
local unrestricted = os.getenv("BREAKOUT_UNRESTRICTED") == "1"

local WIDTH, HEIGHT = 640, 480
local BRICK_WIDTH, BRICK_HEIGHT = 60, 20
local PADDLE_SPEED, PADDLE_Y, PADDLE_HEIGHT = 400, 450, 20
local BALL_RADIUS, POWERUP_SPEED = 7.5, 150

local frames, time, accumulator = 0, 0, 0
local game = { ball = {}, bricks = {}, powerUps = {} }
local effects, trail = {}, {}
local leftDown, rightDown = false, false

local function playBlockHitSound(steel, nextCombo)
    -- Match the same 1..8 multiplier progression used by the game's combo heat.
    local heat = math.min(8, 1 + math.floor(math.max(0, nextCombo or game.combo or 0) / 3))
    presentation.playSound((steel and "steelHot" or "brickHot") .. heat)
end

local STEP = 1 / 120
local COMBO_WINDOW = 2.5
local RUN_SEED = Random.normalizeSeed(os.getenv("BREAKOUT_SEED") or os.time())
local POWERUP_SEED_OFFSET = 13007
local AI_SEED_OFFSET = 65537
local powerUpRandom

local function impact(x, y, strength)
    if #effects == 8 then
        table.remove(effects, 1)
    end
    effects[#effects + 1] = { x = x, y = y, age = 0, strength = strength or 1 }
end

local function clearCombo()
    game.combo = 0
    game.comboTimer = 0
    game.multiplier = 1
    game.comboPulse = 0
end

local function resetBall()
    clearCombo()
    game.paddleWidth = 100
    game.paddleX = math.max(50, math.min(WIDTH - 50, game.paddleX))
    game.ball.x = game.paddleX
    game.ball.y = 430
    local speed = 250 + math.min(100, ((game.level or 1) - 1) * 12)
    game.ball.vx = speed
    game.ball.vy = -speed
    game.powerUps = {}
    game.ballLaunched = false
    trail = {}
end

local function startLevel(number)
    game.level = number
    game.transition = 0
    game.bricks = levels.generate(RUN_SEED, number)
    effects = {}
    resetBall()
    print("Level " .. number .. " / seed " .. RUN_SEED)
end

local function resetGame()
    powerUpRandom = Random.new(RUN_SEED + POWERUP_SEED_OFFSET)
    if aiEnabled then
        playerAI.reset(SDL, Random.new(RUN_SEED + AI_SEED_OFFSET))
    end
    game.paddleX = WIDTH / 2
    game.powerUps = {}
    game.gameOver = false
    game.gameWon = false
    game.score = 0
    game.lives = 3
    game.bestCombo = 0
    effects = {}
    accumulator = 0
    startLevel(1)
end

local function onInput(key, pressed)
    if key == SDL.Keycode.LEFT then
        leftDown = pressed
    elseif key == SDL.Keycode.RIGHT then
        rightDown = pressed
    elseif key == SDL.Keycode.SPACE and pressed and not game.gameOver and not game.gameWon and game.transition <= 0 then
        if not game.ballLaunched then
            presentation.playSound("launch")
        end
        game.ballLaunched = true
    elseif key == SDL.Keycode.R and pressed then
        resetGame()
    end
end

local function pushSyntheticKey(key)
    local e = SDL.Event()
    e.key.type = SDL.EventType.KeyDown
    e.key.keysym.sym = key
    assert_sdl(SDL.PushEvent(e) == 1)
end

local function updatePowerUps(dt)
    for i = #game.powerUps, 1, -1 do
        local p = game.powerUps[i]
        p.y = p.y + POWERUP_SPEED * dt
        if
            math.abs(p.y - PADDLE_Y) < PADDLE_HEIGHT / 2 + 10
            and math.abs(p.x - game.paddleX) < game.paddleWidth / 2 + 10
        then
            game.paddleWidth = 150
            game.paddleX = math.max(75, math.min(WIDTH - 75, game.paddleX))
            presentation.playSound("powerup")
            impact(p.x, p.y)
            table.remove(game.powerUps, i)
        elseif p.y > HEIGHT + 10 then
            table.remove(game.powerUps, i)
        end
    end
end

local function hitBrick(ball)
    for _, b in ipairs(game.bricks) do
        if
            b.health ~= 0
            and math.abs(ball.x - b.x) < BRICK_WIDTH / 2 + BALL_RADIUS
            and math.abs(ball.y - b.y) < BRICK_HEIGHT / 2 + BALL_RADIUS
        then
            local dx, dy = ball.x - b.x, ball.y - b.y
            local ox = BALL_RADIUS + BRICK_WIDTH / 2 - math.abs(dx)
            local oy = BALL_RADIUS + BRICK_HEIGHT / 2 - math.abs(dy)
            if ox < oy then
                ball.vx = -ball.vx
                ball.x = b.x + (BALL_RADIUS + BRICK_WIDTH / 2) * (dx > 0 and 1 or -1)
            else
                ball.vy = -ball.vy
                ball.y = b.y + (BALL_RADIUS + BRICK_HEIGHT / 2) * (dy > 0 and 1 or -1)
            end
            b.flash = 1

            -- Use the combo value this hit is about to produce, so the sound
            -- changes on the exact hit that raises the ball to a hotter tier.
            local nextCombo = game.combo + (b.health > 0 and 1 or 0)
            playBlockHitSound(b.health == -1, nextCombo)

            if b.health > 0 then
                b.health = b.health - 1
                game.combo = game.combo + 1
                game.comboTimer = COMBO_WINDOW
                game.multiplier = math.min(8, 1 + math.floor(game.combo / 3))
                game.bestCombo = math.max(game.bestCombo, game.combo)
                game.comboPulse = 1
                game.score = game.score + 10 * game.multiplier
                if b.health == 0 and powerUpRandom() < 0.2 and #game.powerUps < 16 then
                    game.powerUps[#game.powerUps + 1] = { x = b.x, y = b.y, kind = "widerPaddle" }
                end
            end
            impact(ball.x, ball.y, 1 + (game.multiplier - 1) * 0.25)
            break
        end
    end
end

local function update(dt)
    for i = #effects, 1, -1 do
        effects[i].age = effects[i].age + dt
        if effects[i].age >= 0.55 then
            table.remove(effects, i)
        end
    end
    for i = #trail, 1, -1 do
        trail[i].life = trail[i].life - dt * 4
        if trail[i].life <= 0 then
            table.remove(trail, i)
        end
    end
    for _, b in ipairs(game.bricks) do
        b.flash = math.max(0, b.flash - dt * 6)
    end
    game.comboPulse = math.max(0, game.comboPulse - dt * 3)
    if game.gameOver then
        return
    end
    if game.transition > 0 then
        game.transition = math.max(0, game.transition - dt)
        if game.transition == 0 then
            startLevel(game.level + 1)
        end
        return
    end
    if game.comboTimer > 0 then
        game.comboTimer = math.max(0, game.comboTimer - dt)
        if game.comboTimer == 0 then
            clearCombo()
        end
    end
    game.paddleX = game.paddleX + ((rightDown and 1 or 0) - (leftDown and 1 or 0)) * PADDLE_SPEED * dt
    game.paddleX = math.max(game.paddleWidth / 2, math.min(WIDTH - game.paddleWidth / 2, game.paddleX))

    local b = game.ball
    if not game.ballLaunched then
        b.x = game.paddleX
        return
    end

    updatePowerUps(dt)
    b.x = b.x + b.vx * dt
    b.y = b.y + b.vy * dt
    if b.x < BALL_RADIUS then
        b.vx = math.abs(b.vx)
        b.x = BALL_RADIUS
        impact(b.x, b.y)
        presentation.playSound("wall")
    elseif b.x > WIDTH - BALL_RADIUS then
        b.vx = -math.abs(b.vx)
        b.x = WIDTH - BALL_RADIUS
        impact(b.x, b.y)
        presentation.playSound("wall")
    end
    if b.y < BALL_RADIUS then
        b.vy = math.abs(b.vy)
        b.y = BALL_RADIUS
        impact(b.x, b.y)
        presentation.playSound("wall")
    end
    if b.y > HEIGHT + BALL_RADIUS then
        game.lives = game.lives - 1
        clearCombo()
        presentation.playSound("life")
        print("Ball lost! Lives left: " .. game.lives)
        if game.lives <= 0 then
            game.gameOver = true
            print("You lost! Final score: " .. game.score)
        else
            resetBall()
        end
        return
    end
    if
        b.vy > 0
        and b.y > PADDLE_Y - PADDLE_HEIGHT / 2 - BALL_RADIUS
        and b.y < PADDLE_Y
        and math.abs(b.x - game.paddleX) < game.paddleWidth / 2 + BALL_RADIUS
    then
        b.vx = math.max(-1, math.min(1, (b.x - game.paddleX) / (game.paddleWidth / 2))) * 400
        b.vy = -math.abs(b.vy)
        b.y = PADDLE_Y - PADDLE_HEIGHT / 2 - BALL_RADIUS
        impact(b.x, b.y)
        presentation.playSound("paddle")
    end

    hitBrick(b)

    local remaining = 0
    for _, brick in ipairs(game.bricks) do
        if brick.health > 0 then
            remaining = remaining + 1
        end
    end
    if remaining == 0 then
        game.transition = 1.4
        game.score = game.score + 100 * game.level
        presentation.playSound("win")
        print("Level " .. game.level .. " cleared! Score: " .. game.score)
    end

    if #trail == 16 then
        table.remove(trail, 1)
    end
    trail[#trail + 1] = { x = b.x, y = b.y, life = 1 }
end

local function run()
    presentation.open({
        width = WIDTH,
        height = HEIGHT,
        assetRoot = os.getenv("BREAKOUT_ASSET_ROOT") or baseDir,
        unrestricted = unrestricted,
        comboWindow = COMBO_WINDOW,
        paddleY = PADDLE_Y,
        paddleHeight = PADDLE_HEIGHT,
        ballRadius = BALL_RADIUS,
    })
    resetGame()

    local synthetic = os.getenv("PLAYGROUND_SYNTHETIC_INPUT") == "1"
    if synthetic then
        pushSyntheticKey(SDL.Keycode.SPACE)
    end

    local event = SDL.Event()
    local previous = SDL.GetTicks()
    local running = true
    local maxFrames = tonumber(os.getenv("PLAYGROUND_MAX_FRAMES"))

    while running and (not maxFrames or frames < maxFrames) do
        local now = SDL.GetTicks()
        local dt = math.max(0, math.min((now - previous) / 1000, 0.1))
        previous = now
        if unrestricted then
            -- Advance simulation time on every rendered frame, independent of elapsed time.
            dt = 1 / 25
        end
        time = (time + dt) % 4096
        if aiEnabled and game.transition <= 0 and not game.gameOver then
            playerAI.update(game, SDL, WIDTH, PADDLE_Y, PADDLE_HEIGHT, PADDLE_SPEED, BALL_RADIUS, dt)
        end

        while SDL.PollEvent(event) ~= 0 do
            if event.type == SDL.EventType.Quit then
                running = false
            elseif event.type == SDL.EventType.KeyDown or event.type == SDL.EventType.KeyUp then
                local pressed = event.type == SDL.EventType.KeyDown
                if event.key.keysym.sym == SDL.Keycode.ESCAPE and pressed then
                    running = false
                end
                onInput(event.key.keysym.sym, pressed)
            end
        end
        if not running then
            break
        end

        if unrestricted then
            update(dt)
        else
            accumulator = accumulator + dt
            while accumulator >= STEP do
                update(STEP)
                accumulator = accumulator - STEP
            end
        end

        presentation.draw(game, effects, trail, time)
        if not unrestricted then
            SDL.Delay(16)
        elseif WASM then
            coroutine.yield()
        end
        frames = frames + 1
        if synthetic and frames == 140 then
            pushSyntheticKey(SDL.Keycode.R)
        end
        if synthetic and frames == 141 then
            pushSyntheticKey(SDL.Keycode.SPACE)
        end
    end
end

local ok, err = xpcall(run, debug.traceback)
presentation.close()
if not ok then
    error(err, 0)
end
print("Breakout remaster exited after " .. frames .. " frames (score " .. game.score .. ", lives " .. game.lives .. ")")
