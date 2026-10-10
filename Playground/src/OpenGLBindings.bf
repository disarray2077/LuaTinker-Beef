using System;
using SDL2;
using BeefGL;
using BeefGL.Graphics;

namespace LuaTinker.Playground;

static class OpenGLBindings
{
    private static StringView InitGL()
    {
        GL.Init(scope (proc) => SDL.GL_GetProcAddress(proc));
        return GetMissingRequiredGLFunction();
    }

    private static StringView GetMissingRequiredGLFunction()
    {
        if (GL.glClearColor == null) return "glClearColor";
        if (GL.glClear == null) return "glClear";
        if (GL.glGetError == null) return "glGetError";
        if (GL.glEnable == null) return "glEnable";
        if (GL.glDisable == null) return "glDisable";
        if (GL.glScissor == null) return "glScissor";
        if (GL.glCreateShader == null) return "glCreateShader";
        if (GL.glShaderSource == null) return "glShaderSource";
        if (GL.glCompileShader == null) return "glCompileShader";
        if (GL.glGetShaderiv == null) return "glGetShaderiv";
        if (GL.glGetShaderInfoLog == null) return "glGetShaderInfoLog";
        if (GL.glDeleteShader == null) return "glDeleteShader";
        if (GL.glCreateProgram == null) return "glCreateProgram";
        if (GL.glAttachShader == null) return "glAttachShader";
        if (GL.glLinkProgram == null) return "glLinkProgram";
        if (GL.glGetProgramiv == null) return "glGetProgramiv";
        if (GL.glGetProgramInfoLog == null) return "glGetProgramInfoLog";
        if (GL.glUseProgram == null) return "glUseProgram";
        if (GL.glDeleteProgram == null) return "glDeleteProgram";
        if (GL.glGetUniformLocation == null) return "glGetUniformLocation";
        if (GL.glUniform2f == null) return "glUniform2f";
        if (GL.glUniform4f == null) return "glUniform4f";
        if (GL.glViewport == null) return "glViewport";
        if (GL.glGenBuffers == null) return "glGenBuffers";
        if (GL.glBindBuffer == null) return "glBindBuffer";
        if (GL.glBufferData == null) return "glBufferData";
        if (GL.glDeleteBuffers == null) return "glDeleteBuffers";
        if (GL.glGenVertexArrays == null) return "glGenVertexArrays";
        if (GL.glBindVertexArray == null) return "glBindVertexArray";
        if (GL.glDeleteVertexArrays == null) return "glDeleteVertexArrays";
        if (GL.glVertexAttribPointer == null) return "glVertexAttribPointer";
        if (GL.glEnableVertexAttribArray == null) return "glEnableVertexAttribArray";
        if (GL.glDisableVertexAttribArray == null) return "glDisableVertexAttribArray";
        if (GL.glDrawArrays == null) return "glDrawArrays";
        return default;
    }

    public static void Register(LuaTinker tinker)
    {
        tinker.AutoTinkClass<GL>();
        tinker.AddNamespaceEnum<ClearBufferMask>("BeefGL.GL");
        tinker.AddNamespaceEnum<EnableCap>("BeefGL.GL");
        tinker.AddNamespaceEnum<ShaderType>("BeefGL.GL");
        tinker.AddNamespaceEnum<BlendingFactorSrc>("BeefGL.GL");
        tinker.AddNamespaceEnum<BlendingFactorDest>("BeefGL.GL");
        tinker.AddNamespaceEnum<ShaderParameter>("BeefGL.GL");
        tinker.AddNamespaceEnum<GetProgramParameterName>("BeefGL.GL");
        tinker.AddNamespaceEnum<BufferTarget>("BeefGL.GL");
        tinker.AddNamespaceEnum<BufferUsageHint>("BeefGL.GL");
        tinker.AddNamespaceEnum<BufferParameterName>("BeefGL.GL");
        tinker.AddNamespaceEnum<CullFaceMode>("BeefGL.GL");
        tinker.AddNamespaceEnum<PrimitiveType>("BeefGL.GL");
        tinker.AddNamespaceEnum<VertexAttribPointerType>("BeefGL.GL");
        tinker.AddNamespaceEnum<TextureTarget>("BeefGL.GL");
        tinker.AddNamespaceEnum<TextureParameterName>("BeefGL.GL");
        tinker.AddNamespaceEnum<TextureWrapMode>("BeefGL.GL");
        tinker.AddNamespaceEnum<TextureMinFilter>("BeefGL.GL");
        tinker.AddNamespaceEnum<TextureMagFilter>("BeefGL.GL");
        tinker.AddNamespaceEnum<TextureUnit>("BeefGL.GL");
        tinker.AddNamespaceEnum<TextureComponentCount>("BeefGL.GL");
        tinker.AddNamespaceEnum<PixelInternalFormat>("BeefGL.GL");
        tinker.AddNamespaceEnum<PixelFormat>("BeefGL.GL");
        tinker.AddNamespaceEnum<PixelType>("BeefGL.GL");
        tinker.AddNamespaceEnum<PixelStoreParameter>("BeefGL.GL");
        tinker.AddNamespaceMethod<function StringView()>("BeefGL.GL", "InitGL", => InitGL);
    }
}
