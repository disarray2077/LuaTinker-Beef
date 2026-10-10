using KeraLua;
using SDL2;
using StbImageBeef;

namespace LuaTinker.Playground;

static class ImageBindings
{
    public static void Register(LuaTinker tinker, Lua lua)
    {
        tinker.AutoTinkClass<SDLImage>();
        tinker.AddNamespaceEnum<SDLImage.InitFlags>("SDL2.SDLImage");
        lua.GetGlobal("SDL2");
        lua.GetField(-1, "SDLImage");
        lua.SetGlobal("SDLImage");
        lua.Pop(1);

        tinker.AutoTinkClass<ImageResult>();
        lua.GetGlobal("StbImageBeef");
        lua.SetGlobal("StbImage");
        tinker.AddNamespaceEnum<ColorComponents>("StbImage");
    }
}
