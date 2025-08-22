-- Game constants
PADDLE_SPEED = 400
PADDLE_HEIGHT = 20

BALL_RADIUS = 7.5

BRICK_WIDTH = 60
BRICK_HEIGHT = 20

POWERUP_SPEED = 150

function init()
    game:Reset()
    
    -- Health: -1 = unbreakable, 1 = 1-hit, 2 = 2-hit, etc.
    local level = {
        { -1, -1, 2, 2, 2, 2, 2, -1, -1 },
        { -1, 1, 1, 1, 1, 1, 1, 1, -1 },
        { 0, 1, 2, 1, 2, 1, 2, 1, 0 },
        { 0, 0, 1, 1, 1, 1, 1, 0, 0 }
    }

    game.Bricks:Clear()
    game.PowerUps:Clear()
    for r, row in ipairs(level) do
        for c, health in ipairs(row) do
            if health ~= 0 then
                local x = 40 + (c - 1) * (BRICK_WIDTH + 5)
                local y = 50 + (r - 1) * (BRICK_HEIGHT + 5)
                game.Bricks:Add(Brick(x, y, health))
            end
        end
    end

    game:ResetBall(game.PaddleX)
end

-- Input state
local key_left_down = false
local key_right_down = false

function on_input(key, is_down)
    if key == Keycode.LEFT then
        key_left_down = is_down
    elseif key == Keycode.RIGHT then
        key_right_down = is_down
    elseif key == Keycode.SPACE and is_down and not game.BallIsLaunched then
        game.BallIsLaunched = true
        game:PlaySound("launch")
    elseif key == Keycode.R and is_down then
        init()
    end
end

function update(dt)
    if game.GameOver or game.GameWon then return end

    -- Paddle movement
    if key_left_down then
        game.PaddleX = game.PaddleX - PADDLE_SPEED * dt
    end
    if key_right_down then
        game.PaddleX = game.PaddleX + PADDLE_SPEED * dt
    end
    -- Clamp paddle to screen, using the variable paddle width
    game.PaddleX = math.max(game.PaddleWidth / 2, math.min(640 - game.PaddleWidth / 2, game.PaddleX))

    -- If ball isn't launched, it follows the paddle
    if not game.BallIsLaunched then
        game.Ball.X = game.PaddleX
        return
    end

    -- Iterate backwards so we can safely remove items
    for i = game.PowerUps.Count - 1, 0, -1 do
        local p = game.PowerUps[i]
        p.Y = p.Y + POWERUP_SPEED * dt

        -- Check collision with paddle
        if p.Y > 440 and p.Y < 460 and
           p.X > game.PaddleX - game.PaddleWidth / 2 and
           p.X < game.PaddleX + game.PaddleWidth / 2 then
            
            -- Apply power-up effect
            if p.Type == PowerUpType.WiderPaddle then
                game.PaddleWidth = 150
                game:PlaySound("powerup")
            end
            
            game.PowerUps:RemoveAt(i)
        elseif p.Y > 480 then
            game.PowerUps:RemoveAt(i) -- Remove if it goes off-screen
        else
            game.PowerUps[i] = p -- 'PowerUp' is a value type, so it needs to be updated
        end
    end

    -- Ball movement
    game.Ball.X = game.Ball.X + game.Ball.VelX * dt
    game.Ball.Y = game.Ball.Y + game.Ball.VelY * dt

    if game.Ball.X < BALL_RADIUS then
        game.Ball.VelX = -game.Ball.VelX
        game.Ball.X = BALL_RADIUS -- Clamp position to prevent sticking
        game:PlaySound("wall_hit")
    elseif game.Ball.X > 640 - BALL_RADIUS then
        game.Ball.VelX = -game.Ball.VelX
        game.Ball.X = 640 - BALL_RADIUS -- Clamp position to prevent sticking
        game:PlaySound("wall_hit")
    end

    if game.Ball.Y < BALL_RADIUS then
        game.Ball.VelY = -game.Ball.VelY
        game.Ball.Y = BALL_RADIUS -- Clamp position to prevent sticking
        game:PlaySound("wall_hit")
    end
    
    if game.Ball.Y > 480 then
        game.Lives = game.Lives - 1
        game:OnBallLost()
        game:PlaySound("lose_life")
        if game.Lives <= 0 then
            game.GameOver = true
            game:OnGameOver()
        else
            game:ResetBall(game.PaddleX)
        end
        return
    end

    -- Paddle collision
    local paddle_y = 450
    if game.Ball.Y > paddle_y - PADDLE_HEIGHT / 2 - BALL_RADIUS and
       game.Ball.Y < paddle_y and
       game.Ball.X > game.PaddleX - game.PaddleWidth / 2 and
       game.Ball.X < game.PaddleX + game.PaddleWidth / 2 and
       game.Ball.VelY > 0 then
        
        local hit_pos = (game.Ball.X - game.PaddleX) / (game.PaddleWidth / 2)
        game.Ball.VelX = hit_pos * 400
        game.Ball.VelY = -game.Ball.VelY
        game:PlaySound("paddle_hit")
    end

    -- Brick collision loop
    for i = 0, game.Bricks.Count - 1 do
        local brick = game.Bricks[i]
        if brick.Health ~= 0 then -- if brick is not already broken
            -- AABB collision check
            if game.Ball.X > brick.X - BRICK_WIDTH / 2 - BALL_RADIUS and
               game.Ball.X < brick.X + BRICK_WIDTH / 2 + BALL_RADIUS and
               game.Ball.Y > brick.Y - BRICK_HEIGHT / 2 - BALL_RADIUS and
               game.Ball.Y < brick.Y + BRICK_HEIGHT / 2 + BALL_RADIUS then
                
                -- Calculate the distance from the ball's center to the brick's center
                local diff_x = game.Ball.X - brick.X
                local diff_y = game.Ball.Y - brick.Y
                -- Calculate the combined half-widths of the ball and brick
                local combined_half_width = BALL_RADIUS + BRICK_WIDTH / 2
                local combined_half_height = BALL_RADIUS + BRICK_HEIGHT / 2
                -- Calculate how much the ball is overlapping the brick on each axis
                local overlap_x = combined_half_width - math.abs(diff_x)
                local overlap_y = combined_half_height - math.abs(diff_y)

                -- The axis with the *smaller* overlap is the axis of collision.
                if overlap_x < overlap_y then
                    game.Ball.VelX = -game.Ball.VelX
                    local sign = (diff_x > 0) and 1 or -1
                    game.Ball.X = brick.X + (combined_half_width * sign)
                else
                    game.Ball.VelY = -game.Ball.VelY
                    local sign = (diff_y > 0) and 1 or -1
                    game.Ball.Y = brick.Y + (combined_half_height * sign)
                end

                if brick.Health > 0 then
                    brick.Health = brick.Health - 1
                    game.Score = game.Score + 10

                    if brick.Health == 0 then
                        game:OnBrickBreak()
                        if math.random() < 0.2 then
                            game.PowerUps:Add(PowerUp(brick.X, brick.Y, PowerUpType.WiderPaddle))
                        elseif math.random() < 0.1 then
                            game.PowerUps:Add(PowerUp(brick.X, brick.Y, PowerUpType.MultiBall))
                        end
                        game:PlaySound("brick_break")
                    else
                        game:PlaySound("brick_hit")
                    end
                else -- It's an unbreakable brick
                    game:PlaySound("unbreakable_hit")
                end
                
                game.Bricks[i] = brick
                break -- Handle one brick collision per frame
            end
        end
    end

    -- Count remaining bricks
    local bricks_left = 0
    for i = 0, game.Bricks.Count - 1 do
        local brick = game.Bricks[i]
        if brick.Health > 0 then
            bricks_left = bricks_left + 1
        end
    end

    if bricks_left == 0 and not game.GameWon then
        game.GameWon = true
        game:OnGameWin()
        game:PlaySound("win_game")
    end
end