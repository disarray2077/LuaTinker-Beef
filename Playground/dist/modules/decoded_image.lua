local function wrap(result, error_message)
    return setmetatable({}, {
        __index = function(_, key)
            if key == "Error" then return error_message or "" end
            if key == "Width" or key == "Height" then
                return result and result[key] or 0
            end
            if key == "SourceComp" then
                return result and result.SourceComp or StbImage.ColorComponents.Default
            end
            if key == "Data" then return result and result.Data end
        end,
        __newindex = function() error("image properties are read-only", 2) end,
    })
end

return function(path)
    local file, open_error = io.open(path, "rb")
    if not file then return wrap(nil, open_error) end
    local contents, read_error = file:read("a")
    file:close()
    if not contents then return wrap(nil, read_error) end

    local bytes = UInt8List()
    for offset = 1, #contents, 4096 do
        bytes:AddRange({contents:byte(offset, math.min(offset + 4095, #contents))})
    end
    local result = take_ownership(StbImage.ImageResult.FromMemory(
        bytes, StbImage.ColorComponents.RedGreenBlueAlpha))
    if not result.Data then return wrap(nil, "Cannot decode image " .. path) end
    return wrap(result)
end
