local PI = math.pi
local sqrt, sin, cos = math.sqrt, math.sin, math.cos

local function color(r, g, b, a)
    return ((a or 255) << 24) | (r << 16) | (g << 8) | b
end

-- Geometry is kept in draw order. Two float buffers avoid borrowing client pointers
-- for vertex-attribute offsets, and preserve per-vertex alpha blending.
local canvas = {positions = {}, colors = {}, count = 0}

local function beginFrame()
    canvas.positions, canvas.colors, canvas.count = {}, {}, 0
end

local function tri(x0, y0, x1, y1, x2, y2, rgba)
    local p, c, n = canvas.positions, canvas.colors, canvas.count

    local offset = n * 2
    p[offset + 1], p[offset + 2] = x0, y0
    p[offset + 3], p[offset + 4] = x1, y1
    p[offset + 5], p[offset + 6] = x2, y2

    local r = ((rgba >> 16) & 255) / 255
    local g = ((rgba >> 8) & 255) / 255
    local b = (rgba & 255) / 255
    local a = ((rgba >> 24) & 255) / 255

    offset = n * 4
    for i = 0, 2 do
        local k = offset + i * 4
        c[k + 1], c[k + 2], c[k + 3], c[k + 4] = r, g, b, a
    end

    canvas.count = n + 3
end

local function quad(ax, ay, bx, by, cx, cy, dx, dy, rgba)
    tri(ax, ay, bx, by, cx, cy, rgba)
    tri(ax, ay, cx, cy, dx, dy, rgba)
end

local function rect(x, y, width, height, rgba)
    quad(x, y, x + width, y, x + width, y + height, x, y + height, rgba)
end

local function circle(x, y, radius, rgba, segments)
    local n = segments or 28
    for i = 0, n - 1 do
        local a = 2 * PI * i / n
        local b = 2 * PI * (i + 1) / n
        tri(x, y, x + cos(a) * radius, y + sin(a) * radius,
            x + cos(b) * radius, y + sin(b) * radius, rgba)
    end
end

local function ring(x, y, inner, outer, rgba, segments)
    local n = segments or 32
    for i = 0, n - 1 do
        local a, b = 2 * PI * i / n, 2 * PI * (i + 1) / n
        local ax, ay, bx, by = cos(a), sin(a), cos(b), sin(b)
        quad(x + ax * inner, y + ay * inner, x + bx * inner, y + by * inner,
            x + bx * outer, y + by * outer, x + ax * outer, y + ay * outer, rgba)
    end
end

local function line(ax, ay, bx, by, thickness, rgba)
    local dx, dy = bx - ax, by - ay
    local length = sqrt(dx * dx + dy * dy)
    if length < 1e-4 then
        return
    end
    local nx = -dy / length * thickness * 0.5
    local ny = dx / length * thickness * 0.5
    quad(ax + nx, ay + ny, bx + nx, by + ny, bx - nx, by - ny, ax - nx, ay - ny, rgba)
end

local function star(x, y, radius, rgba)
    for i = 0, 9 do
        local a = -PI / 2 + i * PI / 5
        local b = -PI / 2 + (i + 1) * PI / 5
        local r0 = i % 2 == 0 and radius or radius * 0.45
        local r1 = (i + 1) % 2 == 0 and radius or radius * 0.45
        tri(x, y, x + cos(a) * r0, y + sin(a) * r0,
            x + cos(b) * r1, y + sin(b) * r1, rgba)
    end
end

-- Small bitmap font :D
local font = {
    A={" ### ","#   #","#   #","#####","#   #","#   #","#   #"},
    B={"#### ","#   #","#   #","#### ","#   #","#   #","#### "},
    C={" ####","#    ","#    ","#    ","#    ","#    "," ####"},
    D={"#### ","#   #","#   #","#   #","#   #","#   #","#### "},
    E={"#####","#    ","#    ","#### ","#    ","#    ","#####"},
    F={"#####","#    ","#    ","#### ","#    ","#    ","#    "},
    G={" ####","#    ","#    ","# ###","#   #","#   #"," ####"},
    H={"#   #","#   #","#   #","#####","#   #","#   #","#   #"},
    I={"#####","  #  ","  #  ","  #  ","  #  ","  #  ","#####"},
    J={"    #","    #","    #","    #","#   #","#   #"," ### "},
    K={"#   #","#  # ","# #  ","##   ","# #  ","#  # ","#   #"},
    L={"#    ","#    ","#    ","#    ","#    ","#    ","#####"},
    M={"#   #","## ##","# # #","# # #","#   #","#   #","#   #"},
    N={"#   #","##  #","# # #","#  ##","#   #","#   #","#   #"},
    O={" ### ","#   #","#   #","#   #","#   #","#   #"," ### "},
    P={"#### ","#   #","#   #","#### ","#    ","#    ","#    "},
    Q={" ### ","#   #","#   #","#   #","# # #","#  # "," ## #"},
    R={"#### ","#   #","#   #","#### ","# #  ","#  # ","#   #"},
    S={" ####","#    ","#    "," ### ","    #","    #","#### "},
    T={"#####","  #  ","  #  ","  #  ","  #  ","  #  ","  #  "},
    U={"#   #","#   #","#   #","#   #","#   #","#   #"," ### "},
    V={"#   #","#   #","#   #","#   #","#   #"," # # ","  #  "},
    W={"#   #","#   #","# # #","# # #","# # #","## ##","#   #"},
    X={"#   #","#   #"," # # ","  #  "," # # ","#   #","#   #"},
    Y={"#   #","#   #"," # # ","  #  ","  #  ","  #  ","  #  "},
    Z={"#####","    #","   # ","  #  "," #   ","#    ","#####"},
    ["0"]={" ### ","#   #","#  ##","# # #","##  #","#   #"," ### "},
    ["1"]={"  #  "," ##  ","  #  ","  #  ","  #  ","  #  "," ### "},
    ["2"]={" ### ","#   #","    #","   # ","  #  "," #   ","#####"},
    ["3"]={"#####","   # ","  #  ","   # ","    #","#   #"," ### "},
    ["4"]={"   # ","  ## "," # # ","#  # ","#####","   # ","   # "},
    ["5"]={"#####","#    ","#### ","    #","    #","#   #"," ### "},
    ["6"]={"  ## "," #   ","#    ","#### ","#   #","#   #"," ### "},
    ["7"]={"#####","    #","   # ","  #  "," #   "," #   "," #   "},
    ["8"]={" ### ","#   #","#   #"," ### ","#   #","#   #"," ### "},
    ["9"]={" ### ","#   #","#   #"," ####","    #","   # "," ### "},
    [":"]={"     ","  #  ","     ","     ","  #  ","     ","     "},
    ["-"]={"     ","     ","     ","#####","     ","     ","     "},
    ["."]={"     ","     ","     ","     ","     ","  #  ","     "},
    ["!"]={"  #  ","  #  ","  #  ","  #  ","  #  ","     ","  #  "},
    ["/"]={"    #","    #","   # ","  #  "," #   ","#    ","#    "},
    ["?"]={" ### ","#   #","    #","   # ","  #  ","     ","  #  "},
    ["+"]={"     ","  #  ","  #  ","#####","  #  ","  #  ","     "},
    [","]={"     ","     ","     ","     ","  #  ","  #  "," #   "}
}

local function text(x, y, scale, value, rgba)
    value = value:upper()
    for i = 1, #value do
        local rows = font[value:sub(i, i)]
        if rows then
            for row = 1, 7 do
                for column = 1, 5 do
                    if rows[row]:sub(column, column) == "#" then
                        rect(x + (column - 1) * scale, y + (row - 1) * scale, scale, scale, rgba)
                    end
                end
            end
        end
        x = x + 6 * scale
    end
end

local function textCentered(cx, y, scale, value, rgba)
    text(cx - (#value * 6 - 1) * scale / 2, y, scale, value, rgba)
end

local function textRight(rx, y, scale, value, rgba)
    text(rx - (#value * 6 - 1) * scale, y, scale, value, rgba)
end

canvas.beginFrame = beginFrame
canvas.color = color
canvas.tri = tri
canvas.quad = quad
canvas.rect = rect
canvas.circle = circle
canvas.ring = ring
canvas.line = line
canvas.star = star
canvas.text = text
canvas.textCentered = textCentered
canvas.textRight = textRight
return canvas
