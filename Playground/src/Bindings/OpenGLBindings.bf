using System;
using BeefGL;

namespace LuaTinker.Playground;

static class OpenGLBindings
{
    public static void Register(LuaTinker tinker)
    {
        tinker.RegisterDelegate<delegate void*(String)>();
        using (let gl = tinker.BeginNamespace("BeefGL"))
        {
            gl.AutoTinkClass<GL, ?>(.Deep, .IncludeEnums, .Inline);
            // Texture parameter values are passed as integers, so discovery cannot find these enums.
            gl.AddEnum<BeefGL.Graphics.TextureWrapMode>();
            gl.AddEnum<BeefGL.Graphics.TextureMinFilter>();
            gl.AddEnum<BeefGL.Graphics.TextureMagFilter>();
            gl.AddMethod<function void(delegate void*(String))>("Init", => GL.Init<delegate void*(String)>);
        }
    }
}
