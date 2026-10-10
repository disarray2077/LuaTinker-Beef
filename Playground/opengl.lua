local function assert_sdl(value)
    if not value then
        error(string.from_cstr(SDL.GetError()), 2)
    end
    return value
end

assert_sdl(SDL.Init(SDL.InitFlag.Video) == 0)

local window
local context
local gl
local shaders = {}
local program
local buffer
local vertexArray
local frames = 0

local function compileShader(shaderType, source, stageName)
    assert(source:find("\0", 1, true) == nil,
        stageName .. " shader source contains embedded NUL byte")

    local sources = { source .. "\0" }

    local shader = gl.CreateShader(shaderType)
    assert(shader ~= 0, "Could not create " .. stageName .. " shader")
    shaders[#shaders + 1] = shader

    gl.ShaderSource(shader, #sources, sources, nullptr.int32)
    gl.CompileShader(shader)

    local compileStatus = ref.int32(0)
    gl.GetShader(shader, gl.ShaderParameter.CompileStatus, compileStatus)
    if compileStatus.value == 0 then
        local infoLogLength = ref.int32(0)
        gl.GetShader(shader, gl.ShaderParameter.InfoLogLength, infoLogLength)

        local infoLog = StringBuilder()
        local infoLogWritten = ref.int32(0)
        if infoLogLength.value > 0 then
            gl.GetShaderInfoLog(shader, infoLogLength.value, infoLogWritten, infoLog)
        end

        local message = stageName .. " shader compilation failed (CompileStatus=0)"
        local logText = tostring(infoLog)
        if logText ~= "" then message = message .. ": " .. logText end
        error(message)
    end

    return shader
end

local function linkProgram(vertexShader, fragmentShader)
    program = gl.CreateProgram()
    assert(program ~= 0, "Could not create shader program")
    gl.AttachShader(program, vertexShader)
    gl.AttachShader(program, fragmentShader)
    gl.LinkProgram(program)

    local linkStatus = ref.int32(0)
    gl.GetProgram(program, gl.GetProgramParameterName.LinkStatus, linkStatus)
    if linkStatus.value == 0 then
        local infoLogLength = ref.int32(0)
        gl.GetProgram(program, gl.GetProgramParameterName.InfoLogLength, infoLogLength)

        local infoLog = StringBuilder()
        local infoLogWritten = ref.int32(0)
        if infoLogLength.value > 0 then
            gl.GetProgramInfoLog(program, infoLogLength.value, infoLogWritten, infoLog)
        end

        local message = "shader program link failed (LinkStatus=0)"
        local logText = tostring(infoLog)
        if logText ~= "" then message = message .. ": " .. logText end
        error(message)
    end

    gl.UseProgram(program)
end

local function initShaders()
    local glsl = "#version 330 core\n"
    local vertexSource = glsl .. [[
layout(location = 0) in vec2 localPosition;
uniform vec2 position;
void main() {
    gl_Position = vec4(localPosition + position, 0.0, 1.0);
}
]]
    local fragmentSource = glsl .. [[
out vec4 fragmentColor;
void main() {
    fragmentColor = vec4(0.95, 0.7, 0.25, 1.0);
}
]]
    local vertexShader = compileShader(gl.ShaderType.VertexShader, vertexSource, "vertex")
    local fragmentShader = compileShader(gl.ShaderType.FragmentShader, fragmentSource, "fragment")
    linkProgram(vertexShader, fragmentShader)

    local positionLocation = gl.GetUniformLocation(program, "position")
    assert(positionLocation >= 0, "Shader has no position uniform")
    return positionLocation
end

local function initBuffers(width, height, rectSize)
    local vertexArrayId = ref.uint32(0)
    gl.glGenVertexArrays(1, vertexArrayId)
    vertexArray = vertexArrayId.value
    assert(vertexArray ~= 0, "Could not create vertex array")
    gl.glBindVertexArray(vertexArray)

    local halfWidth, halfHeight = rectSize / width, rectSize / height
    local vertices = FloatList()
    vertices:AddRange({
        -halfWidth, -halfHeight, halfWidth, -halfHeight,
        halfWidth, halfHeight, -halfWidth, halfHeight
    })
    local byteSize = vertices.Count * 4

    local bufferId = ref.uint32(0)
    gl.GenBuffers(1, bufferId)
    buffer = bufferId.value
    assert(buffer ~= 0, "Could not create vertex buffer")

    local arrayBuffer = gl.BufferTarget.ArrayBuffer
    gl.BindBuffer(arrayBuffer, buffer)
    gl.BufferData(arrayBuffer, int32.cast(byteSize), ToIntPtr(vertices.Ptr), gl.BufferUsageHint.StaticDraw)
    vertices = nil -- BufferData copied the source; only the GL buffer is used while drawing.

    local bufferSize = ref.int32(0)
    gl.GetBufferParameter(arrayBuffer, gl.BufferParameterName.BufferSize, bufferSize)
    assert(bufferSize.value == byteSize, "Vertex buffer upload has wrong byte size")

    gl.VertexAttribPointer(0, 2, gl.VertexAttribPointerType.Float, false, 2 * 4, ToIntPtr(nullptr.void))
    gl.EnableVertexAttribArray(0)

    gl.BindBuffer(arrayBuffer, 0)
end

local function run()
    local width, height = 640, 480
    local attr = SDL.SDL_GLAttr
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_MAJOR_VERSION, int32.cast(3)) == 0)
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_MINOR_VERSION, int32.cast(3)) == 0)
    assert_sdl(SDL.GL_SetAttribute(attr.GL_CONTEXT_PROFILE_MASK, SDL.SDL_GLProfile.GL_CONTEXT_PROFILE_CORE) == 0)

    window = assert_sdl(SDL.CreateWindow("LuaTinker OpenGL", SDL.WindowPos.Centered, SDL.WindowPos.Centered,
        width, height, SDL.WindowFlags.OpenGL | SDL.WindowFlags.Shown))
    context = SDL.GL_CreateContext(window)
    assert_sdl(context ~= 0)
    assert_sdl(SDL.GL_MakeCurrent(window, context) == 0)

    gl = BeefGL.GL
    local missing = gl.InitGL()
    assert(missing == "", "Missing required OpenGL entry point: " .. missing)

    local positionLocation = initShaders()
    local rectSize = 48
    initBuffers(width, height, rectSize)

    gl.Viewport(0, 0, width, height)

    assert(gl.GetError() == 0, "OpenGL vertex setup failed")

    local clearMask = gl.ClearBufferMask.ColorBufferBit

    local x, y = (width - rectSize) / 2, (height - rectSize) / 2 -- OpenGL's origin is at the bottom left.
    local speed = 280
    local left, right, up, down = false, false, false, false
    local event = SDL.Event()
    local previous = SDL.GetTicks()
    local running = true
    local max_frames = tonumber(os.getenv("PLAYGROUND_MAX_FRAMES"))

    while running and (not max_frames or frames < max_frames) do
        while SDL.PollEvent(event) ~= 0 do
            if event.type == SDL.EventType.Quit then
                running = false
            elseif event.type == SDL.EventType.KeyDown or event.type == SDL.EventType.KeyUp then
                local key = event.key.keysym.sym
                local pressed = event.type == SDL.EventType.KeyDown
                if key == SDL.Keycode.ESCAPE and pressed then running = false end
                if key == SDL.Keycode.LEFT then left = pressed end
                if key == SDL.Keycode.RIGHT then right = pressed end
                if key == SDL.Keycode.UP then up = pressed end
                if key == SDL.Keycode.DOWN then down = pressed end
            end
        end

        local now = SDL.GetTicks()
        local dt = (now - previous) / 1000
        previous = now
        x = math.max(0, math.min(width - rectSize, x + ((right and 1 or 0) - (left and 1 or 0)) * speed * dt))
        y = math.max(0, math.min(height - rectSize, y + ((up and 1 or 0) - (down and 1 or 0)) * speed * dt))

        gl.ClearColor(0.1, 0.2, 0.35, 1.0)
        gl.Clear(clearMask)
        gl.Uniform2(positionLocation,
            float.cast((x + rectSize / 2) * 2 / width - 1),
            float.cast((y + rectSize / 2) * 2 / height - 1))
        gl.DrawArrays(gl.PrimitiveType.TriangleFan, 0, 4)
        assert(gl.GetError() == 0, "OpenGL drawing failed")
        
        SDL.GL_SwapWindow(window)
        SDL.Delay(16)

        frames = frames + 1
    end
end

local ok, err = xpcall(run, debug.traceback)

if gl and program and program ~= 0 then
    gl.UseProgram(0)
    gl.DeleteProgram(program)
end
if gl and vertexArray and vertexArray ~= 0 then
    gl.glBindVertexArray(0)
    gl.glDeleteVertexArrays(1, ref.uint32(vertexArray))
end
if gl and buffer and buffer ~= 0 then
    gl.DeleteBuffers(1, ref.uint32(buffer))
end
if gl then
    for _, shader in ipairs(shaders) do
        if shader ~= 0 then gl.DeleteShader(shader) end
    end
end

if context and context ~= 0 then SDL.GL_DeleteContext(context) end
if window then SDL.DestroyWindow(window) end
SDL.Quit()

if not ok then error(err) end
print("OpenGL playground exited after " .. frames .. " frames")
