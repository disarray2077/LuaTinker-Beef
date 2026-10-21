using System;
using System.Collections;
using System.Interop;
using SDL2;
using LuaTinker.Helpers;

namespace LuaTinker.Playground;

struct TTFExclusions : IMethodExclusionProvider
{
    [Comptime]
    public static void CollectExcludedMethods(Type type, HashSet<StringView> excluded)
    {
        // The bundled wrapper returns a Version value instead of a pointer and misspells the kerning LinkName.
        excluded.Add("LinkedVersion");
        excluded.Add("GetFontKerningSize");

        // Several Unicode render declarations take char8* even though SDL_ttf expects UTF-16.
        for (let method in type.GetMethods(.Public | .DeclaredOnly))
            if (method.Name.StartsWith("RenderUNICODE_") && method.GetParamType(1) == typeof(char8*))
                excluded.Add(method.Name);

        // These declarations hardcode int32/int64 where SDL_ttf uses the platform's C long.
        if (sizeof(c_long) == sizeof(int32))
        {
            excluded.Add("OpenFontIndex");
            excluded.Add("OpenFontIndexRW");
            excluded.Add("FontFaces");
        }
        else
        {
            excluded.Add("OpenFontIndexDPI");
            excluded.Add("OpenFontIndexDPIRW");
        }
    }
}

static class FontBindings
{
    public static void Register(LuaTinker tinker)
    {
        using (let ttf = tinker.BeginNamespace("SDLTTF"))
        {
            ttf.AutoTinkClass<SDLTTF, TTFExclusions>(.Shallow, .Inline);
            ttf.AddVar("SDL_TTF_MAJOR_VERSION", SDLTTF.SDL_TTF_MAJOR_VERSION);
            ttf.AddVar("SDL_TTF_MINOR_VERSION", SDLTTF.SDL_TTF_MINOR_VERSION);
            ttf.AddVar("SDL_TTF_PATCHLEVEL", SDLTTF.SDL_TTF_PATCHLEVEL);
            ttf.AddVar("UNICODE_BOM_NATIVE", SDLTTF.UNICODE_BOM_NATIVE);
            ttf.AddVar("UNICODE_BOM_SWAPPED", SDLTTF.UNICODE_BOM_SWAPPED);
            ttf.AddVar("TTF_STYLE_NORMAL", SDLTTF.TTF_STYLE_NORMAL);
            ttf.AddVar("TTF_STYLE_BOLD", SDLTTF.TTF_STYLE_BOLD);
            ttf.AddVar("TTF_STYLE_ITALIC", SDLTTF.TTF_STYLE_ITALIC);
            ttf.AddVar("TTF_STYLE_UNDERLINE", SDLTTF.TTF_STYLE_UNDERLINE);
            ttf.AddVar("TTF_STYLE_STRIKETHROUGH", SDLTTF.TTF_STYLE_STRIKETHROUGH);
            ttf.AddVar("TTF_HINTING_NORMAL", SDLTTF.TTF_HINTING_NORMAL);
            ttf.AddVar("TTF_HINTING_LIGHT", SDLTTF.TTF_HINTING_LIGHT);
            ttf.AddVar("TTF_HINTING_MONO", SDLTTF.TTF_HINTING_MONO);
            ttf.AddVar("TTF_HINTING_NONE", SDLTTF.TTF_HINTING_NONE);
            ttf.AddVar("TTF_HINTING_LIGHT_SUBPIXEL", SDLTTF.TTF_HINTING_LIGHT_SUBPIXEL);
            ttf.AddVar("TTF_DIRECTION_LTR", SDLTTF.TTF_DIRECTION_LTR);
            ttf.AddVar("TTF_DIRECTION_RTL", SDLTTF.TTF_DIRECTION_RTL);
            ttf.AddVar("TTF_DIRECTION_TTB", SDLTTF.TTF_DIRECTION_TTB);
            ttf.AddVar("TTF_DIRECTION_BTT", SDLTTF.TTF_DIRECTION_BTT);
        }
    }
}
