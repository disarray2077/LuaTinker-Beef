local requiredFunctions = {
    "glClearColor",
    "glClear",
    "glGetError",
    "glEnable",
    "glDisable",
    "glScissor",
    "glCreateShader",
    "glShaderSource",
    "glCompileShader",
    "glGetShaderiv",
    "glGetShaderInfoLog",
    "glDeleteShader",
    "glCreateProgram",
    "glAttachShader",
    "glLinkProgram",
    "glGetProgramiv",
    "glGetProgramInfoLog",
    "glUseProgram",
    "glDeleteProgram",
    "glGetUniformLocation",
    "glUniform2f",
    "glUniform4f",
    "glViewport",
    "glGenBuffers",
    "glBindBuffer",
    "glBufferData",
    "glDeleteBuffers",
    "glGenVertexArrays",
    "glBindVertexArray",
    "glDeleteVertexArrays",
    "glVertexAttribPointer",
    "glEnableVertexAttribArray",
    "glDisableVertexAttribArray",
    "glDrawArrays",
}

local opengl = {}

function opengl.GetMissingRequiredFunction()
    local gl = BeefGL.GL
    for _, name in ipairs(requiredFunctions) do
        if gl[name].IsNull then
            return name
        end
    end
    return ""
end

return opengl
