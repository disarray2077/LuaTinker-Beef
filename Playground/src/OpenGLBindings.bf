using System;
using SDL2;
using BeefGL;
using BeefGL.Graphics;

namespace LuaTinker.Playground;

static class OpenGLBindings
{
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

        tinker.RegisterDelegate<delegate void*(String)>();

        tinker.AddNamespaceMethod<function void(delegate void*(String))>("BeefGL.GL", "Init", => GL.Init<delegate void*(String)>);
    }
}
