local M = {}

function M.normalizeSeed(value)
    local n = tonumber(value) or 1
    if n ~= n or n == math.huge or n == -math.huge then
        n = 1
    end
    return (math.floor(math.abs(n)) - 1) % 2147483646 + 1
end

function M.new(seed)
    local state = M.normalizeSeed(seed)
    return function(minimum, maximum)
        state = (state * 16807) % 2147483647
        local value = state / 2147483647
        if minimum == nil then
            return value
        end
        return minimum + math.floor(value * (maximum - minimum + 1))
    end
end

return M
