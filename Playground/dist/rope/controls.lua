local levels = require('levels')
local controls = {}

controls.buttons = {
    {x=644, y=10, w=144, h=44, label="RESTART", action="restart"},
    {x=800, y=10, w=144, h=44, label="QUIT", action="quit"},
    {x=380, y=330, w=200, h=44, label="RETRY", action="restart", state="lost"},
    {x=264, y=334, w=200, h=44, label="REPLAY", action="restart", state="won"},
    {x=496, y=334, w=200, h=44, action="next", state="won"}
}

for level = 1, #levels do
    controls.buttons[#controls.buttons + 1] = {
        x=644 + (level - 1) * 60, y=64, w=52, h=44,
        label=tostring(level), action="level", level=level
    }
end

function controls.visible(button, game)
    return not button.state or button.state == game.state
end

function controls.label(button, game)
    if button.action == "next" then
        return game.level < #levels and "NEXT LEVEL" or "PLAY AGAIN"
    end
    return button.label
end

function controls.press(app, game, x, y)
    for _, button in ipairs(controls.buttons) do
        if controls.visible(button, game) and x >= button.x and y >= button.y and
            x < button.x + button.w and y < button.y + button.h then
            app.dragging = false
            if button.action == "quit" then
                app.running = false
            elseif button.action == "restart" then
                game:loadLevel(game.level)
            elseif button.action == "level" then
                game:loadLevel(button.level)
            elseif button.action == "next" then
                game:loadLevel(game.level % #levels + 1)
            end
            return true
        end
    end
    return false
end

return controls
