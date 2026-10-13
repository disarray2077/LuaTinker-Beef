local AI = {}

local leftHeld = false
local rightHeld = false

local wobblePhase = 0
local nextWobbleChange = 0
local wobbleAmount = 0
local launchTimer = 0
local hitOffset = 0
local previousVy = 0
local random

local function pushKey(SDL, key, pressed)
    local event = SDL.Event()
    event.key.type = pressed and SDL.EventType.KeyDown or SDL.EventType.KeyUp
    event.key.keysym.sym = key

    if SDL.PushEvent(event) ~= 1 then
        error(string.from_cstr(SDL.GetError()))
    end
end

local function setLeft(SDL, pressed)
    if leftHeld ~= pressed then
        leftHeld = pressed
        pushKey(SDL, SDL.Keycode.LEFT, pressed)
    end
end

local function setRight(SDL, pressed)
    if rightHeld ~= pressed then
        rightHeld = pressed
        pushKey(SDL, SDL.Keycode.RIGHT, pressed)
    end
end

local function move(SDL, direction)
    if direction < 0 then
        setRight(SDL, false)
        setLeft(SDL, true)
    elseif direction > 0 then
        setLeft(SDL, false)
        setRight(SDL, true)
    else
        setLeft(SDL, false)
        setRight(SDL, false)
    end
end

local function reflectX(x, width, radius)
    local left = radius
    local right = width - radius
    local range = right - left
    local period = range * 2

    x = (x - left) % period

    if x > range then
        x = period - x
    end

    return left + x
end

local function predictLandingX(game, width, paddleY, paddleHeight, ballRadius)
    local ball = game.ball

    if ball.vy <= 0 then
        return ball.x, math.huge
    end

    local collisionY = paddleY - paddleHeight / 2 - ballRadius
    local distanceY = collisionY - ball.y

    if distanceY <= 0 then
        return ball.x, 0
    end

    local time = distanceY / ball.vy
    local rawX = ball.x + ball.vx * time

    return reflectX(rawX, width, ballRadius), time
end

local function chooseDirection(paddleX, targetX, deadZone)
    local difference = targetX - paddleX

    if difference < -deadZone then
        return -1
    elseif difference > deadZone then
        return 1
    end

    return 0
end

local function chooseHitOffset(game)
    local halfWidth = game.paddleWidth / 2

    -- Leave room at the paddle edges for timing inaccuracies.
    local usable = halfWidth * 0.70

    hitOffset = -usable + random() * (usable * 2)
end

function AI.reset(SDL, randomGenerator)
    move(SDL, 0)
    random = randomGenerator
    wobblePhase = 0
    nextWobbleChange = 0
    wobbleAmount = 0
    launchTimer = 0
    hitOffset = 0
    previousVy = 0
end

function AI.update(game, SDL, width, paddleY, paddleHeight, paddleSpeed, ballRadius, dt)
    if game.gameOver or game.gameWon then
        move(SDL, 0)
        return
    end

    wobblePhase = wobblePhase + dt

    -- Launch after a short randomized delay.
    if not game.ballLaunched then
        move(SDL, 0)

        launchTimer = launchTimer - dt

        if launchTimer <= 0 then
            pushKey(SDL, SDL.Keycode.SPACE, true)
            pushKey(SDL, SDL.Keycode.SPACE, false)
            launchTimer = 0.15 + random() * 0.5
        end

        previousVy = game.ball.vy
        return
    end

    local ball = game.ball

    -- Choose one hit position for each descent.
    if ball.vy > 0 and previousVy <= 0 then
        chooseHitOffset(game)
    end

    previousVy = ball.vy

    -- Wander while the ball is rising.
    if ball.vy < 0 then
        nextWobbleChange = nextWobbleChange - dt

        if nextWobbleChange <= 0 then
            nextWobbleChange = 0.12 + random() * 0.35
            wobbleAmount = random(-110, 110)
        end

        local sway = math.sin(wobblePhase * 5.5) * 55
        local target = ball.x + wobbleAmount + sway
        target = math.max(game.paddleWidth / 2, math.min(width - game.paddleWidth / 2, target))
        move(SDL, chooseDirection(game.paddleX, target, 12))

        return
    end

    -- Predict the landing position, accounting for wall bounces.
    local landingX, timeToImpact = predictLandingX(game, width, paddleY, paddleHeight, ballRadius)

    -- Offset the paddle center so the ball lands at the chosen hit position.
    local desiredPaddleX = landingX - hitOffset

    -- Keep the full paddle on screen.
    local halfWidth = game.paddleWidth / 2
    desiredPaddleX = math.max(halfWidth, math.min(width - halfWidth, desiredPaddleX))

    -- Reserve enough travel distance to reach the target before impact.
    local reachableDistance = paddleSpeed * timeToImpact
    local distanceToTarget = math.abs(desiredPaddleX - game.paddleX)

    local safetyMargin = 90
    local mustRecover = distanceToTarget + safetyMargin >= reachableDistance
    local finalApproach = timeToImpact < 0.45

    if mustRecover or finalApproach then
        -- Move directly to the target when time or travel distance is limited.
        move(SDL, chooseDirection(game.paddleX, desiredPaddleX, 2))
    else
        -- Add wobble only within the remaining travel margin.
        local maxSafeWobble = math.max(0, reachableDistance - distanceToTarget - safetyMargin)
        maxSafeWobble = math.min(maxSafeWobble, 80)

        local drunkOffset = math.sin(wobblePhase * 7.0) * maxSafeWobble
        local fakeTarget = desiredPaddleX + drunkOffset
        fakeTarget = math.max(halfWidth, math.min(width - halfWidth, fakeTarget))

        move(SDL, chooseDirection(game.paddleX, fakeTarget, 8))
    end
end

function AI.shutdown(SDL)
    move(SDL, 0)
end

return AI
