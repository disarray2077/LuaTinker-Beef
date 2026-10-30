using SDL2;
using StbImageBeef;

namespace LuaTinker.Playground;

static class ImageBindings
{
    public static void Register(LuaTinker tinker)
    {
        using (let image = tinker.BeginNamespace("SDLImage"))
            image.AutoTinkClass<SDLImage, ?>(.Deep, .IncludeEnums, .Inline);
        using (let stb = tinker.BeginNamespace("StbImage"))
            stb.AutoTinkClass<ImageResult, ?>(.Deep, .IncludeEnums);
    }
}
