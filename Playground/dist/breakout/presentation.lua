local M = {}
local opengl = require("modules.opengl")
local settings

local function assert_sdl(value)
    if not value then
        error(string.from_cstr(SDL.GetError()), 2)
    end
    return value
end

local window, context, gl, vertexArray, buffer, program
local shaders, programs, uniforms = {}, {}, {}

-- Mix_QuickLoad_RAW borrows the sample memory, so
-- keep each UInt8List alive for as long as its Mix_Chunk exists!
local mixer = SDLMixer
local audio = { opened = false, chunks = {}, buffers = {} }

local function synthesize(startHz, endHz, duration, volume)
    local samples = math.floor(44100 * duration)
    local bytes = UInt8List()

    for i = 0, samples - 1 do
        local t = i / 44100
        local phase = 2 * math.pi * (startHz * t + (endHz - startHz) * t * t / (2 * duration))
        local envelope = math.min(1, t / 0.004) * (1 - i / samples) ^ 2
        local sample = math.floor(32767 * volume * envelope * math.sin(phase))
        if sample < 0 then
            sample = sample + 65536
        end
        bytes:Add(sample % 256)
        bytes:Add(math.floor(sample / 256))
    end

    return bytes
end

local function openAudio()
    if SDL.InitSubSystem(SDL.InitFlag.Audio) < 0 then
        print("Breakout audio disabled: " .. string.from_cstr(SDL.GetError()))
        return
    end
    if mixer.OpenAudio(44100, 0x8010, 1, 1024) < 0 then
        print("Breakout audio disabled: " .. string.from_cstr(SDL.GetError()))
        return
    end

    audio.opened = true
    mixer.AllocateChannels(8)

    for _, sound in ipairs({
        { "launch", 420, 560, 0.06, 0.16 },
        { "wall", 430, 330, 0.045, 0.14 },
        { "paddle", 270, 410, 0.075, 0.22 },
        { "powerup", 600, 1050, 0.18, 0.21 },
        { "life", 330, 95, 0.28, 0.25 },
        { "win", 520, 1100, 0.38, 0.23 },
    }) do
        local name = sound[1]
        local bytes = synthesize(sound[2], sound[3], sound[4], sound[5])
        local chunk = mixer.QuickLoad_RAW(bytes.Ptr, bytes.Count)
        assert(chunk, "Cannot create Breakout sound " .. name .. ": " .. string.from_cstr(SDL.GetError()))
        audio.buffers[name] = bytes
        audio.chunks[name] = chunk
    end

    -- Pre-synthesize one brick/steel hit for each combo multiplier.
    for heat = 1, 8 do
        local t = (heat - 1) / 7
        local brickStart = 560 + 520 * t
        local brickEnd = 450 + 420 * t
        local brickDuration = 0.09 - 0.028 * t
        local brickVolume = 0.16 + 0.06 * t
        local steelStart = 260 + 230 * t
        local steelEnd = 170 + 180 * t
        local steelDuration = 0.11 - 0.025 * t
        local steelVolume = 0.15 + 0.045 * t

        for _, sound in ipairs({
            { "brickHot" .. heat, brickStart, brickEnd, brickDuration, brickVolume },
            { "steelHot" .. heat, steelStart, steelEnd, steelDuration, steelVolume },
        }) do
            local name = sound[1]
            local bytes = synthesize(sound[2], sound[3], sound[4], sound[5])
            local chunk = mixer.QuickLoad_RAW(bytes.Ptr, bytes.Count)
            assert(chunk, "Cannot create Breakout sound " .. name .. ": " .. string.from_cstr(SDL.GetError()))
            audio.buffers[name] = bytes
            audio.chunks[name] = chunk
        end
    end
end

function M.playSound(name)
    local chunk = audio.chunks[name]
    if chunk then
        mixer.PlayChannel(-1, chunk, 0)
    end
end

local function closeAudio()
    if not audio.opened then
        return
    end
    mixer.HaltChannel(-1)
    for name, chunk in pairs(audio.chunks) do
        mixer.FreeChunk(chunk)
        audio.chunks[name], audio.buffers[name] = nil, nil
    end
    mixer.CloseAudio()
    audio.opened = false
end

local function readFile(name)
    local path = settings.assetRoot .. "/shaders/" .. name
    local f, err = io.open(path, "rb")
    assert(f, "Cannot load shader " .. path .. ": " .. tostring(err))
    local source = f:read("*a")
    f:close()
    assert(not source:find("\0", 1, true), path .. " contains embedded NUL")
    return (WASM and "#version 300 es\nprecision highp float;\nprecision highp int;\n"
        or "#version 330 core\n") .. source
end

local function compileShader(kind, name)
    local shader = gl.CreateShader(kind)
    assert(shader ~= 0, "Could not create shader " .. name)
    shaders[#shaders + 1] = shader
    gl.ShaderSource(shader, 1, { readFile(name) .. "\0" }, nullptr.int32)
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
        error(name .. ": " .. tostring(log))
    end
    return shader
end

local function setupGraphics()
    local attr = SDL.SDL_GLAttr
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_MAJOR_VERSION, int32.cast(3)) == 0)
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_MINOR_VERSION, int32.cast(WASM and 0 or 3)) == 0)
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_PROFILE_MASK,
        WASM and SDL.SDL_GLProfile.GL_CONTEXT_PROFILE_ES or SDL.SDL_GLProfile.GL_CONTEXT_PROFILE_CORE) == 0)

    window = assert_sdl(SDL.CreateWindow("Breakout / Neon Remaster", 0, 0, settings.width, settings.height,
        SDL.WindowFlags.OpenGL | SDL.WindowFlags.Shown))
    context = SDL.GL_CreateContext(window)
    assert_sdl(context ~= 0)
    assert_sdl(SDL.GL_MakeCurrent(window, context) == 0)
    if settings.unrestricted then
        assert_sdl(SDL.GL_SetSwapInterval(0) == 0)
    end

    gl = BeefGL
    gl.Init(function(proc)
        return SDL.GL_GetProcAddress(proc)
    end)

    local missing = opengl.GetMissingRequiredFunction()
    assert(missing == "", "Missing OpenGL entry point: " .. missing)

    local vs = compileShader(gl.ShaderType.VertexShader, "scene.vert")
    local fs = compileShader(gl.ShaderType.FragmentShader, "scene.frag")
    program = gl.CreateProgram()
    assert(program ~= 0, "Could not create program")
    programs[#programs + 1] = program
    gl.AttachShader(program, vs)
    gl.AttachShader(program, fs)
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
        error("Program link failed: " .. tostring(log))
    end

    local function uniform(name)
        local location = gl.GetUniformLocation(program, name)
        assert(location >= 0, "Missing shader uniform: " .. name)
        return location
    end

    for _, name in ipairs({ "clockState", "paddle", "ball", "comboState", "levelState" }) do
        uniforms[name] = uniform(name)
    end

    for name, count in pairs({ bricks = 36, drops = 16, trail = 16, impacts = 8 }) do
        uniforms[name] = {}
        for i = 1, count do
            uniforms[name][i] = uniform(name .. "[" .. (i - 1) .. "]")
        end
    end

    local vao = ref.uint32(0)
    gl.glGenVertexArrays(1, vao)
    vertexArray = vao.value
    assert(vertexArray ~= 0, "Could not create VAO")
    gl.glBindVertexArray(vertexArray)

    local vertices = FloatList()
    vertices:AddRange({ -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5 })

    local id = ref.uint32(0)
    gl.GenBuffers(1, id)
    buffer = id.value
    assert(buffer ~= 0, "Could not create VBO")
    gl.BindBuffer(gl.BufferTarget.ArrayBuffer, buffer)
    gl.BufferData(gl.BufferTarget.ArrayBuffer, int32.cast(vertices.Count * 4),
        ToIntPtr(vertices.Ptr), gl.BufferUsageHint.StaticDraw)

    gl.VertexAttribPointer(0, 2, gl.VertexAttribPointerType.Float, false, 8, ToIntPtr(nullptr.void))
    gl.EnableVertexAttribArray(0)
    gl.BindBuffer(gl.BufferTarget.ArrayBuffer, 0)
    gl.Viewport(0, 0, settings.width, settings.height)
    assert(gl.GetError() == 0, "OpenGL setup failed")
end

function M.open(options)
    settings = options
    assert_sdl(SDL.Init(SDL.InitFlag.Video) == 0)
    setupGraphics()
    openAudio()
end

function M.draw(game, effects, trail, time)
    gl.UseProgram(program)
    gl.glBindVertexArray(vertexArray)
    gl.Uniform4(uniforms.clockState, float.cast(time), game.lives, game.score,
        game.transition > 0 and 2 or (game.gameOver and 1 or 0))
    gl.Uniform4(uniforms.comboState, float.cast(game.multiplier), game.comboTimer / settings.comboWindow, game.comboPulse, game.combo)
    gl.Uniform4(uniforms.levelState, float.cast(game.level), game.transition / 1.4, 0, 0)
    gl.Uniform4(uniforms.paddle, float.cast(game.paddleX), settings.paddleY, game.paddleWidth, settings.paddleHeight)
    gl.Uniform4(uniforms.ball, float.cast(game.ball.x), game.ball.y, settings.ballRadius, game.ballLaunched and 1 or 0)

    for i = 1, 36 do
        local b = game.bricks[i]
        gl.Uniform4(uniforms.bricks[i], float.cast(b and b.x or 0), b and b.y or 0, b and b.health or 0, b and b.flash or 0)
    end

    for i = 1, 16 do
        local p = game.powerUps[i]
        local t = trail[i]
        gl.Uniform4(uniforms.drops[i], float.cast(p and p.x or 0), p and p.y or 0, p and 1 or 0, 0)
        gl.Uniform4(uniforms.trail[i], float.cast(t and t.x or 0), t and t.y or 0, t and t.life or 0, 0)
    end

    for i = 1, 8 do
        local e = effects[i]
        gl.Uniform4(uniforms.impacts[i], float.cast(e and e.x or 0), e and e.y or 0, e and e.age or 0, e and e.strength or 0)
    end

    gl.DrawArrays(gl.PrimitiveType.TriangleFan, 0, 4)
    assert(gl.GetError() == 0, "OpenGL drawing failed: " .. gl.GetError())
    SDL.GL_SwapWindow(window)
end

function M.close()
    closeAudio()
    if gl then
        gl.UseProgram(0)
        if vertexArray and vertexArray ~= 0 then
            gl.glBindVertexArray(0)
            gl.glDeleteVertexArrays(1, vertexArray)
        end
        if buffer and buffer ~= 0 then
            gl.DeleteBuffers(1, buffer)
        end
        for _, p in ipairs(programs) do
            gl.DeleteProgram(p)
        end
        for _, s in ipairs(shaders) do
            gl.DeleteShader(s)
        end
    end
    if context and context ~= 0 then
        SDL.GL_DeleteContext(context)
    end
    if window then
        SDL.DestroyWindow(window)
    end
    SDL.Quit()
end

return M
