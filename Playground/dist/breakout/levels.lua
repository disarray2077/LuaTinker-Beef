local Random = require("random")
local M = {}

function M.generate(seed, level)
    local state = (seed + (level % 1000000) * 104729) % 2147483646 + 1
    local random = Random.new(state)

    local style = math.floor(random() * 4)
    local rows = math.min(4, 2 + math.floor((level + 1) / 2))
    local maxHealth = math.min(3, 1 + math.floor(level / 3))
    local bricks = {}

    for row = 1, rows do
        for column = 1, 5 do
            local distance = 5 - column
            local pattern = style == 0
                or (style == 1 and distance <= row + 1)
                or (style == 2 and (row + distance) % 2 == 0)
                or (style == 3 and (row == 1 or row == rows or distance >= 3))

            -- Bottom central pair is always present: never an empty level.
            local occupied = (pattern and random() > 0.12) or (row == rows and column == 4)
            if occupied then
                local health = 1 + math.floor(random() * maxHealth)
                local function add(c)
                    bricks[#bricks + 1] = { x = 60 + (c - 1) * 65, y = 65 + (row - 1) * 29, health = health, flash = 0 }
                end
                add(column)
                if column ~= 5 then
                    add(10 - column)
                end
            end
        end
    end

    assert(#bricks > 0 and #bricks <= 36, "Generated level exceeds renderer capacity")
    return bricks
end

return M
