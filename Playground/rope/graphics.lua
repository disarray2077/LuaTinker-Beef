local function assert_sdl(value)
    if not value then error(string.from_cstr(SDL.GetError()), 2) end
    return value
end

local opengl = require('modules.opengl')
local Game = require('game')
local levels = require('levels')
local canvas = require('canvas')

local PI = math.pi
local min, max, floor, sqrt, sin, cos = math.min, math.max, math.floor, math.sqrt, math.sin, math.cos
local W, H = Game.WIDTH, Game.HEIGHT
local beginFrame = canvas.beginFrame
local color = canvas.color
local tri = canvas.tri
local rect = canvas.rect
local circle = canvas.circle
local ring = canvas.ring
local line = canvas.line
local star = canvas.star
local textCentered = canvas.textCentered
local textRight = canvas.textRight
local text = canvas.text

local window, context, gl
local vertexArray, positionBuffer, colorBuffer, program
local shaders = {}
local graphics = {}

local function distance(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return sqrt(dx * dx + dy * dy)
end

local function readShader(name)
    local file = assert(io.open('shaders/' .. name, 'rb'))
    local source = file:read('*a')
    file:close()
    return assert(source)
end

local function drawFrog(game)
    local f, candy = game.frog, game.candy
    
    local open
    if game.state == "won" then
        open = 0.15
    else
        local d = candy.alive and distance(candy.x, candy.y, f.x, f.y) or 999
        open = max(0, min(1, 1 - (d - 50) / 150))
    end
    
    circle(f.x, f.y, 42, color(30,110,40), 40)
    circle(f.x, f.y, 38, color(70,170,70), 40)
    circle(f.x, f.y + 14, 22, color(150,210,120), 32)
    
    local lookX = candy.alive and candy.x - f.x or 0
    local lookY = candy.alive and candy.y - f.y or 1
    local length = sqrt(lookX * lookX + lookY * lookY)
    if length > 1e-3 then
        lookX = lookX / length
        lookY = lookY / length
    end
    
    for side = -1, 1, 2 do
        local ex, ey = f.x + 14 * side, f.y - 16
        circle(ex, ey, 10, color(255,255,255), 20)
        circle(ex + lookX * 4, ey + lookY * 4, 5, color(20,20,20), 12)
        if game.state == "lost" then line(ex - 10, ey - 14, ex + 10, ey + 10 * side, 3, color(30,90,40)) end
    end

    if game.state == "lost" then
        line(f.x - 12, f.y + 14, f.x + 12, f.y + 14, 3, color(20,60,25))
    else
        local radius = 5 + 15 * open
        circle(f.x, f.y + 10 + radius * 0.5, radius, color(40,15,25), 24)
        if open > 0.3 then
            circle(f.x, f.y + 14 + radius * 0.6, radius * 0.55, color(230,90,120), 16)
        end
    end
end

local function drawCandy(game)
    local candy = game.candy
    if not candy.alive then
        return
    end
    
    local x, y = candy.x, candy.y
    tri(x - 12, y, x - 24, y - 9, x - 24, y + 9, color(230,60,90))
    tri(x + 12, y, x + 24, y - 9, x + 24, y + 9, color(230,60,90))
    circle(x, y, candy.radius + 2, color(150,30,50))
    circle(x, y, candy.radius, color(235,70,100))
    line(x - 8, y + 8, x + 8, y - 8, 3, color(255,235,240,110))
    circle(x - 5, y - 5, 4, color(255,180,200), 12)
    if candy.inBubble then
        circle(x, y, 30, color(150,210,255,70), 36)
        ring(x, y, 27, 30, color(255,255,255,150), 36)
        circle(x - 10, y - 11, 4, color(255,255,255,200), 10)
    end
end

local function drawHUD(game)
    text(16, 14, 2, string.format("LEVEL %d/5: %s", game.level, levels[game.level].name), color(255,255,255))
    
    for i = 0, 2 do
        star(28 + i * 30, 56, 11, i < game.starsGot and color(255,215,60) or color(255,255,255,55))
    end
    
    text(112, 49, 2, string.format("BEST %d/3", game.best[game.level]), color(255,255,255,160))
    textRight(W - 16, 14, 2, "OPENGL 3.3", color(180,220,255))
    textRight(W - 16, 40, 2, "R RESTART   1-5 LEVEL   ESC QUIT", color(255,255,255,140))
    textCentered(W / 2, H - 26, 2, "DRAG TO CUT ROPES - CLICK THE BUBBLE TO POP IT", color(255,255,255,120))
    
    if game.state == "playing" then
        return
    end
    
    rect(220, 240, 520, 150, color(0,0,0,170))
    rect(220, 240, 520, 4, color(255,215,60))
    if game.state == "won" then
        textCentered(W / 2, 262, 3, "OM NOM IS HAPPY!", color(255,215,60))
        textCentered(W / 2, 304, 2, string.format("STARS: %d/3", game.starsGot), color(255,255,255))
        local instruction = game.level < #levels and "PRESS N FOR THE NEXT LEVEL" or
            "ALL LEVELS DONE! PRESS 1-5 TO REPLAY"
        textCentered(W / 2, 350, 2, instruction, color(255,255,255,200))
    else
        textCentered(W / 2, 262, 3, "OH NO! THE CANDY IS GONE", color(255,120,120))
        textCentered(W / 2, 330, 2, "PRESS R TO RETRY", color(255,255,255,200))
    end
end

local function drawGame(game)
    beginFrame()

    for i = 0, 15 do
        rect(0, i * H / 16, W, H / 16 + 1, color(22 + i, 26 + i, 46 + 2 * i))
    end

    for i = 0, 11 do
        local x, y = (i * 173 + 40) % W, (i * 97 + 60 + game.time * 6) % H
        circle(x, y, 6 + (i % 3) * 4, color(255,255,255,12), 12)
    end

    for _, spike in ipairs(game.spikes) do
        rect(spike.x, spike.y, spike.w, spike.h, color(70,70,82))
        local x = spike.x
        while x + 20 <= spike.x + spike.w + 0.5 do
            if spike.dir > 0 then
                tri(x, spike.y + spike.h, x + 20, spike.y + spike.h, x + 10, spike.y, color(200,200,212))
            else
                tri(x, spike.y, x + 20, spike.y, x + 10, spike.y + spike.h, color(200,200,212))
            end
            x = x + 20
        end
    end

    for _, h in ipairs(game.hooks) do
        if h.radius > 0 then
            local n = floor(h.radius * 2 * PI / 14)
            local dc = color(255,255,255,h.used and 35 or 110)
            for i = 0, n - 1, 2 do
                local angle = 2 * PI * i / n
                circle(h.x + cos(angle) * h.radius, h.y + sin(angle) * h.radius, 2, dc, 6)
            end
        end
        circle(h.x, h.y, 9, color(125,125,140), 16)
        circle(h.x, h.y, 5, color(55,55,68), 12)
    end

    for _, rope in ipairs(game.ropes) do
        local alpha = floor(255 * max(0, min(1, rope.fade)))
        local col, dark = color(150,100,45,alpha), color(95,60,22,alpha)
        for i = 1, #rope.points do
            local toCandy = i == #rope.points
            if toCandy and not rope.attached then break end
            local a, b = rope.points[i], rope.points[i + 1] or game.candy
            line(a.x, a.y, b.x, b.y, 5, dark)
            line(a.x, a.y, b.x, b.y, 3, col)
            if i > 1 then circle(a.x, a.y, 2.5, dark, 8) end
        end
    end

    for _, b in ipairs(game.bubbles) do
        if b.active then
            circle(b.x, b.y, b.radius, color(150,210,255,60), 32)
            ring(b.x, b.y, b.radius - 3, b.radius, color(255,255,255,140), 32)
            circle(b.x - 9, b.y - 10, 4, color(255,255,255,200), 10)
        end
    end

    for i, s in ipairs(game.stars) do
        if not s.got then
            local radius = 14 + 2 * sin(game.time * 4 + i - 1)
            star(s.x, s.y, radius + 2, color(180,130,20))
            star(s.x, s.y, radius, color(255,215,60))
            star(s.x, s.y, radius * 0.5, color(255,245,160))
        end
    end

    drawFrog(game)
    drawCandy(game)

    for i = 2, #game.trail do
        local prev, curr = game.trail[i - 1], game.trail[i]
        local alpha = floor(220 * max(0, min(1, 1 - (game.time - curr.time) / 0.3)))
        line(prev.x, prev.y, curr.x, curr.y, 3, color(255,255,255,alpha))
    end

    drawHUD(game)
end

local function compileShader(kind, source, name)
    local sources = {source .. "\0"}

    local shader = gl.CreateShader(kind)
    assert(shader ~= 0, "Cannot create " .. name .. " shader")
    shaders[#shaders + 1] = shader
    gl.ShaderSource(shader, #sources, sources, nullptr.int32)
    gl.CompileShader(shader)

    local status = ref.int32(0)
    gl.GetShader(shader, gl.ShaderParameter.CompileStatus, status)
    if status.value == 0 then
        local length = ref.int32(0)
        gl.GetShader(shader, gl.ShaderParameter.InfoLogLength, length)
        local log = StringBuilder()
        if length.value > 0 then
            gl.GetShaderInfoLog(shader, length.value, 0, log)
        end
        error(name .. " shader compilation failed: " .. tostring(log))
    end

    return shader
end

local function setupGraphics()
    local attr = SDL.SDL_GLAttr
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_MAJOR_VERSION, int32.cast(3)) == 0)
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_MINOR_VERSION, int32.cast(WASM and 0 or 3)) == 0)
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_PROFILE_MASK,
        WASM and SDL.SDL_GLProfile.GL_CONTEXT_PROFILE_ES or SDL.SDL_GLProfile.GL_CONTEXT_PROFILE_CORE) == 0)

    local flags = SDL.WindowFlags.OpenGL | SDL.WindowFlags.Shown
    -- SDL's resizable-window size probe can round the size down to zero :(
    if not WASM then flags = flags | SDL.WindowFlags.Resizable end
    
    window = assert_sdl(SDL.CreateWindow("Rope Puzzle", SDL.WindowPos.Centered, SDL.WindowPos.Centered,
        W, H, flags))
    context = SDL.GL_CreateContext(window)
    assert_sdl(context ~= 0)
    assert_sdl(SDL.GL_MakeCurrent(window, context) == 0)

    gl = BeefGL.GL
    gl.Init(function(proc)
        return SDL.GL_GetProcAddress(proc)
    end)
    local missing = opengl.GetMissingRequiredFunction()
    assert(missing == "", "Missing required OpenGL entry point: " .. missing)

    local glsl = WASM and "#version 300 es\n" or "#version 330 core\n"
    local vs = glsl .. readShader('scene.vert')
    local fs = glsl .. (WASM and "precision highp float;\n" or "") .. readShader('scene.frag')
    local vertex = compileShader(gl.ShaderType.VertexShader, vs, "vertex")
    local fragment = compileShader(gl.ShaderType.FragmentShader, fs, "fragment")
    
    program = gl.CreateProgram()
    assert(program ~= 0, "Cannot create shader program")
    gl.AttachShader(program, vertex)
    gl.AttachShader(program, fragment)
    gl.LinkProgram(program)
    
    local status = ref.int32(0)
    gl.GetProgram(program, gl.GetProgramParameterName.LinkStatus, status)
    if status.value == 0 then
        local length = ref.int32(0)
        gl.GetProgram(program, gl.GetProgramParameterName.InfoLogLength, length)
        local log = StringBuilder()
        if length.value > 0 then
            gl.GetProgramInfoLog(program, length.value, 0, log)
        end
        error("shader program linking failed: " .. tostring(log))
    end

    gl.UseProgram(program)

    local sizeLocation = gl.GetUniformLocation(program, "uWorldSize")
    assert(sizeLocation >= 0, "shader is missing world size uniform")
    gl.Uniform2(sizeLocation, float.cast(W), H)

    local vaoId, positionId, colorId = ref.uint32(0), ref.uint32(0), ref.uint32(0)
    gl.glGenVertexArrays(1, vaoId)
    gl.GenBuffers(1, positionId)
    gl.GenBuffers(1, colorId)
    vertexArray, positionBuffer, colorBuffer = vaoId.value, positionId.value, colorId.value
    assert(vertexArray ~= 0 and positionBuffer ~= 0 and colorBuffer ~= 0, "Cannot allocate geometry buffers")

    gl.glBindVertexArray(vertexArray)
    gl.BindBuffer(gl.BufferTarget.ArrayBuffer, positionBuffer)
    gl.VertexAttribPointer(0, 2, gl.VertexAttribPointerType.Float, false, 2 * 4, ToIntPtr(nullptr.void))
    gl.EnableVertexAttribArray(0)
    gl.BindBuffer(gl.BufferTarget.ArrayBuffer, colorBuffer)
    gl.VertexAttribPointer(1, 4, gl.VertexAttribPointerType.Float, false, 4 * 4, ToIntPtr(nullptr.void))
    gl.EnableVertexAttribArray(1)
    gl.Enable(gl.EnableCap.Blend)
    gl.glBlendFunc(0x0302, 0x0303) -- GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA
    assert(gl.GetError() == 0, "OpenGL geometry or blending setup failed")
end

local function present(width, height)
    if width <= 0 or height <= 0 then
        return
    end
    
    local scale = min(width / W, height / H)
    local vw, vh = floor(W * scale), floor(H * scale)
    
    gl.Viewport(0, 0, width, height)
    gl.ClearColor(0.025, 0.03, 0.05, 1)
    gl.Clear(gl.ClearBufferMask.ColorBufferBit)
    gl.Viewport(floor((width - vw) / 2), floor((height - vh) / 2), vw, vh)

    assert(canvas.count <= 2147483647 // (4 * 4), "triangle batch exceeds GL buffer size")
    
    local positions, colors = FloatList(), FloatList()
    positions:AddRange(canvas.positions)
    colors:AddRange(canvas.colors)
    assert(positions.Count == canvas.count * 2 and colors.Count == canvas.count * 4,
        "triangle attribute buffers have different lengths")
    
    local arrayBuffer = gl.BufferTarget.ArrayBuffer
    gl.BindBuffer(arrayBuffer, positionBuffer)
    gl.BufferData(arrayBuffer, int32.cast(positions.Count * 4), ToIntPtr(positions.Ptr), gl.BufferUsageHint.StreamDraw)
    gl.BindBuffer(arrayBuffer, colorBuffer)
    gl.BufferData(arrayBuffer, int32.cast(colors.Count * 4), ToIntPtr(colors.Ptr), gl.BufferUsageHint.StreamDraw)
    
    positions, colors = nil, nil
    
    gl.DrawArrays(gl.PrimitiveType.Triangles, 0, canvas.count)
    assert(gl.GetError() == 0, "OpenGL triangle batch failed")
    
    SDL.GL_SwapWindow(window)
end

function graphics.close()
    if gl then
        gl.UseProgram(0)
        if vertexArray and vertexArray ~= 0 then
            gl.glBindVertexArray(0)
            gl.glDeleteVertexArrays(1, vertexArray)
        end
        if positionBuffer and positionBuffer ~= 0 then
            gl.DeleteBuffers(1, positionBuffer)
        end
        if colorBuffer and colorBuffer ~= 0 then
            gl.DeleteBuffers(1, colorBuffer)
        end
        if program and program ~= 0 then
            gl.DeleteProgram(program)
        end
        for _, shader in ipairs(shaders) do
            gl.DeleteShader(shader)
        end
    end
    if context and context ~= 0 then
        SDL.GL_DeleteContext(context)
    end
    if window then
        SDL.DestroyWindow(window)
    end
end

graphics.open = setupGraphics
graphics.draw = drawGame
graphics.present = present
return graphics
